package com.snaptask.app.ui.settings

import com.snaptask.app.data.model.Category
import com.snaptask.app.data.model.TodoTask

/**
 * DTO for backup export/import. Version allows future format changes.
 */
data class BackupData(
    val version: Int = 1,
    val tasks: List<TodoTask> = emptyList(),
    val categories: List<Category> = emptyList(),
)
