package com.snaptask.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlinx.serialization.builtins.ListSerializer
import java.time.LocalDate
import java.util.UUID

object JournalManager {
    private const val storageKey = "journalEntries.v1"
    private val serializer = ListSerializer(JournalEntry.serializer())

    var entriesByDay by mutableStateOf<Map<Date, JournalEntry>>(emptyMap())
        private set

    fun load() {
        entriesByDay = (Store.load(storageKey, serializer) ?: emptyList()).associateBy { it.date.startOfDay() }
    }

    private fun save() = Store.save(storageKey, serializer, entriesByDay.values.toList())

    private inline fun change(date: Date, block: (JournalEntry) -> JournalEntry) {
        val day = date.startOfDay()
        entriesByDay = entriesByDay + (day to block(entry(day)).copy(updatedAt = now()))
        save()
    }

    /** The day's entry. It is created when asked for, as on iOS, and empty ones count as no entry. */
    fun entry(date: Date): JournalEntry {
        val day = date.startOfDay()
        entriesByDay[day]?.let { return it }
        val new = JournalEntry(date = day)
        entriesByDay = entriesByDay + (day to new)
        save()
        return new
    }

    fun updateTitle(date: Date, title: String) = change(date) { it.copy(title = title) }
    fun updateText(date: Date, text: String) = change(date) { it.copy(text = text) }
    fun updateWorthItText(date: Date, worthItText: String) = change(date) { it.copy(worthItText = worthItText) }
    fun setWorthItHidden(date: Date, isHidden: Boolean) = change(date) { it.copy(isWorthItHidden = isHidden) }

    fun setMood(date: Date, mood: MoodType?) {
        change(date) { it.copy(mood = mood) }
        if (mood != null) MoodManager.setMood(date, mood) else MoodManager.removeMood(date)
    }

    fun addTag(tag: String, date: Date) {
        val trimmed = tag.trim()
        if (trimmed.isEmpty() || trimmed in entry(date).tags) return
        change(date) { it.copy(tags = it.tags + trimmed) }
    }

    fun removeTag(tag: String, date: Date) = change(date) { entry -> entry.copy(tags = entry.tags.filterNot { it.equals(tag, ignoreCase = true) }) }

    fun addVoiceMemo(memo: JournalVoiceMemo, date: Date) = change(date) { it.copy(voiceMemos = it.voiceMemos + memo) }
    fun removeVoiceMemo(id: UUID, date: Date) = change(date) { entry -> entry.copy(voiceMemos = entry.voiceMemos.filter { it.id != id }) }
    fun updateVoiceMemoName(name: String?, memoId: UUID, date: Date) = change(date) { entry ->
        entry.copy(voiceMemos = entry.voiceMemos.map { if (it.id == memoId) it.copy(name = name) else it })
    }

    fun addPhoto(photo: JournalPhoto, date: Date) = change(date) { it.copy(photos = it.photos + photo) }
    fun removePhoto(id: UUID, date: Date) = change(date) { entry -> entry.copy(photos = entry.photos.filter { it.id != id }) }

    fun deleteEntry(date: Date) {
        val day = date.startOfDay()
        if (day !in entriesByDay) return
        entriesByDay = entriesByDay - day
        save()
    }

    /** Backup import: the given entries replace those of the same days. */
    fun importEntries(entries: List<JournalEntry>, replacing: Boolean) {
        val base = if (replacing) emptyMap() else entriesByDay
        entriesByDay = base + entries.associateBy { it.date.startOfDay() }
        save()
    }

    fun resetAll() {
        entriesByDay = emptyMap()
        Store.remove(storageKey)
    }
}

object MoodManager {
    private const val storageKey = "moodEntries.v2"
    private val serializer = ListSerializer(MoodEntry.serializer())

    var entries by mutableStateOf<Map<Date, MoodEntry>>(emptyMap())
        private set

    fun load() {
        entries = (Store.load(storageKey, serializer) ?: emptyList()).associateBy { it.date.startOfDay() }
    }

    private fun save() = Store.save(storageKey, serializer, entries.values.toList())

    fun mood(date: Date): MoodType? = entries[date.startOfDay()]?.type

    fun setMood(date: Date, type: MoodType, notes: String? = null) {
        val day = date.startOfDay()
        entries = entries + (day to MoodEntry(date = day, type = type, notes = notes))
        save()
    }

    fun removeMood(date: Date) {
        entries = entries - date.startOfDay()
        save()
    }

    fun importEntries(newEntries: List<MoodEntry>, replacing: Boolean) {
        entries = (if (replacing) emptyMap() else entries) + newEntries.associateBy { it.date.startOfDay() }
        save()
    }

    fun allEntries(): List<MoodEntry> = entries.values.sortedBy { it.date }

    fun entriesIn(start: Date, end: Date): List<Pair<Date, MoodType>> {
        val from = start.startOfDay()
        val to = end.startOfDay()
        return entries.filter { it.key >= from && it.key <= to }.map { it.key to it.value.type }.sortedBy { it.first }
    }
}

object QuoteManager {
    const val actionDailyQuote = "com.snaptask.app.DAILY_QUOTE"
    const val actionDiaryReminder = "com.snaptask.app.DIARY_REMINDER"
    private const val lastUpdateDateKey = "lastQuoteUpdateDate"
    private const val currentQuoteKey = "currentQuote"

