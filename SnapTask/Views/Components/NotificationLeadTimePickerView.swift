import SwiftUI

struct NotificationLeadTimePickerView: View {
    @Binding var leadMinutes: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("custom_notification_title".localized)
                    .font(.title2.bold())
                    .padding(.top)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("hours".localized.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("hours".localized, selection: $hours) {
                            ForEach(0...23, id: \.self) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    
                    Text(":")
                        .font(.title.bold())
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    
                    VStack {
                        Text("minutes".localized.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("minutes".localized, selection: $minutes) {
                            ForEach(0...59, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }
                .padding(.horizontal)
                
                Button {
                    hours = 0
                    minutes = 0
                } label: {
                    HStack {
                        Image(systemName: "bell")
                            .font(.system(size: 16))
                        Text("at_exact_time".localized)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.08))
                    )
                }
                
                Spacer()
            }
            .navigationTitle("custom_notification_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String.save) {
                        leadMinutes = hours * 60 + minutes
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            hours = max(0, leadMinutes) / 60
            minutes = max(0, leadMinutes) % 60
        }
    }
}