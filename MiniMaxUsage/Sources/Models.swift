import Foundation

// API Response model for MiniMax usage data (token_plan/remains endpoint)
// The new API reports remaining quota as a percentage (0–100) per window.
// Absolute request counts are no longer provided.
struct MiniMaxUsage: Codable {
    let modelRemains: [ModelRemain]
    let baseResp: BaseResp

    enum CodingKeys: String, CodingKey {
        case modelRemains = "model_remains"
        case baseResp = "base_resp"
    }
}

// Unified quota information structure.
// All values are expressed in percentage terms:
//   - 5h / weekly: total = 100, values are percentages (0–100)
//   - daily budget: total = dailyBudgetLimit, values are weekly-percent points
struct QuotaInfo {
    let total: Int
    let remaining: Int
    let used: Int
    let usedPercent: Double
    let resetTimeMs: Int

    // Indicates if this is a daily budget calculation (affects color thresholds)
    let isDailyBudget: Bool

    // For daily budget: the calculated daily budget limit (in weekly-percent points)
    let dailyBudgetLimit: Int

    // For daily budget: today's actual usage (in weekly-percent points)
    let todayUsage: Int

    // True when the quota is on an unlimited / non-metered plan (API status == 3)
    let isUnlimited: Bool

    init(total: Int, remaining: Int, used: Int, usedPercent: Double,
         resetTimeMs: Int, isDailyBudget: Bool, dailyBudgetLimit: Int,
         todayUsage: Int, isUnlimited: Bool = false) {
        self.total = total
        self.remaining = remaining
        self.used = used
        self.usedPercent = usedPercent
        self.resetTimeMs = resetTimeMs
        self.isDailyBudget = isDailyBudget
        self.dailyBudgetLimit = dailyBudgetLimit
        self.todayUsage = todayUsage
        self.isUnlimited = isUnlimited
    }

    var formattedResetTime: String {
        let resetSeconds = resetTimeMs / 1000
        if resetTimeMs >= 86400000 {  // >= 1 day
            let days = resetSeconds / 86400
            let hours = (resetSeconds % 86400) / 3600
            return days > 0 ? "\(days)d \(hours)h" : "\(hours)h"
        } else {
            let hours = resetSeconds / 3600
            let minutes = (resetSeconds % 3600) / 60
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        }
    }

    // Human-readable "used" amount for the detailed menu.
    // Daily budget shows points/limit; percentage windows show a plain percent.
    var usedDescription: String {
        if isUnlimited { return "Unlimited" }
        if isDailyBudget { return "\(used)/\(total)" }
        return "\(used)%"
    }

    var remainingDescription: String {
        if isUnlimited { return "∞" }
        if isDailyBudget { return "\(remaining)/\(total)" }
        return "\(remaining)%"
    }

    // Color threshold for daily budget (80% warning, 100% exceeded)
    // For non-daily quotas, use 50%/80%
    var colorThreshold: Double {
        return isDailyBudget ? 0.8 : 0.5
    }

    var warningThreshold: Double {
        return isDailyBudget ? 1.0 : 0.8
    }
}

// Individual model usage statistics from the token_plan/remains endpoint.
struct ModelRemain: Codable {
    // 5-hour window
    let startTime: Int
    let endTime: Int
    let remainsTime: Int                       // ms until the 5h window resets
    let currentIntervalStatus: Int             // 1 = active/limited, 3 = unlimited/free
    let currentIntervalRemainingPercent: Int   // remaining quota for the 5h window (0–100)

    // Model identifier
    let modelName: String

