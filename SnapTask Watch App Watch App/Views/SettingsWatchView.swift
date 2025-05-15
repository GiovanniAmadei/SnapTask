import SwiftUI

struct SettingsWatchView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var quoteManager = QuoteManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingLanguagePicker = false
    @State private var showingCategoriesView = false
    @State private var showingPrioritiesView = false
    @State private var showingPomodoroSettings = false
    @State private var selectedLanguage = "en"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quote of the day
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quote of the Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if quoteManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        Text(quoteManager.currentQuote.text)
                            .font(.caption)
                            .italic()
                        
                        Text("- \(quoteManager.currentQuote.author)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        Task {
                            await quoteManager.forceUpdateQuote()
                        }
                    }) {
                        Label("New Quote", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
                
                // Categories
                Button(action: { showingCategoriesView = true }) {
                    HStack {
                        Label("Categories", systemImage: "folder.fill")
                        Spacer()
                        Text("\(viewModel.categories.count)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Priorities
                Button(action: { showingPrioritiesView = true }) {
                    HStack {
                        Label("Priorities", systemImage: "flag.fill")
                        Spacer()
                        Text("\(viewModel.priorities.count)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Pomodoro Settings
                Button(action: { showingPomodoroSettings = true }) {
                    HStack {
                        Label("Pomodoro Settings", systemImage: "timer")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Appearance
                VStack(spacing: 8) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    
                    Divider()
                        .padding(.horizontal, 12)
                    
                    Button(action: { showingLanguagePicker = true }) {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Text(selectedLanguage == "en" ? "English" : "Italiano")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                
                // App Info
                VStack(alignment: .center, spacing: 4) {
                    Text("SnapTask")
                        .font(.caption)
                        .bold()
                    
                    Text("Version 1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadCategories()
            viewModel.loadPriorities()
            
            Task {
                await quoteManager.checkAndUpdateQuote()
            }
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePicker(selectedLanguage: $selectedLanguage)
        }
        .sheet(isPresented: $showingCategoriesView) {
            WatchCategoriesView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPrioritiesView) {
            WatchPrioritiesView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPomodoroSettings) {
            WatchPomodoroSettingsView(viewModel: viewModel)
        }
    }
}

struct WatchCategoriesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingNewCategorySheet = false
    @State private var categoryName = ""
    @State private var categoryColor = "FF5733"
    @State private var showingColorPicker = false
    
    // Predefined colors for watchOS
    private let predefinedColors = [
        "FF5733", // Red-orange
        "3498DB", // Blue
        "2ECC71", // Green
        "F1C40F", // Yellow
        "9B59B6", // Purple
        "1ABC9C", // Teal
        "E74C3C", // Red
        "34495E", // Dark blue
        "D35400", // Orange
        "8E44AD"  // Violet
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Categories")
                    .font(.headline)
                    .padding(.top, 8)
                
                if viewModel.categories.isEmpty {
                    Text("No categories yet")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.categories) { category in
                        HStack {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 16, height: 16)
                            
                            Text(category.name)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Add new category form
                VStack(spacing: 10) {
                    Text("New Category")
                        .font(.subheadline)
                    
                    TextField("Category name", text: $categoryName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Color selection button instead of ColorPicker
                    Button(action: {
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Color")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color(hex: categoryColor))
                                .frame(width: 20, height: 20)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if !categoryName.isEmpty {
                            let newCategory = Category(id: UUID(), name: categoryName, color: categoryColor)
                            viewModel.addCategory(newCategory)
                            categoryName = ""
                            categoryColor = "FF5733"
                        }
                    }) {
                        Label("Add Category", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(categoryName.isEmpty)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .padding()
        }
        .sheet(isPresented: $showingColorPicker) {
            WatchColorPicker(selectedColor: $categoryColor)
        }
    }
}

// Add a new color picker view for watchOS
struct WatchColorPicker: View {
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    // Predefined colors for watchOS
    private let predefinedColors = [
        "FF5733", // Red-orange
        "3498DB", // Blue
        "2ECC71", // Green
        "F1C40F", // Yellow
        "9B59B6", // Purple
        "1ABC9C", // Teal
        "E74C3C", // Red
        "34495E", // Dark blue
        "D35400", // Orange
        "8E44AD"  // Violet
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Color")
                .font(.headline)
                .padding(.top, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        dismiss()
                    }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                ZStack {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
    }
}

struct WatchPrioritiesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Priorities")
                    .font(.headline)
                    .padding(.top, 8)
                
                ForEach(viewModel.priorities, id: \.self) { priority in
                    HStack {
                        Image(systemName: priority.icon)
                            .foregroundColor(Color(hex: priority.color))
                        
                        Text(priority.rawValue.capitalized)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                Text("Priorities are predefined and cannot be modified on Apple Watch. Use the iPhone app for advanced customization.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}

struct WatchPomodoroSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var workDuration: Double = 25
    @State private var breakDuration: Double = 5
    @State private var longBreakDuration: Double = 15
    @State private var sessionsUntilLongBreak: Double = 4
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Pomodoro Settings")
                    .font(.headline)
                    .padding(.top, 8)
                
                VStack(spacing: 8) {
                    Text("Work Duration: \(Int(workDuration)) min")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Slider(value: $workDuration, in: 5...60, step: 5)
                }
                
                VStack(spacing: 8) {
                    Text("Break Duration: \(Int(breakDuration)) min")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Slider(value: $breakDuration, in: 1...30, step: 1)
                }
                
                VStack(spacing: 8) {
                    Text("Long Break: \(Int(longBreakDuration)) min")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Slider(value: $longBreakDuration, in: 5...45, step: 5)
                }
                
                VStack(spacing: 8) {
                    Text("Sessions until Long Break: \(Int(sessionsUntilLongBreak))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Slider(value: $sessionsUntilLongBreak, in: 2...6, step: 1)
                }
                
                Button("Save") {
                    viewModel.updatePomodoroSettings(
                        workDuration: Int(workDuration),
                        breakDuration: Int(breakDuration),
                        longBreakDuration: Int(longBreakDuration),
                        sessionsUntilLongBreak: Int(sessionsUntilLongBreak)
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .onAppear {
            // Convert from seconds to minutes for UI
            workDuration = viewModel.pomodoroSettings.workDuration / 60.0
            breakDuration = viewModel.pomodoroSettings.breakDuration / 60.0
            longBreakDuration = viewModel.pomodoroSettings.longBreakDuration / 60.0
            sessionsUntilLongBreak = Double(viewModel.pomodoroSettings.sessionsUntilLongBreak)
        }
    }
}

struct LanguagePicker: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    let languages = [
        ("en", "English"),
        ("it", "Italiano")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Language")
                .font(.headline)
                .padding(.top, 8)
            
            ForEach(languages, id: \.0) { code, name in
                Button(action: {
                    selectedLanguage = code
                    dismiss()
                }) {
                    HStack {
                        Text(name)
                        
                        Spacer()
                        
                        if selectedLanguage == code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
    }
}

// Extension per ottenere il codice esadecimale da un Color
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
} 