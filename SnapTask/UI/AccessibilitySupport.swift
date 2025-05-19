import SwiftUI

// MARK: - Accessibility Extensions for View
extension View {
    
    /// Adds proper accessibility label and hint for a task
    func taskAccessibility(task: TodoTask, completion: Bool? = nil) -> some View {
        let isCompleted = completion ?? (task.completions[Date().startOfDay]?.isCompleted ?? false)
        let completionStatus = isCompleted ? "completato" : "non completato"
        let categoryText = task.category?.name ?? "nessuna categoria"
        
        let taskDescription = task.description?.isEmpty == false ? 
            "Descrizione: \(task.description!)" : ""
        
        let dueText = task.hasDuration ? 
            "Durata: \(task.duration.formatted())" : ""
        
        let priorityText = "Priorità: \(task.priority.rawValue.capitalized)"
        
        return self
            .accessibilityLabel(Text(task.name))
            .accessibilityValue(Text("\(completionStatus), \(categoryText)"))
            .accessibilityHint(Text([taskDescription, dueText, priorityText]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")))
    }
    
    /// Adds proper accessibility label and hint for a button
    func buttonAccessibility(label: String, hint: String? = nil) -> some View {
        var view = self.accessibilityLabel(Text(label))
        if let hint = hint {
            view = view.accessibilityHint(Text(hint))
        }
        return view.eraseToAnyView()
    }
    
    // Extension to make a view accessible only in VoiceOver
    func accessibleOnly(as label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        return self
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint != nil ? Text(hint!) : Text(""))
            .accessibilityAddTraits(traits)
    }
    
    // Extension to group views for accessibility
    func accessibilityGroup(label: String, hint: String? = nil) -> some View {
        let view = self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
        
        if let hint = hint {
            return view.accessibilityHint(Text(hint)).eraseToAnyView()
        }
        
        return view.eraseToAnyView()
    }
    
    // Extension to hide a view from accessibility
    func accessibilityHidden(_ isHidden: Bool = true) -> some View {
        return self.accessibility(hidden: isHidden)
    }
    
    // Extension for dynamic type support
    func dynamicTypeSizeCompatible(maxSize: DynamicTypeSize = .accessibility5) -> some View {
        return self.dynamicTypeSize(...maxSize)
    }
    
    // Helper to erase type
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}

// MARK: - Accessibility Helpers
struct AccessibilityHelper {
    
    /// Returns the appropriate text size for the current accessibility settings
    static func textSize(for size: TextSize, isAccessibilityCategory: Bool) -> CGFloat {
        switch size {
        case .small:
            return isAccessibilityCategory ? 14 : 12
        case .medium:
            return isAccessibilityCategory ? 18 : 16
        case .large:
            return isAccessibilityCategory ? 24 : 20
        case .extraLarge:
            return isAccessibilityCategory ? 32 : 24
        }
    }
    
    /// Returns appropriate amount of padding for the current accessibility settings
    static func padding(for size: PaddingSize, isAccessibilityCategory: Bool) -> CGFloat {
        switch size {
        case .small:
            return isAccessibilityCategory ? 10 : 8
        case .medium:
            return isAccessibilityCategory ? 16 : 12
        case .large:
            return isAccessibilityCategory ? 24 : 16
        }
    }
    
    /// Returns whether the reduced motion setting is enabled
    static var isReducedMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    /// Returns whether the transparency reduction setting is enabled
    static var isReducedTransparencyEnabled: Bool {
        return UIAccessibility.isReduceTransparencyEnabled
    }
    
    /// Returns whether the VoiceOver feature is turned on
    static var isVoiceOverRunning: Bool {
        return UIAccessibility.isVoiceOverRunning
    }
    
    /// Announce a message using VoiceOver
    static func announceMessage(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Enum for text size
enum TextSize {
    case small
    case medium
    case large
    case extraLarge
}

// MARK: - Enum for padding size
enum PaddingSize {
    case small
    case medium
    case large
}

// MARK: - Modifier for improved button accessibility
struct AccessibleButtonStyle: ButtonStyle {
    var label: String
    var hint: String?
    var accentColor: Color = .accentColor
    
    func makeBody(configuration: Configuration) -> some View {
        makeConfiguredBody(configuration: configuration)
    }

    @ViewBuilder
    private func makeConfiguredBody(configuration: Configuration) -> some View {
        let baseView = configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)

        if let hintString = hint, !hintString.isEmpty {
            baseView.accessibilityHint(Text(hintString))
        } else {
            baseView
        }
    }
}

extension ButtonStyle where Self == AccessibleButtonStyle {
    static func accessible(label: String, hint: String? = nil, accentColor: Color = .accentColor) -> AccessibleButtonStyle {
        AccessibleButtonStyle(label: label, hint: hint, accentColor: accentColor)
    }
}

// MARK: - Preview Helpers for testing accessibility
struct AccessibilityPreview<Content: View>: View {
    let content: Content
    
    @State private var showVoiceOverIndicators: Bool = false
    
    var body: some View {
        VStack {
            Toggle("Show VoiceOver Indicators", isOn: $showVoiceOverIndicators)
                .padding()
            
            content
                .environment(\.accessibilityEnabled, showVoiceOverIndicators)
                .border(showVoiceOverIndicators ? Color.blue.opacity(0.5) : Color.clear, width: 1)
        }
    }
} 