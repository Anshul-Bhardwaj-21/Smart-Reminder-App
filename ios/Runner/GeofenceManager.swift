import CoreLocation
import Flutter
import Foundation
import UserNotifications

final class GeofenceManager: NSObject, CLLocationManagerDelegate {
  static let shared = GeofenceManager()

  private let locationManager = CLLocationManager()
  private var methodChannel: FlutterMethodChannel?
  private var pendingPermissionResult: FlutterResult?

  private let idsKey = "smart_reminder_geofence_ids"

  private override init() {
    super.init()
    locationManager.delegate = self
  }

  func setUp(channel: FlutterMethodChannel) {
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self))
    case "getPermissionStatus":
      result(permissionStatusString())
    case "requestPermissions":
      requestAlwaysPermission(result: result)
    case "addGeofence":
      addGeofence(call: call, result: result)
    case "removeGeofence":
      removeGeofence(call: call, result: result)
    case "clearGeofences":
      clearGeofences(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  private func permissionStatusString() -> String {
    switch authorizationStatus() {
    case .notDetermined:
      return "notDetermined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorizedWhenInUse:
      return "whenInUse"
    case .authorizedAlways:
      return "always"
    @unknown default:
      return "unknown"
    }
  }

  private func requestAlwaysPermission(result: @escaping FlutterResult) {
    let status = authorizationStatus()

    if status == .authorizedAlways {
      result("always")
      return
    }

    if status == .denied || status == .restricted {
      result(permissionStatusString())
      return
    }

    pendingPermissionResult = result
    locationManager.requestAlwaysAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let pending = pendingPermissionResult else { return }
    let status = authorizationStatus()
    if status == .notDetermined { return }
    pendingPermissionResult = nil
    pending(permissionStatusString())
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    guard let pending = pendingPermissionResult else { return }
    if status == .notDetermined { return }
    pendingPermissionResult = nil
    pending(permissionStatusString())
  }

  private func addGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "ARGUMENT", message: "Missing arguments", details: nil))
      return
    }

    guard let id = args["id"] as? String, !id.isEmpty,
          let latitude = args["latitude"] as? Double,
          let longitude = args["longitude"] as? Double,
          let radiusMeters = args["radiusMeters"] as? Double
    else {
      result(FlutterError(code: "ARGUMENT", message: "Missing required geofence arguments", details: nil))
      return
    }

    if authorizationStatus() != .authorizedAlways {
      result(FlutterError(code: "PERMISSION", message: "Location permission not granted", details: nil))
      return
    }

    let triggerType = (args["triggerType"] as? String) ?? "locationEnter"
    let locationName = args["locationName"] as? String
    let title = (args["title"] as? String) ?? "Reminder"
    let body = (args["body"] as? String) ?? "Reminder"

    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let radius = min(max(radiusMeters, 50), 1000)
    let region = CLCircularRegion(center: center, radius: radius, identifier: id)
    region.notifyOnEntry = triggerType != "locationExit"
    region.notifyOnExit = triggerType == "locationExit"

    locationManager.startMonitoring(for: region)

    saveMetadata(
      id: id,
      data: [
        "id": id,
        "latitude": latitude,
        "longitude": longitude,
        "radiusMeters": radius,
        "triggerType": triggerType,
        "locationName": locationName ?? "",
        "title": title,
        "body": body,
      ]
    )

    result(true)
  }

  private func removeGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          !id.isEmpty
    else {
      result(FlutterError(code: "ARGUMENT", message: "Missing geofence id", details: nil))
      return
    }

    for region in locationManager.monitoredRegions where region.identifier == id {
      locationManager.stopMonitoring(for: region)
    }

    removeMetadata(id: id)
    result(true)
  }

  private func clearGeofences(result: @escaping FlutterResult) {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }

    clearMetadata()
    result(true)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    showNotification(for: region.identifier, transition: "enter")
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    showNotification(for: region.identifier, transition: "exit")
  }

  private func showNotification(for geofenceId: String, transition: String) {
    let meta = loadMetadata(id: geofenceId)
    let title = (meta?["title"] as? String) ?? "Location reminder"

    let storedLocationName = (meta?["locationName"] as? String) ?? ""
    let locationName = storedLocationName.isEmpty ? "a location" : storedLocationName
    let triggerType = (meta?["triggerType"] as? String) ?? "locationEnter"
    let storedBody = (meta?["body"] as? String) ?? ""

    let fallbackBody: String
    if transition == "exit" || triggerType == "locationExit" {
      fallbackBody = "Left \(locationName)"
    } else {
      fallbackBody = "Arrived near \(locationName)"
    }

    let body = storedBody.isEmpty ? fallbackBody : storedBody

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["reminderId": geofenceId]

    let request = UNNotificationRequest(
      identifier: "geofence-\(geofenceId)-\(Date().timeIntervalSince1970)",
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  private func saveMetadata(id: String, data: [String: Any]) {
    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
      let jsonString = String(data: jsonData, encoding: .utf8)
      UserDefaults.standard.setValue(jsonString, forKey: id)

      var ids = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
      if !ids.contains(id) {
        ids.append(id)
        UserDefaults.standard.setValue(ids, forKey: idsKey)
      }
    }
  }

  private func loadMetadata(id: String) -> [String: Any]? {
    guard let jsonString = UserDefaults.standard.string(forKey: id),
          let data = jsonString.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data, options: []),
          let dict = obj as? [String: Any]
    else {
      return nil
    }

    return dict
  }

  private func removeMetadata(id: String) {
    UserDefaults.standard.removeObject(forKey: id)

    var ids = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
    ids.removeAll(where: { $0 == id })
    UserDefaults.standard.setValue(ids, forKey: idsKey)
  }

  private func clearMetadata() {
    let ids = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
    for id in ids {
      UserDefaults.standard.removeObject(forKey: id)
    }
    UserDefaults.standard.setValue([], forKey: idsKey)
  }
}
