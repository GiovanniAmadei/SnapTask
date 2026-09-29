import SwiftUI

struct MandalaTemplatePickerView: View {
    @ObservedObject private var mandalaManager = MandalaManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var showingCustomForm = false
    @State private var customTitle = ""
    @State private var customCoreGoal = ""
    @State private var targetDate = Date()
    @State private var hasTargetDate = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header card
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(theme.gradient)
                            .padding(.top, 8)
                        
                        Text("mandala_create_chart_title".localized)
                            .font(.title2.bold())
                            .themedPrimaryText()
                            .multilineTextAlignment(.center)
                        
                        Text("mandala_create_chart_subtitle".localized)
                            .font(.subheadline)
                            .themedSecondaryText()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    // Option 0: Template Generico
                    templateCard(
                        title: "Template Generico (Personalizzabile)",
                        subtitle: "8 aree chiave della vita (Salute, Studio, Lavoro, Finanze, Relazioni, Abitudini, Ordine, Tempo Libero) pronte da personalizzare.",
                        icon: "square.grid.3x3.fill",
                        badge: "Consigliato",
                        color: theme.primaryColor
                    ) {
                        applyGenericTemplate()
                    }
                    
                    // Option 1: Template Shohei Ohtani
                    templateCard(
                        title: "Modello Shohei Ohtani (Crescita Personale)",
                        subtitle: "81 caselle per eccellere in disciplina, abitudini, competenze fisiche, mentali ed etiche.",
                        icon: "trophy.fill",
                        badge: "Avanzato",
                        color: Color(hex: "#F59E0B")
                    ) {
                        applySampleTemplate()
                    }
                    
                    // Option 2: Startup / Progetto
                    templateCard(
                        title: "Lancio Startup o Progetto Digitale",
                        subtitle: "Dalla prima riga di codice al go-to-market: prodotto, marketing, metriche e scalabilità.",
                        icon: "rocket.fill",
                        badge: "Business",
                        color: Color(hex: "#3B82F6")
                    ) {
                        applyStartupTemplate()
                    }
                    
                    // Option 3: Fitness & Benessere 360
                    templateCard(
                        title: "Salute & Fitness Totale",
                        subtitle: "Nutrizione, allenamento, sonno, idratazione e abitudini per la massima energia quotidiana.",
                        icon: "heart.text.square.fill",
                        badge: "Salute",
                        color: Color(hex: "#10B981")
                    ) {
                        applyFitnessTemplate()
                    }
                    
                    // Option 4: Da zero (Foglio Bianco)
                    Button(action: { showingCustomForm = true }) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(theme.primaryColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "pencil.and.outline")
                                        .foregroundColor(theme.primaryColor)
                                        .font(.system(size: 20, weight: .semibold))
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("mandala_create_custom_title".localized)
                                    .font(.subheadline.bold())
                                    .themedPrimaryText()
                                
