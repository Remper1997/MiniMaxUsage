import Foundation
import Sparkle

class UpdateController {
    private let updater: SPUStandardUpdaterController
    private var checkTimer: Timer?

    init() {
        updater = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var updaterController: SPUStandardUpdaterController {
        return updater
    }

    func startAutomaticChecks(interval: TimeInterval = 86400) {
        stopAutomaticChecks()
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    func stopAutomaticChecks() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func checkForUpdates() {
        updater.checkForUpdates(nil)
    }

    func setAutomaticUpdateEnabled(_ enabled: Bool) {
        if enabled {
            startAutomaticChecks()
        } else {
            stopAutomaticChecks()
        }
    }

    deinit {
        stopAutomaticChecks()
    }
}