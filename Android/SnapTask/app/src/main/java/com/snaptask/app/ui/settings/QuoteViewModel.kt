package com.snaptask.app.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class Quote(val text: String, val author: String)

/**
 * Simple quote provider matching iOS QuoteManager.
 * Uses fallback list; can be extended with API later.
 */
@HiltViewModel
class QuoteViewModel @Inject constructor() : ViewModel() {

    private val fallbackQuotes = listOf(
        Quote("The only way to do great work is to love what you do.", "Steve Jobs"),
        Quote("Success is not final, failure is not fatal: It is the courage to continue that counts.", "Winston Churchill"),
        Quote("Believe you can and you're halfway there.", "Theodore Roosevelt"),
        Quote("Your time is limited, don't waste it living someone else's life.", "Steve Jobs"),
        Quote("The future belongs to those who believe in the beauty of their dreams.", "Eleanor Roosevelt"),
        Quote("It does not matter how slowly you go as long as you do not stop.", "Confucius"),
        Quote("Don't watch the clock; do what it does. Keep going.", "Sam Levenson"),
        Quote("The way to get started is to quit talking and begin doing.", "Walt Disney"),
        Quote("If you're going through hell, keep going.", "Winston Churchill"),
    )

    private val _currentQuote = MutableStateFlow(fallbackQuotes.random())
    val currentQuote: StateFlow<Quote> = _currentQuote.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun refreshQuote() {
        viewModelScope.launch {
            _isLoading.value = true
            _currentQuote.value = fallbackQuotes.random()
            _isLoading.value = false
        }
    }
}
