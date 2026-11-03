package com.snaptask.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.TimeUnit

// MARK: - Feedback

object FeedbackManager {
    private const val feedbackKey = "saved_feedback_items"
    // Android has its own board: the released iOS apps show everything in "feedback", unfiltered.
    private const val feedbackCollection = "feedback_android"
    private const val votesCollection = "votes_android"
    private const val likesCollection = "likes_android"
    private val serializer = ListSerializer(FeedbackItem.serializer())

    var feedbackItems by mutableStateOf(runCatching { Store.load(feedbackKey, serializer) }.getOrNull()?.sortedByDescending { it.votes } ?: emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set

    fun currentUserId(): String {
        val legacy = Defaults.string("firebase_user_id")
        val current = Defaults.string("anonymous_user_id")
        if (!legacy.isNullOrEmpty() && current == null) {
            Defaults.set("anonymous_user_id", legacy)
            return legacy
        }
        if (current != null) return current
        val id = UUID.randomUUID().uuidString
        Defaults.set("anonymous_user_id", id)
        return id
    }

    fun allUserIds(): List<String> {
        val current = currentUserId()
        val legacy = Defaults.string("firebase_user_id") ?: ""
        return if (legacy.isEmpty() || legacy == current) listOf(current) else listOf(current, legacy)
    }

    fun loadFeedback() {
        if (isLoading) return
        isLoading = true
        MainScope.launch {
            runCatching { fetchFeedback() }.onSuccess { remote ->
                feedbackItems = remote.sortedByDescending { it.votes }
                // Replies visible in the list don't need a notification later.
                FeedbackReplyNotifier.markRepliesSeen(remote.filter { it.isAuthoredByCurrentUser })
                Store.save(feedbackKey, serializer, feedbackItems)
            }
            isLoading = false
        }
    }

    private suspend fun fetchFeedback(): List<FeedbackItem> {
        val documents = Firestore.list(feedbackCollection)
        val votes = userMarks(votesCollection)
        val likes = userMarks(likesCollection)
        return documents.mapNotNull { document ->
            // iOS orders the query by "votes", which leaves out documents without that field.
            if ("votes" !in document.fields) return@mapNotNull null
            createFeedbackItem(document.fields)?.let {
                it.copy(hasVoted = it.id.uuidString in votes, hasLiked = it.id.uuidString in likes)
            }
        }
    }

    private suspend fun userMarks(collection: String): Set<String> = runCatching {
        Firestore.whereEqual(collection, "userId", currentUserId()).mapNotNull { it.fields["feedbackId"] as? String }.toSet()
    }.getOrDefault(emptySet())

    suspend fun fetchFeedback(authorId: String): List<FeedbackItem> =
        Firestore.whereEqual(feedbackCollection, "authorId", authorId).mapNotNull { createFeedbackItem(it.fields) }

    /** Returns whether it reached the server. */
    suspend fun submitFeedback(feedback: FeedbackItem): Boolean = runCatching {
        val item = if (feedback.authorId == null) feedback.copy(authorId = currentUserId()) else feedback
        Firestore.commit(
            listOf(
                Firestore.Write.Set(
                    feedbackCollection,
                    item.id.uuidString,
                    mapOf(
                        "id" to item.id.uuidString,
                        "title" to item.title,
                        "description" to item.description,
                        "category" to item.category.rawValue,
                        "status" to item.status.rawValue,
                        "creationDate" to item.creationDate,
                        "authorId" to (item.authorId ?: ""),
                        "authorName" to (item.authorName ?: ""),
                        "votes" to item.votes,
                        "likes" to item.likes,
                        "replies" to emptyList<Any?>(),
                    ),
                ),
            ),
        )
        loadFeedback()
    }.isSuccess

    fun toggleVote(feedback: FeedbackItem) {
        MainScope.launch {
            val voted = !feedback.hasVoted
            // The list answers at once; the reload below brings the real count.
            feedbackItems = feedbackItems.map {
                if (it.id == feedback.id) it.copy(hasVoted = voted, votes = maxOf(0, it.votes + if (voted) 1 else -1)) else it
            }
            runCatching { writeVote(feedback) }
            loadFeedback()
        }
    }

    private suspend fun writeVote(feedback: FeedbackItem) {
        val userId = currentUserId()
        val id = feedback.id.uuidString
        val voteId = "${userId}_$id"
        val hasVoted = Firestore.get(votesCollection, voteId) != null
        val document = Firestore.get(feedbackCollection, id) ?: return
        val votes = document.fields["votes"] as? Int ?: return
        Firestore.commit(
            listOf(
                if (hasVoted) {
                    Firestore.Write.Delete(votesCollection, voteId)
                } else {
                    Firestore.Write.Set(votesCollection, voteId, mapOf("userId" to userId, "feedbackId" to id, "createdAt" to now()))
                },
                Firestore.Write.Update(feedbackCollection, id, mapOf("votes" to if (hasVoted) maxOf(0, votes - 1) else votes + 1), document.updateTime),
            ),
        )
    }

    fun deleteFeedback(feedback: FeedbackItem) {
        if (!feedback.isAuthoredByCurrentUser) return
        isLoading = true
        MainScope.launch {
            runCatching {
                val id = feedback.id.uuidString
                val related = Firestore.whereEqual(votesCollection, "feedbackId", id).map { Firestore.Write.Delete(votesCollection, it.id) } +
                    Firestore.whereEqual(likesCollection, "feedbackId", id).map { Firestore.Write.Delete(likesCollection, it.id) }
                Firestore.commit(related + Firestore.Write.Delete(feedbackCollection, id))
            }.onSuccess {
                feedbackItems = feedbackItems.filter { it.id != feedback.id }
                Store.save(feedbackKey, serializer, feedbackItems)
            }
            isLoading = false
            loadFeedback()
        }
    }

    suspend fun checkForNewReplies() {
        FeedbackReplyNotifier.checkForNewReplies()
    }

    @Suppress("UNCHECKED_CAST")
    private fun createFeedbackItem(data: Map<String, Any?>): FeedbackItem? {
        val id = (data["id"] as? String)?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: return null
        val title = data["title"] as? String ?: return null
        val description = data["description"] as? String ?: return null
        val category = FeedbackCategory.entries.firstOrNull { it.rawValue == data["category"] } ?: return null
        val status = FeedbackStatus.entries.firstOrNull { it.rawValue == data["status"] } ?: return null
        val date = data["creationDate"] as? Date ?: return null
        val replies = ArrayList<FeedbackReply>()
        (data["replies"] as? List<Any?>)?.forEach { reply ->
            (reply as? Map<String, Any?>)?.let { createReply(it, id) }?.let { replies += it }
        }
        // Answers written from the Firebase console or the reply script.
        (data["developerReply"] as? String)?.takeIf { it.isNotEmpty() }?.let { content ->
            replies += FeedbackReply(
                feedbackId = id,
                content = content,
                authorId = "giovanni_amadei_dev_id",
                authorName = "Giovanni (Developer)",
                creationDate = data["developerReplyDate"] as? Date ?: Date.ofEpochSecond(0),
                isFromDeveloper = true,
            )
        }
        return FeedbackItem(
            id = id,
            title = title,
            description = description,
            category = category,
            status = status,
            creationDate = date,
            authorId = (data["authorId"] as? String)?.ifEmpty { null },
            authorName = (data["authorName"] as? String)?.ifEmpty { null },
            votes = data["votes"] as? Int ?: 0,
            replies = replies,
            likes = data["likes"] as? Int ?: 0,
        )
    }

    private fun createReply(data: Map<String, Any?>, feedbackId: UUID): FeedbackReply? {
        val id = (data["id"] as? String)?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: return null
        val content = data["content"] as? String ?: return null
        val date = data["creationDate"] as? Date ?: return null
        return FeedbackReply(
            id = id,
            feedbackId = feedbackId,
            content = content,
            authorId = (data["authorId"] as? String)?.ifEmpty { null },
            authorName = (data["authorName"] as? String)?.ifEmpty { null },
            creationDate = date,
            isFromDeveloper = data["isFromDeveloper"] as? Boolean ?: false,
            likes = data["likes"] as? Int ?: 0,
        )
    }
}

/**
 * Lets feedback authors know when the developer replies. iOS also gets a push; Android has only
 * this check, on launch and from a periodic background job.
 */
object FeedbackReplyNotifier {
    private const val seenKey = "feedback_seen_developer_replies_v1"
    private const val lastCheckKey = "feedback_replies_last_check"
    private const val channelId = "feedback_replies"
    private const val minimumCheckSeconds = 5 * 60L
    private const val workName = "feedback-replies"
    private val seenSerializer = ListSerializer(String.serializer())
    private var isChecking = false