    private val quotes = listOf(
        Quote(text = "The only way to do great work is to love what you do.", author = "Steve Jobs"),
        Quote(text = "Success is not final, failure is not fatal: It is the courage to continue that counts.", author = "Winston Churchill"),
        Quote(text = "Believe you can and you're halfway there.", author = "Theodore Roosevelt"),
        Quote(text = "Your time is limited, don't waste it living someone else's life.", author = "Steve Jobs"),
        Quote(text = "The future belongs to those who believe in the beauty of their dreams.", author = "Eleanor Roosevelt"),
        Quote(text = "It does not matter how slowly you go as long as you do not stop.", author = "Confucius"),
        Quote(text = "Don't watch the clock; do what it does. Keep going.", author = "Sam Levenson"),
        Quote(text = "The only limit to our realization of tomorrow is our doubts of today.", author = "Franklin D. Roosevelt"),
        Quote(text = "The way to get started is to quit talking and begin doing.", author = "Walt Disney"),
        Quote(text = "If you're going through hell, keep going.", author = "Winston Churchill"),
        Quote(text = "Innovation distinguishes between a leader and a follower.", author = "Steve Jobs"),
        Quote(text = "Life is what happens to you while you're busy making other plans.", author = "John Lennon"),
        Quote(text = "The future depends on what you do today.", author = "Mahatma Gandhi"),
        Quote(text = "It is during our darkest moments that we must focus to see the light.", author = "Aristotle"),
        Quote(text = "Success is not how high you have climbed, but how you make a positive difference to the world.", author = "Roy T. Bennett"),
        Quote(text = "The only impossible journey is the one you never begin.", author = "Tony Robbins"),
        Quote(text = "In the middle of difficulty lies opportunity.", author = "Albert Einstein"),
        Quote(text = "What you get by achieving your goals is not as important as what you become by achieving your goals.", author = "Zig Ziglar"),
        Quote(text = "Do something today that your future self will thank you for.", author = "Sean Patrick Flanery"),
        Quote(text = "The harder you work for something, the greater you'll feel when you achieve it.", author = "Anonymous"),
    )

    var currentQuote by mutableStateOf(Quote.placeholder)
        private set
    var isLoading by mutableStateOf(false)
        private set

    fun load() {
        Store.load(currentQuoteKey, Quote.serializer())?.let { currentQuote = it }
    }

    /** The day's quote: the same one all day, also for reminders of days yet to come. */
    fun quoteFor(date: Date): Quote {
        var state = date.format("yyyy-MM-dd").hashCode().toLong() and 0x7FFFFFFFL
        state = state * 1103515245L + 12345L
        return quotes[(state.mod(quotes.size.toLong())).toInt()]
    }

    fun checkAndUpdateQuote() {
        val last = Defaults.date(lastUpdateDateKey)
        if (last != null && last.isToday()) return
        update()
    }

    fun forceUpdateQuote() = update()

    private fun update() {
        currentQuote = quoteFor(now())
        Store.save(currentQuoteKey, Quote.serializer(), currentQuote)
        Defaults.set(lastUpdateDateKey, now())
    }

    // MARK: Daily reminders

    private fun operation(action: String, flags: Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE): PendingIntent? =
        PendingIntent.getBroadcast(App.context, action.hashCode(), Intent(App.context, ReminderReceiver::class.java).setAction(action), flags)

    private fun arm(action: String, time: String) {
        val parts = time.split(":").mapNotNull { it.toIntOrNull() }
        if (parts.size != 2) return
        var fire = LocalDate.now().instant().withTime(parts[0], parts[1], 0)
        if (fire <= now()) fire = fire.addingDays(1)
        val alarm = App.context.getSystemService(AlarmManager::class.java)
        val pending = operation(action) ?: return
        val canExact = Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()
        if (canExact) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fire.toEpochMilli(), pending)
        else alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fire.toEpochMilli(), pending)
    }

    private fun disarm(action: String) {
        val pending = operation(action, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
        App.context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    /** Android repeats nothing by itself: the next reminder is set when one is delivered. */
    fun rescheduleDailyQuote() {
        if (Defaults.bool("dailyQuoteNotificationsEnabled")) arm(actionDailyQuote, Defaults.string("dailyQuoteNotificationTime") ?: "09:00")
        else disarm(actionDailyQuote)
    }

    fun rescheduleDiary() {
        if (Defaults.bool("diaryNotificationsEnabled")) arm(actionDiaryReminder, Defaults.string("diaryNotificationTime") ?: "20:00")
        else disarm(actionDiaryReminder)
    }

    fun rescheduleAll() {
        rescheduleDailyQuote()
        rescheduleDiary()
    }

    private fun post(id: Int, title: String, body: String, extra: Intent.() -> Unit = {}) {
        if (!TaskNotificationManager.isAuthorized) return
        val context: Context = App.context
        val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP).apply(extra)
        val notification = NotificationCompat.Builder(context, TaskNotificationManager.quoteChannelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id, notification) }
    }

    fun deliverDailyQuote() {
        val quote = quoteFor(now())
        post(71001, "your_daily_motivation".localized, "daily_quote_notification_body".localized(quote.text, quote.author))
        update()
        rescheduleDailyQuote()
    }

    fun deliverDiary() {
        post(71002, "diary_reminder_title".localized, "diary_reminder_body".localized) {
            putExtra("openJournalDate", LocalDate.now().toString())
        }
        rescheduleDiary()
    }
}