                                Text("mandala_create_custom_subtitle".localized)
                                    .font(.caption)
                                    .themedSecondaryText()
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .padding()
                        .background(theme.surfaceColor)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(theme.borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .themedBackground()
            .navigationTitle("mandala_new_chart".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomForm) {
                customFormSheet
            }
        }
    }
    
    private func templateCard(
        title: String,
        subtitle: String,
        icon: String,
        badge: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.system(size: 18, weight: .bold))
                    }
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .themedPrimaryText()
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .themedSecondaryText()
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(theme.surfaceColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1.5)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
    
    private var customFormSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informazioni Principali")) {
                    TextField("Nome del grafico (es. Obiettivi 2026)", text: $customTitle)
                    TextField("Obiettivo Centrale (Core Dream)", text: $customCoreGoal)
                }
                
                Section(header: Text("Scadenza / Orizzonte")) {
                    Toggle("Imposta data target", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Data obiettivo", selection: $targetDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Nuovo Mandala Personalizzato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        showingCustomForm = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("create".localized) {
                        let chart = mandalaManager.createChart(
                            title: customTitle.isEmpty ? "Mio Mandala Chart" : customTitle,
                            coreGoal: customCoreGoal.isEmpty ? "Mio Obiettivo Primario" : customCoreGoal,
                            targetDate: hasTargetDate ? targetDate : nil
                        )
                        mandalaManager.setActiveChart(id: chart.id)
                        showingCustomForm = false
                        dismiss()
                    }
                    .disabled(customCoreGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func applyGenericTemplate() {
        let generic = MandalaManager.genericTemplate()
        mandalaManager.charts.append(generic)
        mandalaManager.setActiveChart(id: generic.id)
    }
    
    private func applySampleTemplate() {
        let sample = MandalaManager.samplePersonalGrowthChart()
        mandalaManager.charts.append(sample)
        mandalaManager.setActiveChart(id: sample.id)
    }
    
    private func applyStartupTemplate() {
        var chart = MandalaChart(
            title: "Lancio Startup & App iOS",
            coreGoal: "Raggiungere 1.000 Utenti Attivi & Scalabilità",
            coreGoalDescription: "Creazione di un prodotto amato dagli utenti con solida base tecnica e marketing costante.",
            targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())
        )
        
        let pillars: [(title: String, icon: String, colorHex: String, actions: [String])] = [
            ("Prodotto & UX", "sparkles", "#3B82F6", ["Interviste utenti", "Wireframe Figma", "Onboarding in 3 passi", "Feature principale MVP", "Test usabilità", "Micro-interazioni haptic", "Dark mode rifinita", "Riduzione attrito login"]),
            ("Sviluppo Tecnico", "chevron.left.forwardslash.chevron.right", "#8B5CF6", ["Architettura pulita", "Swift Concurrency", "CloudKit Sync", "Widget & Lockscreen", "Test unitari critici", "Zero crash a rilascio", "Monitoraggio memoria", "Continuous Integration"]),
            ("Marketing & ASO", "speaker.wave.3.fill", "#EC4899", ["Keyword ASO mirate", "Screenshot accattivanti", "Video preview App Store", "Post demo su Twitter/X", "Lancio Product Hunt", "Contattare 10 blog tech", "Newsletter settimanale", "Reddit community sharing"]),
            ("Feedback & Assistenza", "bubble.left.and.bubble.right.fill", "#F59E0B", ["Pulsante feedback in app", "Risposte recensioni <24h", "Bug fix settimanali", "Changelog trasparente", "Canale Discord utenti", "Sondaggio di soddisfazione", "FAQ chiare", "Beta testing con TestFlight"]),
            ("Finanze & Monetizzazione", "dollarsign.circle.fill", "#10B981", ["Prezzo abbonamento chiaro", "Paywall ben posizionato", "Analisi costo server", "Controllo MRR", "Offerta di lancio annuale", "Integrazione StoreKit 2", "Incentivi fedeltà", "Budget advertising"]),
            ("Metriche & Analytics", "chart.xyaxis.line", "#06B6D4", ["Tracciamento Retention D1/D7", "Monitoraggio funnel signup", "Tempo medio per sessione", "Crash rate < 0.1%", "NPS score", "Feature più utilizzate", "Analisi churn", "Revisione KPI settimanale"]),
            ("Routine Giornaliera", "flame.fill", "#F97316", ["Deep work 3 ore mattina", "Zero distrazioni durante codice", "Inbox e ticket a orari fissi", "Standup serale su avanzamento", "1 ora studio nuove API", "Camminata rigenerante", "Sonno regolare", "Scrivere progressi"]),
            ("Team & Network", "person.3.fill", "#6366F1", ["Condividere progressi sui social", "Cercare mentor di settore", "Partecipare a meetup dev", "Aiutare altri sviluppatori", "Confronto con designer", "Costruire relazioni genuine", "Festeggiare piccoli traguardi", "Visione a lungo termine"])
        ]
        
        var builtPillars: [MandalaPillar] = []
        for (idx, p) in pillars.enumerated() {
            var actions: [MandalaAction] = []
            for (aIdx, aTitle) in p.actions.enumerated() {
                actions.append(MandalaAction(index: aIdx, title: aTitle, actionType: (aIdx % 2 == 0) ? .habit : .task))
            }
            builtPillars.append(MandalaPillar(index: idx, title: p.title, colorHex: p.colorHex, icon: p.icon, actions: actions))
        }
        chart.pillars = builtPillars
        mandalaManager.charts.append(chart)
        mandalaManager.setActiveChart(id: chart.id)
    }
    
    private func applyFitnessTemplate() {
        var chart = MandalaChart(
            title: "Salute, Corpo & Vitalità",
            coreGoal: "Massima Energia Fisica & Benessere Mentale",
            coreGoalDescription: "Scomporre nutrizione, allenamento, sonno e abitudini per una trasformazione sostenibile.",
            targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())
        )
        
        let pillars: [(title: String, icon: String, colorHex: String, actions: [String])] = [
            ("Allenamento Pesi", "dumbbell.fill", "#EF4444", ["3 sessioni forza a settimana", "Riscaldamento articolare", "Sovraccarico progressivo", "Registrare i carichi", "Recupero 2 min tra set", "Focus sulla tecnica", "Stretching post workout", "Defaticamento"]),
            ("Cardio & Movimento", "figure.run", "#F97316", ["10.000 passi al giorno", "2 sessioni cardio zona 2", "Salire sempre le scale", "Bici per spostamenti brevi", "Sprint leggeri 1x/settimana", "Pausa attiva ogni 50 min", "Nuotata nel weekend", "Passeggiata dopo i pasti"]),
            ("Nutrizione & Cibo", "carrot.fill", "#10B981", ["Proteine ad ogni pasto", "Verdure ad ogni piatto", "Eliminare zuccheri raffinati", "Pasti preparati a casa", "Spuntini con frutta secca", "Porzioni moderate", "Cena leggera 3h prima di dormire", "Limitare cibi ultraprocessati"]),
            ("Idratazione", "drop.fill", "#06B6D4", ["Bicchiere d'acqua appena svegli", "2.5 Litri di acqua al giorno", "Borraccia sempre vicina", "Tisana serale rilassante", "Elettroliti post allenamento", "Zero bibite gassate zuccherate", "Limitare alcol", "Un bicchiere prima di ogni pasto"]),
            ("Sonno & Ritmo Circadiano", "moon.stars.fill", "#8B5CF6", ["7.5 - 8 ore a notte", "Stesso orario di sveglia", "No schermi 1h prima di dormire", "Stanza buia e fresca", "Luce naturale nei primi 20 min", "Niente caffeina dopo le 14:00", "Doccia calda rilassante", "Lettura a letto"]),
            ("Salute Mentale & Stress", "brain.head.profile", "#3B82F6", ["Meditazione 10 min al giorno", "Diario pensieri sera", "Respirazione diaframmatica", "Tempo nella natura", "Disconnessione dalle notifiche", "Lettura stimolante", "Conversazioni positive", "Coltivare la pazienza"]),
            ("Mobilità & Postura", "figure.flexibility", "#EC4899", ["Routine mobilità mattina 10m", "Esercizi per la schiena", "Postura eretta alla scrivania", "Foam roller muscolare", "Stretching per i flessori", "Verifica ergonomia sedia", "Spalle rilassate durante il giorno", "Yoga della domenica"]),
            ("Abitudini & Costanza", "calendar.badge.clock", "#6366F1", ["Tracciare allenamenti sull'app", "Pesata settimanale costante", "Foto progresso mensile", "Pianificare pasti domenica", "Borsa palestra pronta la sera", "Celebrare le piccole vittorie", "Non saltare mai 2 giorni di fila", "Patto con se stessi"])
        ]
        
        var builtPillars: [MandalaPillar] = []
        for (idx, p) in pillars.enumerated() {
            var actions: [MandalaAction] = []
            for (aIdx, aTitle) in p.actions.enumerated() {
                actions.append(MandalaAction(index: aIdx, title: aTitle, actionType: .habit))
            }
            builtPillars.append(MandalaPillar(index: idx, title: p.title, colorHex: p.colorHex, icon: p.icon, actions: actions))
        }
        chart.pillars = builtPillars
        mandalaManager.charts.append(chart)
        mandalaManager.setActiveChart(id: chart.id)
    }
}
