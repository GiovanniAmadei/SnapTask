import SwiftUI

struct CloudSyncStatusView: View {
    @ObservedObject var cloudKitService = CloudKitService.shared
    @State private var isShowingDetails = false
    
    var body: some View {
        VStack {
            HStack {
                if cloudKitService.isSyncing {
                    ProgressView()
                        .padding(.trailing, 5)
                } else if cloudKitService.syncError != nil {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                }
                
                Text(statusText)
                    .font(.footnote)
                
                Spacer()
                
                Button(action: {
                    CloudKitService.shared.syncTasks()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(cloudKitService.isSyncing)
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingDetails.toggle()
            }
            
            if isShowingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = cloudKitService.syncError {
                        Text("Errore di sincronizzazione:")
                            .font(.caption)
                            .bold()
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if let lastSync = cloudKitService.lastSyncDate {
                        Text("Ultima sincronizzazione: \(timeAgoString(from: lastSync))")
                            .font(.caption)
                    }
                    
                    Button("Forza sincronizzazione") {
                        CloudKitService.shared.syncTasks()
                    }
                    .padding(.top, 5)
                    .font(.footnote)
                    .disabled(cloudKitService.isSyncing)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: isShowingDetails)
            }
        }
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusText: String {
        if cloudKitService.isSyncing {
            return "Sincronizzazione in corso..."
        } else if let error = cloudKitService.syncError {
            let errorMessage = error.localizedDescription
            if errorMessage.count > 40 {
                return String(errorMessage.prefix(40)) + "..."
            }
            return errorMessage
        } else if let lastSync = cloudKitService.lastSyncDate {
            return "Sincronizzato \(timeAgoString(from: lastSync))"
        } else {
            return "In attesa di sincronizzazione"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    CloudSyncStatusView()
} 