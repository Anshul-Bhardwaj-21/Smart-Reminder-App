package com.example.smart

import android.Manifest
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.example.smart.geofence.GeofenceIntents
import com.example.smart.geofence.GeofenceStore
import com.example.smart.geofence.StoredGeofence
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val geofenceChannelName = "smart_reminder/geofence"

    private lateinit var geofenceChannel: MethodChannel
    private val geofencingClient by lazy { LocationServices.getGeofencingClient(this) }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var fineLocationLauncher: ActivityResultLauncher<Array<String>>
    private lateinit var backgroundLocationLauncher: ActivityResultLauncher<String>

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        fineLocationLauncher = registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { _ ->
            if (!hasFineLocationPermission()) {
                finishPermissionRequest()
                return@registerForActivityResult
            }

            if (needsBackgroundLocationPermission() && !hasBackgroundLocationPermission()) {
                backgroundLocationLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                return@registerForActivityResult
            }

            finishPermissionRequest()
        }

        backgroundLocationLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { _ ->
            finishPermissionRequest()
        }

        geofenceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, geofenceChannelName)
        geofenceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(true)
                "getPermissionStatus" -> result.success(permissionStatus())
                "requestPermissions" -> requestPermissions(result)
                "addGeofence" -> addGeofence(call, result)
                "removeGeofence" -> removeGeofence(call, result)
                "clearGeofences" -> clearGeofences(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("BUSY", "Permission request already in progress", null)
            return
        }

        pendingPermissionResult = result

        if (!hasFineLocationPermission()) {
            fineLocationLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
            return
        }

        if (needsBackgroundLocationPermission() && !hasBackgroundLocationPermission()) {
            backgroundLocationLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            return
        }

        finishPermissionRequest()
    }

    private fun finishPermissionRequest() {
        pendingPermissionResult?.success(permissionStatus())
        pendingPermissionResult = null
    }

    private fun permissionStatus(): String {
        if (!hasFineLocationPermission()) return "denied"
        if (needsBackgroundLocationPermission() && !hasBackgroundLocationPermission()) return "whenInUse"
        return "always"
    }

    private fun needsBackgroundLocationPermission(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }

    private fun hasFineLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun hasBackgroundLocationPermission(): Boolean {
        if (!needsBackgroundLocationPermission()) return true
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun addGeofence(call: MethodCall, result: MethodChannel.Result) {
        if (!hasFineLocationPermission()) {
            result.error("PERMISSION", "Location permission not granted", null)
            return
        }

        val id = call.argument<String>("id")
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        val radiusMeters = call.argument<Double>("radiusMeters")
        val triggerType = call.argument<String>("triggerType")
        val locationName = call.argument<String>("locationName")
        val title = call.argument<String>("title") ?: "Reminder"
        val body = call.argument<String>("body") ?: "Reminder"

        if (id.isNullOrBlank() || latitude == null || longitude == null || radiusMeters == null) {
            result.error("ARGUMENT", "Missing required geofence arguments", null)
            return
        }

        val transitionTypes = when (triggerType) {
            "locationExit" -> Geofence.GEOFENCE_TRANSITION_EXIT
            "locationEnter" -> Geofence.GEOFENCE_TRANSITION_ENTER
            else -> Geofence.GEOFENCE_TRANSITION_ENTER
        }

        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radiusMeters.toFloat())
            .setTransitionTypes(transitionTypes)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .addGeofence(geofence)
            .build()

        val pendingIntent = GeofenceIntents.getGeofencePendingIntent(this)

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener {
                GeofenceStore.save(
                    this,
                    StoredGeofence(
                        id = id,
                        latitude = latitude,
                        longitude = longitude,
                        radiusMeters = radiusMeters,
                        triggerType = triggerType ?: "locationEnter",
                        locationName = locationName,
                        title = title,
                        body = body,
                    )
                )
                result.success(true)
            }
            .addOnFailureListener { e ->
                result.error("ADD_FAILED", e.message, null)
            }
    }

    private fun removeGeofence(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("ARGUMENT", "Missing geofence id", null)
            return
        }

        geofencingClient.removeGeofences(listOf(id))
            .addOnSuccessListener {
                GeofenceStore.remove(this, id)
                result.success(true)
            }
            .addOnFailureListener { e ->
                result.error("REMOVE_FAILED", e.message, null)
            }
    }

    private fun clearGeofences(result: MethodChannel.Result) {
        val pendingIntent = GeofenceIntents.getGeofencePendingIntent(this)
        geofencingClient.removeGeofences(pendingIntent)
            .addOnSuccessListener {
                GeofenceStore.clear(this)
                result.success(true)
            }
            .addOnFailureListener { e ->
                result.error("CLEAR_FAILED", e.message, null)
            }
    }
}
