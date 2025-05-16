import Foundation
import CloudKit

/// Classe proxy per gestire in modo sicuro tutte le interazioni CloudKit
class CloudKitSyncProxy {
    static let shared = CloudKitSyncProxy()
    
    /// Flag che indica se la sincronizzazione CloudKit è stata disabilitata a causa di errori
    private var cloudKitDisabled = false
    
    private init() {}
    
    /// Inizializza CloudKit in modo sicuro
    func setupCloudKit() {
        guard !cloudKitDisabled else {
            print("CloudKit è stato disabilitato a causa di errori precedenti")
            return
        }
        
        // Wrappa tutto in un blocco do-catch per evitare errori non gestiti
        do {
            CloudKitService.shared.setup()
        } catch {
            handleError(error, operation: "CloudKit setup")
        }
    }
    
    /// Sincronizza le attività in modo sicuro
    func syncTasks() {
        guard !cloudKitDisabled else {
            print("CloudKit è stato disabilitato a causa di errori precedenti")
            return
        }
        
        // Wrappa tutto in un blocco do-catch per evitare errori non gestiti
        do {
            CloudKitService.shared.syncTasksSafely()
        } catch {
            handleError(error, operation: "Task synchronization")
        }
    }
    
    /// Salva un'attività in modo sicuro
    func saveTask(_ task: TodoTask) {
        guard !cloudKitDisabled else {
            print("CloudKit è stato disabilitato a causa di errori precedenti")
            return
        }
        
        // Wrappa tutto in un blocco do-catch per evitare errori non gestiti
        do {
            CloudKitService.shared.saveTask(task)
        } catch {
            handleError(error, operation: "Task saving")
        }
    }
    
    /// Elimina un'attività in modo sicuro
    func deleteTask(_ task: TodoTask) {
        guard !cloudKitDisabled else {
            print("CloudKit è stato disabilitato a causa di errori precedenti")
            return
        }
        
        // Wrappa tutto in un blocco do-catch per evitare errori non gestiti
        do {
            CloudKitService.shared.deleteTask(task)
        } catch {
            handleError(error, operation: "Task deletion")
        }
    }
    
    /// Gestisce gli errori CloudKit in modo unificato
    private func handleError(_ error: Error, operation: String) {
        print("ERRORE CloudKit durante \(operation): \(error.localizedDescription)")
        
        // In caso di errori persistenti, disabilitiamo CloudKit
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated, .permissionFailure, .quotaExceeded, .serverRejectedRequest:
                cloudKitDisabled = true
                print("CloudKit disabilitato a causa di un errore critico: \(ckError.localizedDescription)")
            default:
                break
            }
        }
    }
} 