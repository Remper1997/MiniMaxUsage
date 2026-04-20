import AppKit
import ServiceManagement

class PreferencesWindow: NSWindowController {
    private var apiService: ApiService
    private var menuBarController: MenuBarController?
    private var apiKeyField: NSSecureTextField!
    private var statusLabel: NSTextField!
    private var saveButton: NSButton!
    private var refreshPopup: NSPopUpButton!
    private var quotaTypePopup: NSPopUpButton!
    private var showIndicatorCheckbox: NSButton!
    private var showPercentCheckbox: NSButton!
    private var showRequestsCheckbox: NSButton!
    private var showResetCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var autoUpdateCheckbox: NSButton!
    private var lastCheckedLabel: NSTextField!
    private var checkNowButton: NSButton!

    private let refreshOptions: [(String, TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800)
    ]

    init(apiService: ApiService, menuBarController: MenuBarController?) {
        self.apiService = apiService
        self.menuBarController = menuBarController

        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        // Preferences tab (existing content)
        let preferencesTab = NSTabViewItem(viewController: NSViewController())
        preferencesTab.label = "Preferences"
        preferencesTab.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Preferences")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentViewHeight: CGFloat = 710
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: contentViewHeight))
        scrollView.documentView = contentView
        preferencesTab.view = scrollView

        tabViewController.addTabViewItem(preferencesTab)

        // Statistics tab
        let statisticsTab = NSTabViewItem(viewController: NSViewController())
        statisticsTab.label = "Statistics"
        statisticsTab.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Statistics")

        if #available(macOS 12.0, *) {
            let statisticsView = NSHostingView(rootView: StatisticsTabView())
            statisticsView.frame = NSRect(x: 0, y: 0, width: 430, height: 480)
            statisticsTab.view = statisticsView
        } else {
            let fallbackView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 480))
            let label = NSTextField(labelWithString: "Statistics requires macOS 12 or later")
            label.frame = NSRect(x: 20, y: 220, width: 390, height: 40)
            fallbackView.addSubview(label)
            statisticsTab.view = fallbackView
        }

        tabViewController.addTabViewItem(statisticsTab)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MiniMaxUsage Preferences"
        window.contentViewController = tabViewController
        window.center()
        window.minSize = NSSize(width: 450, height: 400)

        super.init(window: window)

        setupUI()
        loadExistingAPIKey()
        loadRefreshInterval()
        loadDisplaySettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let tabViewController = window?.contentViewController as? NSTabViewController,
              let preferencesTab = tabViewController.tabViewItem(at: 0),
              let scrollView = preferencesTab.view as? NSScrollView,
              let contentView = scrollView.documentView else { return }

        // Build UI from bottom to top using positive coordinates
        var yPosition: CGFloat = 20

        // === Updates Section (bottom) ===
        checkNowButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdatesNow))
        checkNowButton.frame = NSRect(x: 40, y: yPosition, width: 150, height: 24)
        checkNowButton.bezelStyle = .rounded
        contentView.addSubview(checkNowButton)

        yPosition += 25
        lastCheckedLabel = NSTextField(labelWithString: "Last checked: \(SettingsHelper.lastUpdateCheckFormatted)")
        lastCheckedLabel.frame = NSRect(x: 40, y: yPosition, width: 200, height: 20)
        lastCheckedLabel.font = NSFont.systemFont(ofSize: 11)
        lastCheckedLabel.textColor = .secondaryLabelColor
        contentView.addSubview(lastCheckedLabel)

        yPosition += 25
        autoUpdateCheckbox = NSButton(checkboxWithTitle: "Check for updates automatically", target: self, action: #selector(autoUpdateChanged))
        autoUpdateCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
        contentView.addSubview(autoUpdateCheckbox)

        yPosition += 30
        let updatesTitleLabel = NSTextField(labelWithString: "Updates")
        updatesTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        updatesTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(updatesTitleLabel)

        yPosition += 40
        let separatorLine4 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine4.boxType = .separator
        contentView.addSubview(separatorLine4)

        yPosition += 30
        refreshPopup = NSPopUpButton(frame: NSRect(x: 20, y: yPosition, width: 200, height: 25))
        for (title, _) in refreshOptions {
            refreshPopup.addItem(withTitle: title)
        }
        refreshPopup.target = self
        refreshPopup.action = #selector(refreshIntervalChanged)
        contentView.addSubview(refreshPopup)

        yPosition += 30
        let refreshTitleLabel = NSTextField(labelWithString: "Refresh Interval")
        refreshTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        refreshTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(refreshTitleLabel)

        yPosition += 40
        let separatorLine3 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine3.boxType = .separator
        contentView.addSubview(separatorLine3)

        yPosition += 30
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Apri MiniMaxUsage all'accesso", target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
        contentView.addSubview(launchAtLoginCheckbox)

        yPosition += 30
        let launchAtLoginTitleLabel = NSTextField(labelWithString: "Startup")
        launchAtLoginTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        launchAtLoginTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(launchAtLoginTitleLabel)

        yPosition += 40
        let separatorLine2 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine2.boxType = .separator
        contentView.addSubview(separatorLine2)

        yPosition += 30
        showIndicatorCheckbox = NSButton(checkboxWithTitle: "Show color indicator (🟢🟡🔴)", target: self, action: #selector(showIndicatorChanged))
        showIndicatorCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
        contentView.addSubview(showIndicatorCheckbox)

        yPosition += 30
        showResetCheckbox = NSButton(checkboxWithTitle: "Reset time", target: self, action: #selector(displayModeChanged))
        showResetCheckbox.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        showResetCheckbox.tag = 3
        contentView.addSubview(showResetCheckbox)

        yPosition += 25
        showRequestsCheckbox = NSButton(checkboxWithTitle: "Requests (used/total)", target: self, action: #selector(displayModeChanged))
        showRequestsCheckbox.frame = NSRect(x: 200, y: yPosition, width: 180, height: 20)
        showRequestsCheckbox.tag = 2
        contentView.addSubview(showRequestsCheckbox)

        showPercentCheckbox = NSButton(checkboxWithTitle: "Percentage (%)", target: self, action: #selector(displayModeChanged))
        showPercentCheckbox.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        showPercentCheckbox.tag = 1
        contentView.addSubview(showPercentCheckbox)

        yPosition += 25
        let showLabel = NSTextField(labelWithString: "Show in menu bar:")
        showLabel.frame = NSRect(x: 20, y: yPosition, width: 120, height: 20)
        contentView.addSubview(showLabel)

        yPosition += 30
        quotaTypePopup = NSPopUpButton(frame: NSRect(x: 150, y: yPosition - 2, width: 200, height: 25))
        quotaTypePopup.addItems(withTitles: ["5-hour window", "Weekly", "Daily"])
        quotaTypePopup.target = self
        quotaTypePopup.action = #selector(quotaTypeChanged)
        contentView.addSubview(quotaTypePopup)

        let quotaTypeLabel = NSTextField(labelWithString: "Quota type:")
        quotaTypeLabel.frame = NSRect(x: 20, y: yPosition, width: 120, height: 20)
        contentView.addSubview(quotaTypeLabel)

        yPosition += 40
        let displayTitleLabel = NSTextField(labelWithString: "Display Settings")
        displayTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        displayTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(displayTitleLabel)

        yPosition += 40
        let separatorLine = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine.boxType = .separator
        contentView.addSubview(separatorLine)

        yPosition += 35
        saveButton = NSButton(title: "Save & Test", target: self, action: #selector(saveAndTest))
        saveButton.frame = NSRect(x: 20, y: yPosition, width: 120, height: 30)
        saveButton.bezelStyle = .rounded
        contentView.addSubview(saveButton)

        let deleteButton = NSButton(title: "Delete API Key", target: self, action: #selector(deleteAPIKey))
        deleteButton.frame = NSRect(x: 150, y: yPosition, width: 130, height: 30)
        deleteButton.bezelStyle = .rounded
        contentView.addSubview(deleteButton)

        yPosition += 30
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: yPosition, width: 410, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(statusLabel)

        yPosition += 30
        apiKeyField = NSSecureTextField(frame: NSRect(x: 20, y: yPosition, width: 410, height: 24))
        apiKeyField.placeholderString = "sk-cp-..."
        contentView.addSubview(apiKeyField)

        yPosition += 30
        let apiTitleLabel = NSTextField(labelWithString: "MiniMax API Key")
        apiTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        apiTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(apiTitleLabel)
    }

    private func loadExistingAPIKey() {
        if let existingKey = KeychainHelper.getAPIKey() {
            apiKeyField.stringValue = existingKey
        }
    }

    private func loadRefreshInterval() {
        let currentInterval = menuBarController?.getRefreshInterval() ?? 300
        for (index, (_, interval)) in refreshOptions.enumerated() {
            if interval == currentInterval {
                refreshPopup.selectItem(at: index)
                break
            }
        }
    }

    private func loadDisplaySettings() {
        quotaTypePopup.selectItem(at: SettingsHelper.quotaType.rawValue)
        showPercentCheckbox.state = SettingsHelper.showPercent ? .on : .off
        showRequestsCheckbox.state = SettingsHelper.showRequests ? .on : .off
        showResetCheckbox.state = SettingsHelper.showResetTime ? .on : .off
        showIndicatorCheckbox.state = SettingsHelper.showIndicator ? .on : .off
        launchAtLoginCheckbox.state = SettingsHelper.launchAtLogin ? .on : .off
        autoUpdateCheckbox.state = SettingsHelper.autoUpdateEnabled ? .on : .off
    }

    @objc private func displayModeChanged(_ sender: NSButton) {
        if sender.tag == 1 {
            SettingsHelper.showPercent = sender.state == .on
        } else if sender.tag == 2 {
            SettingsHelper.showRequests = sender.state == .on
        } else if sender.tag == 3 {
            SettingsHelper.showResetTime = sender.state == .on
        }
    }

    @objc private func quotaTypeChanged() {
        let index = quotaTypePopup.indexOfSelectedItem
        SettingsHelper.quotaType = QuotaType(rawValue: index) ?? .fiveHour
    }

    @objc private func showIndicatorChanged() {
        SettingsHelper.showIndicator = showIndicatorCheckbox.state == .on
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let enable = sender.state == .on
        SettingsHelper.launchAtLogin = enable

        if enable {
            do {
                try SMAppService.mainApp.register()
            } catch {
                let actualStatus = SMAppService.mainApp.status
                if actualStatus == .requiresApproval {
                    sender.state = .off
                    SettingsHelper.launchAtLogin = false
                    statusLabel.stringValue = "Go to System Settings > Login Items to approve"
                    statusLabel.textColor = .systemOrange
                } else {
                    sender.state = .off
                    SettingsHelper.launchAtLogin = false
                    statusLabel.stringValue = "Failed to enable launch at login"
                    statusLabel.textColor = .systemRed
                }
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                sender.state = .on
                SettingsHelper.launchAtLogin = true
                statusLabel.stringValue = "Failed to disable launch at login"
                statusLabel.textColor = .systemRed
            }
        }
    }

    @objc private func autoUpdateChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        SettingsHelper.autoUpdateEnabled = enabled

        if enabled {
            NotificationCenter.default.post(name: .enableAutoUpdate, object: nil)
        } else {
            NotificationCenter.default.post(name: .disableAutoUpdate, object: nil)
        }
    }

    @objc private func checkForUpdatesNow() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
        SettingsHelper.lastUpdateCheck = Date()
        lastCheckedLabel.stringValue = "Last checked: Just now"
    }

    @objc private func refreshIntervalChanged() {
        guard let selectedTitle = refreshPopup.selectedItem?.title,
              let selected = refreshOptions.first(where: { $0.0 == selectedTitle }) else {
            return
        }
        menuBarController?.setRefreshInterval(selected.1)
    }

    @objc private func saveAndTest() {
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            statusLabel.stringValue = "Please enter an API key"
            statusLabel.textColor = .systemRed
            return
        }

        statusLabel.stringValue = "Testing connection..."
        statusLabel.textColor = .secondaryLabelColor
        saveButton.isEnabled = false

        Task {
            do {
                _ = try await apiService.fetchUsage(apiKey: apiKey)
                await MainActor.run {
                    if KeychainHelper.saveAPIKey(apiKey) {
                        self.statusLabel.stringValue = "Saved successfully!"
                        self.statusLabel.textColor = .systemGreen
                        self.saveButton.isEnabled = true
                        self.menuBarController?.refreshData()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.close()
                        }
                    } else {
                        self.statusLabel.stringValue = "Failed to save to Keychain"
                        self.statusLabel.textColor = .systemRed
                        self.saveButton.isEnabled = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Test failed: \(error.localizedDescription)"
                    self.statusLabel.textColor = .systemRed
                    self.saveButton.isEnabled = true
                }
            }
        }
    }

    @objc private func deleteAPIKey() {
        if KeychainHelper.deleteAPIKey() {
            apiKeyField.stringValue = ""
            statusLabel.stringValue = "API key deleted"
            statusLabel.textColor = .systemOrange
            menuBarController?.refreshData()
        }
    }
}
