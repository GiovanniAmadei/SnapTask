import SwiftUI

struct PomodoroColorsView: View {
    @AppStorage("pomodoroFocusColor") private var focusColor = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColor = "#059669"
    
    private let colorOptions = [
        ("Blue", "#4F46E5"),
        ("Purple", "#7C3AED"),
        ("Pink", "#EC4899"),
        ("Red", "#EF4444"),
        ("Orange", "#F97316"),
        ("Yellow", "#EAB308"),
        ("Green", "#059669"),
        ("Teal", "#0D9488"),
        ("Cyan", "#0891B2"),
        ("Indigo", "#4338CA")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Preview Section
            VStack(spacing: 16) {
                Text("Preview")
                    .font(.headline)
                
                // Mini Pomodoro Preview
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color(hex: focusColor).opacity(0.2), lineWidth: 6)
                        .frame(width: 120, height: 120)
                    
                    // Progress ring (showing 60% progress)
                    Circle()
                        .trim(from: 0.0, to: 0.6)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: focusColor), Color(hex: focusColor).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle(degrees: -90))
                    
                    // Center content
                    VStack(spacing: 4) {
                        Text("15:00")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: focusColor), Color(hex: focusColor).opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Focus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar preview
                HStack(spacing: 2) {
                    // Focus segment
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: focusColor), Color(hex: focusColor).opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    
                    // Break segment
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: breakColor), Color(hex: breakColor).opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 40, height: 6)
                        .opacity(0.5)
                }
                .padding(.horizontal, 20)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            
            // Color Selection
            List {
                Section("Focus Time") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colorOptions, id: \.1) { name, hex in
                            ColorDot(
                                hex: hex,
                                isSelected: focusColor == hex
                            ) {
                                focusColor = hex
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Break Time") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colorOptions, id: \.1) { name, hex in
                            ColorDot(
                                hex: hex,
                                isSelected: breakColor == hex
                            ) {
                                breakColor = hex
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Colors")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorDot: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: hex), lineWidth: isSelected ? 2 : 0)
                        .scaleEffect(1.3)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        PomodoroColorsView()
    }
}
