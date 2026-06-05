import Foundation
import UserNotifications
import AppKit

class NotificationHelper {
    static let shared = NotificationHelper()

    // UserDefaults keys for notification preferences
    private static let notifyWarningEnabledKey = "notifyWarningEnabled"
    private static let notifyCriticalEnabledKey = "notifyCriticalEnabled"
    private static let notifyResetEnabledKey = "notifyResetEnabled"
    private static let notifyDailyBudgetEnabledKey = "notifyDailyBudgetEnabled"
    private static let warningThresholdKey = "warningThreshold"
    private static let criticalThresholdKey = "criticalThreshold"

    // Default thresholds
    static let defaultWarningThreshold: Double = 0.50
    static let defaultCriticalThreshold: Double = 0.80

    // Track previous values to detect threshold crossings.
    // Persisted in UserDefaults so a restart doesn't replay a "0 → current" jump
    // and fire a spurious notification when the user is already above threshold.
    private var previousFiveHourPercent: Double {
        get { UserDefaults.standard.double(forKey: Self.previousFiveHourPercentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.previousFiveHourPercentKey) }
    }
    private var previousWeeklyPercent: Double {
        get { UserDefaults.standard.double(forKey: Self.previousWeeklyPercentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.previousWeeklyPercentKey) }
    }
    private var previousDailyPercent: Double {
        get { UserDefaults.standard.double(forKey: Self.previousDailyPercentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.previousDailyPercentKey) }
    }
    private var previousResetTimes: [Int: Int] = [:]  // quota type -> previous reset time ms

    // UserDefaults keys for persisted reset detection
    private static let previousFiveHourResetTimeKey = "previousFiveHourResetTime"
    private static let previousWeeklyResetTimeKey = "previousWeeklyResetTime"

    // UserDefaults keys for persisted threshold-crossing detection
    private static let previousFiveHourPercentKey = "previousFiveHourPercent"
    private static let previousWeeklyPercentKey = "previousWeeklyPercent"
    private static let previousDailyPercentKey = "previousDailyPercent"

    private init() {
        // Load persisted reset times from UserDefaults
        previousResetTimes[0] = UserDefaults.standard.integer(forKey: Self.previousFiveHourResetTimeKey)
        previousResetTimes[1] = UserDefaults.standard.integer(forKey: Self.previousWeeklyResetTimeKey)
    }

    // MARK: - Preference Accessors

