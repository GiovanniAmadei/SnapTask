import Foundation
import AVFoundation
import QuartzCore

final class VoiceMemoService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording: Bool = false
    @Published var meterLevels: [Float] = []
    @Published private(set) var currentRecordingDuration: TimeInterval = 0
    @Published private(set) var didReachMaxDuration: Bool = false

    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?
    private var recordingStartDate: Date?
    private var displayLink: CADisplayLink?
    private var durationTimer: Timer?
    private var lastMeterLevel: Float = 0
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    private var attachmentsRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Attachments", isDirectory: true)
    }

    private func taskFolder(for taskId: UUID) -> URL {
        attachmentsRoot.appendingPathComponent(taskId.uuidString, isDirectory: true)
    }
    
    private func journalFolder(for entryId: UUID) -> URL {
        attachmentsRoot.appendingPathComponent("Journal", isDirectory: true)
            .appendingPathComponent(entryId.uuidString, isDirectory: true)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Task Voice Memos

    func startRecording(for taskId: UUID) throws {
        if isRecording {
            stopRecording()
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let folder = taskFolder(for: taskId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let uid = UUID().uuidString
        let fileURL = folder.appendingPathComponent("memo_\(uid).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        self.currentFileURL = fileURL
        self.recordingStartDate = Date()
        self.isRecording = true
        self.currentRecordingDuration = 0
        self.didReachMaxDuration = false
        
        // Start duration timer for max duration limit
        startDurationTimer()
        
        try startRealTimeWaveform()
    }

    func stopRecording() -> TaskVoiceMemo? {
        guard isRecording, let url = currentFileURL else { return nil }
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopRealTimeWaveform()

        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)

        let memo = TaskVoiceMemo(audioPath: url.path, duration: durationSeconds, createdAt: recordingStartDate ?? Date())

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
        }

        currentFileURL = nil
        recordingStartDate = nil
        stopDurationTimer()
        return memo
    }
    
    // MARK: - Duration Timer
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.recordingStartDate else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            DispatchQueue.main.async {
                self.currentRecordingDuration = elapsed
                
                // Auto-stop if max duration reached
                if elapsed >= MediaLimits.maxVoiceMemoDuration {
                    self.didReachMaxDuration = true
                    _ = self.stopRecording()
                }
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        currentRecordingDuration = 0
    }

    // MARK: - Journal Voice Memos

    func startJournalRecording(for entryId: UUID) throws {
        if isRecording {
            stopJournalRecording()
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let folder = journalFolder(for: entryId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let uid = UUID().uuidString
        let fileURL = folder.appendingPathComponent("journal_memo_\(uid).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        self.currentFileURL = fileURL
        self.recordingStartDate = Date()
        self.isRecording = true
        self.currentRecordingDuration = 0
        self.didReachMaxDuration = false
        
        // Start duration timer for max duration limit
        startDurationTimer()
        
        try startRealTimeWaveform()
    }

    func stopJournalRecording() -> JournalVoiceMemo? {
        guard isRecording, let url = currentFileURL else { return nil }
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopRealTimeWaveform()

        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)

        let memo = JournalVoiceMemo(audioPath: url.path, duration: durationSeconds, createdAt: recordingStartDate ?? Date())

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
        }

        currentFileURL = nil
        recordingStartDate = nil
        stopDurationTimer()
        return memo
    }

    // MARK: - Common Methods

    func cancelRecordingAndDeleteFile() {
        recorder?.stop()
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        currentFileURL = nil
        recordingStartDate = nil
        isRecording = false
        stopRealTimeWaveform()
        stopDurationTimer()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
        }
    }

    func deleteMemo(_ memo: TaskVoiceMemo) {
        if FileManager.default.fileExists(atPath: memo.audioPath) {
            try? FileManager.default.removeItem(atPath: memo.audioPath)
        }
    }

    func deleteJournalMemo(_ memo: JournalVoiceMemo) {
        if FileManager.default.fileExists(atPath: memo.audioPath) {
            try? FileManager.default.removeItem(atPath: memo.audioPath)
        }
    }

    func renameMemo(_ memo: TaskVoiceMemo, to newName: String) -> TaskVoiceMemo {
        var updatedMemo = memo
        updatedMemo.name = newName.isEmpty ? nil : newName
        return updatedMemo
    }

    func renameJournalMemo(_ memo: JournalVoiceMemo, to newName: String) -> JournalVoiceMemo {
        var updatedMemo = memo
        updatedMemo.name = newName.isEmpty ? nil : newName
        return updatedMemo
    }

    private func startRealTimeWaveform() throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }
        
        inputNode = audioEngine.inputNode
        guard let inputNode else { return }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        try audioEngine.start()
        
        meterLevels = Array(repeating: 0, count: 64)
        lastMeterLevel = 0
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(updateWaveformDisplay))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopRealTimeWaveform() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        displayLink?.invalidate()
        displayLink = nil
        lastMeterLevel = 0
    }

    private var currentPeak: Float = 0
    private let peakLock = NSLock()

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]
        
        var peak: Float = 0
        for i in 0..<frameLength {
            let sample = samples[i]
            let amplitude = sample >= 0 ? sample : -sample
            if amplitude > peak {
                peak = amplitude
            }
        }
        
        peakLock.lock()
        currentPeak = peak
        peakLock.unlock()
    }

    @objc private func updateWaveformDisplay() {
        peakLock.lock()
        let peak = currentPeak
        peakLock.unlock()
        
        // Stessa elaborazione della waveform dei file
        let noiseFloor: Float = 0.03
        let processedPeak = peak < noiseFloor ? 0 : peak
        
        // Stessa curva gamma della waveform statica
        let gamma: Float = 0.6
        let visualLevel = pow(processedPeak, gamma)
        
        var arr = meterLevels
        arr.append(visualLevel)
        if arr.count > 64 { 
            arr.removeFirst(arr.count - 64) 
        }
        meterLevels = arr
    }
}