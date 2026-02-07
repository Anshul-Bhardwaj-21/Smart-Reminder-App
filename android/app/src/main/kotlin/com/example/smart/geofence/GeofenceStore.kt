package com.example.smart.geofence

import android.content.Context
import org.json.JSONObject

object GeofenceStore {
    private const val prefsName = "smart_reminder_geofences"
    private const val keyIds = "ids"

    fun save(context: Context, geofence: StoredGeofence) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(keyIds, emptySet())?.toMutableSet() ?: mutableSetOf()
        ids.add(geofence.id)

        val json = JSONObject()
            .put("id", geofence.id)
            .put("latitude", geofence.latitude)
            .put("longitude", geofence.longitude)
            .put("radiusMeters", geofence.radiusMeters)
            .put("triggerType", geofence.triggerType)
            .put("locationName", geofence.locationName)
            .put("title", geofence.title)
            .put("body", geofence.body)
            .toString()

        prefs.edit()
            .putStringSet(keyIds, ids)
            .putString(geofence.id, json)
            .apply()
    }

    fun get(context: Context, id: String): StoredGeofence? {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val jsonString = prefs.getString(id, null) ?: return null
        return try {
            val json = JSONObject(jsonString)
            StoredGeofence(
                id = json.optString("id", id),
                latitude = json.optDouble("latitude", 0.0),
                longitude = json.optDouble("longitude", 0.0),
                radiusMeters = json.optDouble("radiusMeters", 150.0),
                triggerType = json.optString("triggerType", "locationEnter"),
                locationName = json.optString("locationName", null),
                title = json.optString("title", "Reminder"),
                body = json.optString("body", "Reminder"),
            )
        } catch (_: Throwable) {
            null
        }
    }

    fun listAll(context: Context): List<StoredGeofence> {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(keyIds, emptySet()) ?: emptySet()
        return ids.mapNotNull { get(context, it) }
    }

    fun remove(context: Context, id: String) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(keyIds, emptySet())?.toMutableSet() ?: mutableSetOf()
        ids.remove(id)

        prefs.edit()
            .putStringSet(keyIds, ids)
            .remove(id)
            .apply()
    }

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
    }
}

