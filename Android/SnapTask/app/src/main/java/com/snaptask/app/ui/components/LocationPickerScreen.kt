package com.snaptask.app.ui.components

import android.content.Context
import android.location.Geocoder
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalContext
import com.snaptask.app.R
import com.snaptask.app.data.model.TaskLocation
import com.snaptask.app.data.model.TaskPlacemark
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

/**
 * Faithful port of iOS LocationPickerView.
 * Allows searching for locations and selecting them for tasks.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationPickerScreen(
    initialLocation: TaskLocation? = null,
    onLocationSelected: (TaskLocation?) -> Unit,
    onDismiss: () -> Unit,
) {
    var searchText by remember { mutableStateOf("") }
    var selectedLocation by remember { mutableStateOf(initialLocation) }
    var isSearching by remember { mutableStateOf(false) }
    var searchResults by remember { mutableStateOf<List<TaskLocation>>(emptyList()) }
    val context = LocalContext.current

    // Android's system geocoder provides a real, keyless place search. Calls run
    // off the main thread because individual geocoder providers may use network IO.
    LaunchedEffect(searchText) {
        if (searchText.length >= 2) {
            isSearching = true
            searchResults = searchLocations(context, searchText)
            isSearching = false
        } else {
            searchResults = emptyList()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.select_location), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.action_cancel))
                    }
                },
                actions = {
                    TextButton(onClick = { onLocationSelected(selectedLocation) }) {
                        Text(stringResource(R.string.action_done))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Search field
            SearchField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = stringResource(R.string.search_for_a_place),
                onClear = {
                    searchText = ""
                    searchResults = emptyList()
                },
            )

            when {
                isSearching -> {
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    }
                }

                searchResults.isNotEmpty() -> {
                    Text(
                        stringResource(R.string.search_results),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(searchResults) { location ->
                            LocationResultRow(
                                location = location,
                                onClick = {
                                    selectedLocation = location
                                    searchText = ""
                                    searchResults = emptyList()
                                },
                            )
                        }
                    }
                }

                searchText.isNotBlank() && !isSearching -> {
                    Text(
                        stringResource(R.string.no_results_found),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                selectedLocation != null -> {
                    SelectedLocationCard(
                        location = selectedLocation!!,
                        onRemove = { selectedLocation = null },
                    )
                }
            }

            if (selectedLocation == null && searchText.isBlank()) {
                Text(
                    stringResource(R.string.location_picker_hint),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    onClear: () -> Unit,
) {
    val containerColor = MaterialTheme.colorScheme.surface

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(containerColor)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            Icons.Default.Search,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(20.dp),
        )
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f),
            singleLine = true,
            decorationBox = { innerTextField ->
                Box {
                    if (value.isBlank()) {
                        Text(
                            placeholder,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    innerTextField()
                }
            },
        )
        if (value.isNotBlank()) {
            IconButton(
                onClick = onClear,
                modifier = Modifier.size(20.dp),
            ) {
                Icon(
                    Icons.Default.Clear,
                    contentDescription = stringResource(R.string.action_clear),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@Composable
private fun LocationResultRow(
    location: TaskLocation,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Default.LocationOn,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(24.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                location.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            location.address?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
private fun SelectedLocationCard(
    location: TaskLocation,
    onRemove: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f))
            .border(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                Icons.Default.LocationOn,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.selected_location),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    location.displayName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                location.address?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        OutlinedButton(
            onClick = onRemove,
            modifier = Modifier.align(Alignment.End),
        ) {
            Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text(stringResource(R.string.remove_location))
        }
    }
}

private suspend fun searchLocations(context: Context, query: String): List<TaskLocation> =
    withContext(Dispatchers.IO) {
        if (!Geocoder.isPresent()) return@withContext emptyList()

        runCatching {
            @Suppress("DEPRECATION")
            Geocoder(context, Locale.getDefault()).getFromLocationName(query, 10)
                .orEmpty()
                .map { address ->
                    val name = address.featureName
                        ?: address.getAddressLine(0)
                        ?: query
                    val formattedAddress = (0..address.maxAddressLineIndex)
                        .mapNotNull(address::getAddressLine)
                        .joinToString(", ")
                        .takeIf { it.isNotBlank() }
                    TaskLocation(
                        name = name,
                        address = formattedAddress,
                        latitude = address.takeIf { it.hasLatitude() }?.latitude,
                        longitude = address.takeIf { it.hasLongitude() }?.longitude,
                        placemark = TaskPlacemark(
                            name = name,
                            thoroughfare = address.thoroughfare,
                            locality = address.locality,
                            administrativeArea = address.adminArea,
                            country = address.countryName,
                            postalCode = address.postalCode,
                        ),
                    )
                }
        }.getOrDefault(emptyList())
    }
