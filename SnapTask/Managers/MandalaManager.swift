import Foundation
import Combine
import SwiftUI

@MainActor
final class MandalaManager: ObservableObject {
    static let shared = MandalaManager()
    
    @Published var charts: [MandalaChart] = []
    @Published var activeChartId: UUID? = nil
    
    private let chartsKey = "savedMandalaCharts"
    private let activeChartIdKey = "activeMandalaChartId"
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {
        loadCharts()
        setupTaskObservers()
    }
    
    var activeChart: MandalaChart? {
        if let activeChartId = activeChartId, let found = charts.first(where: { $0.id == activeChartId }) {
            return found
        }
        return charts.first
    }
    
    // MARK: - Persistence
    
    private func loadCharts() {
        if let data = UserDefaults.standard.data(forKey: chartsKey) {
            do {
                let decoder = JSONDecoder()
                charts = try decoder.decode([MandalaChart].self, from: data)
            } catch {
                print("❌ Failed to decode Mandala charts: \(error)")
                charts = []
            }
        }
        
        if let savedIdString = UserDefaults.standard.string(forKey: activeChartIdKey),
           let savedUUID = UUID(uuidString: savedIdString) {
            activeChartId = savedUUID
        } else {
            activeChartId = charts.first?.id
        }
        
        // If first launch and no charts exist, create an initial sample
        if charts.isEmpty {
            createInitialSampleChart()
        }
    }
    
