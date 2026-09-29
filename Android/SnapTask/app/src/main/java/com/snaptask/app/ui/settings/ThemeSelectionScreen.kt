package com.snaptask.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.ui.theme.AppTheme
import com.snaptask.app.ui.theme.ThemeViewModel

/** Faithful Android equivalent of iOS ThemeSelectionView. */
@Composable
fun ThemeSelectionScreen(
    onDismiss: () -> Unit,
    themeViewModel: ThemeViewModel = hiltViewModel(),
) {
    val selectedTheme by themeViewModel.appTheme.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Themes & customization",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        ThemeSectionTitle("Current theme")
        CurrentThemeCard(selectedTheme)

        ThemeSectionTitle("Free themes")
        ThemeGrid(
            themes = AppTheme.freeThemes,
            selectedTheme = selectedTheme,
            onSelect = themeViewModel::selectTheme,
        )

        ThemeSectionTitle("Premium themes")
        ThemeGrid(
            themes = AppTheme.premiumThemes,
            selectedTheme = selectedTheme,
            onSelect = themeViewModel::selectTheme,
        )

        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ThemeSectionTitle(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(top = 24.dp, bottom = 10.dp),
    )
}

@Composable
private fun CurrentThemeCard(theme: AppTheme) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ThemePreview(theme = theme, modifier = Modifier.size(60.dp))
            Spacer(Modifier.size(16.dp))
            Column(Modifier.weight(1f)) {
                Text(theme.displayName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text("Active", style = MaterialTheme.typography.bodySmall, color = theme.accent)
            }
            Icon(Icons.Filled.Check, contentDescription = null, tint = theme.accent)
        }
    }
}

@Composable
private fun ThemeGrid(
    themes: List<AppTheme>,
    selectedTheme: AppTheme,
    onSelect: (AppTheme) -> Unit,
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        userScrollEnabled = false,
        modifier = Modifier.height(((themes.size + 1) / 2 * 132).dp),
    ) {
        items(themes) { theme ->
            ThemeCard(
                theme = theme,
                selected = selectedTheme == theme,
                onClick = { onSelect(theme) },
            )
        }
    }
}

@Composable
private fun ThemeCard(theme: AppTheme, selected: Boolean, onClick: () -> Unit) {
    val scheme = theme.colorScheme(systemIsDark = false)
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = if (selected) CardDefaults.outlinedCardBorder().copy(brush = SolidColor(theme.accent)) else null,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(scheme.background),
            ) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(10.dp)
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(theme.accent),
                )
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(8.dp)
                        .fillMaxWidth(0.75f)
                        .height(12.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(scheme.surface),
                )
                if (selected) {
                    Icon(
                        Icons.Filled.Check,
                        contentDescription = null,
                        tint = theme.accent,
                        modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).size(18.dp),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(theme.displayName, style = MaterialTheme.typography.labelLarge, maxLines = 1)
                if (theme.isPremium) Icon(Icons.Filled.Lock, contentDescription = "Premium", modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun ThemePreview(theme: AppTheme, modifier: Modifier = Modifier) {
    val scheme = theme.colorScheme(systemIsDark = false)
    Box(modifier.clip(RoundedCornerShape(12.dp)).background(scheme.background)) {
        Box(
            Modifier
                .align(Alignment.Center)
                .size(28.dp)
                .clip(CircleShape)
                .background(theme.accent),
        )
    }
}
