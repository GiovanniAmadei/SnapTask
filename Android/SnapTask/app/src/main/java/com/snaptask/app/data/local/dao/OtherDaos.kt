package com.snaptask.app.data.local.dao

import androidx.room.*
import com.snaptask.app.data.local.entity.*
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Dao
interface RewardDao {
    @Query("SELECT * FROM rewards ORDER BY name ASC")
    fun getAllRewards(): Flow<List<RewardEntity>>

    @Query("SELECT * FROM rewards WHERE id = :rewardId")
    suspend fun getRewardById(rewardId: UUID): RewardEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReward(reward: RewardEntity)

    @Update
    suspend fun updateReward(reward: RewardEntity)

    @Delete
    suspend fun deleteReward(reward: RewardEntity)
}

@Dao
interface FinanceEntryDao {
    @Query("SELECT * FROM finance_entries ORDER BY date DESC")
    fun getAllEntries(): Flow<List<FinanceEntryEntity>>

    @Query("SELECT * FROM finance_entries WHERE id = :entryId")
    suspend fun getEntryById(entryId: UUID): FinanceEntryEntity?

    @Query("SELECT * FROM finance_entries WHERE type = :type ORDER BY date DESC")
    fun getEntriesByType(type: String): Flow<List<FinanceEntryEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEntry(entry: FinanceEntryEntity)

    @Update
    suspend fun updateEntry(entry: FinanceEntryEntity)

    @Delete
    suspend fun deleteEntry(entry: FinanceEntryEntity)
}

@Dao
interface JournalDao {
    @Query("SELECT * FROM journal_entries ORDER BY date DESC")
    fun getAllEntries(): Flow<List<JournalEntryEntity>>

    @Query("SELECT * FROM journal_entries WHERE id = :entryId")
    suspend fun getEntryById(entryId: UUID): JournalEntryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEntry(entry: JournalEntryEntity)

    @Update
    suspend fun updateEntry(entry: JournalEntryEntity)

    @Delete
    suspend fun deleteEntry(entry: JournalEntryEntity)
}

@Dao
interface TrackingSessionDao {
    @Query("SELECT * FROM tracking_sessions ORDER BY start_time DESC")
    fun getAllSessions(): Flow<List<TrackingSessionEntity>>

    @Query("SELECT * FROM tracking_sessions WHERE id = :sessionId")
    suspend fun getSessionById(sessionId: UUID): TrackingSessionEntity?

    @Query("SELECT * FROM tracking_sessions WHERE task_id = :taskId ORDER BY start_time DESC")
    fun getSessionsByTask(taskId: UUID): Flow<List<TrackingSessionEntity>>

    @Query("SELECT * FROM tracking_sessions WHERE is_running = 1 LIMIT 1")
    suspend fun getRunningSession(): TrackingSessionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: TrackingSessionEntity)

    @Update
    suspend fun updateSession(session: TrackingSessionEntity)

    @Delete
    suspend fun deleteSession(session: TrackingSessionEntity)
}
