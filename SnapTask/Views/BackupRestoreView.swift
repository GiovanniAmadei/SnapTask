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
            Section(header: Text("Backup")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Esporta tutti i tuoi dati in un file che puoi salvare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        createBackup()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                            Text("Esporta Backup")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Ripristino")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ripristina i tuoi dati da un file di backup precedentemente salvato")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("⚠️ Questo sovrascriverà tutti i dati attuali")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                    
                    Button(action: {
                        isImporting = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Importa Backup")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Backup e Ripristino")
        .overlay(
            Group {
                if isProcessing {
                    ProgressView("Elaborazione in corso...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
            }
        )
        .alert("Operazione completata", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("L'operazione è stata completata con successo.")
        }
        .alert("Errore", isPresented: $showingErrorAlert) {
            Button("OK") { }
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