    static var notifyWarningEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notifyWarningEnabledKey) == nil {
                return true  // Default enabled
            }
            return UserDefaults.standard.bool(forKey: notifyWarningEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: notifyWarningEnabledKey) }
    }

    static var notifyCriticalEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notifyCriticalEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notifyCriticalEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: notifyCriticalEnabledKey) }
    }

    static var notifyResetEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notifyResetEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notifyResetEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: notifyResetEnabledKey) }
    }

    static var notifyDailyBudgetEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notifyDailyBudgetEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notifyDailyBudgetEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: notifyDailyBudgetEnabledKey) }
    }

    static var warningThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: warningThresholdKey)
            return val > 0 ? val : defaultWarningThreshold
        }
        set { UserDefaults.standard.set(newValue, forKey: warningThresholdKey) }
    }

    static var criticalThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: criticalThresholdKey)
            return val > 0 ? val : defaultCriticalThreshold
        }
        set { UserDefaults.standard.set(newValue, forKey: criticalThresholdKey) }
    }

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    // MARK: - Check & Send Notifications

    func checkAndNotify(modelRemain: ModelRemain, dailyTracking: SettingsHelper.DailyTrackingData?, currentQuotaType: QuotaType) {
        // Unlimited / non-metered plans never cross a usage threshold; skip them.
        let intervalUnlimited = modelRemain.isIntervalUnlimited
        let weeklyUnlimited = modelRemain.isWeeklyUnlimited

        let fiveHourUsedPercent = Double(100 - modelRemain.currentIntervalRemainingPercent) / 100.0
        let weeklyUsedPercent = Double(100 - modelRemain.currentWeeklyRemainingPercent) / 100.0

        let dailyUsedPercent = (dailyTracking?.dailyBudget ?? 0) > 0
            ? Double(dailyTracking?.todayUsage ?? 0) / Double(dailyTracking?.dailyBudget ?? 0)
            : 0

        // 5h threshold check - always check all quota types, not just the selected one
        if !intervalUnlimited {
            checkThresholdCrossing(
                newPercent: fiveHourUsedPercent,
                previousPercent: previousFiveHourPercent,
                quotaName: "5h window",
                currentThreshold: Self.warningThreshold,
                criticalThreshold: Self.criticalThreshold,
                isDaily: false
            )
            previousFiveHourPercent = fiveHourUsedPercent
        }

        // Weekly threshold check
        if !weeklyUnlimited {
            checkThresholdCrossing(
                newPercent: weeklyUsedPercent,
                previousPercent: previousWeeklyPercent,
                quotaName: "Weekly",
                currentThreshold: Self.warningThreshold,
                criticalThreshold: Self.criticalThreshold,
                isDaily: false
            )
            previousWeeklyPercent = weeklyUsedPercent

            // Daily budget check (derived from the weekly quota)
            checkThresholdCrossing(
                newPercent: dailyUsedPercent,
                previousPercent: previousDailyPercent,
                quotaName: "Daily Budget",
                currentThreshold: Self.warningThreshold,
                criticalThreshold: Self.criticalThreshold,
                isDaily: true
            )
            previousDailyPercent = dailyUsedPercent
        }

        // Reset detection (check if remaining time decreased significantly - indicates quota reset)
        // When quota resets, remainsTime drops from a large value to a small one
        let currentResetTime = modelRemain.remainsTime
        let previousResetTime = previousResetTimes[0] ?? 0
        if !intervalUnlimited && previousResetTime > 0 && currentResetTime < previousResetTime - 3600000 {  // > 1 hour decrease = reset
            if Self.notifyResetEnabled {
                sendNotification(title: "Quota Reset", body: "MiniMaxUsage: 5h window quota has been reset")
            }
        }
        previousResetTimes[0] = currentResetTime
        UserDefaults.standard.set(currentResetTime, forKey: Self.previousFiveHourResetTimeKey)

        let currentWeeklyResetTime = modelRemain.weeklyRemainsTime
        let previousWeeklyResetTime = previousResetTimes[1] ?? 0
        if !weeklyUnlimited && previousWeeklyResetTime > 0 && currentWeeklyResetTime < previousWeeklyResetTime - 86400000 {  // > 1 day decrease
            if Self.notifyResetEnabled {
                sendNotification(title: "Weekly Reset", body: "MiniMaxUsage: Weekly quota has been reset")
            }
        }
        previousResetTimes[1] = currentWeeklyResetTime
        UserDefaults.standard.set(currentWeeklyResetTime, forKey: Self.previousWeeklyResetTimeKey)

        // Daily budget exceeded check.
        // Skip when the budget is 0 (rounds down to zero near the end of the weekly
        // cycle); otherwise any usage would fire a spurious "exceeded" notification.
        let dailyBudget = dailyTracking?.dailyBudget ?? 0
        if !weeklyUnlimited && dailyBudget > 0 && (dailyTracking?.todayUsage ?? 0) > dailyBudget {
            if Self.notifyDailyBudgetEnabled {
                sendNotification(title: "Budget Exceeded", body: "MiniMaxUsage: Daily budget exceeded!")
            }
        }
    }

    private func checkThresholdCrossing(newPercent: Double, previousPercent: Double, quotaName: String, currentThreshold: Double, criticalThreshold: Double, isDaily: Bool) {
        guard currentThreshold > 0 else { return }

        // Crossed from below to above warning
        if previousPercent < currentThreshold && newPercent >= currentThreshold {
            if Self.notifyWarningEnabled {
                sendNotification(
                    title: "Warning",
                    body: "MiniMaxUsage: \(quotaName) at \(Int(newPercent * 100))% — approaching limit"
                )
            }
        }

        // Crossed from below to above critical
        if previousPercent < criticalThreshold && newPercent >= criticalThreshold {
            if Self.notifyCriticalEnabled {
                sendNotification(
                    title: "Critical",
                    body: "MiniMaxUsage: \(quotaName) at \(Int(newPercent * 100))% — critical!"
                )
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}