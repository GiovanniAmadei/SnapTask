package com.snaptask.app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.snaptask.app.data.model.TaskPhoto
import com.snaptask.app.data.model.TaskVoiceMemo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for managing task attachments (photos and voice memos).
 * Faithful port of iOS AttachmentService.
 */
@Singleton
class AttachmentService @Inject constructor(
    private val context: Context,
) {
    private val attachmentsRoot: File
        get() = File(context.filesDir, "Attachments").apply { mkdirs() }

    private fun taskFolder(taskId: UUID): File {
        return File(attachmentsRoot, taskId.toString()).apply { mkdirs() }
    }

    private fun journalFolder(entryId: UUID): File {
        return File(File(attachmentsRoot, "Journal"), entryId.toString()).apply { mkdirs() }
    }

    // ============ Task Photos ============

    /**
     * Save a photo for a task with automatic downscaling.
     * Returns paths to the saved photo and thumbnail.
     */
    fun savePhoto(taskId: UUID, imageData: ByteArray): Pair<String, String>? {
        val original = BitmapFactory.decodeByteArray(imageData, 0, imageData.size) ?: return null

        // Downscale to max dimension 1600 px
        val scaled = downscale(original, maxDimension = 1600)
        val jpeg = compressToJpeg(scaled, quality = 85) ?: return null

        // Thumbnail ~200 px
        val thumb = downscale(scaled, maxDimension = 200)
        val thumbJpeg = compressToJpeg(thumb, quality = 80) ?: return null

        val folder = taskFolder(taskId)
        val photoFile = File(folder, "photo.jpg")
        val thumbFile = File(folder, "thumb.jpg")

        return try {
            FileOutputStream(photoFile).use { it.write(jpeg) }
            FileOutputStream(thumbFile).use { it.write(thumbJpeg) }
            Pair(photoFile.absolutePath, thumbFile.absolutePath)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Add a new photo to a task's photo collection.
     */
    fun addPhoto(taskId: UUID, imageData: ByteArray): TaskPhoto? {
        val original = BitmapFactory.decodeByteArray(imageData, 0, imageData.size) ?: return null
        val scaled = downscale(original, maxDimension = 1600)
        val jpeg = compressToJpeg(scaled, quality = 85) ?: return null

        val thumb = downscale(scaled, maxDimension = 200)
        val thumbJpeg = compressToJpeg(thumb, quality = 80) ?: return null

        val folder = taskFolder(taskId)
        val uid = UUID.randomUUID().toString()
        val photoFile = File(folder, "photo_$uid.jpg")
        val thumbFile = File(folder, "thumb_$uid.jpg")

        return try {
            FileOutputStream(photoFile).use { it.write(jpeg) }
            FileOutputStream(thumbFile).use { it.write(thumbJpeg) }
            TaskPhoto(
                id = UUID.fromString(uid),
                photoPath = photoFile.absolutePath,
                thumbnailPath = thumbFile.absolutePath,
                createdAt = System.currentTimeMillis(),
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Delete a specific photo from a task.
     */
    fun deletePhoto(taskId: UUID, photo: TaskPhoto) {
        File(photo.photoPath).delete()
        File(photo.thumbnailPath).delete()

        // Remove empty folder
        val folder = taskFolder(taskId)
        if (folder.listFiles()?.isEmpty() == true) {
            folder.delete()
        }
    }

    /**
     * Delete all photos for a task.
     */
    fun deleteAllPhotos(taskId: UUID) {
        taskFolder(taskId).deleteRecursively()
    }

    /**
     * Load a bitmap from a file path.
     */
    fun loadImage(path: String): Bitmap? {
        return if (File(path).exists()) {
            BitmapFactory.decodeFile(path)
        } else null
    }

    // ============ Journal Photos ============

    fun addJournalPhoto(
        entryId: UUID,
        imageData: ByteArray,
        id: UUID = UUID.randomUUID(),
        createdAt: Long = System.currentTimeMillis(),
    ): TaskPhoto? {
        val original = BitmapFactory.decodeByteArray(imageData, 0, imageData.size) ?: return null
        val scaled = downscale(original, maxDimension = 1600)
        val jpeg = compressToJpeg(scaled, quality = 85) ?: return null

        val thumb = downscale(scaled, maxDimension = 200)
        val thumbJpeg = compressToJpeg(thumb, quality = 80) ?: return null

        val folder = journalFolder(entryId)
        val photoFile = File(folder, "photo_${id}.jpg")
        val thumbFile = File(folder, "thumb_${id}.jpg")

        return try {
            FileOutputStream(photoFile).use { it.write(jpeg) }
            FileOutputStream(thumbFile).use { it.write(thumbJpeg) }
            TaskPhoto(
                id = id,
                photoPath = photoFile.absolutePath,
                thumbnailPath = thumbFile.absolutePath,
                createdAt = System.currentTimeMillis(),
            )
        } catch (e: Exception) {
            null
        }
    }

    fun deleteJournalPhoto(entryId: UUID, photo: TaskPhoto) {
        File(photo.photoPath).delete()
        File(photo.thumbnailPath).delete()
    }

    // ============ Voice Memos ============

    fun saveVoiceMemo(
        taskId: UUID,
        audioData: ByteArray,
        duration: Double,
    ): TaskVoiceMemo? {
        val folder = taskFolder(taskId)
        val uid = UUID.randomUUID()
        val audioFile = File(folder, "voicememo_${uid}.m4a")

        return try {
            FileOutputStream(audioFile).use { it.write(audioData) }
            TaskVoiceMemo(
                id = uid,
                audioPath = audioFile.absolutePath,
                duration = duration,
                createdAt = System.currentTimeMillis(),
            )
        } catch (e: Exception) {
            null
        }
    }

    fun deleteVoiceMemo(taskId: UUID, memo: TaskVoiceMemo) {
        File(memo.audioPath).delete()
    }

    fun loadVoiceMemo(path: String): ByteArray? {
        return try {
            File(path).readBytes()
        } catch (e: Exception) {
            null
        }
    }

    // ============ Helper Methods ============

    private fun downscale(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        if (width <= maxDimension && height <= maxDimension) {
            return bitmap
        }

        val ratio = width.toFloat() / height.toFloat()
        val newWidth: Int
        val newHeight: Int

        if (width > height) {
            newWidth = maxDimension
            newHeight = (maxDimension / ratio).toInt()
        } else {
            newHeight = maxDimension
            newWidth = (maxDimension * ratio).toInt()
        }

        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    private fun compressToJpeg(bitmap: Bitmap, quality: Int): ByteArray? {
        return try {
            java.io.ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
                stream.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Resolve a potentially stale file path.
     */
    fun resolveFilePath(path: String): String? {
        val file = File(path)
        return if (file.exists()) file.absolutePath else null
    }

    /**
     * Get the total size of all attachments in bytes.
     */
    fun getTotalAttachmentSize(): Long {
        return attachmentsRoot.walkTopDown()
            .filter { it.isFile }
            .sumOf { it.length() }
    }

    /**
     * Clean up orphaned attachment folders.
     */
    suspend fun cleanupOrphanedAttachments(validTaskIds: Set<UUID>, validEntryIds: Set<UUID>) =
        withContext(Dispatchers.IO) {
            attachmentsRoot.listFiles()?.forEach { folder ->
                if (folder.isDirectory && folder.name != "Journal") {
                    try {
                        val taskId = UUID.fromString(folder.name)
                        if (taskId !in validTaskIds) {
                            folder.deleteRecursively()
                        }
                    } catch (e: IllegalArgumentException) {
                        // Not a valid UUID, skip
                    }
                }
            }
        }
}
