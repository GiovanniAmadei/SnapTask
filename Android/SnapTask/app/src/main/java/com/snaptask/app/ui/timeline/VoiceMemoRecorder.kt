package com.snaptask.app.ui.timeline

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import com.snaptask.app.data.model.MediaLimits
import com.snaptask.app.data.model.TaskVoiceMemo
import java.io.File
import java.util.UUID

class VoiceMemoRecorder(
    private val context: Context,
) {
    private var recorder: MediaRecorder? = null
    private var currentFile: File? = null
    private var startMs: Long = 0L

    private var player: MediaPlayer? = null
    private var playingPath: String? = null

    fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    fun isRecording(): Boolean = recorder != null

    fun start(taskId: UUID): Boolean {
        if (recorder != null) return false

        val folder = File(File(context.filesDir, "Attachments"), taskId.toString()).apply { mkdirs() }
        val uid = UUID.randomUUID()
        val file = File(folder, "memo_${uid}.m4a")
        currentFile = file
        startMs = System.currentTimeMillis()

        val r = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioChannels(1)
            setAudioEncodingBitRate(128_000)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }

        recorder = r
        return true
    }

    fun stop(): TaskVoiceMemo? {
        val r = recorder ?: return null
        val file = currentFile ?: return null

        return try {
            r.stop()
            r.release()
            recorder = null

            val durationSeconds = (System.currentTimeMillis() - startMs) / 1000.0
            currentFile = null
            startMs = 0L

            val bounded = durationSeconds.coerceAtMost(MediaLimits.maxVoiceMemoDurationSeconds)
            TaskVoiceMemo(
                id = UUID.randomUUID(),
                audioPath = file.absolutePath,
                duration = bounded,
                createdAt = System.currentTimeMillis(),
            )
        } catch (e: Exception) {
            try {
                r.release()
            } catch (_: Exception) {
            }
            recorder = null
            null
        }
    }

    fun currentDurationSeconds(): Double {
        if (recorder == null) return 0.0
        return (System.currentTimeMillis() - startMs) / 1000.0
    }

    fun play(path: String, onComplete: () -> Unit) {
        stopPlayback()
        val p = MediaPlayer().apply {
            setDataSource(path)
            setOnCompletionListener {
                stopPlayback()
                onComplete()
            }
            prepare()
            start()
        }
        player = p
        playingPath = path
    }

    fun isPlaying(path: String): Boolean = playingPath == path && player != null

    fun stopPlayback() {
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        playingPath = null
    }

    fun deleteMemo(memo: TaskVoiceMemo) {
        File(memo.audioPath).delete()
        if (playingPath == memo.audioPath) {
            stopPlayback()
        }
    }
}
