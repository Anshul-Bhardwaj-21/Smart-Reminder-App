package com.example.smart.geofence

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object GeofenceIntents {
    private const val requestCode = 9331

    fun getGeofencePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java).apply {
            action = "com.example.smart.GEOFENCE_EVENT"
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }

        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}

