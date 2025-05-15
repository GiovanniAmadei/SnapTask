import Foundation

extension TaskManager {
    // Esta función debe llamarse después de cada operación que modifique las tareas
    func synchronizeWithWatch() {
        WatchConnectivityManager.shared.updateWatchContext()
    }
} 