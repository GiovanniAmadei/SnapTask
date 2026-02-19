package com.snaptask.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.snaptask.app.data.local.dao.*
import com.snaptask.app.data.local.entity.*

/**
 * Room database for SnapTask.
 * Stores all persistent data locally.
 */
@Database(
    entities = [
        TaskEntity::class,
        CategoryEntity::class,
        RewardEntity::class,
        FinanceEntryEntity::class,
        JournalEntryEntity::class,
        TrackingSessionEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class SnapTaskDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun categoryDao(): CategoryDao
    abstract fun rewardDao(): RewardDao
    abstract fun financeEntryDao(): FinanceEntryDao
    abstract fun journalDao(): JournalDao
    abstract fun trackingSessionDao(): TrackingSessionDao

    companion object {
        const val DATABASE_NAME = "snaptask_db"
    }
}
