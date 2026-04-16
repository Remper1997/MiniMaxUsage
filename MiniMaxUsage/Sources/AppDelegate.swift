import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var apiService: ApiService?
    private var preferencesWindow: PreferencesWindow?
    private var updateController: UpdateController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        apiService = ApiService()
        menuBarController = MenuBarController(apiService: apiService!)
        updateController = UpdateController()
        if SettingsHelper.autoUpdateEnabled {
            updateController?.startAutomaticChecks()
        }

        NotificationCenter.default.addObserver(
            forName: .showPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPreferences()
        }

        NotificationCenter.default.addObserver(
            forName: .enableAutoUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateController?.startAutomaticChecks()
        }

        NotificationCenter.default.addObserver(
            forName: .disableAutoUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateController?.stopAutomaticChecks()
        }

        NotificationCenter.default.addObserver(
            forName: .checkForUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateController?.checkForUpdates()
            SettingsHelper.lastUpdateCheck = Date()
        }

        if KeychainHelper.getAPIKey() == nil {
            showPreferences()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stopTimer()
    }

    @objc func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow(apiService: apiService!, menuBarController: menuBarController)
        }
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let enableAutoUpdate = Notification.Name("enableAutoUpdate")
    static let disableAutoUpdate = Notification.Name("disableAutoUpdate")
    static let checkForUpdates = Notification.Name("checkForUpdates")
}
