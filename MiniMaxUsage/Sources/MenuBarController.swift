import AppKit
import Foundation

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var apiService: ApiService
    private var refreshTimer: Timer?
    private var currentUsage: MiniMaxUsage?
    private var currentDailyTracking: SettingsHelper.DailyTrackingData?

    // Tag range for dynamic menu items
    private static let dynamicMenuItemTagMin = 100
    private static let dynamicMenuItemTagMax = 110
    private static let defaultRefreshInterval: TimeInterval = 300

    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
    }

    init(apiService: ApiService) {
        self.apiService = apiService
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        NotificationHelper.shared.requestAuthorization()

        setupRetryCallback()
        setupMenu()
        setupSettingsObserver()
        startTimer()
        refreshData()
    }

    private func setupRetryCallback() {
        apiService.onRetry = { [weak self] attempt, maxRetries in
            DispatchQueue.main.async {
                let title = "🔄 Retry \(attempt)/\(maxRetries)..."
                self?.updateButton(title: title, color: .systemYellow)
            }
        }
    }

    private func setupMenu() {
        guard let button = statusItem.button else { return }
        button.title = "⏳ Loading..."
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "MiniMaxUsage", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let checkUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit MiniMaxUsage", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupSettingsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    @objc private func settingsChanged() {
        if let usage = currentUsage {
            updateDisplay(usage: usage)
        }
    }

    @objc func refreshData() {
        guard let apiKey = KeychainHelper.getAPIKey() else {
            updateButton(title: "🔑 Set API Key", color: .systemOrange)
            return
        }

        updateButton(title: "⏳ Loading...", color: .secondaryLabelColor)

        Task {
            do {
                let usage = try await apiService.fetchUsage(apiKey: apiKey)
                await MainActor.run {
                    // Skip UI update if data hasn't meaningfully changed
                    if self.shouldUpdateDisplay(newUsage: usage) {
                        self.currentUsage = usage

                        // Extract m2 for use in notification and snapshot (also sets currentDailyTracking)
                        guard let m2 = usage.modelRemains.first(where: { $0.modelName.contains("MiniMax-M") }) else { return }
                        self.updateDisplay(usage: usage)

                        // Check and send notifications if needed
                        NotificationHelper.shared.checkAndNotify(
                            modelRemain: m2,
                            dailyTracking: currentDailyTracking,
                            currentQuotaType: SettingsHelper.quotaType
                        )

                        // Save usage snapshot for history charts
                        let snapshot = UsageSnapshot(from: m2, dailyTracking: currentDailyTracking, currentQuotaType: SettingsHelper.quotaType)
                        HistoryStorage.shared.saveSnapshot(snapshot)
                    }
                }
            } catch {
                await MainActor.run {
                    self.updateButton(title: "❌ Error", color: .systemRed)
                }
            }
        }
    }

    // Check if the new usage data is meaningfully different from current
    private func shouldUpdateDisplay(newUsage: MiniMaxUsage) -> Bool {
        guard let current = currentUsage else { return true }

        guard let currentModel = current.modelRemains.first(where: { $0.modelName.contains("MiniMax-M") }),
              let newModel = newUsage.modelRemains.first(where: { $0.modelName.contains("MiniMax-M") }) else {
            return true
        }

        return currentModel.currentIntervalUsageCount != newModel.currentIntervalUsageCount ||
               currentModel.currentWeeklyUsageCount != newModel.currentWeeklyUsageCount ||
               currentModel.remainsTime != newModel.remainsTime ||
               currentModel.weeklyRemainsTime != newModel.weeklyRemainsTime
    }

    private func updateDisplay(usage: MiniMaxUsage) {
        guard let m2 = usage.modelRemains.first(where: { $0.modelName.contains("MiniMax-M") }) else {
            updateButton(title: "❓ No data", color: .secondaryLabelColor)
            updateDetailedMenu(usage: usage, m2Usage: nil)
            return
        }

        // DEBUG: Log API values
        print("DEBUG: weeklyRemainsTime = \(m2.weeklyRemainsTime) ms")
        print("DEBUG: currentWeeklyUsageCount = \(m2.currentWeeklyUsageCount)")
        print("DEBUG: currentWeeklyTotalCount = \(m2.currentWeeklyTotalCount)")

        // Get quota info based on selected type
        let quotaInfo: QuotaInfo

        if SettingsHelper.quotaType == .daily {
            // Update daily tracking and get daily quota info
            let tracking = SettingsHelper.updateDailyTracking(
                currentWeeklyRemaining: m2.currentWeeklyUsageCount,
                weeklyRemainsTimeMs: m2.weeklyRemainsTime
            )
            currentDailyTracking = tracking
            quotaInfo = SettingsHelper.getDailyQuotaInfo(
                modelRemain: m2,
                todayUsage: tracking.todayUsage,
                dailyBudget: tracking.dailyBudget,
                weeklyRemainsTimeMs: m2.weeklyRemainsTime
            )

            // DEBUG: Log daily tracking values
            print("DEBUG DAILY: todayUsage = \(tracking.todayUsage)")
            print("DEBUG DAILY: dailyBudget = \(tracking.dailyBudget)")
            print("DEBUG DAILY: daysRemaining = \(tracking.daysRemaining)")
            print("DEBUG DAILY: quotaInfo.used = \(quotaInfo.used)")
            print("DEBUG DAILY: quotaInfo.total = \(quotaInfo.total)")
            print("DEBUG DAILY: quotaInfo.usedPercent = \(quotaInfo.usedPercent)")
        } else {
            quotaInfo = m2.quotaInfo(for: SettingsHelper.quotaType)
        }

        // Determine color based on quota type (daily has different thresholds)
        let (icon, color) = colorForQuota(quotaInfo: quotaInfo, isDaily: SettingsHelper.quotaType == .daily)

        let prefix = SettingsHelper.showIndicator ? "\(icon) " : ""

        var parts: [String] = []
        if SettingsHelper.showPercent {
            parts.append(String(format: "%.0f%%", min(quotaInfo.usedPercent, 9.99) * 100))
        }
        if SettingsHelper.showRequests {
            parts.append("\(quotaInfo.used)/\(quotaInfo.total)")
        }
        if SettingsHelper.showResetTime {
            parts.append(quotaInfo.formattedResetTime)
        }

        let title = parts.isEmpty ? "\(prefix)--" : "\(prefix)\(parts.joined(separator: " "))"

        updateButton(title: title, color: color)
        updateDetailedMenu(usage: usage, m2Usage: m2)
    }

    // Color logic: daily uses 80%/100% thresholds, others use 50%/80%
    private func colorForQuota(quotaInfo: QuotaInfo, isDaily: Bool) -> (String, NSColor) {
        let usedPercent = quotaInfo.usedPercent

        if isDaily {
            if usedPercent < 0.8 {
                return ("🟢", .systemGreen)
            } else if usedPercent < 1.0 {
                return ("🟡", .systemOrange)
            } else {
                return ("🔴", .systemRed)
            }
        } else {
            if usedPercent < 0.5 {
                return ("🟢", .systemGreen)
            } else if usedPercent < 0.8 {
                return ("🟡", .systemYellow)
            } else {
                return ("🔴", .systemRed)
            }
        }
    }

    private func updateButton(title: String, color: NSColor) {
        guard let button = statusItem.button else { return }

        // Create attributed string
        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attributedTitle.length))

        // Add glow effect via shadow
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.8)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: 0)
        attributedTitle.addAttribute(.shadow, value: shadow, range: NSRange(location: 0, length: attributedTitle.length))

        button.attributedTitle = attributedTitle
    }

    private func updateDetailedMenu(usage: MiniMaxUsage, m2Usage: ModelRemain?) {
        guard let menu = statusItem.menu else { return }

        // Remove previously added dynamic menu items
        while let index = menu.items.firstIndex(where: { item in
            item.tag >= Self.dynamicMenuItemTagMin && item.tag <= Self.dynamicMenuItemTagMax
        }) {
            menu.removeItem(at: index)
        }

        var insertIndex = 2
        var currentTag = Self.dynamicMenuItemTagMin

        guard let m2 = m2Usage else { return }

        // Display the "other" quota types (not currently selected) - up to 2 others
        let selectedType = SettingsHelper.quotaType
        let otherTypes: [QuotaType] = {
            switch selectedType {
            case .fiveHour:
                return [.weekly, .daily]
            case .weekly:
                return [.fiveHour, .daily]
            case .daily:
                return [.fiveHour, .weekly]
            }
        }()

        for otherType in otherTypes {
            let otherQuotaInfo: QuotaInfo
            if otherType == .daily {
                let tracking = SettingsHelper.updateDailyTracking(
                    currentWeeklyRemaining: m2.currentWeeklyUsageCount,
                    weeklyRemainsTimeMs: m2.weeklyRemainsTime
                )
                otherQuotaInfo = SettingsHelper.getDailyQuotaInfo(
                    modelRemain: m2,
                    todayUsage: tracking.todayUsage,
                    dailyBudget: tracking.dailyBudget,
                    weeklyRemainsTimeMs: m2.weeklyRemainsTime
                )
            } else {
                otherQuotaInfo = m2.quotaInfo(for: otherType)
            }

            let headerTitle: String
            switch otherType {
            case .fiveHour: headerTitle = "───── 5h Window ─────"
            case .weekly: headerTitle = "───── Weekly ─────"
            case .daily: headerTitle = "───── Daily Budget ─────"
            }

            let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
            headerItem.tag = currentTag; currentTag += 1
            headerItem.isEnabled = false
            menu.insertItem(headerItem, at: insertIndex); insertIndex += 1

            let usedItem = NSMenuItem(title: "Used: \(otherQuotaInfo.used)/\(otherQuotaInfo.total) (\(String(format: "%.0f%%", min(otherQuotaInfo.usedPercent, 9.99) * 100)))", action: nil, keyEquivalent: "")
            usedItem.tag = currentTag; currentTag += 1
            usedItem.isEnabled = false
            menu.insertItem(usedItem, at: insertIndex); insertIndex += 1

            let remainingItem = NSMenuItem(title: "Remaining: \(otherQuotaInfo.remaining)/\(otherQuotaInfo.total)", action: nil, keyEquivalent: "")
            remainingItem.tag = currentTag; currentTag += 1
            remainingItem.isEnabled = false
            menu.insertItem(remainingItem, at: insertIndex); insertIndex += 1

            if SettingsHelper.showResetTime {
                let resetItem = NSMenuItem(title: "Reset in: \(otherQuotaInfo.formattedResetTime)", action: nil, keyEquivalent: "")
                resetItem.tag = currentTag; currentTag += 1
                resetItem.isEnabled = false
                menu.insertItem(resetItem, at: insertIndex); insertIndex += 1
            }
        }

        let separatorItem = NSMenuItem.separator()
        separatorItem.tag = currentTag
        menu.insertItem(separatorItem, at: insertIndex)
    }

    func setRefreshInterval(_ seconds: TimeInterval) {
        UserDefaults.standard.set(seconds, forKey: "refreshInterval")
        startTimer()
    }

    func getRefreshInterval() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "refreshInterval")
        return stored > 0 ? stored : Self.defaultRefreshInterval
    }

    func startTimer() {
        refreshTimer?.invalidate()
        let interval = getRefreshInterval()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }

    func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func openPreferences() {
        NotificationCenter.default.post(name: .showPreferences, object: nil)
    }

    @objc private func checkForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let showPreferences = Notification.Name("showPreferences")
}