    // Weekly window
    let weeklyStartTime: Int
    let weeklyEndTime: Int
    let weeklyRemainsTime: Int                  // ms until the weekly window resets
    let currentWeeklyStatus: Int               // 1 = active/limited, 3 = unlimited/free
    let currentWeeklyRemainingPercent: Int     // remaining quota for the week (0–100)

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case remainsTime = "remains_time"
        case currentIntervalStatus = "current_interval_status"
        case currentIntervalRemainingPercent = "current_interval_remaining_percent"
        case modelName = "model_name"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
        case weeklyRemainsTime = "weekly_remains_time"
        case currentWeeklyStatus = "current_weekly_status"
        case currentWeeklyRemainingPercent = "current_weekly_remaining_percent"
    }

    // API status value indicating an unlimited / non-metered plan
    static let unlimitedStatus = 3

    var isIntervalUnlimited: Bool { currentIntervalStatus == Self.unlimitedStatus }
    var isWeeklyUnlimited: Bool { currentWeeklyStatus == Self.unlimitedStatus }

    // Extract quota info for a given quota type.
    // Note: For .daily, use SettingsHelper.getDailyQuotaInfo() to get the tracked todayUsage.
    func quotaInfo(for type: QuotaType) -> QuotaInfo {
        switch type {
        case .fiveHour:
            let remaining = currentIntervalRemainingPercent
            let used = 100 - remaining
            let usedPercent = Double(used) / 100.0
            return QuotaInfo(total: 100, remaining: remaining, used: used,
                           usedPercent: usedPercent, resetTimeMs: remainsTime,
                           isDailyBudget: false, dailyBudgetLimit: 0, todayUsage: 0,
                           isUnlimited: isIntervalUnlimited)
        case .weekly:
            let remaining = currentWeeklyRemainingPercent
            let used = 100 - remaining
            let usedPercent = Double(used) / 100.0
            return QuotaInfo(total: 100, remaining: remaining, used: used,
                           usedPercent: usedPercent, resetTimeMs: weeklyRemainsTime,
                           isDailyBudget: false, dailyBudgetLimit: 0, todayUsage: 0,
                           isUnlimited: isWeeklyUnlimited)
        case .daily:
            // Fallback daily budget = remaining weekly percentage (the real value with
            // todayUsage comes from SettingsHelper.getDailyQuotaInfo()).
            let remaining = currentWeeklyRemainingPercent
            return QuotaInfo(total: remaining, remaining: remaining, used: 0,
                           usedPercent: 0, resetTimeMs: weeklyRemainsTime,
                           isDailyBudget: true, dailyBudgetLimit: remaining, todayUsage: 0,
                           isUnlimited: isWeeklyUnlimited)
        }
    }
}

// API response status
struct BaseResp: Codable {
    let statusCode: Int
    let statusMsg: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMsg = "status_msg"
    }
}

// Usage history snapshot for Statistics tab charts.
// All quota values are percentages (0–100); daily values are weekly-percent points.
struct UsageSnapshot: Codable {
    let timestamp: Date
    let fiveHourUsed: Int        // percent used (0–100)
    let fiveHourTotal: Int       // always 100
    let fiveHourRemaining: Int   // percent remaining (0–100)
    let weeklyUsed: Int          // percent used (0–100)
    let weeklyTotal: Int         // always 100
    let weeklyRemaining: Int     // percent remaining (0–100)
    let weeklyRemainsTime: Int   // ms until the weekly window resets
    let dailyUsed: Int           // weekly-percent points used today
    let dailyBudget: Int         // weekly-percent points budgeted for today
    let isDailyBudgetExceeded: Bool

    var fiveHourUsedPercent: Double {
        fiveHourTotal > 0 ? Double(fiveHourUsed) / Double(fiveHourTotal) : 0
    }

    var weeklyUsedPercent: Double {
        weeklyTotal > 0 ? Double(weeklyUsed) / Double(weeklyTotal) : 0
    }

    var dailyUsedPercent: Double {
        dailyBudget > 0 ? Double(dailyUsed) / Double(dailyBudget) : 0
    }

    init(from modelRemain: ModelRemain, dailyTracking: SettingsHelper.DailyTrackingData?, currentQuotaType: QuotaType) {
        self.timestamp = Date()
        self.fiveHourUsed = 100 - modelRemain.currentIntervalRemainingPercent
        self.fiveHourTotal = 100
        self.fiveHourRemaining = modelRemain.currentIntervalRemainingPercent
        self.weeklyUsed = 100 - modelRemain.currentWeeklyRemainingPercent
        self.weeklyTotal = 100
        self.weeklyRemaining = modelRemain.currentWeeklyRemainingPercent
        self.weeklyRemainsTime = modelRemain.weeklyRemainsTime
        self.dailyUsed = dailyTracking?.todayUsage ?? 0
        self.dailyBudget = dailyTracking?.dailyBudget ?? 0
        // Only "exceeded" when there is a real (non-zero) budget to exceed.
        self.isDailyBudgetExceeded = self.dailyBudget > 0 && self.dailyUsed > self.dailyBudget
    }
}