    /** Same key as iOS and the reply script: sha256("<FEEDBACK-UUID>\n<content>"), first 32 hex chars. */
    fun replyKey(feedbackId: UUID, content: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest("${feedbackId.uuidString}\n$content".toByteArray())
            .joinToString("") { "%02x".format(it) }
            .take(32)

    private fun developerReplies(items: List<FeedbackItem>) = items.flatMap { item ->
        item.replies.filter { it.isFromDeveloper }.map { Triple(item, it, replyKey(item.id, it.content)) }
    }

    private var seenKeys: Set<String>?
        get() = Store.load(seenKey, seenSerializer)?.toSet()
        set(value) {
            if (value == null) Store.remove(seenKey) else Store.save(seenKey, seenSerializer, value.toList())
        }

    fun markRepliesSeen(items: List<FeedbackItem>) {
        seenKeys = (seenKeys ?: emptySet()) + developerReplies(items).map { it.third }
    }

    /** The first run only records the existing replies, so old answers don't all fire at once. */
    suspend fun checkForNewReplies(force: Boolean = false): Boolean {
        if (isChecking) return false
        val last = Defaults.date(lastCheckKey)
        if (!force && last != null && now().epochSecond - last.epochSecond < minimumCheckSeconds) return false
        isChecking = true
        try {
            val items = runCatching { FeedbackManager.allUserIds().flatMap { FeedbackManager.fetchFeedback(it) } }.getOrNull() ?: return false
            Defaults.set(lastCheckKey, now())
            if (items.isEmpty()) return false
            val replies = developerReplies(items)
            val seen = seenKeys
            if (seen == null) {
                seenKeys = replies.map { it.third }.toSet()
                return false
            }
            val unseen = replies.filter { it.third !in seen }
            if (unseen.isEmpty()) return false
            unseen.takeLast(3).forEach { (item, reply, key) -> post(item, reply, key) }
            seenKeys = seen + unseen.map { it.third }
            return true
        } finally {
            isChecking = false
        }
    }

    private fun post(feedback: FeedbackItem, reply: FeedbackReply, key: String) {
        if (!TaskNotificationManager.isAuthorized) return
        val context: Context = App.context
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(channelId, "feedback_suggestions".localized, NotificationManager.IMPORTANCE_DEFAULT))
        val id = key.hashCode()
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("openFeedbackId", feedback.id.uuidString)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("feedback_reply_notification_title".localized)
            .setSubText(feedback.title)
            .setContentText(reply.content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(reply.content))
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id, notification) }
    }

    fun scheduleBackgroundRefresh(context: Context) {
        val request = PeriodicWorkRequestBuilder<FeedbackRepliesWorker>(1, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(workName, ExistingPeriodicWorkPolicy.KEEP, request)
    }
}

class FeedbackRepliesWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        FeedbackReplyNotifier.checkForNewReplies(force = true)
        return Result.success()
    }
}

// MARK: - News

object UpdateNewsService {
    private const val cacheKey = "cached_update_news"
    private const val lastViewedKey = "last_news_viewed"
    private const val collection = "app_updates"
    private val serializer = ListSerializer(UpdateNews.serializer())
    private var started = false

    var newsItems by mutableStateOf(runCatching { Store.load(cacheKey, serializer) }.getOrNull() ?: emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    private var lastViewed by mutableStateOf(Defaults.date(lastViewedKey))

    /** The first time it's asked for, like the shared instance on iOS. */
    fun start() {
        if (started) return
        started = true
        MainScope.launch { fetchNews() }
    }

    suspend fun fetchNews() {
        isLoading = true
        runCatching { Firestore.list(collection, limit = 50) }.onSuccess { documents ->
            newsItems = documents.mapNotNull { document ->
                val fields = document.fields
                val title = fields["title"] as? String ?: return@mapNotNull null
                val description = fields["description"] as? String ?: return@mapNotNull null
                val type = NewsType.entries.firstOrNull { it.rawValue == fields["type"] } ?: return@mapNotNull null
                UpdateNews(
                    id = document.id,
                    title = title,
                    description = description,
                    version = (fields["version"] as? String)?.trim()?.ifEmpty { null },
                    date = fields["date"] as? Date,
                    type = type,
                    isHighlighted = fields["isHighlighted"] as? Boolean ?: false,
                )
            }
            Store.save(cacheKey, serializer, newsItems)
        }
        isLoading = false
    }

    fun markAsViewed() {
        lastViewed = now()
        Defaults.set(lastViewedKey, lastViewed!!)
    }

    fun hasUnreadHighlightedItems(): Boolean {
        val highlighted = newsItems.filter { it.isHighlighted }
        val viewed = lastViewed ?: return highlighted.isNotEmpty()
        return highlighted.any { item -> item.date?.let { it.isAfter(viewed) } == true }
    }

    fun news(type: NewsType): List<UpdateNews> = newsItems.filter { it.type == type }.sortedWith(newsOrder)
}

/** Highlighted first, then the newest, then by title. */
val newsOrder: Comparator<UpdateNews> = compareBy<UpdateNews> { !it.isHighlighted }
    .thenBy { it.date == null }
    .thenByDescending { it.date }
    .thenBy { it.title }
