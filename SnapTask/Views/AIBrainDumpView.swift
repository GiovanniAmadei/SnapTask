import SwiftUI
import Speech
import MapKit

struct AIBrainDumpView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject private var taskManager = TaskManager.shared
    @ObservedObject private var categoryManager = CategoryManager.shared
    @StateObject private var speechService = SpeechRecognitionService()
    @ObservedObject private var geminiService = GeminiAIService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var inputText: String = ""
    @State private var parsedTasks: [ParsedTask] = []
    @State private var hasAnalyzed: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var analysisMode: String = "native"
    @State private var engineUsedText: String = ""
    @State private var showingAddCategory = false
    @State private var showApiKeySheet: Bool = false
    @State private var tempApiKey: String = ""
    @State private var analysisErrorMessage: String? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 18) {
                        // Header info card
                        headerBannerCard
                        
                        // Input Area: Text + Speech
                        inputCardSection
                        
                        // Action Buttons: Motore Rapido Nativo + Cloud IA Gemini
                        actionButtonsSection
                        
                        // Parsed Tasks Preview
                        if hasAnalyzed || !parsedTasks.isEmpty {
                            parsedResultsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, !parsedTasks.isEmpty ? 80 : 20)
                }
                .themedBackground()
                
                // Bottom Fixed CTA if tasks are parsed
                if !parsedTasks.isEmpty {
                    createTasksFloatingCTA
                }
            }
            .navigationTitle("🧠 Brain Dump IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        if speechService.isRecording {
                            speechService.stopRecording()
                        }
                        dismiss()
                    }
                    .foregroundColor(theme.primaryColor)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        tempApiKey = geminiService.apiKey
                        showApiKeySheet = true
                    }) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundColor(geminiService.isConfigured ? theme.primaryColor : .gray)
                    }
                }
            }
            .onAppear {
                speechService.requestAuthorization()
            }
            .onChange(of: speechService.transcript) { newTranscript in
                if speechService.isRecording && !newTranscript.isEmpty {
                    inputText = newTranscript
                }
            }
            .sheet(isPresented: $showApiKeySheet) {
                apiKeyConfigurationSheet
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerBannerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.primaryColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.primaryColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Brain Dump Intelligente")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primaryColor)
                    
                    Text("VELOCE & PRIVATO")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primaryColor.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(theme.primaryColor)
                }
                
                Text("Ditta o scrivi liberamente. L'IA organizzerà i tuoi pensieri in task con date, luoghi Apple Maps, ricorrenze e punti.")
                    .font(.system(size: 12))
                    .themedSecondaryText()
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var inputCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cosa hai in mente?")
                    .font(.system(size: 15, weight: .semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                if speechService.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0 + CGFloat(speechService.audioLevel) * 0.5)
                            .animation(.easeIn(duration: 0.2), value: speechService.audioLevel)
                        
                        Text("Registrazione in corso...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("Es: \"Devo andare in palestra alla mcfit domani alle 18 per 15 punti, e entro capodanno volare a Tokyo per due settimane. Ricordati di dare 1000 punti a Tokyo...\"")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $inputText)
                    .font(.system(size: 14))
                    .frame(minHeight: 110, maxHeight: 160)
                    .scrollContentBackground(.hidden)
                    .themedPrimaryText()
                    .focused($isInputFocused)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.backgroundColor.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(theme.borderColor, lineWidth: 1)
                    )
            )
            
            // Microphone & Clear controls
            HStack {
                Button(action: {
                    speechService.toggleRecording()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 20))
                        Text(speechService.isRecording ? "Ferma Dettato" : "Detta Vocale")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(speechService.isRecording ? .white : theme.primaryColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(speechService.isRecording ? Color.red : theme.primaryColor.opacity(0.12))
                    )
                }
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                        parsedTasks.removeAll()
                        hasAnalyzed = false
                        analysisErrorMessage = nil
                    }) {
                        Text("Cancella")
                            .font(.system(size: 13, weight: .medium))
                            .themedSecondaryText()
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            // Motore 1: IA Rapida Nativa On-Device (0 MB, Offline, Istantanea)
            Button(action: {
                performAnalysis(mode: "native")
            }) {
                HStack(spacing: 8) {
                    if isAnalyzing && analysisMode == "native" {
                        ProgressView()
                            .tint(theme.backgroundColor)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    
                    Text(isAnalyzing && analysisMode == "native" ? "Analisi Rapida in corso..." : "⚡️ Organizza con IA Rapida (Nativa On-Device)")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(theme.backgroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.primaryColor.opacity(0.4) : theme.primaryColor)
                )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            
            // Motore 2: Cloud IA Gemini (Ultra Intelligente, Gratuito)
            Button(action: {
                if !geminiService.isConfigured {
                    tempApiKey = ""
                    showApiKeySheet = true
                } else {
                    performAnalysis(mode: "gemini")
                }
            }) {
                HStack(spacing: 8) {
                    if isAnalyzing && analysisMode == "gemini" {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                    }
                    
                    Text(isAnalyzing && analysisMode == "gemini" ? "Elaborazione Cloud in corso..." : "✨ Organizza con Cloud IA (Groq · Llama 3.1)")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [Color.blue.opacity(0.4), Color.indigo.opacity(0.4)] : [Color.blue, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(12)
                )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
        }
    }
    
    private var parsedResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Identificate (\(parsedTasks.filter { $0.isSelected }.count)/\(parsedTasks.count))")
                        .font(.system(size: 16, weight: .bold))
                        .themedPrimaryText()
                    
                    if !engineUsedText.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text("Motore: \(engineUsedText)")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    addNewEmptyParsedTask()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Aggiungi")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                }
            }
            
            if let errorMsg = analysisErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMsg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
            }
            
            if parsedTasks.isEmpty && !isAnalyzing {
                VStack(spacing: 8) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 32))
                        .themedSecondaryText()
                    Text("Nessuna task identificata dal testo.")
                        .font(.system(size: 13))
                        .themedSecondaryText()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach($parsedTasks) { $task in
                        ParsedTaskRowView(
                            task: $task,
                            availableCategories: categoryManager.categories,
                            onDelete: {
                                parsedTasks.removeAll(where: { $0.id == task.id })
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var createTasksFloatingCTA: some View {
        let selectedCount = parsedTasks.filter { $0.isSelected && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count
        
        return Button(action: {
            createSelectedTasks()
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Crea \(selectedCount) Task\(selectedCount == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(theme.backgroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedCount == 0 ? theme.primaryColor.opacity(0.4) : theme.primaryColor)
                    .shadow(color: theme.shadowColor, radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .disabled(selectedCount == 0)
    }
    
    private var apiKeyConfigurationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Groq AI — Llama 3.1 (Gratuito)")
                            .font(.system(size: 16, weight: .bold))
                            .themedPrimaryText()
                        Text("6.000 richieste/giorno gratuite, zero carta di credito")
                            .font(.system(size: 12))
                            .themedSecondaryText()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inserisci la tua Chiave API Groq:")
                        .font(.system(size: 13, weight: .semibold))
                        .themedPrimaryText()
                    
                    SecureField("gsk_...", text: $tempApiKey)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.surfaceColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(theme.borderColor, lineWidth: 1)
                                )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Come ottenere la chiave Groq gratis in 1 minuto:")
                        .font(.system(size: 12, weight: .semibold))
                        .themedPrimaryText()
                    
                    Text("1. Vai su console.groq.com\n2. Registrati con Google o email\n3. Clicca su 'API Keys' → 'Create API Key'\n4. Copia la chiave (inizia con gsk_) e incollala qui sopra.")
                        .font(.system(size: 11))
                        .themedSecondaryText()
                        .lineSpacing(3)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.08))
                )
                
                Spacer()
                
                Button(action: {
                    geminiService.saveApiKey(tempApiKey)
                    showApiKeySheet = false
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        performAnalysis(mode: "gemini")
                    }
                }) {
                    Text("Salva e Continua")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        )
                }
                .disabled(tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .themedBackground()
            .navigationTitle("Configura Cloud IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        showApiKeySheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Actions
    
    private func performAnalysis(mode: String) {
        isInputFocused = false
        isAnalyzing = true
        analysisMode = mode
        analysisErrorMessage = nil
        engineUsedText = (mode == "gemini") ? "✨ Cloud IA (Groq · Llama 3.1)" : "⚡️ IA Rapida (Nativa On-Device)"
        
        Task {
            let categories = categoryManager.categories
            
            if mode == "gemini" {
                do {
                    let results = try await geminiService.parseTextWithGemini(text: inputText, availableCategories: categories)
                    await MainActor.run {
                        self.parsedTasks = results
                        self.hasAnalyzed = true
                        self.isAnalyzing = false
                    }
                } catch {
                    await MainActor.run {
                        self.analysisErrorMessage = error.localizedDescription
                        self.hasAnalyzed = true
                        self.isAnalyzing = false
                    }
                }
            } else {
                let results = await AITaskParser.shared.parseText(inputText, availableCategories: categories, resolveGeocoding: true)
                await MainActor.run {
                    self.parsedTasks = results
                    self.hasAnalyzed = true
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func addNewEmptyParsedTask() {
        let newTask = ParsedTask(
            title: "",
            timeScope: viewModel.selectedTimeScope,
            startDate: viewModel.selectedDate,
            priority: .medium
        )
        parsedTasks.append(newTask)
    }
    
    private func createSelectedTasks() {
        let validTasks = parsedTasks.filter { $0.isSelected && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        let cal = Calendar.current
        
        Task {
            for item in validTasks {
                var task = TodoTask(
                    name: item.title,
                    description: item.notes ?? "",
                    location: item.location,
                    startTime: item.startTime ?? item.startDate,
                    hasSpecificDay: item.timeScope == .today || item.hasSpecificTime,
                    hasSpecificTime: item.hasSpecificTime,
                    duration: item.duration,
                    hasDuration: item.duration > 0,
                    category: item.category,
                    priority: item.priority,
                    icon: item.category != nil ? "folder" : "circle",
                    recurrence: item.recurrence,
                    hasRewardPoints: item.hasRewardPoints,
                    rewardPoints: item.rewardPoints,
                    timeScope: item.timeScope
                )
                
                switch item.timeScope {
                case .today:
                    task.hasSpecificDay = true
                    task.scopeStartDate = item.startDate
                    task.scopeEndDate = nil
                case .week:
                    let weekStart = cal.startOfWeek(for: item.startDate)
                    task.scopeStartDate = weekStart
                    task.scopeEndDate = cal.date(byAdding: .day, value: 6, to: weekStart)
                    task.startTime = weekStart
                    task.hasSpecificDay = false
                case .month:
                    let monthStart = cal.startOfMonth(for: item.startDate)
                    task.scopeStartDate = monthStart
                    if let next = cal.date(byAdding: .month, value: 1, to: monthStart) {
                        task.scopeEndDate = cal.date(byAdding: .day, value: -1, to: next)
                    }
                    task.startTime = monthStart
                    task.hasSpecificDay = false
                case .year:
                    let yearStart = cal.startOfYear(for: item.startDate)
                    task.scopeStartDate = yearStart
                    var endComps = DateComponents()
                    endComps.year = cal.component(.year, from: yearStart)
                    endComps.month = 12
                    endComps.day = 31
                    task.scopeEndDate = cal.date(from: endComps)
                    task.startTime = yearStart
                    task.hasSpecificDay = false
                case .longTerm, .inbox, .all:
                    task.scopeStartDate = nil
                    task.scopeEndDate = nil
                    task.hasSpecificDay = false
                }
                
                await taskManager.addTask(task)
            }
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Subcomponents: ParsedTaskRowView

struct ParsedTaskRowView: View {
    @Binding var task: ParsedTask
    let availableCategories: [Category]
    let onDelete: () -> Void
    @Environment(\.theme) private var theme
    
    @State private var isEditingTitle: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var showRecurrencePicker: Bool = false
    @State private var showCategoryPicker: Bool = false
    @State private var showPointsEditor: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: {
                    task.isSelected.toggle()
                }) {
                    Image(systemName: task.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(task.isSelected ? theme.primaryColor : theme.secondaryTextColor.opacity(0.4))
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Nome task...", text: $task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .themedPrimaryText()
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            // Flow of Badges (Scope, Priority, Time, Location, Points, Category, Recurrence)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Time Scope Menu
                    Menu {
                        Button("Oggi / Giorno") { task.timeScope = .today }
                        Button("Settimana") { task.timeScope = .week }
                        Button("Mese") { task.timeScope = .month }
                        Button("Anno") { task.timeScope = .year }
                        Button("Lungo Termine") { task.timeScope = .longTerm }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: task.timeScope.icon)
                            Text(task.timeScope.displayName)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.primaryColor.opacity(0.12))
                        .foregroundColor(theme.primaryColor)
                        .cornerRadius(8)
                    }
                    
                    // Priority Menu
                    let prioColor: Color = task.priority == .high ? .red : (task.priority == .medium ? .orange : .green)
                    Menu {
                        Button("Alta") { task.priority = .high }
                        Button("Media") { task.priority = .medium }
                        Button("Bassa") { task.priority = .low }
                    } label: {
                        HStack(spacing: 4) {
                            Text(task.priority.displayName)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(prioColor.opacity(0.15))
                        .foregroundColor(prioColor)
                        .cornerRadius(8)
                    }
                    
                    // Orario (se presente)
                    if task.hasSpecificTime, let time = task.startTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                            Text(TimeFormat.time(time))
                            Button(action: {
                                task.hasSpecificTime = false
                                task.startTime = nil
                            }) {
                                Image(systemName: "xmark").font(.system(size: 9))
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                    }
                    
                    // Luogo (se presente)
                    if let loc = task.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(loc.name)
                                .lineLimit(1)
                            Button(action: {
                                task.location = nil
                            }) {
                                Image(systemName: "xmark").font(.system(size: 9))
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    
                    // Punti Ricompensa (se presenti)
                    if task.hasRewardPoints {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("\(task.rewardPoints) pt")
                            Button(action: {
                                task.hasRewardPoints = false
                                task.rewardPoints = 0
                            }) {
                                Image(systemName: "xmark").font(.system(size: 9))
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    
                    // Categoria (se presente)
                    Menu {
                        Button("Nessuna") { task.category = nil }
                        ForEach(availableCategories) { cat in
                            Button(cat.name) { task.category = cat }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(task.category?.name ?? "Categoria")
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    // Ricorrenza (se presente)
                    if let rec = task.recurrence {
                        let recTitle: String = {
                            switch rec.type {
                            case .daily: return "Giornaliera"
                            case .weekly(let days):
                                if days.count == 5 && !days.contains(1) && !days.contains(7) {
                                    return "Lun-Ven"
                                }
                                return "Settimanale"
                            case .monthly: return "Mensile"
                            case .monthlyOrdinal: return "Mensile"
                            case .yearly: return "Annuale"
                            }
                        }()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                            Text(recTitle)
                            Button(action: {
                                task.recurrence = nil
                            }) {
                                Image(systemName: "xmark").font(.system(size: 9))
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(task.isSelected ? theme.primaryColor.opacity(0.4) : theme.borderColor, lineWidth: 1)
                )
        )
    }
}
