import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let startX: CGFloat
    let delay: Double
    let speed: Double
    let driftX: CGFloat
    let rotationSpeed: Double
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        .red, .blue, .green, .yellow, .purple, .orange, .pink, .mint, .cyan, .indigo
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    FallingParticle(particle: particle, screenHeight: geometry.size.height)
                }
            }
            .onAppear {
                spawnParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func spawnParticles(in size: CGSize) {
        var new: [ConfettiParticle] = []
        for _ in 0..<90 {
            // Randomly square or rectangle
            let w = CGFloat.random(in: 6...12)
            let h = Bool.random() ? w : w * CGFloat.random(in: 1.5...2.5) // square or rectangle

            let p = ConfettiParticle(
                color: colors.randomElement() ?? .yellow,
                width: w,
                height: h,
                startX: CGFloat.random(in: 0...size.width),
                delay: Double.random(in: 0...0.3),
                speed: Double.random(in: 0.4...0.8),
                driftX: CGFloat.random(in: -30...30),
                rotationSpeed: Double.random(in: -3.0...3.0)
            )
            new.append(p)
        }
        particles = new
    }
}

/// A single falling square/rectangle particle.
private struct FallingParticle: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var offsetY: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.width, height: particle.height)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(x: particle.startX + offsetX, y: -20 + offsetY)
            .onAppear {
                let totalFall = screenHeight + 60
                DispatchQueue.main.asyncAfter(deadline: .now() + particle.delay) {
                    withAnimation(.linear(duration: particle.speed)) {
                        offsetY = totalFall
                        offsetX = particle.driftX
                        rotation = particle.rotationSpeed * 360
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + particle.speed * 0.65) {
                        withAnimation(.linear(duration: particle.speed * 0.35)) {
                            opacity = 0
                        }
                    }
                }
            }
    }
}

extension Animation {
    static var customExplosion: Animation {
        Animation.timingCurve(0.1, 0.9, 0.2, 1.0, duration: 2.2)
    }
}

@MainActor
class ConfettiManager: ObservableObject {
    static let shared = ConfettiManager()
    @Published var triggerCounter = 0

    private init() {}

    func trigger() {
        guard CloudKitSettingsManager.shared.enableConfettiCelebration else { return }
        self.triggerCounter += 1
    }
}
