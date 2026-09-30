import Foundation
import Combine

/// Ordine scelto a mano (drag and drop) per una lista della vista predefinita.
struct TaskListOrder: Codable, Equatable {
    let listKey: String
    var taskIds: [UUID]
    var lastModified: Date
}

/// Ordine manuale dei task, uno per lista: giorno, settimana, mese, anno, lungo termine.
/// Sta su un record CloudKit separato dai task, così riordinare non modifica i task
/// e non entra in conflitto con le modifiche fatte su un altro dispositivo.
@MainActor
final class TaskOrderManager: ObservableObject {
    static let shared = TaskOrderManager()

    @Published private(set) var orders: [String: TaskListOrder] = [:]

    private let storageKey = "task_list_orders_v1"

    private init() {
        load()
    }

    // MARK: - List Keys

    /// Chiave stabile della lista, uguale su tutti i dispositivi. nil dove l'ordine non si può cambiare.
    static func listKey(scope: TaskTimeScope, date: Date, calendar: Calendar = .current) -> String? {
        let periodStart: Date
        switch scope {
        case .today:
            periodStart = calendar.startOfDay(for: date)
        case .week:
            periodStart = calendar.startOfWeek(for: date)
        case .month:
            periodStart = calendar.startOfMonth(for: date)
        case .year:
            periodStart = calendar.startOfYear(for: date)
        case .longTerm:
            return "longTerm"
        case .inbox:
            return "inbox"
        case .all:
            return nil
        }
        let c = calendar.dateComponents([.year, .month, .day], from: periodStart)
        return "\(scope.rawValue)-" + String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Sorting

    /// Applica l'ordine salvato per la lista. Se la lista non ne ha uno usa l'ultimo ordine
    /// scelto per lo stesso tipo di lista, così i task ricorrenti tengono la posizione nei giorni seguenti.
    /// I task mai spostati vanno in fondo, nell'ordine ricevuto (per orario).
    func sorted(_ tasks: [TodoTask], listKey: String) -> [TodoTask] {
        guard let order = orders[listKey] ?? latestOrder(sameKindAs: listKey) else { return tasks }

        var rank: [UUID: Int] = [:]
        for (position, id) in order.taskIds.enumerated() where rank[id] == nil {
            rank[id] = position
        }

        let placed = tasks
            .filter { rank[$0.id] != nil }
            .sorted { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
        let others = tasks.filter { rank[$0.id] == nil }
        return placed + others
    }

    private func latestOrder(sameKindAs listKey: String) -> TaskListOrder? {
        guard let dash = listKey.firstIndex(of: "-") else { return nil }
        let prefix = String(listKey[...dash])
        return orders.values
            .filter { $0.listKey.hasPrefix(prefix) }
            .max { $0.lastModified < $1.lastModified }
    }

    // MARK: - Updates

    func setOrder(_ taskIds: [UUID], listKey: String) {
        guard !taskIds.isEmpty else { return }
        let order = TaskListOrder(listKey: listKey, taskIds: taskIds, lastModified: Date())
        orders[listKey] = order
        save()
        CloudKitService.shared.saveTaskListOrder(order)
    }

    /// Ordini arrivati da CloudKit: per ogni lista vince la modifica più recente.
    func mergeRemote(_ remoteOrders: [TaskListOrder]) {
        var merged = orders
        var changed = false
        for remote in remoteOrders {
            if let local = merged[remote.listKey], local.lastModified >= remote.lastModified {
                continue
            }
            merged[remote.listKey] = remote
            changed = true
        }
        guard changed else { return }
        orders = merged
        save()
    }

    func removeAll() {
        orders = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([String: TaskListOrder].self, from: data) else { return }
        orders = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(orders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
