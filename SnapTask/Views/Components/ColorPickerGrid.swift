import SwiftUI

struct ColorPickerGrid: View {
    @Binding var selectedColor: String

    private let presetColors: [String] = [
        "#EF4444", "#F97316", "#F59E0B", "#EAB308",
        "#22C55E", "#10B981", "#14B8A6", "#06B6D4",
        "#3B82F6", "#6366F1", "#8B5CF6", "#A855F7",
        "#EC4899", "#F43F5E", "#84CC16", "#94A3B8"
    ]

    private let columns = 8

    var body: some View {
        VStack(spacing: 12) {
            let rows = presetColors.chunked(into: columns)
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 10) {
                    ForEach(rows[rowIndex], id: \.self) { hex in
                        Button {
                            selectedColor = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(radius: 1)
                                        .opacity(selectedColor.uppercased() == hex.uppercased() ? 1 : 0)
                                )
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Native color picker as a standalone row
            ColorPicker("custom_colors".localized, selection: Binding(
                get: { Color(hex: selectedColor) },
                set: { newColor in
                    if let hex = newColor.resolvedHex() {
                        selectedColor = hex
                    }
                }
            ), supportsOpacity: false)
        }
        .padding(.vertical, 8)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension Color {
    func resolvedHex() -> String? {
        let uiColor = UIColor(self).resolvedColor(with: UITraitCollection.current)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }
}