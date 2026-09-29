import SwiftUI

extension Category {
    /// Icon to render when the user hasn't picked one yet.
    var displayIcon: String { icon ?? "tag.fill" }
}

/// Reusable icon tile: the category color as a soft background, the symbol tinted on top.
struct CategoryIconTile: View {
    let icon: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                    .fill(color.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var name: String
    @State private var colorHex: String
    @State private var icon: String
    @State private var showingAllIcons = false
    @FocusState private var nameFocused: Bool
    private let editingCategory: Category?
    var onSave: (Category) -> Void

    static let palette = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#30B0C7", "#32ADE6",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93"
    ]

    static let suggestedIcons = [
        "briefcase.fill", "house.fill", "heart.fill", "figure.run", "book.fill", "graduationcap.fill",
        "cart.fill", "banknote.fill", "person.2.fill", "paintbrush.fill", "music.note", "gamecontroller.fill",
        "airplane", "leaf.fill", "fork.knife", "bed.double.fill", "laptopcomputer", "brain.head.profile",
        "pawprint.fill", "star.fill", "sparkles", "target", "lightbulb.fill", "tag.fill"
    ]

    init(editingCategory: Category? = nil, onSave: @escaping (Category) -> Void) {
        self.editingCategory = editingCategory
        self.onSave = onSave
        _name = State(initialValue: editingCategory?.name ?? "")
        _colorHex = State(initialValue: editingCategory?.color ?? CategoryFormView.palette[7])
        _icon = State(initialValue: editingCategory?.displayIcon ?? "tag.fill")
    }

    private var tint: Color { Color(hex: colorHex) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isDuplicateName: Bool {
        CategoryManager.shared.categories.contains {
            $0.id != editingCategory?.id && $0.name.lowercased() == trimmedName.lowercased()
        }
    }

    private var isCustomColor: Bool {
        !Self.palette.contains { $0.caseInsensitiveCompare(colorHex) == .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                preview
                nameSection
                colorSection
                iconSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .themedBackground()
        .navigationTitle(editingCategory == nil ? "new_category".localized : "edit_category".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save".localized) {
                    onSave(Category(
                        id: editingCategory?.id ?? UUID(),
                        name: trimmedName,
                        color: colorHex,
                        icon: icon
                    ))
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(trimmedName.isEmpty || isDuplicateName)
            }
        }
        .sheet(isPresented: $showingAllIcons) {
            IconPickerView(selectedIcon: $icon)
        }
        .onAppear {
            if editingCategory == nil { nameFocused = true }
        }
    }

    // MARK: - Sections

    private var preview: some View {
        VStack(spacing: 10) {
            CategoryIconTile(icon: icon, color: tint, size: 72)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: icon)
                .animation(.easeInOut(duration: 0.2), value: colorHex)

            Text(trimmedName.isEmpty ? "category_name".localized : trimmedName)
                .font(.title3.weight(.semibold))
                .foregroundColor(trimmedName.isEmpty ? theme.secondaryTextColor : theme.textColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("category_name".localized, text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(card)

            if isDuplicateName {
                Label("category_name_exists".localized, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var colorSection: some View {
        section(title: "color".localized) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 12) {
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 34, height: 34)
                            .overlay(selectionRing(isSelected: colorHex.caseInsensitiveCompare(hex) == .orderedSame, color: Color(hex: hex)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hex)
                }

                // Custom color: system picker, highlighted when the current color isn't in the palette.
                ColorPicker("", selection: Binding(
                    get: { tint },
                    set: { colorHex = $0.toHex() }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34, height: 34)
                .overlay(selectionRing(isSelected: isCustomColor, color: tint))
                .accessibilityLabel("custom".localized)
            }
        }
    }

    private var iconSection: some View {
        section(title: "icon".localized) {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(Self.suggestedIcons, id: \.self) { symbol in
                        Button {
                            icon = symbol
                        } label: {
                            iconCell(symbol, isSelected: symbol == icon)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showingAllIcons = true
                } label: {
                    HStack(spacing: 8) {
                        if !Self.suggestedIcons.contains(icon) {
                            // The chosen icon comes from the full list: show it here so the selection is visible.
                            iconCell(icon, isSelected: true)
                                .frame(width: 40, height: 40)
                        }
                        Text("all_icons".localized)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Building blocks

    private func iconCell(_ symbol: String, isSelected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(isSelected ? .white : theme.textColor.opacity(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint : theme.textColor.opacity(0.06))
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func selectionRing(isSelected: Bool, color: Color) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: 2.5)
            .padding(-5)
            .opacity(isSelected ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.surfaceColor)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.footnote.weight(.medium))
                .foregroundColor(theme.secondaryTextColor)
                .padding(.horizontal, 4)
            content()
                .padding(14)
                .background(card)
        }
    }
}
