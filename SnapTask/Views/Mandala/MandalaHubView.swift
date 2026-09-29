import SwiftUI

enum MandalaDisplayMode: String, CaseIterable {
    case core = "Focus 3x3"
    case galaxy = "Galassia 9x9"
    
    var icon: String {
        switch self {
        case .core: return "square.grid.3x3.fill"
        case .galaxy: return "circle.grid.3x3.fill"
        }
    }
}

// Stable Identifiers for modal presentations to prevent SwiftUI re-creation loops
struct ActionSheetItem: Identifiable, Equatable {
    var id: String { "\(pillarIndex)_\(actionIndex)" }
    let pillarIndex: Int
    let actionIndex: Int
}

struct PillarSheetItem: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
}

struct MandalaHubView: View {
    @StateObject private var mandalaManager = MandalaManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var displayMode: MandalaDisplayMode = .core
    @State private var selectedPillarIndex: Int? = nil
    
    // Stable Sheet States
    @State private var activeActionItem: ActionSheetItem? = nil
    @State private var activePillarItem: PillarSheetItem? = nil
    @State private var showingTemplatePicker = false
    @State private var editingCoreGoal = false
    @State private var showingClearActionsAlert = false
    
    private var activeChart: MandalaChart? {
        mandalaManager.activeChart
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let chart = activeChart {
                    chartHeader(chart)
                    
                    // Segmented mode switcher
                    Picker("Visualizzazione", selection: $displayMode) {
                        ForEach(MandalaDisplayMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    // Main content depending on mode and zoom state
                    if displayMode == .core {
                        if let selectedPillar = selectedPillarIndex {
                            pillarDetailView(chart: chart, pillarIndex: selectedPillar)
                        } else {
                            coreGridView(chart: chart)
                        }
                    } else {
                        galaxyCanvasView(chart: chart)
                    }
                } else {
                    emptyStateView
                }
            }
            .themedBackground()
            .navigationTitle("Mandala Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let chart = activeChart {
                            Section("Personalizzazione") {
                                Button(action: { editingCoreGoal = true }) {
                                    Label("Modifica Obiettivo & Titolo", systemImage: "pencil")
                                }
                                Button(action: { showingTemplatePicker = true }) {
                                    Label("Scegli / Cambia Template", systemImage: "square.grid.3x3.topleft.filled")
                                }
                                Button(role: .destructive, action: { showingClearActionsAlert = true }) {
                                    Label("Svuota tutte le azioni", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }
                        
                        Divider()
                        
                        Section("I tuoi Grafici") {
                            ForEach(mandalaManager.charts) { c in
                                Button(action: {
                                    withAnimation {
                                        mandalaManager.setActiveChart(id: c.id)
                                        selectedPillarIndex = nil
                                    }
                                }) {
                                    HStack {
                                        Text(c.title)
                                        if c.id == activeChart?.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            Button(action: { showingTemplatePicker = true }) {
                                Label("Nuovo Mandala Chart", systemImage: "plus.circle")
                            }
                        }
                        
                        if let chart = activeChart, mandalaManager.charts.count > 1 {
                            Divider()
                            Button(role: .destructive, action: {
                                mandalaManager.deleteChart(id: chart.id)
                                selectedPillarIndex = nil
                            }) {
                                Label("Elimina questo grafico", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(theme.primaryColor)
                    }
                }
            }
            // MARK: - Stable Sheets (Fixed infinite open/close loop)
            .sheet(isPresented: $showingTemplatePicker) {
                MandalaTemplatePickerView()
            }
            .sheet(item: $activeActionItem) { item in
                if let chart = activeChart {
                    MandalaActionDetailSheet(
                        chartId: chart.id,
                        pillarIndex: item.pillarIndex,
                        actionIndex: item.actionIndex
                    )
                }
            }
            .sheet(item: $activePillarItem) { item in
                if let chart = activeChart {
                    PillarEditorSheet(
                        chartId: chart.id,
                        pillarIndex: item.index
                    )
                }
            }
            .sheet(isPresented: $editingCoreGoal) {
                if let chart = activeChart {
                    CoreGoalEditorSheet(chartId: chart.id)
                }
            }
            .alert("Svuotare tutte le azioni?", isPresented: $showingClearActionsAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Svuota", role: .destructive) {
                    if let chart = activeChart {
                        mandalaManager.clearChartActions(chartId: chart.id)
                        HapticManager.shared.notification(.success)
                    }
                }
            } message: {
                Text("I titoli dei pilastri e l'obiettivo centrale rimarranno invariati, ma tutte le 64 azioni verranno rimosse per permetterti di personalizzarle da capo.")
            }
        }
    }
    
    // MARK: - Header Bar
    
    private func chartHeader(_ chart: MandalaChart) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: { editingCoreGoal = true }) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(chart.title)
                            .font(.headline.weight(.bold))
                            .themedPrimaryText()
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    
                    Text(chart.coreGoal)
                        .font(.caption)
                        .themedSecondaryText()
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Progress Ring & stats
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(chart.totalCompletedActions)/64")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .themedPrimaryText()
                    
                    Text("\(Int(chart.totalGridCompletionPercentage * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.primaryColor)
                }
                
                ZStack {
                    Circle()
                        .stroke(theme.primaryColor.opacity(0.15), lineWidth: 4)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.02, chart.totalGridCompletionPercentage)))
                        .stroke(
                            theme.primaryColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surfaceColor.opacity(0.6))
    }
    
    // MARK: - Mode 1: Core 3x3 Grid
    
    private func coreGridView(chart: MandalaChart) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // Info helper bar
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .foregroundColor(theme.primaryColor)
                        .font(.caption)
                    Text("Tocca un pilastro per esplorare o personalizzare le sue 8 azioni")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryTextColor)
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // 3x3 Grid Layout
                GeometryReader { geo in
                    let size = min(geo.size.width - 24, geo.size.height - 20)
                    let cellSize = (size - 16) / 3
                    
                    VStack(spacing: 8) {
                        // Row 0: [0, 1, 2]
                        HStack(spacing: 8) {
                            pillarCell(chart: chart, index: 0, size: cellSize)
                            pillarCell(chart: chart, index: 1, size: cellSize)
                            pillarCell(chart: chart, index: 2, size: cellSize)
                        }
                        
                        // Row 1: [7, CORE GOAL, 3]
                        HStack(spacing: 8) {
                            pillarCell(chart: chart, index: 7, size: cellSize)
                            coreGoalCenterCell(chart: chart, size: cellSize)
                            pillarCell(chart: chart, index: 3, size: cellSize)
                        }
                        
                        // Row 2: [6, 5, 4]
                        HStack(spacing: 8) {
                            pillarCell(chart: chart, index: 6, size: cellSize)
                            pillarCell(chart: chart, index: 5, size: cellSize)
                            pillarCell(chart: chart, index: 4, size: cellSize)
                        }
                    }
                    .frame(width: size, height: size)
                    .position(x: geo.size.width / 2, y: size / 2 + 10)
                }
                .frame(height: 380)
                .padding(.horizontal, 12)
                
