import SwiftUI
import Foundation

// MARK: - Theme Model
struct Theme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let isPremium: Bool
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let surfaceColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    
    init(
        id: String,
        name: String,
        isPremium: Bool = false,
        primaryColor: Color,
        secondaryColor: Color,
        accentColor: Color,
        backgroundColor: Color,
        surfaceColor: Color,
        textColor: Color,
        secondaryTextColor: Color
    ) {
        self.id = id
        self.name = name
        self.isPremium = isPremium
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.surfaceColor = surfaceColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
    }
    
    // Indica se questo tema sovrascrive i colori di sistema (non compatibile con dark mode)
    var overridesSystemColors: Bool {
        // I temi che usano colori custom per background e testo non sono compatibili con dark mode
        return id == "midnight" || id == "volcanic" || id == "rose_gold" || id == "ocean" || id == "emerald" || id == "lavender"
    }
    
    // Helper properties for easier access
    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryColor, secondaryColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var cardBackground: Color {
        // Usa surfaceColor con un'opacità leggermente ridotta per un effetto più morbido
        // simile alla schermata Premi
        surfaceColor.opacity(0.9)
    }
    
    var borderColor: Color {
        primaryColor.opacity(0.2)
    }
    
    var shadowColor: Color {
        // Migliora la visibilità delle ombre per temi scuri
        if isDarkBackground {
            return Color.black.opacity(0.3)
        } else {
            return textColor.opacity(0.1)
        }
    }
    
    // IMPORTANT: Smart text colors for buttons and contrasting elements
    var buttonTextColor: Color {
        // Return white for dark buttons, black for light buttons
        return isDarkPrimary ? .white : .black
    }
    
    var onSurfaceTextColor: Color {
        // Text color to use on surface color background
        return isDarkSurface ? .white : .black
    }
    
    // Helper computed properties to determine if colors are dark
    private var isDarkPrimary: Bool {
        let uiColor = UIColor(primaryColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }
    
    private var isDarkSurface: Bool {
        let uiColor = UIColor(surfaceColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }
    
    // Public property to determine if the theme has a dark background
    var isDarkTheme: Bool {
        return isDarkBackground
    }
    
    private var isDarkBackground: Bool {
        let uiColor = UIColor(backgroundColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }
    
    var warningColor: Color {
        .orange
    }
    
    var errorColor: Color {
        .red
    }
    
    var successColor: Color {
        .green
    }
    
    var infoColor: Color {
        .blue
    }
}

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme {
        didSet {
            saveCurrentTheme()
            // Apply theme to the app
            applyTheme()
        }
    }
    
    private let subscriptionManager = SubscriptionManager.shared
    
    private init() {
        // Load saved theme or default
        self.currentTheme = ThemeManager.loadSavedTheme() ?? ThemeManager.defaultTheme
        applyTheme()
    }
    
    // MARK: - Available Themes
    static let allThemes: [Theme] = [
        // Free themes
        Theme(
            id: "default",
            name: "theme_default".localized,
            isPremium: false,
            primaryColor: Color.blue,
            secondaryColor: Color.cyan,
            accentColor: Color.blue,
            backgroundColor: Color(UIColor.systemBackground),
            surfaceColor: Color(UIColor.secondarySystemBackground),
            textColor: Color.primary,
            secondaryTextColor: Color.secondary
        ),
        
        Theme(
            id: "forest",
            name: "theme_forest".localized,
            isPremium: false,
            primaryColor: Color.green,
            secondaryColor: Color.mint,
            accentColor: Color.green,
            backgroundColor: Color(UIColor.systemBackground),
            surfaceColor: Color(UIColor.secondarySystemBackground),
            textColor: Color.primary,
            secondaryTextColor: Color.secondary
        ),
        
        Theme(
            id: "sunset",
            name: "theme_sunset".localized,
            isPremium: false,
            primaryColor: Color.orange,
            secondaryColor: Color.pink,
            accentColor: Color.orange,
            backgroundColor: Color(UIColor.systemBackground),
            surfaceColor: Color(UIColor.secondarySystemBackground),
            textColor: Color.primary,
            secondaryTextColor: Color.secondary
        ),
        
        // Premium themes with improved contrast
        Theme(
            id: "midnight",
            name: "theme_midnight".localized,
            isPremium: true,
            primaryColor: Color(red: 0.5, green: 0.2, blue: 0.8),  // Viola più acceso
            secondaryColor: Color(red: 0.3, green: 0.2, blue: 0.5),  // Viola scuro
            accentColor: Color(red: 0.8, green: 0.4, blue: 1.0),     // Viola chiaro
            backgroundColor: Color(red: 0.05, green: 0.05, blue: 0.1), // Nero con sfumatura bluastra
            surfaceColor: Color(red: 0.15, green: 0.15, blue: 0.2),  // Grigio scuro con sfumatura bluastra
            textColor: Color.white,                                   // Testo bianco
            secondaryTextColor: Color(red: 0.9, green: 0.9, blue: 0.95)  // Grigio molto chiaro per migliore leggibilità
        ),
        
        Theme(
            id: "amethyst",
            name: "theme_amethyst".localized,
            isPremium: true,
            primaryColor: Color(red: 0.5, green: 0.2, blue: 0.8),  // Viola più acceso
            secondaryColor: Color(red: 0.3, green: 0.2, blue: 0.5),  // Viola scuro
            accentColor: Color(red: 0.8, green: 0.4, blue: 1.0),     // Viola chiaro
            backgroundColor: Color(red: 0.05, green: 0.05, blue: 0.1), // Nero con sfumatura bluastra
            surfaceColor: Color(red: 0.15, green: 0.15, blue: 0.2),  // Grigio scuro con sfumatura bluastra
            textColor: Color.white,                                   // Testo bianco
            secondaryTextColor: Color(red: 0.9, green: 0.9, blue: 0.95)  // Grigio molto chiaro per migliore leggibilità
        ),
        
        Theme(
            id: "rose_gold",
            name: "theme_rose_gold".localized,
            isPremium: true,
            primaryColor: Color.pink,
            secondaryColor: Color(red: 0.9, green: 0.7, blue: 0.5),
            accentColor: Color.pink,
            backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.92),
            surfaceColor: Color(red: 0.95, green: 0.92, blue: 0.88),
            textColor: Color.black,
            secondaryTextColor: Color(red: 0.4, green: 0.4, blue: 0.4)
        ),
        
        Theme(
            id: "ocean",
            name: "theme_ocean".localized,
            isPremium: true,
            primaryColor: Color.blue,
            secondaryColor: Color.teal,
            accentColor: Color.blue,
            backgroundColor: Color(red: 0.9, green: 0.95, blue: 0.98),
            surfaceColor: Color(red: 0.85, green: 0.92, blue: 0.96),
            textColor: Color.black,
            secondaryTextColor: Color(red: 0.2, green: 0.4, blue: 0.6)
        ),
        
        Theme(
            id: "emerald",
            name: "theme_emerald".localized,
            isPremium: true,
            primaryColor: Color.green,
            secondaryColor: Color(red: 0.2, green: 0.8, blue: 0.6),
            accentColor: Color.green,
            backgroundColor: Color(red: 0.92, green: 0.98, blue: 0.95),
            surfaceColor: Color(red: 0.88, green: 0.95, blue: 0.92),
            textColor: Color.black,
            secondaryTextColor: Color(red: 0.1, green: 0.5, blue: 0.3)
        ),
        
        Theme(
            id: "volcanic",
            name: "theme_volcanic".localized,
            isPremium: true,
            primaryColor: Color.red,
            secondaryColor: Color.orange,
            accentColor: Color.red,
            backgroundColor: Color(red: 0.15, green: 0.1, blue: 0.1),
            surfaceColor: Color(red: 0.2, green: 0.15, blue: 0.15),
            textColor: Color.white,
            secondaryTextColor: Color(red: 0.9, green: 0.7, blue: 0.7) 
        ),
        
        Theme(
            id: "lavender",
            name: "theme_lavender".localized,
            isPremium: true,
            primaryColor: Color.purple,
            secondaryColor: Color(red: 0.8, green: 0.7, blue: 0.9),
            accentColor: Color.purple,
            backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
            surfaceColor: Color(red: 0.92, green: 0.88, blue: 0.96),
            textColor: Color.black,
            secondaryTextColor: Color(red: 0.4, green: 0.3, blue: 0.6)
        )
    ]
    
    static let defaultTheme = allThemes.first { $0.id == "default" }!
    
    // MARK: - Public Methods
    func setTheme(_ theme: Theme) {
        // Check if theme is premium and user has access
        if theme.isPremium && !subscriptionManager.hasAccess(to: .customThemes) {
            print("⚠️ Attempted to set premium theme without subscription: \(theme.name)")
            return
        }
        
        currentTheme = theme
        print("🎨 Theme changed to: \(theme.name)")
    }
    
    func canUseTheme(_ theme: Theme) -> Bool {
        if theme.isPremium {
            return subscriptionManager.hasAccess(to: .customThemes)
        }
        return true
    }
    
    var availableThemes: [Theme] {
        return Self.allThemes
    }
    
    var freeThemes: [Theme] {
        return Self.allThemes.filter { !$0.isPremium }
    }
    
    var premiumThemes: [Theme] {
        return Self.allThemes.filter { $0.isPremium }
    }
    
    // Public property to determine if the current theme has a dark background
    var isDarkTheme: Bool {
        // Solo i temi premium sovrascrivono la dark mode
        if currentTheme.overridesSystemColors {
            return currentTheme.isDarkTheme
        } else {
            // Per i temi base, usa la dark mode di sistema
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
    }
    
    // MARK: - Private Methods
    private func applyTheme() {
        // Update global tint color
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.tintColor = UIColor(currentTheme.accentColor)
        }
        
        // Configure status bar style based on theme
        // Solo i temi premium sovrascrivono la status bar
        if currentTheme.overridesSystemColors {
            if currentTheme.isDarkTheme {
                UIApplication.shared.statusBarStyle = .lightContent
            } else {
                UIApplication.shared.statusBarStyle = .darkContent
            }
        } else {
            // Per i temi base, usa lo stile di sistema
            UIApplication.shared.statusBarStyle = .default
        }
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(currentTheme.backgroundColor)
        
        // Configure normal (unselected) tab items
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(currentTheme.secondaryTextColor)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(currentTheme.secondaryTextColor)
        ]
        
        // Configure selected tab items
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(currentTheme.primaryColor)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(currentTheme.primaryColor)
        ]
        
        // Apply the appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(currentTheme.backgroundColor)
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(currentTheme.textColor)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(currentTheme.textColor)
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .themeChanged, object: currentTheme)
    }

    private func saveCurrentTheme() {
        if let encoded = try? JSONEncoder().encode(currentTheme) {
            UserDefaults.standard.set(encoded, forKey: "currentTheme")
        }
    }
    
    private static func loadSavedTheme() -> Theme? {
        guard let data = UserDefaults.standard.data(forKey: "currentTheme"),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            return nil
        }
        
        // Make sure the theme still exists in our available themes
        return allThemes.first { $0.id == theme.id }
    }
}

// MARK: - Theme Environment
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = ThemeManager.defaultTheme
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Extensions
extension Color: Codable {
    private struct Components {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }
    
    private var components: Components {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return Components(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let components = Components(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decode(Double.self, forKey: .alpha)
        )
        
        self.init(red: components.red, green: components.green, blue: components.blue, opacity: components.alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let components = self.components
        
        try container.encode(components.red, forKey: .red)
        try container.encode(components.green, forKey: .green)
        try container.encode(components.blue, forKey: .blue)
        try container.encode(components.alpha, forKey: .alpha)
    }
    
    private enum CodingKeys: CodingKey {
        case red, green, blue, alpha
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}