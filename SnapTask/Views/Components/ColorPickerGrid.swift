import SwiftUI

struct ColorPickerGrid: View {
    @Binding var selectedColor: String
    
    private let presetColors: [[Color]] = [
        [.red, .orange, .yellow, .green],
        [.mint, .teal, .cyan, .blue],
        [.indigo, .purple, .pink, .brown],
        [.gray, .black, .white, .clear]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(presetColors, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { color in
                        Button {
                            selectedColor = color.toHex()
                        } label: {
                            Circle()
                                .fill(color)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .opacity(selectedColor == color.toHex() ? 1 : 0)
                                )
                                .frame(width: 44, height: 44)
                        }
                    }
                }
            }
            
            ColorPicker("Custom Color", selection: Binding(
                get: { Color(hex: selectedColor) },
                set: { selectedColor = $0.toHex() }
            ))
        }
        .padding(.vertical, 8)
    }
}