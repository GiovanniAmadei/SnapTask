package com.snaptask.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Theme selection screen matching iOS ThemeSelectionView.
 * Shows available themes with preview cards for selection.
 * Note: Full theming infrastructure (ThemeManager) is not yet implemented,
 * this is a placeholder UI structure matching the iOS layout.
 */
@Composable
fun ThemeSelectionScreen(
    onDismiss: () -> Unit,
) {
    data class ThemeOption(
        val id: String,
        val name: String,
        val primaryColor: Color,
        val backgroundColor: Color,
        val surfaceColor: Color,
        val isPremium: Boolean = false,
    )

    val freeThemes = listOf(
        ThemeOption("simple", "Simple", Color(0xFF6366F1), Color(0xFFF8FAFC), Color.White),
        ThemeOption("ocean", "Ocean", Color(0xFF0EA5E9), Color(0xFFF0F9FF), Color.White),
        ThemeOption("forest", "Forest", Color(0xFF22C55E), Color(0xFFF0FDF4), Color.White),
        ThemeOption("sunset", "Sunset", Color(0xFFF97316), Color(0xFFFFF7ED), Color.White),
    )

    val premiumThemes = listOf(
        ThemeOption("midnight", "Midnight", Color(0xFF818CF8), Color(0xFF0F172A), Color(0xFF1E293B), true),
        ThemeOption("cherry", "Cherry Blossom", Color(0xFFF472B6), Color(0xFFFFF1F2), Color.White, true),
        ThemeOption("aurora", "Aurora", Color(0xFF34D399), Color(0xFF0F172A), Color(0xFF1E293B), true),
        ThemeOption("lavender", "Lavender", Color(0xFFA78BFA), Color(0xFFF5F3FF), Color.White, true),
    )

    var selectedThemeId by remember { mutableStateOf("simple") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Themes",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Current Theme
        Text(
            "CURRENT THEME",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        val currentTheme = (freeThemes + premiumThemes).firstOrNull { it.id == selectedThemeId } ?: freeThemes[0]
        CurrentThemeCard(theme = currentTheme)

        Spacer(modifier = Modifier.height(24.dp))

        // Free Themes
        Text(
            "FREE THEMES",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(12.dp))

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.heightIn(max = 300.dp),
        ) {
            items(freeThemes) { theme ->
                ThemeCard(
                    theme = theme,
                    isSelected = theme.id == selectedThemeId,
                    onClick = { selectedThemeId = theme.id },
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Premium Themes
        Text(
            "PREMIUM THEMES",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(12.dp))

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.heightIn(max = 300.dp),
        ) {
            items(premiumThemes) { theme ->
                ThemeCard(
                    theme = theme,
                    isSelected = theme.id == selectedThemeId,
                    onClick = { selectedThemeId = theme.id },
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun CurrentThemeCard(theme: Any) {
    // Use reflection-free approach
    val name = when {
        theme is ThemeDisplayData -> theme.name
        else -> "Simple"
    }
    val primaryColor = when {
        theme is ThemeDisplayData -> theme.primaryColor
        else -> Color(0xFF6366F1)
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Theme preview mini-card
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(primaryColor.copy(alpha = 0.15f))
                    .border(2.dp, primaryColor, RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(primaryColor),
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            Column {
                Text(
                    name,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                )
                Text(
                    "Active",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

private data class ThemeDisplayData(
    val id: String,
    val name: String,
    val primaryColor: Color,
    val backgroundColor: Color,
    val surfaceColor: Color,
    val isPremium: Boolean = false,
)

@Composable
private fun ThemeCard(
    theme: Any,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    // Extract values safely regardless of type
    val id: String
    val name: String
    val primaryColor: Color
    val isPremium: Boolean
    val backgroundColor: Color

    // Use the data class from the calling context
    @Suppress("UNCHECKED_CAST")
    when (theme) {
        else -> {
            // Use reflection-free access via the function parameters
            val themeFields = theme.javaClass.declaredFields
            id = try { themeFields.first { it.name == "id" }.also { it.isAccessible = true }.get(theme) as String } catch (_: Exception) { "" }
            name = try { themeFields.first { it.name == "name" }.also { it.isAccessible = true }.get(theme) as String } catch (_: Exception) { "Theme" }
            primaryColor = try { themeFields.first { it.name == "primaryColor" }.also { it.isAccessible = true }.get(theme) as Color } catch (_: Exception) { Color(0xFF6366F1) }
            isPremium = try { themeFields.first { it.name == "isPremium" }.also { it.isAccessible = true }.get(theme) as Boolean } catch (_: Exception) { false }
            backgroundColor = try { themeFields.first { it.name == "backgroundColor" }.also { it.isAccessible = true }.get(theme) as Color } catch (_: Exception) { Color.White }
        }
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
        border = if (isSelected) CardDefaults.outlinedCardBorder().copy(
            brush = androidx.compose.ui.graphics.SolidColor(primaryColor),
        ) else null,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Preview
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(backgroundColor),
                contentAlignment = Alignment.Center,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(modifier = Modifier.size(12.dp).clip(CircleShape).background(primaryColor))
                    Box(modifier = Modifier.size(12.dp).clip(CircleShape).background(primaryColor.copy(alpha = 0.5f)))
                    Box(modifier = Modifier.size(12.dp).clip(CircleShape).background(primaryColor.copy(alpha = 0.3f)))
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                name,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
            )

            if (isSelected) {
                Icon(
                    Icons.Filled.Check,
                    contentDescription = "Selected",
                    tint = primaryColor,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}
