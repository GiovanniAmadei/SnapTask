package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.Category
import com.snaptask.app.ui.statistics.parseColor

/**
 * Category picker matching iOS CategoryPickerView.
 * Shows available categories with selection state and add button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryPickerScreen(
    categories: List<Category>,
    selectedCategory: Category?,
    onSelectCategory: (Category?) -> Unit,
    onAddCategory: () -> Unit,
    onDismiss: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Select Category",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.weight(1f, fill = false),
        ) {
            // No category option
            item {
                val isSelected = selectedCategory == null
                CategoryOptionRow(
                    color = null,
                    name = "No Category",
                    isSelected = isSelected,
                    onClick = {
                        onSelectCategory(null)
                        onDismiss()
                    },
                )
            }

            // Category options
            items(categories, key = { it.id }) { category ->
                val isSelected = selectedCategory?.id == category.id
                CategoryOptionRow(
                    color = category.color,
                    name = category.name,
                    isSelected = isSelected,
                    onClick = {
                        if (isSelected) {
                            onSelectCategory(null)
                        } else {
                            onSelectCategory(category)
                        }
                        onDismiss()
                    },
                )
            }

            // Add new category button
            item {
                OutlinedButton(
                    onClick = onAddCategory,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Add New Category")
                }
            }

            item { Spacer(modifier = Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun CategoryOptionRow(
    color: String?,
    name: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = if (isSelected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.outlineVariant
    }
    val bgColor = if (isSelected) {
        MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
    } else {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = bgColor),
        border = CardDefaults.outlinedCardBorder().copy(
            brush = androidx.compose.ui.graphics.SolidColor(borderColor),
        ),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Color dot
            if (color != null) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(parseColor(color)),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .border(1.5.dp, MaterialTheme.colorScheme.onSurfaceVariant, CircleShape),
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Text(
                name,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )

            if (isSelected) {
                Icon(
                    Icons.Filled.Check,
                    contentDescription = "Selected",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
