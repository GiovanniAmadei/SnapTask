import SwiftUI

struct ContextualRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: viewModel.selectedTimeScope.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(viewModel.selectedTimeScope.color))
                        
                        Text("recurrence_for".localized + " " + viewModel.selectedTimeScope.displayName)
                            .font(.headline)
                            .themedPrimaryText()
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Text(contextualDescription)
                        .font(.subheadline)
                        .themedSecondaryText()
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 16) {
                        RecurrenceSummaryCard(viewModel: viewModel)
                        
                        switch viewModel.selectedTimeScope {
                        case .today:
                            RecurrenceOptionsCard(viewModel: viewModel)
                            
                        case .week:
                            WeekRecurrenceSettingsCard(viewModel: viewModel)
                            
                        case .month:
                            MonthRecurrenceSettingsCard(viewModel: viewModel)
                            
                        case .year:
                            YearRecurrenceSettingsCard(viewModel: viewModel)
                            
                        case .longTerm:
                            LongTermInfoCard()
                        case .all:
                            RecurrenceOptionsCard(viewModel: viewModel)
                        }
                        
                        if viewModel.selectedTimeScope != .longTerm {
                            EndDateSection(viewModel: viewModel)
                        }
                        
                        Spacer()
                            .frame(height: 50)
                    }
                    .padding(.top, 16)
                }
            }
            .themedBackground()
            .navigationTitle("recurrence_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .themedPrimary()
                }
            }
        }
    }
    
    private var contextualDescription: String {
        switch viewModel.selectedTimeScope {
        case .today:
            return "choose_how_often_daily_task".localized
        case .week:
            return "Configura una ricorrenza a livello di settimana (senza giorni specifici)."
        case .month:
            return "Configura una ricorrenza a livello di mese."
        case .year:
            return "Configura una ricorrenza a livello di anno."
        case .longTerm:
            return "long_term_goals_no_recurrence".localized
        case .all:
            return "choose_how_often_daily_task".localized
        }
    }
}

