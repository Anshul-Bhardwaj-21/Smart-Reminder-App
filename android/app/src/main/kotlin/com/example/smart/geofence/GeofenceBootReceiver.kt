package com.example.smart.geofence

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }

        val fineGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED

        if (!fineGranted) return

        val needsBackground = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val backgroundGranted = !needsBackground || ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        if (needsBackground && !backgroundGranted) return

        val geofences = GeofenceStore.listAll(context)
        if (geofences.isEmpty()) return

        val pendingResult = goAsync()

        val geofencingClient = LocationServices.getGeofencingClient(context)
        val requestBuilder = GeofencingRequest.Builder()
        for (stored in geofences) {
            val transitionTypes = when (stored.triggerType) {
                "locationExit" -> Geofence.GEOFENCE_TRANSITION_EXIT
                "locationEnter" -> Geofence.GEOFENCE_TRANSITION_ENTER
                else -> Geofence.GEOFENCE_TRANSITION_ENTER
            }

            requestBuilder.addGeofence(
                Geofence.Builder()
                    .setRequestId(stored.id)
                    .setCircularRegion(stored.latitude, stored.longitude, stored.radiusMeters.toFloat())
                    .setTransitionTypes(transitionTypes)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .build()
            )
        }

        val request = requestBuilder.build()
        val pendingIntent = GeofenceIntents.getGeofencePendingIntent(context)

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnCompleteListener {
                pendingResult.finish()
            }
    }
}

