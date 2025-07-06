import SwiftUI

struct TimelineOrganizationView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Organization Options
                List {
                    Section("organization_mode_title".localized) {
                        ForEach(TimelineOrganization.allCases, id: \.self) { organization in
                            HStack {
                                Image(systemName: organization.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(.pink)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(organization.displayName)
                                        .font(.body)
                                    
                                    if organization != .none {
                                        Text(organizationDescription(for: organization))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if viewModel.organization == organization {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.pink)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.organization = organization
                            }
                        }
                    }
                    
                    // Time Sort Order (only when organizing by time)
                    if viewModel.organization == .time {
                        Section("time_sort_order_title".localized) {
                            ForEach(TimeSortOrder.allCases, id: \.self) { sortOrder in
                                HStack {
                                    Image(systemName: sortOrder == .ascending ? "arrow.up" : "arrow.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)
                                    
                                    Text(sortOrder.displayName)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    if viewModel.timeSortOrder == sortOrder {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.pink)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.timeSortOrder = sortOrder
                                }
                            }
                        }
                    }
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
                        .foregroundColor(.pink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("organize_tasks".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
        case .none:
            return ""
        }
    }
}