                // Quick Summary list of the 8 Pillars with direct edit buttons
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("I Tuoi 8 Pilastri")
                            .font(.subheadline.weight(.bold))
                            .themedPrimaryText()
                        Spacer()
                        Text("Tocca per entrare o matita per modificare")
                            .font(.caption2)
                            .themedSecondaryText()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    ForEach(chart.pillars) { p in
                        HStack(spacing: 10) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedPillarIndex = p.index
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(p.color)
                                        .frame(width: 10, height: 10)
                                    
                                    Image(systemName: p.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(p.color)
                                        .frame(width: 20)
                                    
                                    Text(p.title.isEmpty ? "Pilastro \(p.index + 1)" : p.title)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    
                                    Spacer()
                                    
                                    Text("\(p.completedActionsCount)/8")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(theme.secondaryTextColor)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Direct Edit Pillar button
                            Button(action: {
                                activePillarItem = PillarSheetItem(index: p.index)
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.surfaceColor)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(theme.borderColor, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
    }
    
    private func coreGoalCenterCell(chart: MandalaChart, size: CGFloat) -> some View {
        Button(action: {
            editingCoreGoal = true
            HapticManager.shared.impact(.light)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.primaryColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: theme.primaryColor.opacity(0.3), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 5) {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(chart.coreGoal)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                    
                    Text("Core Goal")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(6)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
    
    private func pillarCell(chart: MandalaChart, index: Int, size: CGFloat) -> some View {
        let pillar = chart.pillars[index]
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedPillarIndex = index
            }
            HapticManager.shared.impact(.light)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(pillar.color.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 1)
                
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: pillar.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(pillar.color)
                        
                        Spacer()
                        
                        Text("\(pillar.completedActionsCount)/8")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(pillar.color)
                    }
                    
                    Spacer()
                    
                    Text(pillar.title.isEmpty ? "Pilastro \(index + 1)" : pillar.title)
                        .font(.system(size: 11, weight: .semibold))
                        .themedPrimaryText()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    
                    Spacer()
                    
                    // Progress bar
                    GeometryReader { pGeo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(pillar.color.opacity(0.15))
                                .frame(height: 3)
                            Capsule()
                                .fill(pillar.color)
                                .frame(width: pGeo.size.width * CGFloat(pillar.progress), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(8)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Mode 2: Pillar Detail 3x3 Grid
    
    private func pillarDetailView(chart: MandalaChart, pillarIndex: Int) -> some View {
        let pillar = chart.pillars[pillarIndex]
        
        return VStack(spacing: 12) {
            // Navigation Back & Edit Bar
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedPillarIndex = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("Tutti i Pilastri")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(theme.primaryColor)
                }
                
                Spacer()
                
                Button(action: {
                    activePillarItem = PillarSheetItem(index: pillarIndex)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Personalizza Pilastro")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.primaryColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Sub-grid 3x3 layout for this pillar
            GeometryReader { geo in
                let size = min(geo.size.width - 24, geo.size.height - 20)
                let cellSize = (size - 16) / 3
                
                VStack(spacing: 8) {
                    // Row 0: Actions [0, 1, 2]
                    HStack(spacing: 8) {
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 0, size: cellSize)
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 1, size: cellSize)
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 2, size: cellSize)
                    }
                    
                    // Row 1: Action 7, CENTER PILLAR, Action 3
                    HStack(spacing: 8) {
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 7, size: cellSize)
                        pillarCenterCell(pillar: pillar, pillarIndex: pillarIndex, size: cellSize)
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 3, size: cellSize)
                    }
                    
                    // Row 2: Actions [6, 5, 4]
                    HStack(spacing: 8) {
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 6, size: cellSize)
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 5, size: cellSize)
                        actionCell(pillar: pillar, pillarIndex: pillarIndex, actionIndex: 4, size: cellSize)
                    }
                }
                .frame(width: size, height: size)
                .position(x: geo.size.width / 2, y: size / 2 + 10)
            }
            .frame(height: 380)
            .padding(.horizontal, 12)
            
            // Instructions helper
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.caption)
                Text("Tocca una casella per modificare l'azione o portarla in SnapTask")
                    .font(.caption2)
                    .foregroundColor(theme.secondaryTextColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
    
    private func pillarCenterCell(pillar: MandalaPillar, pillarIndex: Int, size: CGFloat) -> some View {
        Button(action: {
            activePillarItem = PillarSheetItem(index: pillarIndex)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(pillar.color)
                    .shadow(color: pillar.color.opacity(0.35), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Image(systemName: pillar.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(pillar.title.isEmpty ? "Pilastro \(pillarIndex + 1)" : pillar.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    Text("\(pillar.completedActionsCount)/8 Fatti")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(6)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
    
    private func actionCell(pillar: MandalaPillar, pillarIndex: Int, actionIndex: Int, size: CGFloat) -> some View {
        let action = pillar.actions[actionIndex]
        
        return Button(action: {
            activeActionItem = ActionSheetItem(pillarIndex: pillarIndex, actionIndex: actionIndex)
            HapticManager.shared.impact(.light)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(action.isCompleted ? pillar.color.opacity(0.12) : theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                action.isCompleted ? pillar.color : (action.isAssigned ? theme.borderColor : theme.borderColor.opacity(0.5)),
                                lineWidth: action.isCompleted ? 1.5 : 1
                            )
                    )
                
                if action.isAssigned {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: action.actionType.icon)
                                .font(.system(size: 9))
                                .foregroundColor(theme.secondaryTextColor)
                            
                            Spacer()
                            
                            // Checkmark button (toggles completion directly)
                            Button(action: {
                                if let chart = activeChart {
                                    mandalaManager.toggleActionCompletion(
                                        chartId: chart.id,
                                        pillarIndex: pillarIndex,
                                        actionIndex: actionIndex
                                    )
                                    HapticManager.shared.impact(.medium)
                                }
                            }) {
                                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(action.isCompleted ? pillar.color : theme.secondaryTextColor.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        Text(action.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(action.isCompleted ? theme.secondaryTextColor : theme.textColor)
                            .strikethrough(action.isCompleted, color: theme.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                        
                        Spacer()
                        
                        if action.linkedTaskId != nil {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8))
                                Text("SnapTask")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(theme.primaryColor)
                        }
                    }
                    .padding(6)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                        
                        Text("Azione \(actionIndex + 1)")
                            .font(.system(size: 9))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Mode 3: Galaxy 9x9 (Full Matrix)
    
    private func galaxyCanvasView(chart: MandalaChart) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 6) {
                // Outer 3x3 of 3x3 blocks = 9x9 total grid
                // Row 0 of blocks: Pillar 0, Pillar 1, Pillar 2
                HStack(spacing: 6) {
                    miniPillarBlock(chart: chart, pillarIndex: 0)
                    miniPillarBlock(chart: chart, pillarIndex: 1)
                    miniPillarBlock(chart: chart, pillarIndex: 2)
                }
                
                // Row 1 of blocks: Pillar 7, CENTER BLOCK, Pillar 3
                HStack(spacing: 6) {
                    miniPillarBlock(chart: chart, pillarIndex: 7)
                    miniCenterCoreBlock(chart: chart)
                    miniPillarBlock(chart: chart, pillarIndex: 3)
                }
                
                // Row 2 of blocks: Pillar 6, Pillar 5, Pillar 4
                HStack(spacing: 6) {
                    miniPillarBlock(chart: chart, pillarIndex: 6)
                    miniPillarBlock(chart: chart, pillarIndex: 5)
                    miniPillarBlock(chart: chart, pillarIndex: 4)
                }
            }
            .padding(12)
        }
    }
    
    private func miniPillarBlock(chart: MandalaChart, pillarIndex: Int) -> some View {
        let pillar = chart.pillars[pillarIndex]
        let blockSize: CGFloat = 160
        let miniCellSize: CGFloat = (blockSize - 12) / 3
        
        return VStack(spacing: 3) {
            // Row 0: Actions 0, 1, 2
            HStack(spacing: 3) {
                miniActionCell(action: pillar.actions[0], color: pillar.color, size: miniCellSize)
                miniActionCell(action: pillar.actions[1], color: pillar.color, size: miniCellSize)
                miniActionCell(action: pillar.actions[2], color: pillar.color, size: miniCellSize)
            }
            // Row 1: Action 7, Pillar Center, Action 3
            HStack(spacing: 3) {
                miniActionCell(action: pillar.actions[7], color: pillar.color, size: miniCellSize)
                
                // Center: Pillar
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(pillar.color)
                    VStack(spacing: 1) {
                        Image(systemName: pillar.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                        Text(pillar.title)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(2)
                }
                .frame(width: miniCellSize, height: miniCellSize)
                
                miniActionCell(action: pillar.actions[3], color: pillar.color, size: miniCellSize)
            }
            // Row 2: Actions 6, 5, 4
            HStack(spacing: 3) {
                miniActionCell(action: pillar.actions[6], color: pillar.color, size: miniCellSize)
                miniActionCell(action: pillar.actions[5], color: pillar.color, size: miniCellSize)
                miniActionCell(action: pillar.actions[4], color: pillar.color, size: miniCellSize)
            }
        }
        .padding(4)
        .background(pillar.color.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(pillar.color.opacity(0.3), lineWidth: 1)
        )
        .frame(width: blockSize, height: blockSize)
        .onTapGesture {
            withAnimation {
                displayMode = .core
                selectedPillarIndex = pillarIndex
            }
        }
    }
    
    private func miniActionCell(action: MandalaAction, color: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(action.isCompleted ? color.opacity(0.3) : theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(action.isCompleted ? color : Color.gray.opacity(0.2), lineWidth: 0.5)
                )
            
            Text(action.title)
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(action.isCompleted ? color : theme.textColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(1)
        }
        .frame(width: size, height: size)
    }
    
    private func miniCenterCoreBlock(chart: MandalaChart) -> some View {
        let blockSize: CGFloat = 160
        let miniCellSize: CGFloat = (blockSize - 12) / 3
        
        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                miniCorePillarRef(pillar: chart.pillars[0], size: miniCellSize)
                miniCorePillarRef(pillar: chart.pillars[1], size: miniCellSize)
                miniCorePillarRef(pillar: chart.pillars[2], size: miniCellSize)
            }
            HStack(spacing: 3) {
                miniCorePillarRef(pillar: chart.pillars[7], size: miniCellSize)
                
                // Central Goal
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.primaryColor)
                    Text(chart.coreGoal)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .padding(2)
                }
                .frame(width: miniCellSize, height: miniCellSize)
                
                miniCorePillarRef(pillar: chart.pillars[3], size: miniCellSize)
            }
            HStack(spacing: 3) {
                miniCorePillarRef(pillar: chart.pillars[6], size: miniCellSize)
                miniCorePillarRef(pillar: chart.pillars[5], size: miniCellSize)
                miniCorePillarRef(pillar: chart.pillars[4], size: miniCellSize)
            }
        }
        .padding(4)
        .background(theme.primaryColor.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.primaryColor, lineWidth: 1.5)
        )
        .frame(width: blockSize, height: blockSize)
    }
    
    private func miniCorePillarRef(pillar: MandalaPillar, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(pillar.color.opacity(0.2))
            Text(pillar.title)
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(pillar.color)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(1)
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 50))
                .foregroundStyle(theme.gradient)
                .padding(.top, 40)
            
            Text("Nessun Mandala Chart")
                .font(.title2.bold())
                .themedPrimaryText()
            
            Text("Scomponi un grande obiettivo in 8 pilastri e 64 azioni quotidiane con il metodo Harada.")
                .font(.subheadline)
                .themedSecondaryText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showingTemplatePicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Crea il tuo Mandala")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(theme.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 12)
            
            Spacer()
        }
    }
}

// MARK: - Dedicated Full Customization Sheet for Pillars
struct PillarEditorSheet: View {
    let chartId: UUID
    let pillarIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var mandalaManager = MandalaManager.shared
    
    @State private var title: String = ""
    @State private var selectedIcon: String = "circle.grid.2x2"
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var customColor: Color = .blue
    @State private var showingIconPicker = false
    
    private var pillar: MandalaPillar? {
        guard let chart = mandalaManager.charts.first(where: { $0.id == chartId }),
              chart.pillars.indices.contains(pillarIndex) else { return nil }
        return chart.pillars[pillarIndex]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Nome del Pilastro") {
                    TextField("Nome del pilastro (es. Salute, Studio...)", text: $title)
                        .font(.body.weight(.medium))
                }
                
                Section("Icona") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColorHex).opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: selectedColorHex))
                        }
                        
                        Button("Cambia icona...") {
                            showingIconPicker = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.primaryColor)
                    }
                    .padding(.vertical, 4)
                    
                    // Quick Icon Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MandalaChart.presetIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                    HapticManager.shared.impact(.light)
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedIcon == icon ? Color(hex: selectedColorHex) : theme.secondaryTextColor)
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color(hex: selectedColorHex).opacity(0.15) : theme.surfaceColor)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedIcon == icon ? Color(hex: selectedColorHex) : theme.borderColor, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Colore Tematico") {
                    // Quick Color Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MandalaChart.presetColors, id: \.self) { hex in
                                Button(action: {
                                    selectedColorHex = hex
                                    customColor = Color(hex: hex)
                                    HapticManager.shared.impact(.light)
                                }) {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                                        )
                                        .shadow(color: Color(hex: hex).opacity(0.3), radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ColorPicker("Scegli un colore personalizzato", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { newColor in
                            if let hex = newColor.toHex() {
                                selectedColorHex = hex
                            }
                        }
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Personalizza Pilastro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        mandalaManager.updatePillar(
                            chartId: chartId,
                            pillarIndex: pillarIndex,
                            title: title,
                            icon: selectedIcon,
                            colorHex: selectedColorHex
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
            .onAppear {
                if let p = pillar {
                    title = p.title
                    selectedIcon = p.icon
                    selectedColorHex = p.colorHex
                    customColor = Color(hex: p.colorHex)
                }
            }
        }
    }
}

