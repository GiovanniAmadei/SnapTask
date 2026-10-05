import Foundation

extension TodoTask {
    /// Combines the completions of two copies of the same task, occurrence by occurrence: for
    /// each day the most recent change wins, wherever it was made. Taking the whole list from
    /// the copy edited last lost the days completed on the other device in the meantime.
    static func mergedCompletions(local: TodoTask, remote: TodoTask, preferRemote: Bool)
        -> (completions: [Date: TaskCompletion], completionDates: [Date]) {
        var merged = local.completions
        for (key, remoteCompletion) in remote.completions {
            guard let localCompletion = local.completions[key] else {
                merged[key] = remoteCompletion
                continue
            }
            let localTime = localCompletion.modifiedAt ?? .distantPast
            let remoteTime = remoteCompletion.modifiedAt ?? .distantPast
            if remoteTime > localTime || (remoteTime == localTime && preferRemote) {
                merged[key] = remoteCompletion
            }
        }
        
        let completed = merged.filter { $0.value.isCompleted }.map(\.key)
        // Days listed without any completion entry come from old versions: keep them.
        let legacy = (local.completionDates + remote.completionDates).filter { merged[$0] == nil }
        return (merged, Array(Set(completed + legacy)).sorted())
    }
}
