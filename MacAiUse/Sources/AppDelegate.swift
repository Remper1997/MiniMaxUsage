import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var apiService: ApiService?
    private var preferencesWindow: PreferencesWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        apiService = ApiService()
        menuBarController = MenuBarController(apiService: apiService!)

        NotificationCenter.default.addObserver(
            forName: .showPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPreferences()
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
