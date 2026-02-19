package com.snaptask.app.ui.journal

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.JournalEntry
import com.snaptask.app.data.repository.JournalRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Journal screen. Provides entries and save action,
 * matching iOS JournalManager usage from JournalView.
 */
@HiltViewModel
class JournalViewModel @Inject constructor(
    private val journalRepository: JournalRepository,
) : ViewModel() {

    val entries = journalRepository.getAllEntries()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun saveEntry(entry: JournalEntry) {
        viewModelScope.launch {
            journalRepository.saveEntry(entry)
        }
    }
}
