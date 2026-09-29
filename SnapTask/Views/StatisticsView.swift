import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: StatisticsTab = .overview
    @State private var showingPremiumPaywall = false
    @Environment(\.theme) private var theme

    enum StatisticsTab: String, CaseIterable {
        case overview, streaks, consistency, performance

        var displayName: String {
            switch self {
            case .overview: return "overview".localized
            case .streaks: return "streaks".localized
            case .consistency: return "consistency".localized
            case .performance: return "performance".localized
            }
        }

        var isPremium: Bool { self != .overview }
    }

    /// Rolling periods shared by every tab.
    private static let periods: [StatisticsViewModel.TimeRange] = [.week, .month, .year, .allTime]

    private func periodLabel(_ range: StatisticsViewModel.TimeRange) -> String {
        switch range {
        case .today: return "today".localized
        case .week: return "stats_period_7d".localized
        case .month: return "stats_period_30d".localized
        case .year: return "stats_period_12m".localized
        case .allTime: return "stats_period_all".localized
        }
    }

    private var hasAdvancedAccess: Bool { subscriptionManager.hasAccess(to: .advancedStatistics) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("statistics".localized)
                    .font(.largeTitle.bold())
                    .themedPrimaryText()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    StatsSegmentedControl(
                        options: StatisticsTab.allCases,
                        selection: $selectedTab,
                        label: { $0.displayName },
                        isLocked: { $0.isPremium && !hasAdvancedAccess },
                        onLockedTap: { _ in showingPremiumPaywall = true }
                    )
                    StatsSegmentedControl(
                        options: Self.periods,
                        selection: $viewModel.selectedTimeRange,
                        label: periodLabel
                    )
                }
                .padding(.horizontal, 16)

                TabView(selection: $selectedTab) {
                    OverviewStatsTab(viewModel: viewModel)
                        .tag(StatisticsTab.overview)

                    if hasAdvancedAccess {
                        StreaksStatsTab(viewModel: viewModel)
                            .tag(StatisticsTab.streaks)
                        ConsistencyStatsTab(viewModel: viewModel)
                            .tag(StatisticsTab.consistency)
                        PerformanceStatsTab(viewModel: viewModel)
                            .tag(StatisticsTab.performance)
                    } else {
                        PremiumRequiredTab().tag(StatisticsTab.streaks)
                        PremiumRequiredTab().tag(StatisticsTab.consistency)
                        PremiumRequiredTab().tag(StatisticsTab.performance)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .themedBackground()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
        }
        .onAppear {
            if !Self.periods.contains(viewModel.selectedTimeRange) {
                viewModel.selectedTimeRange = .week
            }
            viewModel.startObserving()
            viewModel.refreshStats()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshStats()
            }
        }
    }
}

private struct PremiumRequiredTab: View {
    @State private var showingPremiumPaywall = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                }
                
                VStack(spacing: 8) {
                    Text("premium_required".localized)
                        .font(.title2.bold())
                        .themedPrimaryText()
                    
                    Text("premium_feature_locked".localized)
                        .font(.subheadline)
                        .themedSecondaryText()
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                Text("advanced_statistics_desc".localized)
                    .font(.body)
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    showingPremiumPaywall = true
                }) {
                    HStack {
                        Text("upgrade_to_pro".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top, 60)
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
        }
    }
}
