import SwiftUI

struct ContextualRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with context info
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
                        // Recurrence options
                        RecurrenceOptionsCard(viewModel: viewModel)
                        
                        // End date section
                        EndDateSection(viewModel: viewModel)
                        
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
            return "choose_how_often_weekly_goal".localized
        case .month:
            return "choose_how_often_monthly_goal".localized
        case .year:
            return "choose_how_often_yearly_goal".localized
        case .longTerm:
            return "long_term_goals_no_recurrence".localized
        }
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

#Preview {
    ContextualRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}