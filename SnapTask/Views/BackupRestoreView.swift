import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        List {
            Section(header: Text("backup".localized)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("export_all_data".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        createBackup()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                            Text("export_backup".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("restore".localized)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("restore_from_backup".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("will_overwrite_data".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                    
                    Button(action: {
                        isImporting = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("import_backup".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("backup_restore".localized)
        .overlay(
            Group {
                if isProcessing {
                    ProgressView("processing".localized)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
            }
        )
        .alert("operation_completed".localized, isPresented: $showingSuccessAlert) {
            Button("done".localized) { }
        } message: {
            Text("operation_success".localized)
        }
        .alert("error".localized, isPresented: $showingErrorAlert) {
            Button("done".localized) { }
        } message: {
            Text(errorMessage)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .onChange(of: isExporting) { _, newValue in
            if !newValue {
                // Quando l'attività di esportazione termina
                isProcessing = false
            }
        }
    }
    
    private func createBackup() {
        isProcessing = true
        
        Task {
            do {
                let backupURL = try await BackupService.shared.createAndShareBackup()
                
                // Trova la view controller per presentare l'activity view
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    await BackupService.shared.shareBackup(from: rootViewController)
                    isProcessing = false
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        isProcessing = true
        
        switch result {
        case .success(let urls):
            guard let selectedFile = urls.first else {
                handleError(BackupService.BackupError.fileReadError)
                return
            }
            
            // Verifica che il file sia valido
            guard BackupService.shared.isValidBackupFile(selectedFile) else {
                handleError(BackupService.BackupError.invalidBackupFile)
                return
            }
            
            // Effettua il ripristino
            do {
                try BackupService.shared.restoreFromBackup(fileURL: selectedFile)
                DispatchQueue.main.async {
                    isProcessing = false
                    showingSuccessAlert = true
                }
            } catch {
                handleError(error)
            }
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            isProcessing = false
            
            if let backupError = error as? BackupService.BackupError {
                errorMessage = backupError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            showingErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}