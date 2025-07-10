import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var currentStep = 0
    @State private var showingContent = false
    
    private let steps = [
        WelcomeStep(
            icon: "heart.fill",
            title: "welcome_title_1".localized,
            subtitle: "welcome_subtitle_1".localized,
            description: "welcome_description_1".localized,
            color: .pink
        ),
        WelcomeStep(
            icon: "sparkles",
            title: "welcome_title_2".localized,
            subtitle: "welcome_subtitle_2".localized,
            description: "welcome_description_2".localized,
            color: .blue
        ),
        WelcomeStep(
            icon: "bubble.left.and.bubble.right",
            title: "welcome_title_3".localized,
            subtitle: "welcome_subtitle_3".localized,
            description: "welcome_description_3".localized,
            color: .orange
        ),
        WelcomeStep(
            icon: "gift.fill",
            title: "welcome_title_4".localized,
            subtitle: "welcome_subtitle_4".localized,
            description: "welcome_description_4".localized,
            color: .purple
        ),
        WelcomeStep(
            icon: "rocket.fill",
            title: "welcome_title_5".localized,
            subtitle: "welcome_subtitle_5".localized,
            description: "welcome_description_5".localized,
            color: .green
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    theme.backgroundColor.opacity(0.1),
                    theme.primaryColor.opacity(0.1),
                    theme.secondaryColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? steps[currentStep].color : theme.borderColor)
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Main content
                if showingContent {
                    VStack(spacing: 32) {
                        // Icon
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(steps[currentStep].color)
                            .transition(.opacity)
                        
                        // Text content
                        VStack(spacing: 16) {
                            Text(steps[currentStep].title)
                                .font(.title.bold())
                                .themedPrimaryText()
                                .multilineTextAlignment(.center)
                            
                            Text(steps[currentStep].subtitle)
                                .font(.title3.weight(.medium))
                                .foregroundColor(steps[currentStep].color)
                                .multilineTextAlignment(.center)
                            
                            Text(steps[currentStep].description)
                                .font(.body)
                                .themedSecondaryText()
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }
                    .id(currentStep)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if currentStep < steps.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } label: {
                            HStack {
                                Text("continue".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [steps[currentStep].color, steps[currentStep].color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                    } else {
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
                            dismiss()
                        } label: {
                            HStack {
                                Text("start_using_app".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                    }
                    
                    Group {
                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            } label: {
                                Text("back".localized)
                                    .font(.body.weight(.medium))
                                    .themedSecondaryText()
                            }
                        } else {
                            // Spazio vuoto per mantenere l'altezza costante
                            Text("")
                                .font(.body.weight(.medium))
                                .opacity(0)
                        }
                    }
                    
                    // Skip button
                    if currentStep < steps.count - 1 {
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
                            dismiss()
                        } label: {
                            Text("skip_intro".localized)
                                .font(.footnote)
                                .themedSecondaryText()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                showingContent = true
            }
        }
    }
}

struct WelcomeStep {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

#Preview {
    WelcomeView()
}