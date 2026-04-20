import Foundation

// API Response model for MiniMax usage data
// WARNING: Field names like "UsageCount" are misleading - they actually contain REMAINING counts
struct MiniMaxUsage: Codable {
    let modelRemains: [ModelRemain]
    let baseResp: BaseResp

    enum CodingKeys: String, CodingKey {
        case modelRemains = "model_remains"
        case baseResp = "base_resp"
    }
}

// Unified quota information structure
struct QuotaInfo {
    let total: Int
    let remaining: Int
    let used: Int
    let usedPercent: Double
    let resetTimeMs: Int

    // Indicates if this is a daily budget calculation (affects color thresholds)
    let isDailyBudget: Bool

    // For daily budget: the calculated daily budget limit
    let dailyBudgetLimit: Int

    // For daily budget: today's actual usage
    let todayUsage: Int

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

    // Color threshold for daily budget (80% warning, 100% exceeded)
    // For non-daily quotas, use 50%/80%
    var colorThreshold: Double {
        return isDailyBudget ? 0.8 : 0.5
    }

    var warningThreshold: Double {
        return isDailyBudget ? 1.0 : 0.8
    }
}

// Individual model usage statistics
// WARNING: Fields ending in "UsageCount" store REMAINING count, not used count
struct ModelRemain: Codable {
    // 5-hour window timing (Unix timestamp in milliseconds)
    let startTime: Int
    let endTime: Int
    let remainsTime: Int

    // 5-hour window quota
    let currentIntervalTotalCount: Int
    let currentIntervalUsageCount: Int  // Named "Usage" but is actually REMAINING

    // Model identifier
    let modelName: String

    // Weekly quota
    let currentWeeklyTotalCount: Int
    let currentWeeklyUsageCount: Int  // Named "Usage" but is actually REMAINING

    // Weekly window timing
    let weeklyStartTime: Int
    let weeklyEndTime: Int
    let weeklyRemainsTime: Int

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case remainsTime = "remains_time"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
        case modelName = "model_name"
        case currentWeeklyTotalCount = "current_weekly_total_count"
        case currentWeeklyUsageCount = "current_weekly_usage_count"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
        case weeklyRemainsTime = "weekly_remains_time"
    }

    // Extract quota info for a given quota type
    // Note: For .daily, use SettingsHelper.getDailyQuotaInfo() to get todayUsage
    func quotaInfo(for type: QuotaType) -> QuotaInfo {
        switch type {
        case .fiveHour:
            let total = currentIntervalTotalCount
            let remaining = currentIntervalUsageCount
            let used = total - remaining
            let usedPercent = total > 0 ? Double(used) / Double(total) : 0
            return QuotaInfo(total: total, remaining: remaining, used: used,
                           usedPercent: usedPercent, resetTimeMs: remainsTime,
                           isDailyBudget: false, dailyBudgetLimit: 0, todayUsage: 0)
        case .weekly:
            let total = currentWeeklyTotalCount
            let remaining = currentWeeklyUsageCount
            let used = total - remaining
            let usedPercent = total > 0 ? Double(used) / Double(total) : 0
            return QuotaInfo(total: total, remaining: remaining, used: used,
                           usedPercent: usedPercent, resetTimeMs: weeklyRemainsTime,
                           isDailyBudget: false, dailyBudgetLimit: 0, todayUsage: 0)
        case .daily:
            // Daily budget is calculated from weekly remaining divided by days left
            // actual todayUsage comes from SettingsHelper.getDailyTracking()
            // This method returns the budget limit only
            let total = currentWeeklyTotalCount
            let remaining = currentWeeklyUsageCount
            return QuotaInfo(total: remaining, remaining: remaining, used: 0,
                           usedPercent: 0, resetTimeMs: weeklyRemainsTime,
                           isDailyBudget: true, dailyBudgetLimit: remaining, todayUsage: 0)
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

// Usage history snapshot for Statistics tab charts
struct UsageSnapshot: Codable {
    let timestamp: Date
    let fiveHourUsed: Int
    let fiveHourTotal: Int
    let fiveHourRemaining: Int
    let weeklyUsed: Int
    let weeklyTotal: Int
    let weeklyRemaining: Int
    let dailyUsed: Int
    let dailyBudget: Int
    let isDailyBudgetExceeded: Bool

    init(from modelRemain: ModelRemain, dailyTracking: SettingsHelper.DailyTrackingData?, currentQuotaType: QuotaType) {
        self.timestamp = Date()
        self.fiveHourUsed = modelRemain.currentIntervalTotalCount - modelRemain.currentIntervalUsageCount
        self.fiveHourTotal = modelRemain.currentIntervalTotalCount
        self.fiveHourRemaining = modelRemain.currentIntervalUsageCount
        self.weeklyUsed = modelRemain.currentWeeklyTotalCount - modelRemain.currentWeeklyUsageCount
        self.weeklyTotal = modelRemain.currentWeeklyTotalCount
        self.weeklyRemaining = modelRemain.currentWeeklyUsageCount
        self.dailyUsed = dailyTracking?.todayUsage ?? 0
        self.dailyBudget = dailyTracking?.dailyBudget ?? 0
        self.isDailyBudgetExceeded = (dailyTracking?.todayUsage ?? 0) > (dailyTracking?.dailyBudget ?? 0)
    }
}