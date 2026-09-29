import SwiftUI

/// Category management opened from the category picker: same screen as Settings → Categories.
struct CategoryEditorView: View {
    @StateObject private var viewModel = SettingsViewModel.shared
    
    var body: some View {
        CategoriesView(viewModel: viewModel)
    }
}

struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    let onColorSelected: (String) -> Void
    
    private let colors = [
        "#FF69B4", "#FF0000", "#FFA500", "#FFFF00", 
        "#00FF00", "#0000FF", "#800080", "#A52A2A",
        "#808080", "#000000"
    ]
    
    var body: some View {
        List {
            ForEach(colors, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 24, height: 24)
                        Spacer()
                        if color == selectedColor {
                            Image(systemName: "checkmark")
                                .foregroundColor(.pink)
                        }
                    }
                }
            }
        }
        .navigationTitle("select_color".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) {
                    dismiss()
                }
            }
        }
    } 
}