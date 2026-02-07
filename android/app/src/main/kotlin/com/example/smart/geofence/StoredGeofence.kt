package com.example.smart.geofence

data class StoredGeofence(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double,
    val triggerType: String,
    val locationName: String?,
    val title: String,
    val body: String,
)

