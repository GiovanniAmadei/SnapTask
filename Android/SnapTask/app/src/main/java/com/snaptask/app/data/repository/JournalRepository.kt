package com.snaptask.app.data.repository

import com.snaptask.app.data.local.dao.JournalDao
import com.snaptask.app.data.local.entity.JournalEntryEntity
import com.snaptask.app.data.model.JournalEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for Journal entries, matching iOS JournalManager functionality.
 */
@Singleton
class JournalRepository @Inject constructor(
    private val journalDao: JournalDao,
) {
    fun getAllEntries(): Flow<List<JournalEntry>> =
        journalDao.getAllEntries().map { entities ->
            entities.map { it.toModel() }
        }

    suspend fun getEntry(id: UUID): JournalEntry? =
        journalDao.getEntryById(id)?.toModel()

    suspend fun getEntryForDate(date: Date): JournalEntry? {
        val cal = Calendar.getInstance().apply {
            time = date
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val dayStart = cal.time
        cal.add(Calendar.DAY_OF_YEAR, 1)
        val dayEnd = cal.time

        return journalDao.getAllEntries().map { entities ->
            entities.map { it.toModel() }
        }.let { flow ->
            // For one-shot retrieval, collect first emission
            var result: JournalEntry? = null
            flow.collect { entries ->
                result = entries.find { entry ->
                    entry.date >= dayStart && entry.date < dayEnd
                }
                return@collect
            }
            result
        }
    }

    suspend fun saveEntry(entry: JournalEntry) {
        val existing = journalDao.getEntryById(entry.id)
        if (existing != null) {
            journalDao.updateEntry(JournalEntryEntity.fromModel(entry.copy(lastModifiedDate = Date())))
        } else {
            journalDao.insertEntry(JournalEntryEntity.fromModel(entry))
        }
    }

    suspend fun deleteEntry(entry: JournalEntry) {
        journalDao.deleteEntry(JournalEntryEntity.fromModel(entry))
    }
}
