import SwiftUI

struct EnhancedRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showingOrdinalPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("recurrence_type".localized)
                        .font(.headline)
                        .themedPrimaryText()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 2) {
                        RecurrenceTypeButton(type: .daily, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .daily
                        }
                        RecurrenceTypeButton(type: .weekly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .weekly
                        }
                        RecurrenceTypeButton(type: .monthly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .monthly
                        }
                        RecurrenceTypeButton(type: .yearly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .yearly
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.primaryColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(theme.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch viewModel.recurrenceType {
                        case .daily:
                            DailyRecurrenceView(viewModel: viewModel)
                            
                        case .weekly:
                            WeeklyRecurrenceView(viewModel: viewModel)
                            
                        case .monthly:
                            MonthlyRecurrenceView(viewModel: viewModel, showingOrdinalPicker: $showingOrdinalPicker)
                            
                        case .yearly:
                            YearlyRecurrenceView(viewModel: viewModel)
                        }
                        
                        EndDateSection(viewModel: viewModel)
                        
                        Spacer()
                            .frame(height: 50)
                    }
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
            .sheet(isPresented: $showingOrdinalPicker) {
                OrdinalPatternPickerView(selectedPatterns: $viewModel.selectedOrdinalPatterns)
            }
        }
    }
}

struct RecurrenceTypeButton: View {
    let type: RecurrenceType
    let selectedType: RecurrenceType
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            Text(type.localizedString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selectedType == type ? theme.backgroundColor : theme.primaryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType == type ? theme.primaryColor : Color.clear)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct DailyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("daily_recurrence".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("repeat_every".localized)
                        .themedPrimaryText()
                    Spacer()
                    Stepper(value: $viewModel.dayInterval, in: 1...60) {
                        let unit = viewModel.dayInterval == 1 ? "day_unit".localized : "days_unit".localized
                        Text("\(viewModel.dayInterval) \(unit)")
                            .foregroundColor(theme.primaryColor)
                    }
                    .frame(width: 200)
                }
                .padding(.horizontal)
                
                Text("anchored_to_task_start_date".localized)
                    .font(.caption)
                    .themedSecondaryText()
                    .padding(.horizontal)
                
                Text(viewModel.dayInterval == 1 ? "repeats_every_day".localized : String(format: "repeats_every_n_days".localized, viewModel.dayInterval))
                    .font(.caption)
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct WeeklyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("weekly_recurrence".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                WeekdayRow(weekday: (2, "monday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (3, "tuesday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (4, "wednesday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (5, "thursday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (6, "friday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (7, "saturday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (1, "sunday".localized), viewModel: viewModel)
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

struct WeekdayRow: View {
    let weekday: (Int, String)
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            Text(weekday.1)
                .font(.subheadline)
                .themedPrimaryText()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.selectedDays.contains(weekday.0) {
                DatePicker("", selection: Binding(
                    get: {
                        viewModel.weeklyTimes[weekday.0] ?? viewModel.startDate
                    },
                    set: { newTime in
                        viewModel.weeklyTimes[weekday.0] = newTime
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .accentColor(theme.primaryColor)
                .frame(width: 80)
            }
            
            Toggle("", isOn: Binding(
                get: { viewModel.selectedDays.contains(weekday.0) },
                set: { isSelected in
                    if isSelected {
                        viewModel.selectedDays.insert(weekday.0)
                    } else {
                        viewModel.selectedDays.remove(weekday.0)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
            .frame(width: 50)
        }
        .padding(.horizontal)
    }
}

struct MonthlyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Binding var showingOrdinalPicker: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("monthly_recurrence".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                MonthlyTypeButton(type: .days, selectedType: viewModel.monthlySelectionType) {
                    viewModel.monthlySelectionType = .days
                }
                MonthlyTypeButton(type: .ordinal, selectedType: viewModel.monthlySelectionType) {
                    viewModel.monthlySelectionType = .ordinal
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            if viewModel.monthlySelectionType == .days {
                MonthlyDaysView(viewModel: viewModel)
            } else {
                MonthlyPatternsView(viewModel: viewModel, showingOrdinalPicker: $showingOrdinalPicker)
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

struct MonthlyTypeButton: View {
    let type: MonthlySelectionType
    let selectedType: MonthlySelectionType
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            Text(type.localizedString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedType == type ? theme.backgroundColor : theme.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType == type ? theme.primaryColor : Color.clear)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct MonthlyDaysView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("select_days_of_month".localized)
                .font(.subheadline)
                .themedSecondaryText()
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Button(action: {
                        if viewModel.selectedMonthlyDays.contains(day) {
                            viewModel.selectedMonthlyDays.remove(day)
                        } else {
                            viewModel.selectedMonthlyDays.insert(day)
                        }
                    }) {
                        Text("\(day)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(viewModel.selectedMonthlyDays.contains(day) ? theme.backgroundColor : theme.textColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(viewModel.selectedMonthlyDays.contains(day) ? theme.primaryColor : theme.surfaceColor)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(theme.borderColor, lineWidth: viewModel.selectedMonthlyDays.contains(day) ? 0 : 1)
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

struct MonthlyPatternsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Binding var showingOrdinalPicker: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("select_patterns_ordinal".localized)
                .font(.subheadline)
                .themedSecondaryText()
                .padding(.horizontal)
            
            Button(action: {
                showingOrdinalPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("monthly_patterns".localized)
                            .font(.subheadline)
                            .themedPrimaryText()
                        
                        if viewModel.selectedOrdinalPatterns.isEmpty {
                            Text("none_selected".localized)
                                .font(.caption)
                                .themedSecondaryText()
                        } else {
                            Text(viewModel.selectedOrdinalPatterns.map { $0.displayText }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(theme.primaryColor)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .themedSecondaryText()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(theme.borderColor, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal)
        }
    }
}

struct YearlyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("yearly_recurrence".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            Text("select_day_of_year".localized)
                .font(.subheadline)
                .themedSecondaryText()
                .padding(.horizontal)
            
            HStack {
                Text("repeat_on".localized)
                    .font(.subheadline)
                    .themedPrimaryText()
                Spacer()
                DatePicker("", selection: $viewModel.yearlyDate, displayedComponents: [.date])
                    .labelsHidden()
                    .accentColor(theme.primaryColor)
            }
            .padding(.horizontal)
            
            Text("task_repeat_yearly_on".localized + " \(formattedYearlyDate)")
                .font(.caption)
                .foregroundColor(theme.primaryColor)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private var formattedYearlyDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: viewModel.yearlyDate)
    }
}

struct EndDateSection: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("end_date".localized)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("set_end_date".localized)
                        .font(.subheadline)
                        .themedPrimaryText()
                    Spacer()
                    Toggle("", isOn: $viewModel.hasRecurrenceEndDate)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
                }
                .padding(.horizontal)
                
                if viewModel.hasRecurrenceEndDate {
                    HStack {
                        Text("end_date".localized)
                            .font(.subheadline)
                            .themedPrimaryText()
                        Spacer()
                        DatePicker("", selection: $viewModel.recurrenceEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .accentColor(theme.primaryColor)
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

#Preview {
    EnhancedRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}