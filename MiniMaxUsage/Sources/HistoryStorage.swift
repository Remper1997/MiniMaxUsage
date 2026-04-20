import Foundation

class HistoryStorage {
    static let shared = HistoryStorage()

    private let fileManager = FileManager.default
    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MiniMaxUsage", isDirectory: true)
        return appDir.appendingPathComponent("usage_history.json")
    }

    private let schemaVersionKey = "historySchemaVersion"
    private let currentSchemaVersion = 1
    private let maxRetentionDays = 30

    private init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        let dir = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    func saveSnapshot(_ snapshot: UsageSnapshot) {
        var snapshots = loadSnapshots()
        snapshots.append(snapshot)
        cleanupOldSnapshots(snapshots: &snapshots)
        saveSnapshots(snapshots)
    }

    func loadSnapshots(forDays days: Int = 30) -> [UsageSnapshot] {
        let snapshots = loadSnapshots()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return snapshots.filter { $0.timestamp > cutoff }
    }

    func loadSnapshots7d() -> [UsageSnapshot] {
        return loadSnapshots(forDays: 7)
    }

    func loadSnapshots30d() -> [UsageSnapshot] {
        return loadSnapshots(forDays: 30)
    }

    func clearAllHistory() {
        try? fileManager.removeItem(at: storageURL)
    }

    // MARK: - Private Helpers

    private func loadSnapshots() -> [UsageSnapshot] {
        guard fileManager.fileExists(atPath: storageURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([UsageSnapshot].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
            return []
        }
    }

    private func saveSnapshots(_ snapshots: [UsageSnapshot]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snapshots)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func cleanupOldSnapshots(snapshots: inout [UsageSnapshot]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date())!
        snapshots.removeAll { $0.timestamp < cutoff }
    }
}