    private func saveCharts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(charts)
            UserDefaults.standard.set(data, forKey: chartsKey)
            if let activeId = activeChartId {
                UserDefaults.standard.set(activeId.uuidString, forKey: activeChartIdKey)
            }
            objectWillChange.send()
        } catch {
            print("❌ Failed to encode Mandala charts: \(error)")
        }
    }
    
    // MARK: - Task Sync
    
    private func setupTaskObservers() {
        // Observe TaskManager updates to keep Mandala completion in sync
        TaskManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncStatusWithTaskManager()
            }
            .store(in: &cancellables)
    }
    
    func syncStatusWithTaskManager() {
        let tasks = TaskManager.shared.tasks
        var didChange = false
        
        for chartIndex in charts.indices {
            for pillarIndex in charts[chartIndex].pillars.indices {
                for actionIndex in charts[chartIndex].pillars[pillarIndex].actions.indices {
                    let action = charts[chartIndex].pillars[pillarIndex].actions[actionIndex]
                    if let taskId = action.linkedTaskId,
                       let task = tasks.first(where: { $0.id == taskId }) {
                        let isCompletedToday = task.completions[task.completionKey(for: Date())]?.isCompleted ?? false
                        if action.isCompleted != isCompletedToday {
                            charts[chartIndex].pillars[pillarIndex].actions[actionIndex].isCompleted = isCompletedToday
                            didChange = true
                        }
                    }
                }
            }
        }
        
        if didChange {
            saveCharts()
        }
    }
    
    // MARK: - CRUD
    
    @discardableResult
    func createChart(title: String, coreGoal: String, targetDate: Date? = nil) -> MandalaChart {
        var newChart = MandalaChart(title: title, coreGoal: coreGoal, targetDate: targetDate)
        newChart.createdDate = Date()
        newChart.lastModifiedDate = Date()
        charts.append(newChart)
        activeChartId = newChart.id
        saveCharts()
        return newChart
    }
    
    func updateChart(_ chart: MandalaChart) {
        if let idx = charts.firstIndex(where: { $0.id == chart.id }) {
            var updated = chart
            updated.lastModifiedDate = Date()
            charts[idx] = updated
            saveCharts()
        }
    }
    
    func deleteChart(id: UUID) {
        charts.removeAll { $0.id == id }
        if activeChartId == id {
            activeChartId = charts.first?.id
        }
        saveCharts()
    }
    
    func resetAll() {
        charts.removeAll()
        activeChartId = nil
        UserDefaults.standard.removeObject(forKey: chartsKey)
        UserDefaults.standard.removeObject(forKey: activeChartIdKey)
        UserDefaults.standard.synchronize()
        objectWillChange.send()
    }
    
    func setActiveChart(id: UUID) {
        activeChartId = id
        UserDefaults.standard.set(id.uuidString, forKey: activeChartIdKey)
        objectWillChange.send()
    }
    
    func updatePillar(chartId: UUID, pillarIndex: Int, title: String, icon: String, colorHex: String) {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }),
              charts[chartIdx].pillars.indices.contains(pillarIndex) else { return }
        
        charts[chartIdx].pillars[pillarIndex].title = title
        charts[chartIdx].pillars[pillarIndex].icon = icon
        charts[chartIdx].pillars[pillarIndex].colorHex = colorHex
        charts[chartIdx].lastModifiedDate = Date()
        saveCharts()
    }
    
    func updateAction(
        chartId: UUID,
        pillarIndex: Int,
        actionIndex: Int,
        title: String,
        note: String,
        actionType: MandalaActionType,
        isCompleted: Bool? = nil
    ) {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }),
              charts[chartIdx].pillars.indices.contains(pillarIndex),
              charts[chartIdx].pillars[pillarIndex].actions.indices.contains(actionIndex) else { return }
        
        var action = charts[chartIdx].pillars[pillarIndex].actions[actionIndex]
        action.title = title
        action.note = note
        action.actionType = actionType
        if let completed = isCompleted {
            action.isCompleted = completed
        }
        charts[chartIdx].pillars[pillarIndex].actions[actionIndex] = action
        charts[chartIdx].lastModifiedDate = Date()
        saveCharts()
    }
    
    func toggleActionCompletion(chartId: UUID, pillarIndex: Int, actionIndex: Int) {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }),
              charts[chartIdx].pillars.indices.contains(pillarIndex),
              charts[chartIdx].pillars[pillarIndex].actions.indices.contains(actionIndex) else { return }
        
        var action = charts[chartIdx].pillars[pillarIndex].actions[actionIndex]
        let newStatus = !action.isCompleted
        action.isCompleted = newStatus
        charts[chartIdx].pillars[pillarIndex].actions[actionIndex] = action
        charts[chartIdx].lastModifiedDate = Date()
        
        // If linked to a TodoTask, toggle it in TaskManager as well
        if let linkedTaskId = action.linkedTaskId {
            TaskManager.shared.toggleTaskCompletion(linkedTaskId, on: Date())
        }
        
        saveCharts()
    }
    
    // MARK: - Integration with TodoTask
    
    @discardableResult
    func createTaskFromAction(
        chartId: UUID,
        pillarIndex: Int,
        actionIndex: Int,
        timeScope: TaskTimeScope = .today,
        priority: Priority = .medium
    ) async -> TodoTask? {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }),
              charts[chartIdx].pillars.indices.contains(pillarIndex),
              charts[chartIdx].pillars[pillarIndex].actions.indices.contains(actionIndex) else { return nil }
        
        let pillar = charts[chartIdx].pillars[pillarIndex]
        let action = pillar.actions[actionIndex]
        
        guard action.isAssigned else { return nil }
        
        let recurrence: Recurrence? = (action.actionType == .habit) ? Recurrence(type: .daily, startDate: Date(), endDate: nil) : nil
        
        let newTask = TodoTask(
            name: action.title,
            description: action.note.isEmpty ? "Mandala Chart: \(pillar.title)" : "\(action.note)\n\n[Mandala: \(pillar.title)]",
            startTime: Date(),
            hasSpecificDay: (timeScope == .today),
            priority: priority,
            icon: pillar.icon,
            recurrence: recurrence,
            hasRewardPoints: true,
            rewardPoints: action.actionType == .habit ? 15 : 25,
            timeScope: timeScope,
            domainId: pillar.id,
            goalId: chartId
        )
        
        await TaskManager.shared.addTask(newTask)
        
        // Link task to action
        charts[chartIdx].pillars[pillarIndex].actions[actionIndex].linkedTaskId = newTask.id
        saveCharts()
        
        return newTask
    }
    
    func clearChartActions(chartId: UUID) {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }) else { return }
        for pIdx in charts[chartIdx].pillars.indices {
            for aIdx in charts[chartIdx].pillars[pIdx].actions.indices {
                charts[chartIdx].pillars[pIdx].actions[aIdx].title = ""
                charts[chartIdx].pillars[pIdx].actions[aIdx].note = ""
                charts[chartIdx].pillars[pIdx].actions[aIdx].isCompleted = false
                charts[chartIdx].pillars[pIdx].actions[aIdx].linkedTaskId = nil
            }
        }
        charts[chartIdx].lastModifiedDate = Date()
        saveCharts()
    }
    
    func resetChart(chartId: UUID, to newChart: MandalaChart) {
        guard let chartIdx = charts.firstIndex(where: { $0.id == chartId }) else { return }
        var updated = newChart
        updated.id = chartId
        updated.lastModifiedDate = Date()
        charts[chartIdx] = updated
        saveCharts()
    }
    
    // MARK: - Default Sample & Templates
    
    private func createInitialSampleChart() {
        let sample = MandalaManager.genericTemplate()
        charts.append(sample)
        activeChartId = sample.id
        saveCharts()
    }
    
    static func blankChart(title: String = "Mio Mandala", coreGoal: String = "Mio Obiettivo") -> MandalaChart {
        var chart = MandalaChart(
            title: title,
            coreGoal: coreGoal,
            targetDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())
        )
        return chart
    }
    
    static func genericTemplate() -> MandalaChart {
        var chart = MandalaChart(
            title: "Mio Piano Annuale",
            coreGoal: "Successo, Equilibrio & Crescita 2026",
            coreGoalDescription: "Scomponi i tuoi obiettivi in 8 aree chiave. Personalizza ogni pilastro e compila le azioni man mano.",
            targetDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())
        )
        
        let genericPillarsData: [(title: String, icon: String, colorHex: String, sampleActions: [String])] = [
            ("Salute & Energia", "figure.run", "#10B981", ["Allenamento 3x a settimana", "Bere 2L d'acqua"]),
            ("Studio & Competenze", "brain.head.profile", "#3B82F6", ["Leggere 15 min al giorno", "Pratica quotidiana"]),
            ("Lavoro & Obiettivi", "briefcase.fill", "#8B5CF6", ["Completare progetto chiave", "Pianificare settimana"]),
            ("Finanze & Risparmio", "banknote.fill", "#F59E0B", ["Budget mensile definito", "Tracciare le spese"]),
            ("Relazioni & Famiglia", "heart.fill", "#EF4444", ["Tempo di qualità insieme", "Chiamare chi ami"]),
            ("Abitudini Quotidiane", "flame.fill", "#F97316", ["Routine del mattino", "Sonno regolare 8 ore"]),
            ("Ordine & Ambiente", "house.fill", "#06B6D4", ["Spazio di lavoro in ordine", "Decluttering"]),
            ("Passioni & Svago", "sparkles", "#6366F1", ["Dedicare tempo al tuo hobby", "Passeggiata rigenerante"])
        ]
        
        var builtPillars: [MandalaPillar] = []
        for (idx, pData) in genericPillarsData.enumerated() {
            var actions: [MandalaAction] = []
            for aIdx in 0..<8 {
                let sampleTitle = aIdx < pData.sampleActions.count ? pData.sampleActions[aIdx] : ""
                actions.append(MandalaAction(
                    index: aIdx,
                    title: sampleTitle,
                    actionType: (aIdx < 4) ? .habit : .task
                ))
            }
            builtPillars.append(MandalaPillar(
                index: idx,
                title: pData.title,
                colorHex: pData.colorHex,
                icon: pData.icon,
                actions: actions
            ))
        }
        
        chart.pillars = builtPillars
        return chart
    }
    
    static func samplePersonalGrowthChart() -> MandalaChart {
        var chart = MandalaChart(
            title: "Superare i propri limiti",
            coreGoal: "Successo Personale & Benessere 2026",
            coreGoalDescription: "Ispirato al metodo Harada di Shohei Ohtani per raggiungere eccellenza, equilibrio e costanza.",
            targetDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())
        )
        
        let samplePillarsData: [(title: String, icon: String, colorHex: String, actions: [String])] = [
            (
                "Salute & Fisico",
                "figure.run",
                "#10B981",
                ["Allenamento 4x/settimana", "Dormire 8 ore", "Bere 2.5L d'acqua", "Camminata 10k passi", "Stretching 15 min", "Dieta equilibrata", "Check-up medico", "Limiti allo zucchero"]
            ),
            (
                "Competenze & Studio",
                "brain.head.profile",
                "#3B82F6",
                ["Leggere 20 pagine/giorno", "Corso Swift & SwiftUI", "Studio Concurrency", "Podcast formativo", "Pratica codice 1h", "Scrivere appunti", "Imparare nuova lingua", "Risolvere sfide logiche"]
            ),
            (
                "Mentalità & Focus",
                "flame.fill",
                "#F59E0B",
                ["Meditazione 10 min", "Sessione Pomodoro 4x", "Diario della gratitudine", "Digital detox 1h/sera", "Affermazioni positive", "Respirazione profonda", "Gestione dello stress", "Pensiero critico"]
            ),
            (
                "Carriera & Progetti",
                "bolt.fill",
                "#8B5CF6",
                ["Completare feature chiave", "Revisione settimanale", "Network professionale", "Portfolio aggiornato", "Mentoring", "Studio dei competitor", "Feedback dagli utenti", "Organizzazione task"]
            ),
            (
                "Finanze & Risparmio",
                "sparkles",
                "#EC4899",
                ["Budget mensile", "Risparmio 20% entrate", "Tracciamento spese", "Fondo emergenza", "Investimento ricorrente", "Zero debiti inutili", "Educazione finanziaria", "Revisione abbonamenti"]
            ),
            (
                "Relazioni & Famiglia",
                "heart.fill",
                "#EF4444",
                ["Cena in famiglia", "Chiamare un amico caro", "Ascolto attivo", "Tempo di qualità", "Sorprendere chi ami", "Condividere successi", "Supporto reciproco", "Coltivare empatia"]
            ),
            (
                "Carattere & Fortuna",
                "leaf.fill",
                "#06B6D4",
                ["Raccogliere spazzatura a terra", "Salutare cordialmente", "Mantenere la parola", "Ordine nella stanza", "Puntualità assoluta", "Aiutare senza chiedere", "Gratitudine quotidiana", "Autocontrollo"]
            ),
            (
                "Ambiente & Ordine",
                "book.fill",
                "#6366F1",
                ["Scrivania pulita ogni sera", "Decluttering settimanale", "Inbox Zero", "Backup dispositivi", "Spazio di lavoro ergonomico", "Pianificazione giorno prima", "Rinnovare gli strumenti", "Atmosfera rilassante"]
            )
        ]
        
        var builtPillars: [MandalaPillar] = []
        for (idx, pData) in samplePillarsData.enumerated() {
            var actions: [MandalaAction] = []
            for (aIdx, aTitle) in pData.actions.enumerated() {
                actions.append(MandalaAction(
                    index: aIdx,
                    title: aTitle,
                    actionType: (aIdx < 5) ? .habit : .task
                ))
            }
            builtPillars.append(MandalaPillar(
                index: idx,
                title: pData.title,
                colorHex: pData.colorHex,
                icon: pData.icon,
                actions: actions
            ))
        }
        
        chart.pillars = builtPillars
        return chart
    }
}
