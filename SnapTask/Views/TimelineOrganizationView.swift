import SwiftUI

struct TimelineOrganizationView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    private var availableOrganizations: [TimelineOrganization] {
        // Hide time-based organization for non-daily scopes
        if viewModel.selectedTimeScope == .today {
            return TimelineOrganization.allCases
        } else {
            return TimelineOrganization.allCases.filter { $0 != .time }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Organization Options
                ScrollView {
                    VStack(spacing: 16) {
                        // Organization Mode Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("organization_mode_title".localized)
                                .font(.system(size: 18, weight: .semibold))
                                .themedPrimaryText()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                ForEach(availableOrganizations, id: \.self) { organization in
                                    Button(action: {
                                        viewModel.organization = organization
                                    }) {
                                        HStack {
                                            Image(systemName: organization.icon)
                                                .font(.system(size: 16))
                                                .foregroundColor(theme.primaryColor)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(organization.displayName)
                                                    .font(.body)
                                                    .themedPrimaryText()
                                                
                                                if organization != .none {
                                                    Text(organizationDescription(for: organization))
                                                        .font(.caption)
                                                        .themedSecondaryText()
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if viewModel.organization == organization {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(theme.primaryColor)
                                            }
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.organization == organization ? theme.primaryColor.opacity(0.1) : theme.surfaceColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .strokeBorder(
                                                            viewModel.organization == organization ? theme.primaryColor : theme.borderColor,
                                                            lineWidth: viewModel.organization == organization ? 2 : 1
                                                        )
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.backgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(theme.borderColor, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        
                        // Time Sort Order (only when organizing by time and Today scope)
                        if viewModel.selectedTimeScope == .today && viewModel.organization == .time {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("time_sort_order_title".localized)
                                    .font(.system(size: 18, weight: .semibold))
                                    .themedPrimaryText()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 8) {
                                    ForEach(TimeSortOrder.allCases, id: \.self) { sortOrder in
                                        Button(action: {
                                            viewModel.timeSortOrder = sortOrder
                                        }) {
                                            HStack {
                                                Image(systemName: sortOrder == .ascending ? "arrow.up" : "arrow.down")
                                                    .font(.system(size: 14))
                                                    .themedSecondaryText()
                                                    .frame(width: 24)
                                                
                                                Text(sortOrder.displayName)
                                                    .font(.body)
                                                    .themedPrimaryText()
                                                
                                                Spacer()
                                                
                                                if viewModel.timeSortOrder == sortOrder {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(theme.primaryColor)
                                                }
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(viewModel.timeSortOrder == sortOrder ? theme.primaryColor.opacity(0.1) : theme.surfaceColor)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .strokeBorder(
                                                                viewModel.timeSortOrder == sortOrder ? theme.primaryColor : theme.borderColor,
                                                                lineWidth: viewModel.timeSortOrder == sortOrder ? 2 : 1
                                                            )
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(theme.backgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(theme.borderColor, lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.resetView()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("reset_to_default".localized)
                                }
                                .font(.headline)
                                .foregroundColor(theme.primaryColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.primaryColor.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(theme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .themedBackground()
            .navigationTitle("organize_tasks".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .themedSecondaryText()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .themedPrimary()
                }
            }
        }
    }
    
    private func organizationDescription(for organization: TimelineOrganization) -> String {
        switch organization {
        case .time:
            return "sort_by_time_description".localized
        case .category:
            return "group_by_category_description".localized
        case .priority:
            return "group_by_priority_description".localized
        case .eisenhower:
            return "group_by_urgency_importance_description".localized
        case .none:
            return ""
        }
    }
}