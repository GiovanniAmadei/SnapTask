import Foundation

/// Tracked-time statistics ("timeTracking" and "taskMetadata" in UserDefaults) hold the time
/// tracked on this device. Each device uploads its own copy to iCloud and the statistics add up
/// the copies of all devices, so iPhone and Mac show the same hours. Copies never conflict:
/// every device only ever writes its own.
enum TimeTrackingStats {
    typealias Hours = [String: [String: Double]]          // ISO day → category/task key → hours
    typealias Metadata = [String: [String: String]]       // task key → name, color

    static let localKey = "timeTracking"
    static let metadataKey = "taskMetadata"
    private static let otherDevicesKey = "timeTracking_otherDevices"
    private static let otherMetadataKey = "taskMetadata_otherDevices"
    private static let deviceIdKey = "stats_device_id"

    /// Stable id of this install (kept in backups, so a restored device replaces its own copy).
    static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: deviceIdKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIdKey)
        return id
    }

    static var local: Hours {
        UserDefaults.standard.dictionary(forKey: localKey) as? Hours ?? [:]
    }

    static var localMetadata: Metadata {
        UserDefaults.standard.dictionary(forKey: metadataKey) as? Metadata ?? [:]
    }

    /// This device's hours plus every other device's.
    static func combined() -> Hours {
        var result = local
        for (_, hours) in otherDevices() {
            for (day, values) in hours {
                for (key, value) in values {
                    result[day, default: [:]][key, default: 0] += value
                }
            }
        }
        return result
    }

    static func combinedMetadata() -> Metadata {
        var result: Metadata = [:]
        for (_, metadata) in otherDevicesMetadata() {
            result.merge(metadata) { current, _ in current }
        }
        result.merge(localMetadata) { _, own in own }
        return result
    }

    /// Stores another device's copy (the own copy coming back from iCloud is ignored).
    static func applyRemote(deviceId remoteId: String, hours: Hours, metadata: Metadata) {
        guard remoteId != deviceId else { return }
        var devices = otherDevices()
        var metas = otherDevicesMetadata()
        devices[remoteId] = hours
        metas[remoteId] = metadata
        if let data = try? JSONSerialization.data(withJSONObject: devices) {
            UserDefaults.standard.set(data, forKey: otherDevicesKey)
        }
        if let data = try? JSONSerialization.data(withJSONObject: metas) {
            UserDefaults.standard.set(data, forKey: otherMetadataKey)
        }
    }

    private static func otherDevices() -> [String: Hours] {
        guard let data = UserDefaults.standard.data(forKey: otherDevicesKey) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Hours] ?? [:]
    }

    private static func otherDevicesMetadata() -> [String: Metadata] {
        guard let data = UserDefaults.standard.data(forKey: otherMetadataKey) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Metadata] ?? [:]
    }
}
