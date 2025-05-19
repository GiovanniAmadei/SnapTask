import Foundation
import UIKit

/// Struttura per il backup dei dati dell'app
struct AppBackup: Codable {
    let version: String
    let creationDate: Date
    let tasks: [TodoTask]
    let categories: [Category]
    
    init(tasks: [TodoTask], categories: [Category]) {
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.creationDate = Date()
        self.tasks = tasks
        self.categories = categories
    }
}

/// Service per gestire backup e restore
class BackupService {
    static let shared = BackupService()
    
    enum BackupError: Error {
        case encodingError
        case decodingError
        case fileWriteError
        case fileReadError
        case invalidBackupFile
        case fileOperationError
        
        var localizedDescription: String {
            switch self {
            case .encodingError:
                return "Errore durante la codifica dei dati di backup"
            case .decodingError:
                return "Errore durante la decodifica del file di backup"
            case .fileWriteError:
                return "Impossibile scrivere il file di backup"
            case .fileReadError:
                return "Impossibile leggere il file di backup"
            case .invalidBackupFile:
                return "Il file di backup non è valido o è danneggiato"
            case .fileOperationError:
                return "Errore durante l'operazione sui file"
            }
        }
    }
    
    /// Nome del file di backup
    private let backupFileName = "snaptask_backup.json"
    
    /// Directory per i backup temporanei
    private var tempBackupDirectory: URL {
        FileManager.default.temporaryDirectory
    }
    
    /// URL per il file di backup temporaneo
    private var tempBackupURL: URL {
        tempBackupDirectory.appendingPathComponent(backupFileName)
    }
    
    // MARK: - Backup
    
    /// Crea un backup e lo condivide come file
    func createAndShareBackup() async throws -> URL {
        // Ottieni i dati
        let tasks = TaskManager.shared.tasks
        let categories = CategoryManager.shared.categories
        
        // Crea oggetto backup
        let backup = AppBackup(tasks: tasks, categories: categories)
        
        // Converti in JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(backup) else {
            Log("Errore nella codifica del backup", level: .error, subsystem: "data")
            throw BackupError.encodingError
        }
        
        // Scrivi su file temporaneo
        do {
            try data.write(to: tempBackupURL)
            Log("Backup creato con successo: \(tempBackupURL.path)", level: .info, subsystem: "data")
            return tempBackupURL
        } catch {
            Log("Errore nella scrittura del file di backup: \(error)", level: .error, subsystem: "data")
            throw BackupError.fileWriteError
        }
    }
    
    /// Condividi un file di backup usando UIActivityViewController
    func shareBackup(from viewController: UIViewController) async {
        do {
            let backupURL = try await createAndShareBackup()
            
            DispatchQueue.main.async {
                let activityViewController = UIActivityViewController(
                    activityItems: [backupURL],
                    applicationActivities: nil
                )
                
                // Previeni crash su iPad
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = viewController.view
                    popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, 
                                                        y: viewController.view.bounds.midY, 
                                                        width: 0, 
                                                        height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                viewController.present(activityViewController, animated: true)
            }
        } catch {
            Log("Errore nella condivisione del backup: \(error)", level: .error, subsystem: "data")
        }
    }
    
    // MARK: - Restore
    
    /// Ripristina i dati da un file di backup
    func restoreFromBackup(fileURL: URL) throws {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backup = try decoder.decode(AppBackup.self, from: data)
            
            // Ripristina categorie
            CategoryManager.shared.importCategories(backup.categories)
            
            // Ripristina attività
            TaskManager.shared.updateAllTasks(backup.tasks)
            
            Log("Dati ripristinati con successo dal backup", level: .info, subsystem: "data")
        } catch {
            Log("Errore nel ripristino del backup: \(error)", level: .error, subsystem: "data")
            throw BackupError.decodingError
        }
    }
    
    /// Verifica se un file è un backup valido
    func isValidBackupFile(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "json" else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Tenta di decodificare per verificare che sia un file valido
            _ = try decoder.decode(AppBackup.self, from: data)
            return true
        } catch {
            return false
        }
    }
} 