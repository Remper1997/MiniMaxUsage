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

    // Track previous values to detect threshold crossings
    private var previousFiveHourPercent: Double = 0
    private var previousWeeklyPercent: Double = 0
    private var previousDailyPercent: Double = 0
    private var previousResetTimes: [Int: Int] = [:]  // quota type -> previous reset time ms

    private init() {}

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
        let fiveHourUsedPercent = modelRemain.currentIntervalTotalCount > 0
            ? Double(modelRemain.currentIntervalTotalCount - modelRemain.currentIntervalUsageCount) / Double(modelRemain.currentIntervalTotalCount)
            : 0

        let weeklyUsedPercent = modelRemain.currentWeeklyTotalCount > 0
            ? Double(modelRemain.currentWeeklyTotalCount - modelRemain.currentWeeklyUsageCount) / Double(modelRemain.currentWeeklyTotalCount)
            : 0

        let dailyUsedPercent = (dailyTracking?.dailyBudget ?? 0) > 0
            ? Double(dailyTracking?.todayUsage ?? 0) / Double(dailyTracking?.dailyBudget ?? 0)
            : 0

        // 5h threshold check
        checkThresholdCrossing(
            newPercent: fiveHourUsedPercent,
            previousPercent: previousFiveHourPercent,
            quotaName: "5h window",
            currentThreshold: currentQuotaType == .fiveHour ? Self.warningThreshold : 0,
            criticalThreshold: currentQuotaType == .fiveHour ? Self.criticalThreshold : 0,
            isDaily: false
        )
        previousFiveHourPercent = fiveHourUsedPercent

        // Weekly threshold check
        checkThresholdCrossing(
            newPercent: weeklyUsedPercent,
            previousPercent: previousWeeklyPercent,
            quotaName: "Weekly",
            currentThreshold: currentQuotaType == .weekly ? Self.warningThreshold : 0,
            criticalThreshold: currentQuotaType == .weekly ? Self.criticalThreshold : 0,
            isDaily: false
        )
        previousWeeklyPercent = weeklyUsedPercent

        // Daily budget check
        if currentQuotaType == .daily {
            checkThresholdCrossing(
                newPercent: dailyUsedPercent,
                previousPercent: previousDailyPercent,
                quotaName: "Daily Budget",
                currentThreshold: Self.warningThreshold,
                criticalThreshold: Self.criticalThreshold,
                isDaily: true
            )
        }
        previousDailyPercent = dailyUsedPercent

        // Reset detection (check if reset time increased significantly)
        let currentResetTime = modelRemain.remainsTime
        let previousResetTime = previousResetTimes[0] ?? 0
        if previousResetTime > 0 && currentResetTime > previousResetTime + 3600000 {  // > 1 hour increase = reset
            if Self.notifyResetEnabled {
                sendNotification(title: "Quota Reset", body: "MiniMaxUsage: 5h window quota has been reset")
            }
        }
        previousResetTimes[0] = currentResetTime

        let currentWeeklyResetTime = modelRemain.weeklyRemainsTime
        let previousWeeklyResetTime = previousResetTimes[1] ?? 0
        if previousWeeklyResetTime > 0 && currentWeeklyResetTime > previousWeeklyResetTime + 86400000 {  // > 1 day increase
            if Self.notifyResetEnabled {
                sendNotification(title: "Weekly Reset", body: "MiniMaxUsage: Weekly quota has been reset")
            }
        }
        previousResetTimes[1] = currentWeeklyResetTime

        // Daily budget exceeded check
        if dailyTracking != nil && (dailyTracking?.todayUsage ?? 0) > (dailyTracking?.dailyBudget ?? 0) {
            if Self.notifyDailyBudgetEnabled {
                sendNotification(title: "Budget Exceeded", body: "MiniMaxUsage: Daily budget exceeded!")
            }
        }
    }

    private func checkThresholdCrossing(newPercent: Double, previousPercent: Double, quotaName: String, currentThreshold: Double, criticalThreshold: Double, isDaily: Bool) {
        guard currentThreshold > 0 else { return }

        // Crossed from below to above warning
        if previousPercent < currentThreshold && newPercent >= currentThreshold {
            if isDaily ? Self.notifyWarningEnabled : Self.notifyWarningEnabled {
                sendNotification(
                    title: "Warning",
                    body: "MiniMaxUsage: \(quotaName) at \(Int(newPercent * 100))% — approaching limit"
                )
            }
        }

        // Crossed from below to above critical
        if previousPercent < criticalThreshold && newPercent >= criticalThreshold {
            if isDaily ? Self.notifyCriticalEnabled : Self.notifyCriticalEnabled {
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