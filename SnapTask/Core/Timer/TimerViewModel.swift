import Combine
import Foundation

@MainActor
protocol TimerViewModel: ObservableObject {
    associatedtype State: Equatable
    var timeRemaining: TimeInterval { get set }
    var progress: Double { get }
    var state: State { get set }
    
    func start()
    func pause()
    func reset()
}

@MainActor
extension TimerViewModel {
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 