package com.snaptask.app.ui.settings

import androidx.compose.foundation.background
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
 * Categories management screen matching iOS CategoriesView.
 * Lists all categories with edit/delete actions and add button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoriesScreen(
    viewModel: SettingsViewModel,
    onDismiss: () -> Unit,
) {
    val categories by viewModel.categories.collectAsState()
    var showNewCategoryForm by remember { mutableStateOf(false) }
    var editingCategory by remember { mutableStateOf<Category?>(null) }
    var categoryToDelete by remember { mutableStateOf<Category?>(null) }

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
                "Categories",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Add Category Button
        OutlinedButton(
            onClick = { showNewCategoryForm = true },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Icon(Icons.Filled.Add, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Add Category")
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Categories List
        if (categories.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(32.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "No categories yet.\nTap \"Add Category\" to create one.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.weight(1f, fill = false),
            ) {
                items(categories, key = { it.id }) { category ->
                    CategoryRow(
                        category = category,
                        onEdit = { editingCategory = category },
                        onDelete = { categoryToDelete = category },
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }

    // New Category Sheet
    if (showNewCategoryForm) {
        ModalBottomSheet(
            onDismissRequest = { showNewCategoryForm = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            CategoryFormScreen(
                onSave = { category ->
                    viewModel.addCategory(category)
                    showNewCategoryForm = false
                },
                onDismiss = { showNewCategoryForm = false },
            )
        }
    }

    // Edit Category Sheet
    editingCategory?.let { category ->
        ModalBottomSheet(
            onDismissRequest = { editingCategory = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            CategoryFormScreen(
                editingCategory = category,
                onSave = { updatedCategory ->
                    viewModel.updateCategory(updatedCategory)
                    editingCategory = null
                },
                onDismiss = { editingCategory = null },
            )
        }
    }

    // Delete Confirmation
    categoryToDelete?.let { category ->
        AlertDialog(
            onDismissRequest = { categoryToDelete = null },
            title = { Text("Delete Category") },
            text = { Text("Are you sure you want to delete '${category.name}'? This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteCategory(category.id)
                        categoryToDelete = null
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { categoryToDelete = null }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun CategoryRow(
    category: Category,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Color dot
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(parseColor(category.color)),
            )

            Spacer(modifier = Modifier.width(12.dp))

            // Name
            Text(
                category.name,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )

            // Edit button
            IconButton(onClick = onEdit, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Filled.Edit,
                    contentDescription = "Edit",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }

            // Delete button
            IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Filled.Delete,
                    contentDescription = "Delete",
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}
