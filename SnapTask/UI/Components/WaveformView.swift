import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    var color: Color = .blue
    var spacing: CGFloat = 2
    var cornerRadius: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let raw = (i < levels.count) ? levels[i] : 0
                    let level = max(0, min(1, raw))
                    let h = max(2, CGFloat(level) * geo.size.height)
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: barWidth, height: h)
                        .frame(height: geo.size.height, alignment: .center)
                }
            }
        }
        .frame(height: 36)
        .drawingGroup()
    }
}