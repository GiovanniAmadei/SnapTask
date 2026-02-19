package com.snaptask.app.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R

/**
 * Eisenhower Matrix settings: "Consider urgent within X hours" for today's tasks.
 * Matches iOS Eisenhower settings in ThemesAndCustomization / Behavior.
 */
@Composable
fun EisenhowerSettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel(),
    onDismiss: () -> Unit,
) {
    val urgentHours by viewModel.eisenhowerTodayUrgentHours.collectAsState()
    var sliderHours by remember(urgentHours) { mutableIntStateOf(urgentHours) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
    ) {
        Text(
            text = stringResource(R.string.settings_eisenhower),
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.settings_eisenhower_urgent_hours_desc),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.settings_eisenhower_urgent_hours_value, sliderHours),
            style = MaterialTheme.typography.titleMedium,
        )
        Slider(
            value = sliderHours.toFloat(),
            onValueChange = { sliderHours = it.toInt().coerceIn(1, 24) },
            valueRange = 1f..24f,
            steps = 22,
            onValueChangeFinished = { viewModel.setEisenhowerTodayUrgentHours(sliderHours) },
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(24.dp))
        TextButton(onClick = onDismiss) {
            Text(stringResource(R.string.action_done))
        }
    }
}
