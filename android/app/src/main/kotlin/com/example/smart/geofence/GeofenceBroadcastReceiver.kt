package com.example.smart.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return

        val transition = event.geofenceTransition
        val triggeringGeofences = event.triggeringGeofences ?: return

        for (geofence in triggeringGeofences) {
            val id = geofence.requestId
            val stored = GeofenceStore.get(context, id)

            val title = stored?.title ?: "Location reminder"
            val locationName = stored?.locationName ?: "a location"

            val fallbackBody = when (transition) {
                Geofence.GEOFENCE_TRANSITION_EXIT -> "Left $locationName"
                Geofence.GEOFENCE_TRANSITION_ENTER -> "Arrived near $locationName"
                else -> "Location update for $locationName"
            }

            val body = stored?.body?.takeIf { it.isNotBlank() } ?: fallbackBody
            GeofenceNotificationHelper.show(context, id, title, body)
        }
    }
}

