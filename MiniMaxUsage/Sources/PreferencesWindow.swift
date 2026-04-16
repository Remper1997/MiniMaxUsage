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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 480))
        scrollView.documentView = contentView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MiniMaxUsage Preferences"
        window.contentView = scrollView
        window.center()
        window.minSize = NSSize(width: 450, height: 300)

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
        guard let scrollView = window?.contentView as? NSScrollView,
              let contentView = scrollView.documentView else { return }

        var yPosition = 440

        let apiTitleLabel = NSTextField(labelWithString: "MiniMax API Key")
        apiTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        apiTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(apiTitleLabel)

        yPosition -= 30
        apiKeyField = NSSecureTextField(frame: NSRect(x: 20, y: yPosition, width: 410, height: 24))
        apiKeyField.placeholderString = "sk-cp-..."
        contentView.addSubview(apiKeyField)

        yPosition -= 30
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: yPosition, width: 410, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(statusLabel)

        yPosition -= 35
        saveButton = NSButton(title: "Save & Test", target: self, action: #selector(saveAndTest))
        saveButton.frame = NSRect(x: 20, y: yPosition, width: 120, height: 30)
        saveButton.bezelStyle = .rounded
        contentView.addSubview(saveButton)

        let deleteButton = NSButton(title: "Delete API Key", target: self, action: #selector(deleteAPIKey))
        deleteButton.frame = NSRect(x: 150, y: yPosition, width: 130, height: 30)
        deleteButton.bezelStyle = .rounded
        contentView.addSubview(deleteButton)

        yPosition -= 40
        let separatorLine = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine.boxType = .separator
        contentView.addSubview(separatorLine)

        yPosition -= 30
        let displayTitleLabel = NSTextField(labelWithString: "Display Settings")
        displayTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        displayTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(displayTitleLabel)

        yPosition -= 30
        let quotaTypeLabel = NSTextField(labelWithString: "Quota type:")
        quotaTypeLabel.frame = NSRect(x: 20, y: yPosition, width: 120, height: 20)
        contentView.addSubview(quotaTypeLabel)

        quotaTypePopup = NSPopUpButton(frame: NSRect(x: 150, y: yPosition - 2, width: 200, height: 25))
        quotaTypePopup.addItems(withTitles: ["5-hour window", "Weekly", "Daily"])
        quotaTypePopup.target = self
        quotaTypePopup.action = #selector(quotaTypeChanged)
        contentView.addSubview(quotaTypePopup)

        yPosition -= 30
        let showLabel = NSTextField(labelWithString: "Show in menu bar:")
        showLabel.frame = NSRect(x: 20, y: yPosition, width: 120, height: 20)
        contentView.addSubview(showLabel)

        yPosition -= 25
        showPercentCheckbox = NSButton(checkboxWithTitle: "Percentage (%)", target: self, action: #selector(displayModeChanged))
        showPercentCheckbox.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        showPercentCheckbox.tag = 1
        contentView.addSubview(showPercentCheckbox)

        showRequestsCheckbox = NSButton(checkboxWithTitle: "Requests (used/total)", target: self, action: #selector(displayModeChanged))
        showRequestsCheckbox.frame = NSRect(x: 200, y: yPosition, width: 180, height: 20)
        showRequestsCheckbox.tag = 2
        contentView.addSubview(showRequestsCheckbox)

        yPosition -= 25
        showResetCheckbox = NSButton(checkboxWithTitle: "Reset time", target: self, action: #selector(displayModeChanged))
        showResetCheckbox.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        showResetCheckbox.tag = 3
        contentView.addSubview(showResetCheckbox)

        yPosition -= 30
        showIndicatorCheckbox = NSButton(checkboxWithTitle: "Show color indicator (🟢🟡🔴)", target: self, action: #selector(showIndicatorChanged))
        showIndicatorCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
        contentView.addSubview(showIndicatorCheckbox)

        yPosition -= 40
        let separatorLine2 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine2.boxType = .separator
        contentView.addSubview(separatorLine2)

        yPosition -= 30
        let launchAtLoginTitleLabel = NSTextField(labelWithString: "Startup")
        launchAtLoginTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        launchAtLoginTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(launchAtLoginTitleLabel)

        yPosition -= 30
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Apri MiniMaxUsage all'accesso", target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
        contentView.addSubview(launchAtLoginCheckbox)

        yPosition -= 40
        let separatorLine3 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
        separatorLine3.boxType = .separator
        contentView.addSubview(separatorLine3)

        yPosition -= 30
        let refreshTitleLabel = NSTextField(labelWithString: "Refresh Interval")
        refreshTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        refreshTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(refreshTitleLabel)

        yPosition -= 30
        refreshPopup = NSPopUpButton(frame: NSRect(x: 20, y: yPosition, width: 200, height: 25))
        for (title, _) in refreshOptions {
            refreshPopup.addItem(withTitle: title)
        }
        refreshPopup.target = self
        refreshPopup.action = #selector(refreshIntervalChanged)
        contentView.addSubview(refreshPopup)
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
