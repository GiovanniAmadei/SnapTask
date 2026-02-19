package com.snaptask.app.data.model

import java.util.UUID

/**
 * Location attached to a task, matching iOS TaskLocation struct.
 */
data class TaskLocation(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val address: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val placemark: TaskPlacemark? = null,
) {
    val displayName: String
        get() = if (!address.isNullOrBlank()) "$name - $address" else name

    val shortDisplayName: String
        get() = name

    val hasCoordinate: Boolean
        get() = latitude != null && longitude != null
}

/**
 * Simplified placemark data, matching iOS TaskPlacemark struct.
 */
data class TaskPlacemark(
    val name: String? = null,
    val thoroughfare: String? = null,
    val locality: String? = null,
    val administrativeArea: String? = null,
    val country: String? = null,
    val postalCode: String? = null,
) {
    val formattedAddress: String
        get() = listOfNotNull(thoroughfare, locality, administrativeArea)
            .joinToString(", ")
}