struct RecurrenceSummaryCard: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Si ripete")
                .font(.headline)
                .themedPrimaryText()
            Text(viewModel.contextualRecurrenceSummary)
                .font(.subheadline)
                .foregroundColor(theme.primaryColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct RecurrenceOptionsCard: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("recurrence_options".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(viewModel.availableContextualRecurrenceTypes, id: \.self) { recurrenceType in
                    Button(action: {
                        viewModel.contextualRecurrenceType = recurrenceType
                    }) {
                        HStack {
                            Text(recurrenceType.localizedString)
                                .font(.subheadline)
                                .themedPrimaryText()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if viewModel.contextualRecurrenceType == recurrenceType {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.primaryColor)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 16))
                                    .themedSecondaryText()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.contextualRecurrenceType == recurrenceType ?
                                      theme.primaryColor.opacity(0.1) :
                                      Color.clear)
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct WeekRecurrenceSettingsCard: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ricorrenza settimanale")
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                SegmentPill(
                    title: "Ogni N settimane",
                    selected: viewModel.weekRecurrenceMode == .everyNWeeks
                ) { viewModel.weekRecurrenceMode = .everyNWeeks }
                SegmentPill(
                    title: "Settimane del mese",
                    selected: viewModel.weekRecurrenceMode == .specificWeeksOfMonth
                ) { viewModel.weekRecurrenceMode = .specificWeeksOfMonth }
                SegmentPill(
                    title: "Pattern (modulo)",
                    selected: viewModel.weekRecurrenceMode == .moduloPattern
                ) { viewModel.weekRecurrenceMode = .moduloPattern }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.primaryColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.primaryColor.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            switch viewModel.weekRecurrenceMode {
            case .everyNWeeks:
                VStack(spacing: 12) {
                    HStack {
                        Text("Ripeti ogni")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.weekInterval, in: 1...12) {
                            Text("\(viewModel.weekInterval) \(viewModel.weekInterval == 1 ? "settimana" : "settimane")")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 200)
                    }
                    .padding(.horizontal)
                    
                    Text("Ancorato alla settimana di inizio attività.")
                        .font(.caption)
                        .themedSecondaryText()
                        .padding(.horizontal)
                }
                
            case .specificWeeksOfMonth:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Seleziona settimane del mese")
                        .font(.subheadline)
                        .themedSecondaryText()
                        .padding(.horizontal)
                    
                    WrapOrdinalWeeks(
                        selection: $viewModel.weekSelectedOrdinals,
                        ordinals: [1, 2, 3, 4, 5, -1]
                    )
                    .padding(.horizontal)
                }
                
            case .moduloPattern:
                VStack(spacing: 12) {
                    HStack {
                        Text("Ogni k-esima settimana (k ≥ 2)")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.weekModuloK, in: 2...12) {
                            Text("k = \(viewModel.weekModuloK)")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 180)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Offset")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.weekModuloOffset, in: 0...(max(0, viewModel.weekModuloK - 1))) {
                            Text("\(viewModel.weekModuloOffset + 1)")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 180)
                    }
                    .padding(.horizontal)
                    
                    if viewModel.weekModuloK == 2 {
                        Text(viewModel.weekModuloOffset == 0 ? "Settimane pari" : "Settimane dispari")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                            .padding(.horizontal)
                    } else {
                        Text("Le settimane selezionate soddisfano: (settimana − ancoraggio) % k = offset")
                            .font(.caption)
                            .themedSecondaryText()
                            .padding(.horizontal)
                    }
                }
                .onChange(of: viewModel.weekModuloK) { _, newValue in
                    if viewModel.weekModuloOffset >= newValue {
                        viewModel.weekModuloOffset = max(0, newValue - 1)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct MonthRecurrenceSettingsCard: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    private let months = Calendar.current.monthSymbols.enumerated().map { ($0.offset + 1, $0.element.capitalized) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ricorrenza mensile")
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                SegmentPill(
                    title: "Ogni N mesi",
                    selected: viewModel.monthRecurrenceMode == .everyNMonths
                ) { viewModel.monthRecurrenceMode = .everyNMonths }
                SegmentPill(
                    title: "Mesi specifici",
                    selected: viewModel.monthRecurrenceMode == .specificMonths
                ) { viewModel.monthRecurrenceMode = .specificMonths }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.primaryColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.primaryColor.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            switch viewModel.monthRecurrenceMode {
            case .everyNMonths:
                VStack(spacing: 12) {
                    HStack {
                        Text("Ripeti ogni")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.monthInterval, in: 1...12) {
                            Text("\(viewModel.monthInterval) \(viewModel.monthInterval == 1 ? "mese" : "mesi")")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 200)
                    }
                    .padding(.horizontal)
                    
                    Text("Ancorato al mese di inizio attività.")
                        .font(.caption)
                        .themedSecondaryText()
                        .padding(.horizontal)
                }
                
            case .specificMonths:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seleziona mesi")
                        .font(.subheadline)
                        .themedSecondaryText()
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(months, id: \.0) { month in
                            let isSelected = viewModel.monthSelectedMonths.contains(month.0)
                            Button {
                                if isSelected {
                                    viewModel.monthSelectedMonths.remove(month.0)
                                } else {
                                    viewModel.monthSelectedMonths.insert(month.0)
                                }
                            } label: {
                                HStack {
                                    Text(month.1)
                                        .font(.subheadline)
                                        .foregroundColor(isSelected ? theme.backgroundColor : theme.textColor)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? theme.primaryColor : theme.backgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(isSelected ? theme.primaryColor.opacity(0.3) : theme.borderColor, lineWidth: isSelected ? 2 : 1)
                                        )
                                )
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct YearRecurrenceSettingsCard: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ricorrenza annuale")
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                SegmentPill(
                    title: "Ogni N anni",
                    selected: viewModel.yearRecurrenceMode == .everyNYears
                ) { viewModel.yearRecurrenceMode = .everyNYears }
                SegmentPill(
                    title: "Pattern (modulo)",
                    selected: viewModel.yearRecurrenceMode == .moduloPattern
                ) { viewModel.yearRecurrenceMode = .moduloPattern }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.primaryColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.primaryColor.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            switch viewModel.yearRecurrenceMode {
            case .everyNYears:
                VStack(spacing: 12) {
                    HStack {
                        Text("Ripeti ogni")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.yearInterval, in: 1...10) {
                            Text("\(viewModel.yearInterval) \(viewModel.yearInterval == 1 ? "anno" : "anni")")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 200)
                    }
                    .padding(.horizontal)
                    
                    Text("Ancorato all'anno di inizio attività.")
                        .font(.caption)
                        .themedSecondaryText()
                        .padding(.horizontal)
                }
                
            case .moduloPattern:
                VStack(spacing: 12) {
                    HStack {
                        Text("Ogni k anni (k ≥ 2)")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.yearModuloK, in: 2...10) {
                            Text("k = \(viewModel.yearModuloK)")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 180)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Offset")
                            .themedPrimaryText()
                        Spacer()
                        Stepper(value: $viewModel.yearModuloOffset, in: 0...(max(0, viewModel.yearModuloK - 1))) {
                            Text("\(viewModel.yearModuloOffset + 1)")
                                .foregroundColor(theme.primaryColor)
                        }
                        .frame(width: 180)
                    }
                    .padding(.horizontal)
                    
                    if viewModel.yearModuloK == 2 {
                        Text(viewModel.yearModuloOffset == 0 ? "Anni pari" : "Anni dispari")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                            .padding(.horizontal)
                    } else {
                        Text("Gli anni selezionati soddisfano: (anno − ancoraggio) % k = offset")
                            .font(.caption)
                            .themedSecondaryText()
                            .padding(.horizontal)
                    }
                }
                .onChange(of: viewModel.yearModuloK) { _, newValue in
                    if viewModel.yearModuloOffset >= newValue {
                        viewModel.yearModuloOffset = max(0, newValue - 1)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct LongTermInfoCard: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Obiettivi a lungo termine")
                .font(.headline)
                .themedPrimaryText()
            Text("Le attività a lungo termine non hanno impostazioni di ricorrenza.")
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct SegmentPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selected ? theme.backgroundColor : theme.primaryColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? theme.primaryColor : Color.clear)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct WrapOrdinalWeeks: View {
    @Binding var selection: Set<Int>
    let ordinals: [Int]
    @Environment(\.theme) private var theme
    
    private func label(for value: Int) -> String {
        switch value {
        case 1: return "1ª"
        case 2: return "2ª"
        case 3: return "3ª"
        case 4: return "4ª"
        case 5: return "5ª"
        case -1: return "Ultima"
        default: return "\(value)ª"
        }
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(ordinals, id: \.self) { o in
                let isSelected = selection.contains(o)
                Button {
                    if isSelected {
                        selection.remove(o)
                    } else {
                        selection.insert(o)
                    }
                } label: {
                    HStack {
                        Text(label(for: o))
                            .font(.subheadline)
                            .foregroundColor(isSelected ? theme.backgroundColor : theme.textColor)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? theme.primaryColor : theme.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? theme.primaryColor.opacity(0.3) : theme.borderColor, lineWidth: isSelected ? 2 : 1)
                            )
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}

#Preview {
    ContextualRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}