// MARK: - Dedicated Full Customization Sheet for Core Goal
struct CoreGoalEditorSheet: View {
    let chartId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var mandalaManager = MandalaManager.shared
    
    @State private var chartTitle: String = ""
    @State private var coreGoal: String = ""
    @State private var coreGoalDescription: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Date()
    
    private var chart: MandalaChart? {
        mandalaManager.charts.first(where: { $0.id == chartId })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Titolo del Grafico") {
                    TextField("Nome (es. Obiettivi 2026, Progetto App)", text: $chartTitle)
                }
                
                Section("Obiettivo Centrale (Core Dream)") {
                    TextField("L'obiettivo principale che vuoi raggiungere", text: $coreGoal)
                        .font(.body.weight(.medium))
                }
                
                Section("Motivazione & Perché") {
                    TextField("Perché è importante per te raggiungere questo traguardo?", text: $coreGoalDescription, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("Scadenza / Orizzonte") {
                    Toggle("Imposta data target", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Data obiettivo", selection: $targetDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Personalizza Mandala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        if var updated = chart {
                            updated.title = chartTitle.isEmpty ? "Mio Mandala Chart" : chartTitle
                            updated.coreGoal = coreGoal.isEmpty ? "Obiettivo Primario" : coreGoal
                            updated.coreGoalDescription = coreGoalDescription.isEmpty ? nil : coreGoalDescription
                            updated.targetDate = hasTargetDate ? targetDate : nil
                            mandalaManager.updateChart(updated)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let c = chart {
                    chartTitle = c.title
                    coreGoal = c.coreGoal
                    coreGoalDescription = c.coreGoalDescription ?? ""
                    if let td = c.targetDate {
                        hasTargetDate = true
                        targetDate = td
                    }
                }
            }
        }
    }
}
