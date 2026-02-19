package com.snaptask.app.data.local.dao

import androidx.room.*
import com.snaptask.app.data.local.entity.TaskEntity
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks ORDER BY start_time ASC")
    fun getAllTasks(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    suspend fun getTaskById(taskId: UUID): TaskEntity?

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    fun getTaskByIdFlow(taskId: UUID): Flow<TaskEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTask(task: TaskEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTasks(tasks: List<TaskEntity>)

    @Update
    suspend fun updateTask(task: TaskEntity)

    @Delete
    suspend fun deleteTask(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteTaskById(taskId: UUID)

    @Query("SELECT * FROM tasks WHERE time_scope = :scope ORDER BY start_time ASC")
    fun getTasksByScope(scope: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE has_notification = 1")
    fun getTasksWithNotifications(): Flow<List<TaskEntity>>

    @Query("SELECT COUNT(*) FROM tasks")
    suspend fun getTaskCount(): Int

    @Query("DELETE FROM tasks")
    suspend fun deleteAllTasks()
}
