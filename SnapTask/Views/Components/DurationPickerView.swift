import SwiftUI

struct DurationPickerView: View {
    @Binding var duration: TimeInterval
    @Environment(\.dismiss) private var dismiss
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("how_long_did_it_take".localized)
                    .font(.title2.bold())
                    .padding(.top)
                
                HStack(spacing: 20) {
                    // Hours picker
                    VStack {
                        Text("hours".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Hours", selection: $hours) {
                            ForEach(0...23, id: \.self) { hour in
                                Text("\(hour)")
                                    .font(.title2)
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    
                    Text(":")
                        .font(.title.bold())
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    
                    // Minutes picker
                    VStack {
                        Text("minutes".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0...59, id: \.self) { minute in
                                Text(String(format: "%02d", minute))
                                    .font(.title2)
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("actual_duration".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        duration = TimeInterval(hours * 3600 + minutes * 60)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(hours == 0 && minutes == 0)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        let totalMinutes = Int(duration / 60)
        hours = totalMinutes / 60
        minutes = totalMinutes % 60
    }
}

#Preview {
    DurationPickerView(duration: .constant(3600))
}