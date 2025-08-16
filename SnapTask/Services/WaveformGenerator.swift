import Foundation
import AVFoundation

enum WaveformGenerator {
    static func generate(from url: URL, samples targetSamples: Int = 60) async -> [Float] {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let totalFrames = AVAudioFrameCount(file.length)
            if totalFrames == 0 { return [] }

            let bins = max(8, min(200, targetSamples))
            let framesPerBin = max(512, Int64(file.length) / Int64(bins))
            var peaks: [Float] = []
            peaks.reserveCapacity(bins)

            var framesRemaining = Int64(file.length)
            while framesRemaining > 0 && peaks.count < bins {
                let framesToRead = AVAudioFrameCount(min(Int64(framesRemaining), framesPerBin))
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead)!
                try file.read(into: buffer, frameCount: framesToRead)
                if buffer.frameLength == 0 { break }

                if let data = buffer.floatChannelData {
                    let channels = Int(format.channelCount)
                    let frameLen = Int(buffer.frameLength)
                    var peak: Float = 0
                    for ch in 0..<channels {
                        let ptr = data[ch]
                        var channelPeak: Float = 0
                        for i in 0..<frameLen {
                            let s = ptr[i]
                            let a = s >= 0 ? s : -s
                            if a > channelPeak { channelPeak = a }
                        }
                        if channelPeak > peak { peak = channelPeak }
                    }
                    peaks.append(peak)
                } else {
                    peaks.append(0)
                }

                framesRemaining -= Int64(framesToRead)
            }

            guard !peaks.isEmpty else { return [] }

            // Normalizza e modella per maggior contrasto
            let maxVal = max(0.0001, peaks.max() ?? 1)
            var normalized = peaks.map { min(1, max(0, $0 / maxVal)) }

            // Noise floor per evitare tappeto piatto
            let noiseFloor: Float = 0.03
            normalized = normalized.map { $0 < noiseFloor ? 0 : $0 }

            // Espansione gamma per far “saltare” i picchi
            let gamma: Float = 0.6
            normalized = normalized.map { pow($0, gamma) }

            if normalized.count < bins {
                normalized.append(contentsOf: Array(repeating: 0, count: bins - normalized.count))
            } else if normalized.count > bins {
                normalized = Array(normalized.prefix(bins))
            }

            return normalized
        } catch {
            return []
        }
    }
}