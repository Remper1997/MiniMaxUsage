import Foundation

enum QuotaType: Int {
    case fiveHour = 0
    case weekly = 1
    case daily = 2
}

class SettingsHelper {
    private static let quotaTypeKey = "quotaType"
    private static let showIndicatorKey = "showIndicator"
    private static let showPercentKey = "showPercent"
    private static let showRequestsKey = "showRequests"
    private static let showResetTimeKey = "showResetTime"
    private static let launchAtLoginKey = "launchAtLogin"
    private static let autoUpdateEnabledKey = "autoUpdateEnabled"
    private static let lastUpdateCheckKey = "lastUpdateCheck"

    // Daily tracking UserDefaults keys
    private static let dailyLastRecordedDateKey = "dailyLastRecordedDate"
    private static let dailyLastRecordedRemainingKey = "dailyLastRecordedRemaining"
    private static let dailyBudgetAtDayStartKey = "dailyBudgetAtDayStart"

    static var quotaType: QuotaType {
        get {
            let raw = UserDefaults.standard.integer(forKey: quotaTypeKey)
            return QuotaType(rawValue: raw) ?? .fiveHour
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: quotaTypeKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var showIndicator: Bool {
        get {
            if UserDefaults.standard.object(forKey: showIndicatorKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showIndicatorKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showIndicatorKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var showPercent: Bool {
        get {
            if UserDefaults.standard.object(forKey: showPercentKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showPercentKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showPercentKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var showRequests: Bool {
        get {
            return UserDefaults.standard.bool(forKey: showRequestsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showRequestsKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var showResetTime: Bool {
        get {
            if UserDefaults.standard.object(forKey: showResetTimeKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showResetTimeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showResetTimeKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var launchAtLogin: Bool {
        get {
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var autoUpdateEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoUpdateEnabledKey) == nil {
                return true  // Default to enabled
            }
            return UserDefaults.standard.bool(forKey: autoUpdateEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoUpdateEnabledKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    static var lastUpdateCheck: Date? {
        get {
            return UserDefaults.standard.object(forKey: lastUpdateCheckKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastUpdateCheckKey)
        }
    }

    static var lastUpdateCheckFormatted: String {
        guard let lastCheck = lastUpdateCheck else {
            return "Never"
        }
        let interval = Date().timeIntervalSince(lastCheck)
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    // MARK: - Daily Tracking

    // Last recorded date (midnight of that day)
    private static var dailyLastRecordedDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: dailyLastRecordedDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dailyLastRecordedDateKey)
        }
    }

    // Weekly remaining count at time of last daily reset
    private static var dailyLastRecordedRemaining: Int {
        get {
            return UserDefaults.standard.integer(forKey: dailyLastRecordedRemainingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dailyLastRecordedRemainingKey)
        }
    }

    // Daily budget calculated at the start of the day (fixed for the entire day)
    private static var dailyBudgetAtDayStart: Int {
        get {
            return UserDefaults.standard.integer(forKey: dailyBudgetAtDayStartKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dailyBudgetAtDayStartKey)
        }
    }

    // Computed daily tracking data
    struct DailyTrackingData {
        let todayUsage: Int        // Requests used today
        let dailyBudget: Int      // Calculated daily budget limit
        let daysRemaining: Int    // Days left in current period
    }

    // Call this on each API refresh to update daily tracking
    // Returns today's usage based on weekly remaining comparison
    // Budget is calculated once at start of day and stays fixed
    // Pass weeklyRemainsTime (in ms) for accurate days calculation
    static func updateDailyTracking(currentWeeklyRemaining: Int, weeklyRemainsTimeMs: Int) -> DailyTrackingData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate actual days remaining from weeklyRemainsTime
        let daysRemaining = daysRemainingFromMs(weeklyRemainsTimeMs)

        // Check for week reset: if current remaining is significantly higher than stored,
        // the weekly quota has been reset and we should treat it as a new day
        let weekResetDetected = dailyLastRecordedRemaining > 0 &&
                                currentWeeklyRemaining > dailyLastRecordedRemaining

        if let lastDate = dailyLastRecordedDate {
            let lastDay = calendar.startOfDay(for: lastDate)

            if lastDay == today && !weekResetDetected {
                // Same day - calculate usage based on how much remaining has decreased
                // todayUsage = previousRemaining - currentRemaining
                // Budget stays fixed from start of day
                let usage = max(0, dailyLastRecordedRemaining - currentWeeklyRemaining)
                return DailyTrackingData(todayUsage: usage, dailyBudget: dailyBudgetAtDayStart, daysRemaining: daysRemaining)
            } else {
                // New day or week reset detected - calculate new budget and reset tracking
                let newBudget = calculateDailyBudget(weeklyRemaining: currentWeeklyRemaining, days: daysRemaining)
                dailyBudgetAtDayStart = newBudget
                dailyLastRecordedDate = today
                dailyLastRecordedRemaining = currentWeeklyRemaining
                return DailyTrackingData(todayUsage: 0, dailyBudget: newBudget, daysRemaining: daysRemaining)
            }
        } else {
            // First run - initialize tracking
            let newBudget = calculateDailyBudget(weeklyRemaining: currentWeeklyRemaining, days: daysRemaining)
            dailyBudgetAtDayStart = newBudget
            dailyLastRecordedDate = today
            dailyLastRecordedRemaining = currentWeeklyRemaining
            return DailyTrackingData(todayUsage: 0, dailyBudget: newBudget, daysRemaining: daysRemaining)
        }
    }

    // Convert milliseconds to days remaining (minimum 1 day to avoid division by zero)
    private static func daysRemainingFromMs(_ ms: Int) -> Int {
        let days = ms / 86400000  // ms per day
        return max(1, days)
    }

    // Calculate daily budget based on weekly remaining and days left
    private static func calculateDailyBudget(weeklyRemaining: Int, days: Int) -> Int {
        if days <= 1 { return weeklyRemaining }  // If almost at reset, use all remaining
        return weeklyRemaining / days
    }

    // Get daily QuotaInfo with actual todayUsage and fixed daily budget
    // Pass weeklyRemainsTime for days calculation, budget and todayUsage from tracking
    static func getDailyQuotaInfo(modelRemain: ModelRemain, todayUsage: Int, dailyBudget: Int, weeklyRemainsTimeMs: Int) -> QuotaInfo {
        let weeklyRemaining = modelRemain.currentWeeklyUsageCount
        let daysRemaining = daysRemainingFromMs(weeklyRemainsTimeMs)

        // Calculate usage percentage based on the FIXED daily budget (not recalculated)
        let usedPercent = dailyBudget > 0 ? Double(todayUsage) / Double(dailyBudget) : 0

        return QuotaInfo(
            total: dailyBudget,
            remaining: max(0, dailyBudget - todayUsage),
            used: todayUsage,
            usedPercent: usedPercent,
            resetTimeMs: modelRemain.weeklyRemainsTime,
            isDailyBudget: true,
            dailyBudgetLimit: dailyBudget,
            todayUsage: todayUsage
        )
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}