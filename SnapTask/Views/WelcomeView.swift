import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var currentStep = 0
    @State private var showingContent = false
    @State private var showingPaywall = false
    
    private let onboardingSteps = [
        OnboardingStep(
            icon: "checkmark.circle.fill",
            title: "onboarding_title_1".localized,
            subtitle: "onboarding_subtitle_1".localized,
            description: "onboarding_description_1".localized,
            color: .blue
        ),
        OnboardingStep(
            icon: "timer",
            title: "onboarding_title_2".localized,
            subtitle: "onboarding_subtitle_2".localized,
            description: "onboarding_description_2".localized,
            color: .red
        ),
        OnboardingStep(
            icon: "gift.fill",
            title: "onboarding_title_3".localized,
            subtitle: "onboarding_subtitle_3".localized,
            description: "onboarding_description_3".localized,
            color: .purple
        ),
        OnboardingStep(
            icon: "chart.line.uptrend.xyaxis",
            title: "onboarding_title_4".localized,
            subtitle: "onboarding_subtitle_4".localized,
            description: "onboarding_description_4".localized,
            color: .green
        ),
        // Support & Feedback just before Cloud
        OnboardingStep(
            icon: "bubble.left.and.bubble.right.fill",
            title: "onboarding_title_6".localized,
            subtitle: "onboarding_subtitle_6".localized,
            description: "onboarding_description_6".localized,
            color: .teal
        ),
        OnboardingStep(
            icon: "icloud.fill",
            title: "onboarding_title_5".localized,
            subtitle: "onboarding_subtitle_5".localized,
            description: "onboarding_description_5".localized,
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.backgroundColor.opacity(0.05),
                    onboardingSteps[currentStep].color.opacity(0.1),
                    theme.backgroundColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: currentStep)
            
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? onboardingSteps[currentStep].color : theme.borderColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.3 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                if showingContent {
                    VStack(spacing: 40) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            onboardingSteps[currentStep].color.opacity(0.15),
                                            onboardingSteps[currentStep].color.opacity(0.05)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .scaleEffect(showingContent ? 1.0 : 0.8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showingContent)
                            
                            Image(systemName: onboardingSteps[currentStep].icon)
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(onboardingSteps[currentStep].color)
                                .scaleEffect(showingContent ? 1.0 : 0.5)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showingContent)
                        }
                        .transition(.opacity.combined(with: .scale))
                        
                        VStack(spacing: 20) {
                            Text(onboardingSteps[currentStep].title)
                                .font(.title.bold())
                                .themedPrimaryText()
                                .multilineTextAlignment(.center)
                            
                            Text(onboardingSteps[currentStep].subtitle)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(onboardingSteps[currentStep].color)
                                .multilineTextAlignment(.center)
                            
                            Text(onboardingSteps[currentStep].description)
                                .font(.body)
                                .themedSecondaryText()
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    .id(currentStep)
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    if currentStep < onboardingSteps.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentStep += 1
                            }
                        } label: {
                            HStack {
                                Text("onboarding_continue".localized)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        onboardingSteps[currentStep].color,
                                        onboardingSteps[currentStep].color.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: onboardingSteps[currentStep].color.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .scaleEffect(showingContent ? 1.0 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: showingContent)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                
                                Text("onboarding_unlock_potential".localized)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .scaleEffect(showingContent ? 1.0 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: showingContent)
                    }
                    
                    HStack {
                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline.weight(.medium))
                                    Text(NSLocalizedString("back", comment: "Back button"))
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(theme.secondaryTextColor)
                            }
                        }
                        
                        Spacer()
                        
                        if currentStep < onboardingSteps.count - 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    currentStep = onboardingSteps.count - 1
                                }
                            } label: {
                                Text("onboarding_skip".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .opacity(showingContent ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.4).delay(0.6), value: showingContent)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showingContent = true
            }
        }
        .onChange(of: currentStep) { oldValue, newValue in
            if newValue == onboardingSteps.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showingPaywall = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
                .onDisappear {
                    completeOnboarding()
                }
        }
        .task {
            await subscriptionManager.loadProducts()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
        dismiss()
    }
}

struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

#Preview {
    WelcomeView()
}