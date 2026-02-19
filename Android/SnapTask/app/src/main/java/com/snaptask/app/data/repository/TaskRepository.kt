package com.snaptask.app.data.repository

import com.snaptask.app.data.local.dao.TaskDao
import com.snaptask.app.data.local.dao.CategoryDao
import com.snaptask.app.data.local.entity.TaskEntity
import com.snaptask.app.data.local.entity.CategoryEntity
import com.snaptask.app.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.Calendar
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for task operations.
 * Abstracts data access, providing a clean API to ViewModels.
 */
@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val categoryDao: CategoryDao,
) {
    // ---- Tasks ----

    val allTasks: Flow<List<TodoTask>> = taskDao.getAllTasks().map { entities ->
        entities.map { it.toModel() }
    }

    suspend fun getTaskById(taskId: UUID): TodoTask? =
        taskDao.getTaskById(taskId)?.toModel()

    fun getTaskByIdFlow(taskId: UUID): Flow<TodoTask?> =
        taskDao.getTaskByIdFlow(taskId).map { it?.toModel() }

    suspend fun addTask(task: TodoTask) {
        taskDao.insertTask(TaskEntity.fromModel(task.copy(lastModifiedDate = Date())))
    }

    suspend fun updateTask(task: TodoTask) {
        taskDao.updateTask(TaskEntity.fromModel(task.copy(lastModifiedDate = Date())))
    }

    suspend fun deleteTask(task: TodoTask) {
        taskDao.deleteTask(TaskEntity.fromModel(task))
    }

    suspend fun deleteTaskById(taskId: UUID) {
        taskDao.deleteTaskById(taskId)
    }

    /**
     * Toggle task completion for a given date.
     */
    suspend fun toggleCompletion(taskId: UUID, date: Date) {
        val task = getTaskById(taskId) ?: return
        val key = task.completionKey(date)
        val existingCompletion = task.completions[key]

        val updatedCompletions = task.completions.toMutableMap()
        if (existingCompletion?.isCompleted == true) {
            // Uncomplete
            updatedCompletions.remove(key)
        } else {
            // Complete
            updatedCompletions[key] = TaskCompletion(
                isCompleted = true,
                completionDate = Date(),
                completedSubtasks = task.subtasks.filter { it.isCompleted }.map { it.id }.toSet(),
            )
        }

        val updatedDates = if (existingCompletion?.isCompleted == true) {
            task.completionDates.toMutableList().also { dates ->
                dates.removeAll { TodoTask.isSameDay(it, date) }
            }
        } else {
            task.completionDates + date
        }

        updateTask(task.copy(
            completions = updatedCompletions,
            completionDates = updatedDates,
        ))
    }

    /**
     * Toggle a subtask completion within a task.
     */
    suspend fun toggleSubtask(taskId: UUID, subtaskId: UUID) {
        val task = getTaskById(taskId) ?: return
        val key = task.completionKey(Date())
        val existingCompletion = task.completions[key] ?: TaskCompletion(
            isCompleted = false,
            completionDate = Date(),
            completedSubtasks = emptySet(),
        )

        val updatedSubtasks = existingCompletion.completedSubtasks.toMutableSet()
        if (subtaskId in updatedSubtasks) {
            updatedSubtasks.remove(subtaskId)
        } else {
            updatedSubtasks.add(subtaskId)
        }

        val allSubtasksComplete = updatedSubtasks.size == task.subtasks.size
        val updatedCompletions = task.completions.toMutableMap()
        updatedCompletions[key] = existingCompletion.copy(
            completedSubtasks = updatedSubtasks,
            isCompleted = allSubtasksComplete,
        )

        updateTask(task.copy(completions = updatedCompletions))
    }

    // ---- Queries ----

    /**
     * Get tasks for a specific date (considering recurrence).
     */
    fun getTasksForDate(date: Date): Flow<List<TodoTask>> = allTasks.map { tasks ->
        val calendar = Calendar.getInstance()
        tasks.filter { task ->
            when (task.timeScope) {
                TaskTimeScope.TODAY -> {
                    if (task.recurrence != null) {
                        task.occurs(date)
                    } else {
                        TodoTask.isSameDay(task.startTime, date)
                    }
                }
                TaskTimeScope.WEEK -> {
                    val weekStart = Recurrence.startOfWeek(date)
                    val scopeStart = task.scopeStartDate ?: task.startTime
                    val scopeWeekStart = Recurrence.startOfWeek(scopeStart)
                    scopeWeekStart.time == weekStart.time
                }
                TaskTimeScope.MONTH -> {
                    val monthStart = Recurrence.startOfMonth(date)
                    val scopeStart = task.scopeStartDate ?: task.startTime
                    val scopeMonthStart = Recurrence.startOfMonth(scopeStart)
                    scopeMonthStart.time == monthStart.time
                }
                TaskTimeScope.YEAR, TaskTimeScope.LONG_TERM, TaskTimeScope.ALL -> true
            }
        }
    }

    // ---- Categories ----

    val allCategories: Flow<List<Category>> = categoryDao.getAllCategories().map { entities ->
        entities.map { it.toModel() }
    }

    suspend fun addCategory(category: Category) {
        categoryDao.insertCategory(CategoryEntity.fromModel(category))
    }

    suspend fun updateCategory(category: Category) {
        categoryDao.updateCategory(CategoryEntity.fromModel(category))
    }

    suspend fun deleteCategory(categoryId: UUID) {
        categoryDao.deleteCategoryById(categoryId)
    }

    /**
     * Delete all tasks (for Data Management > Delete All Data).
     */
    suspend fun deleteAllTasks() {
        taskDao.deleteAllTasks()
    }
}
