package com.snaptask.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaPlayer
import android.media.MediaRecorder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteOrder
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Records voice memos of a task or of a journal entry. */
class VoiceMemoService {
    var isRecording by mutableStateOf(false)
        private set
    var meterLevels by mutableStateOf<List<Float>>(emptyList())
        private set
    var currentRecordingDuration by mutableStateOf(0.0)
        private set
    var didReachMaxDuration by mutableStateOf(false)
        private set

    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var startedAt: Date? = null
    private var timer: Job? = null

    fun start(folder: File, onMax: () -> Unit) {
        folder.mkdirs()
        val id = UUID.randomUUID().uuidString
        val output = File(folder, "memo_$id.m4a")
        val media = if (android.os.Build.VERSION.SDK_INT >= 31) MediaRecorder(App.context) else @Suppress("DEPRECATION") MediaRecorder()
        media.setAudioSource(MediaRecorder.AudioSource.MIC)
        media.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        media.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        media.setAudioSamplingRate(44100)
        media.setAudioEncodingBitRate(128000)
        media.setOutputFile(output.path)
        media.prepare()
        media.start()
        recorder = media
        file = output
        startedAt = now()
        isRecording = true
        didReachMaxDuration = false
        meterLevels = emptyList()
        currentRecordingDuration = 0.0
        timer = MainScope.launch {
            while (isRecording) {
                delay(100)
                val level = (recorder?.maxAmplitude ?: 0) / 32767f
                meterLevels = (meterLevels + sqrt(level).coerceIn(0.03f, 1f)).takeLast(60)
                currentRecordingDuration = now().timeIntervalSince(startedAt ?: now())
                if (currentRecordingDuration >= MediaLimits.maxVoiceMemoDuration) {
                    didReachMaxDuration = true
                    onMax()
                    break
                }
            }
        }
    }

    /** Stops and gives the file with its length, nil when nothing usable was recorded. */
    fun stop(): Pair<String, Double>? {
        val path = file?.path
        val duration = now().timeIntervalSince(startedAt ?: now())
        timer?.cancel()
        runCatching { recorder?.stop() }
        runCatching { recorder?.release() }
        recorder = null
        file = null
        isRecording = false
        return if (path != null && duration > 0.3) path to duration else null
    }

    companion object {
        fun taskFolder(taskId: UUID) = File(File(App.filesDir, "Attachments"), taskId.uuidString)
        fun journalFolder(entryId: UUID) = File(File(File(App.filesDir, "Attachments"), "Journal"), entryId.uuidString)
    }
}

/** Plays a memo. */
class AudioPlayerObject {
    var isPlaying by mutableStateOf(false)
        private set
    var currentTime by mutableStateOf(0.0)
        private set
    var duration by mutableStateOf(0.0)
        private set
    private var player: MediaPlayer? = null
    private var path: String? = null
    private var ticker: Job? = null

    fun prepare(path: String) {
        if (this.path == path && player != null) return
        release()
        this.path = path
        player = runCatching {
            MediaPlayer().apply {
                setDataSource(path)
                prepare()
                setOnCompletionListener {
                    this@AudioPlayerObject.isPlaying = false
                    currentTime = 0.0
                    ticker?.cancel()
                }
            }
        }.getOrNull()
        duration = (player?.duration ?: 0) / 1000.0
        currentTime = 0.0
    }

    fun play(path: String) {
        prepare(path)
        val media = player ?: return
        media.start()
        isPlaying = true
        ticker?.cancel()
        ticker = MainScope.launch {
            while (isPlaying) {
                currentTime = media.currentPosition / 1000.0
                delay(100)
            }
        }
    }

    fun seek(time: Double) {
        val media = player ?: return
        val clamped = max(0.0, min(time, duration))
        media.seekTo((clamped * 1000).toInt())
        currentTime = clamped
    }

    fun pause() {
        runCatching { player?.pause() }
        isPlaying = false
        ticker?.cancel()
    }

    fun release() {
        ticker?.cancel()
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        path = null
        isPlaying = false
        currentTime = 0.0
    }
}

/** Levels of an audio file for the memo rows. */
object WaveformGenerator {
    suspend fun generate(path: String, samples: Int): List<Float> = withContext(Dispatchers.IO) {
        runCatching {
            val extractor = MediaExtractor()
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return@runCatching emptyList<Float>()
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()
            val values = ArrayList<Float>()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            while (!outputDone) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(10_000)
                    if (index >= 0) {
                        val size = extractor.readSampleData(codec.getInputBuffer(index)!!, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val output = codec.dequeueOutputBuffer(info, 10_000)
                if (output >= 0) {
                    val buffer = codec.getOutputBuffer(output)
                    if (buffer != null && info.size > 0) {
                        val shorts = buffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        var peak = 0
                        var position = 0
                        while (position < shorts.remaining()) {
                            peak = max(peak, abs(shorts.get(position).toInt()))
                            position += 8
                        }
                        values += peak / 32767f
                    }
                    codec.releaseOutputBuffer(output, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }
            codec.stop()
            codec.release()
            extractor.release()
            if (values.isEmpty()) return@runCatching emptyList<Float>()
            val bin = max(1, values.size / samples)
            val result = values.chunked(bin).map { chunk -> chunk.max() }.take(samples)
            val top = result.max().coerceAtLeast(0.01f)
            result.map { (it / top).coerceIn(0.05f, 1f) }
        }.getOrDefault(emptyList())
    }
}
