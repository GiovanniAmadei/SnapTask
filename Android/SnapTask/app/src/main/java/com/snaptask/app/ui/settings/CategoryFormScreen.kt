package com.snaptask.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.snaptask.app.data.model.Category
import java.util.UUID

/**
 * Category creation/edit form matching iOS CategoryFormView.
 * Includes name field and color picker grid.
 */
@Composable
fun CategoryFormScreen(
    editingCategory: Category? = null,
    onSave: (Category) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(editingCategory?.name ?: "") }
    var selectedColor by remember { mutableStateOf(editingCategory?.color ?: "#FF6366F1") }

    val presetColors = listOf(
        "#FFFF69B4", "#FFFF0000", "#FFFF6B6B", "#FFFF9800",
        "#FFFFC107", "#FF4CAF50", "#FF00BCD4", "#FF2196F3",
        "#FF3F51B5", "#FF6366F1", "#FF9C27B0", "#FFE91E63",
        "#FF795548", "#FF607D8B", "#FF9E9E9E", "#FF000000",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onDismiss) { Text("Cancel") }
            Text(
                if (editingCategory == null) "New Category" else "Edit Category",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(
                onClick = {
                    val category = Category(
                        id = editingCategory?.id ?: UUID.randomUUID(),
                        name = name.trim(),
                        color = selectedColor,
                    )
                    onSave(category)
                },
                enabled = name.isNotBlank(),
            ) { Text("Save") }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Name Field
        Text(
            "CATEGORY NAME",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            placeholder = { Text("Enter category name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            singleLine = true,
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Color Picker
        Text(
            "COLOR",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(12.dp))

        LazyVerticalGrid(
            columns = GridCells.Fixed(8),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.heightIn(max = 200.dp),
        ) {
            items(presetColors) { colorHex ->
                val color = try {
                    Color(android.graphics.Color.parseColor(colorHex.replace("FF", "#", ignoreCase = false).take(7)))
                } catch (e: Exception) {
                    Color(android.graphics.Color.parseColor(colorHex))
                }
                val isSelected = colorHex == selectedColor

                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(color)
                        .then(
                            if (isSelected) Modifier.border(
                                3.dp,
                                MaterialTheme.colorScheme.primary,
                                CircleShape,
                            ) else Modifier,
                        )
                        .clickable { selectedColor = colorHex },
                    contentAlignment = Alignment.Center,
                ) {
                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Filled.Check,
                            contentDescription = "Selected",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Preview
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(
                            try {
                                Color(android.graphics.Color.parseColor(selectedColor.replace("FF", "#", ignoreCase = false).take(7)))
                            } catch (e: Exception) {
                                Color(android.graphics.Color.parseColor(selectedColor))
                            },
                        ),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    if (name.isNotBlank()) name else "Preview",
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (name.isNotBlank()) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}
