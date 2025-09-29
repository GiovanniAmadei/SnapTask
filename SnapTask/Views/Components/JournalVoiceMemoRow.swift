import SwiftUI
import AVFoundation
import Combine

struct JournalVoiceMemoRow: View {
    let memo: JournalVoiceMemo
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onEditingStateChanged: (Bool) -> Void
    @StateObject private var player = AudioPlayerObject()
    @State private var waveform: [Float] = []
    @State private var isLoadingWaveform = true
    @State private var isEditing = false
    @State private var editingText = ""
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play(path: memo.audioPath)
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            .disabled(isEditing)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isEditing {
                        TextField("voice_memo_name_placeholder".localized, text: $editingText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.subheadline.weight(.medium))
                            .onSubmit {
                                saveName()
                            }
                        
                        Button("save".localized) {
                            saveName()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("cancel".localized) {
                            cancelEditing()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    } else {
                        HStack(spacing: 4) {
                            Text(memo.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                startEditing()
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                        
                        if player.isPlaying || player.currentTime > 0 {
                            Text("\(formatTime(player.currentTime)) / \(formatTime(memo.duration))")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if !isEditing {
                    Text(formatted(duration: memo.duration) + " • " + memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let progress = memo.duration > 0 ? (player.currentTime / memo.duration) : 0.0
                    WaveformWithProgress(
                        levels: waveform, 
                        color: .blue, 
                        progress: progress,
                        onScrub: { p in
                            let t = max(0, min(memo.duration, p * memo.duration))
                            player.seek(to: t)
                        }
                    )
                    .frame(height: 28)
                }
            }
            
            Spacer()

            Button {
                player.stop()
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            player.prepare(path: memo.audioPath)
            if waveform.isEmpty {
                let path = memo.audioPath
                Task {
                    let samples = await WaveformGenerator.generate(from: URL(fileURLWithPath: path), samples: 60)
                    await MainActor.run {
                        self.waveform = samples.isEmpty ? Array(repeating: 0.2, count: 60) : samples
                        self.isLoadingWaveform = false
                    }
                }
            } else {
                isLoadingWaveform = false
            }
        }
    }
    
    private func startEditing() {
        editingText = memo.name ?? ""
        isEditing = true
        onEditingStateChanged(true)
    }
    
    private func saveName() {
        onRename(editingText)
        isEditing = false
        onEditingStateChanged(false)
    }
    
    private func cancelEditing() {
        editingText = ""
        isEditing = false
        onEditingStateChanged(false)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatted(duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%02dm %02ds", m, s)
        }
    }
}

// Riutilizziamo lo stesso AudioPlayerObject da TaskDetailView
private final class AudioPlayerObject: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var lastURL: URL?

    func prepare(path: String) {
        let url = URL(fileURLWithPath: path)
        if let existing = lastURL, existing == url, player != nil {
            duration = player?.duration ?? duration
            return
        }
        do {
            lastURL = url
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
        } catch {
            player = nil
            duration = 0
            currentTime = 0
        }
    }

    func play(path: String) {
        if let p = player, let last = lastURL, last.path == path {
            if !p.isPlaying {
                p.play()
                isPlaying = true
                startTimer()
            }
            return
        }
        
        let url = URL(fileURLWithPath: path)
        lastURL = url
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    func seek(to time: TimeInterval) {
        if player == nil, let url = lastURL {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        }
        guard let p = player else { return }
        let clamped = max(0, min(time, p.duration))
        p.currentTime = clamped
        currentTime = clamped
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
}

private struct WaveformWithProgress: View {
    let levels: [Float]
    var color: Color = .blue
    var spacing: CGFloat = 2
    let progress: Double 
    var onScrub: ((Double) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(count))
            let progressIndex = Int(Double(count) * progress)
            
            ZStack {
                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { i in
                        let raw = (i < levels.count) ? levels[i] : 0
                        let level = max(0, min(1, raw))
                        let h = max(2, CGFloat(level) * geo.size.height)
                        
                        Capsule(style: .continuous)
                            .fill(i <= progressIndex ? color : color.opacity(0.3))
                            .frame(width: barWidth, height: h)
                            .frame(height: geo.size.height, alignment: .center)
                    }
                }
                
                ZStack {
                    Capsule()
                        .fill(color.opacity(0.6))
                        .frame(width: 4, height: geo.size.height + 4)
                        .blur(radius: 1)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: 2, height: geo.size.height)
                    
                }
                .position(x: progress * geo.size.width, y: geo.size.height / 2)
                .animation(.easeOut(duration: 0.1), value: progress) 

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = max(0, min(1, value.location.x / geo.size.width))
                                onScrub?(p)
                            }
                            .onEnded { value in
                                let p = max(0, min(1, value.location.x / geo.size.width))
                                onScrub?(p)
                            }
                    )
            }
        }
        .drawingGroup()
    }
}