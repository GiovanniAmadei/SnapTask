import Foundation

struct BiohackingArticle: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let icon: String
    let sourceURL: URL
    let metrics: [Metric]
    
    struct Metric: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let icon: String
        let color: String
    }
}

@MainActor
class BiohackingViewModel: ObservableObject {
    @Published var articles: [BiohackingArticle] = [
        BiohackingArticle(
            title: "Sleep Optimization",
            content: """
            ## Productivity Impact
            Quality sleep improves decision-making accuracy by 38% and problem-solving speed by 31%. 
            Studies show well-rested individuals complete complex tasks 42% faster.
            
            ## Key Practices
            • Maintain 65°F bedroom temperature for optimal sleep quality
            • Use red light (620-750nm) after sunset to preserve melatonin
            • Implement 90-minute sleep cycles aligned with natural rhythms
            
            ## Quick Wins
            → 20-min power nap before 3PM boosts afternoon focus
            → 10-min morning sunlight regulates circadian rhythm
            """,
            icon: "moon.zzz",
            sourceURL: URL(string: "https://www.nih.gov/sleep-productivity")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Focus Gain", 
                    value: "+42%", 
                    icon: "brain.head.profile", 
                    color: "#6366F1"
                ),
                BiohackingArticle.Metric(
                    label: "Error Reduction", 
                    value: "-38%", 
                    icon: "xmark.circle", 
                    color: "#8B5CF6"
                )
            ]
        ),
        BiohackingArticle(
            title: "Grounding Practices",
            content: """
            Connect with nature to reduce stress and improve focus:
            - Walk barefoot on natural surfaces 20 mins/day
            - Use grounding mats while working
            - Practice earthing during breaks
            - Combine with sunlight exposure
            """,
            icon: "leaf",
            sourceURL: URL(string: "https://example.com/grounding-practices")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Focus Duration", 
                    value: "+18%", 
                    icon: "timer", 
                    color: "#10B981"
                ),
                BiohackingArticle.Metric(
                    label: "Stress Reduction", 
                    value: "-25%", 
                    icon: "heart.fill", 
                    color: "#34D399"
                )
            ]
        ),
        BiohackingArticle(
            title: "Brain-Boosting Nutrition",
            content: """
            Fuel your cognitive performance:
            - Intermittent fasting (16:8 pattern)
            - Omega-3 rich foods (wild salmon, walnuts)
            - Antioxidant berries (blueberries, acai)
            - Matcha green tea instead of coffee
            """,
            icon: "fork.knife",
            sourceURL: URL(string: "https://example.com/brain-boosting-nutrition")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Mental Clarity", 
                    value: "+35%", 
                    icon: "lightbulb", 
                    color: "#F59E0B"
                ),
                BiohackingArticle.Metric(
                    label: "Energy Slumps", 
                    value: "-40%", 
                    icon: "chart.line.downtrend.xyaxis", 
                    color: "#FCD34D"
                )
            ]
        ),
        BiohackingArticle(
            title: "Sunlight Exposure",
            content: """
            Morning light regulates circadian rhythm:
            - Get 10-30 mins morning sunlight
            - Use light therapy lamps in winter
            - Avoid bright lights after dark
            - Balance UV exposure with vitamin D
            """,
            icon: "sun.max",
            sourceURL: URL(string: "https://example.com/sunlight-exposure")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Alertness", 
                    value: "+28%", 
                    icon: "sun.max.fill", 
                    color: "#FCD34D"
                ),
                BiohackingArticle.Metric(
                    label: "Sleep Quality", 
                    value: "+22%", 
                    icon: "moon.zzz", 
                    color: "#8B5CF6"
                )
            ]
        ),
        BiohackingArticle(
            title: "Meditation Techniques",
            content: """
            Enhance mental clarity through mindfulness:
            - 10 mins morning breathwork (4-7-8 pattern)
            - Focused attention meditation
            - Binaural beats for deep work sessions
            - NSDR (Non-Sleep Deep Rest) breaks
            """,
            icon: "brain",
            sourceURL: URL(string: "https://example.com/meditation-techniques")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Focus Gain", 
                    value: "+45%", 
                    icon: "brain.head.profile", 
                    color: "#8B5CF6"
                ),
                BiohackingArticle.Metric(
                    label: "Stress Reduction", 
                    value: "-32%", 
                    icon: "waveform.path.ecg", 
                    color: "#C4B5FD"
                )
            ]
        ),
        BiohackingArticle(
            title: "Movement & Exercise",
            content: """
            Strategic physical activity boosts cognition:
            - Morning bodyweight exercises
            - Post-lunch walks (10-15 mins)
            - Isometric holds during breaks
            - Zone 2 cardio for mitochondrial health
            """,
            icon: "figure.walk",
            sourceURL: URL(string: "https://example.com/movement-exercise")!,
            metrics: [
                BiohackingArticle.Metric(
                    label: "Cognitive Speed", 
                    value: "+29%", 
                    icon: "bolt.heart", 
                    color: "#EF4444"
                ),
                BiohackingArticle.Metric(
                    label: "Creativity", 
                    value: "+33%", 
                    icon: "paintbrush.pointed", 
                    color: "#FCA5A5"
                )
            ]
        )
    ]
} 