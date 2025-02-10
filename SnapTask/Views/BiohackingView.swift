import SwiftUI

struct BiohackingView: View {
    @StateObject private var viewModel = BiohackingViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List(viewModel.articles) { article in
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    HStack(spacing: 12) {
                        // Icon with gradient background
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [
                                        Color(hex: articleColor(for: article.title)).opacity(colorScheme == .dark ? 0.6 : 0.2),
                                        Color(hex: articleColor(for: article.title)).opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: article.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .primary : Color(hex: articleColor(for: article.title)))
                        }
                        
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Progress indicator
                        Circle()
                            .stroke(lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Biohacking")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func articleColor(for title: String) -> String {
        switch title {
        case "Sleep Optimization": return "#6366F1"
        case "Grounding Practices": return "#10B981"
        case "Brain-Boosting Nutrition": return "#F59E0B"
        case "Sunlight Exposure": return "#FCD34D"
        case "Meditation Techniques": return "#8B5CF6"
        case "Movement & Exercise": return "#EF4444"
        default: return "#6B7280"
        }
    }
}

struct ArticleDetailView: View {
    let article: BiohackingArticle
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                productivityImpactSection
                keyPracticesSection
                quickWinsSection
                referenceSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(article.title)
                .font(.system(.title, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(article.metrics) { metric in
                    MetricBadge(metric: metric)
                }
            }
        }
        .padding(.bottom, 24)
    }
    
    private var productivityImpactSection: some View {
        contentSection(
            title: "Productivity Impact",
            content: article.content.components(separatedBy: "## Productivity Impact").last?.components(separatedBy: "## ").first ?? ""
        )
    }
    
    private var keyPracticesSection: some View {
        contentSection(
            title: "Key Practices",
            content: article.content.components(separatedBy: "## Key Practices").last?.components(separatedBy: "## ").first ?? ""
        )
    }
    
    private var quickWinsSection: some View {
        contentSection(
            title: "Quick Wins",
            content: article.content.components(separatedBy: "## Quick Wins").last?.components(separatedBy: "## ").first ?? ""
        )
    }
    
    private func contentSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(6)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            ReferenceLink(sourceURL: article.sourceURL)
        }
    }
}

// MARK: - Subviews
private struct MetricBadge: View {
    let metric: BiohackingArticle.Metric
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: metric.color))
            
            VStack(alignment: .leading) {
                Text(metric.value)
                    .font(.system(.subheadline, weight: .bold))
                Text(metric.label)
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - View Extensions
private extension Image {
    func iconStyle() -> some View {
        self
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(.accentColor)
            .frame(width: 44, height: 44)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
    }
    
    func metricIconStyle(color: Color) -> some View {
        self
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(color)
            .frame(width: 36, height: 36)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
    }
}

private extension Text {
    func valueStyle() -> some View {
        self
            .font(.body.weight(.semibold))
    }
    
    func labelStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    func sectionHeaderStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.bottom, 4)
    }
    
    func sectionContentStyle() -> some View {
        self
            .font(.body)
            .foregroundColor(.secondary)
            .lineSpacing(6)
    }
}

private extension View {
    func metricContainerStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
    
    func sectionContainerStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

// MARK: - Helper Extension
private extension BiohackingArticle {
    var contentComponents: [String] {
        content.components(separatedBy: "## ").filter { !$0.isEmpty }
    }
}

private struct MetricCard: View {
    let metric: BiohackingArticle.Metric
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: metric.icon)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            
            VStack(spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .layoutPriority(1)
                
                Text(metric.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(width: 150, height: 150)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }
}

private struct ReferenceLink: View {
    let sourceURL: URL
    
    var body: some View {
        HStack {
            Image(systemName: "book.closed.fill")
                .foregroundColor(.accentColor)
            
            Link("Scientific Reference", destination: sourceURL)
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
} 
