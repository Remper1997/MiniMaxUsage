# Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-update functionality using Sparkle 2.x with automatic background checks and manual trigger

**Architecture:** Sparkle handles update checking, download, and installation. AppDelegate initializes updater. PreferencesWindow provides user controls. SettingsHelper persists user preferences.

**Tech Stack:** Sparkle 2.x (SPM), ServiceManagement

---

## File Structure

- **Modify:** `project.yml` — Add Sparkle SPM dependency
- **Modify:** `Info.plist` — Add Sparkle configuration
- **Modify:** `MiniMaxUsage.entitlements` — Add outgoing network if needed
- **Create:** `MiniMaxUsage/Sources/UpdateController.swift` — Sparkle wrapper
- **Modify:** `MiniMaxUsage/Sources/SettingsHelper.swift` — Add autoUpdateEnabled, lastUpdateCheck
- **Modify:** `MiniMaxUsage/Sources/AppDelegate.swift` — Initialize updater
- **Modify:** `MiniMaxUsage/Sources/PreferencesWindow.swift` — Add Updates section

---

## Task 1: Add Sparkle SPM Dependency

**Files:**
- Modify: `project.yml:1-33`

- [ ] **Step 1: Add SPM packages section to project.yml**

Find line 17 (`targets:`) and add before it:
```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.0.0
```

- [ ] **Step 2: Add Sparkle dependency to target**

In `targets.MiniMaxUsage`, add `dependencies` section:
```yaml
dependencies:
  - package: Sparkle
    product: Sparkle
```

The target section should look like:
```yaml
targets:
  MiniMaxUsage:
    type: application
    platform: macOS
    sources:
      - path: MiniMaxUsage/Sources
        type: group
    dependencies:
      - package: Sparkle
        product: Sparkle
    settings:
      base:
        ...
```

- [ ] **Step 3: Regenerate project**

```bash
xcodegen generate
```

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "feat: add Sparkle SPM dependency for auto-update"
```

---

## Task 2: Add UpdateController

**Files:**
- Create: `MiniMaxUsage/Sources/UpdateController.swift`

- [ ] **Step 1: Create UpdateController.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add MiniMaxUsage/Sources/UpdateController.swift
git commit -m "feat: add UpdateController with Sparkle integration"
```

---

## Task 3: Add autoUpdate settings to SettingsHelper

**Files:**
- Modify: `MiniMaxUsage/Sources/SettingsHelper.swift`

- [ ] **Step 1: Add new keys**

After line 15 (`launchAtLoginKey`), add:
```swift
private static let autoUpdateEnabledKey = "autoUpdateEnabled"
private static let lastUpdateCheckKey = "lastUpdateCheck"
```

- [ ] **Step 2: Add autoUpdateEnabled property**

After the `launchAtLogin` property (after line 90), add:
```swift
static var autoUpdateEnabled: Bool {
    get {
        if UserDefaults.standard.object(forKey: autoUpdateEnabledKey) == nil {
            return true  // Default to enabled
        }
        return UserDefaults.standard.bool(forKey: autoUpdateEnabledKey)
    }
    set {
        UserDefaults.standard.set(newValue, forKey: autoUpdateEnabledKey)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

static var lastUpdateCheck: Date? {
    get {
        return UserDefaults.standard.object(forKey: lastUpdateCheckKey) as? Date
    }
    set {
        UserDefaults.standard.set(newValue, forKey: lastUpdateCheckKey)
    }
}

static var lastUpdateCheckFormatted: String {
    guard let lastCheck = lastUpdateCheck else {
        return "Never"
    }
    let interval = Date().timeIntervalSince(lastCheck)
    if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MiniMaxUsage/Sources/SettingsHelper.swift
git commit -m "feat: add autoUpdate settings to SettingsHelper"
```

---

## Task 4: Modify AppDelegate to initialize Sparkle

**Files:**
- Modify: `MiniMaxUsage/Sources/AppDelegate.swift`

- [ ] **Step 1: Add UpdateController property**

After line 4 (`private var preferencesWindow`), add:
```swift
private var updateController: UpdateController?
```

- [ ] **Step 2: Initialize update controller and start checks**

In `applicationDidFinishLaunching()`, after line 13 (`menuBarController = MenuBarController...`), add:
```swift
updateController = UpdateController()
if SettingsHelper.autoUpdateEnabled {
    updateController?.startAutomaticChecks()
}
```

- [ ] **Step 3: Commit**

```bash
git add MiniMaxUsage/Sources/AppDelegate.swift
git commit -m "feat: initialize Sparkle updater in AppDelegate"
```

---

## Task 5: Add Updates section to PreferencesWindow

**Files:**
- Modify: `MiniMaxUsage/Sources/PreferencesWindow.swift`

- [ ] **Step 1: Add properties**

After line 16 (`private var launchAtLoginCheckbox`), add:
```swift
private var autoUpdateCheckbox: NSButton!
private var lastCheckedLabel: NSTextField!
private var checkNowButton: NSButton!
```

- [ ] **Step 2: Add Updates section UI**

Find the section at the end of `setupUI()` where `refreshPopup` is added (around line 174). After the refreshPopup setup block (line 180), add:
```swift
yPosition -= 40
let separatorLine4 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
separatorLine4.boxType = .separator
contentView.addSubview(separatorLine4)

yPosition -= 30
let updatesTitleLabel = NSTextField(labelWithString: "Updates")
updatesTitleLabel.font = NSFont.boldSystemFont(ofSize: 14)
updatesTitleLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
contentView.addSubview(updatesTitleLabel)

yPosition -= 30
autoUpdateCheckbox = NSButton(checkboxWithTitle: "Check for updates automatically", target: self, action: #selector(autoUpdateChanged))
autoUpdateCheckbox.frame = NSRect(x: 20, y: yPosition, width: 250, height: 20)
contentView.addSubview(autoUpdateCheckbox)

yPosition -= 25
lastCheckedLabel = NSTextField(labelWithString: "Last checked: \(SettingsHelper.lastUpdateCheckFormatted)")
lastCheckedLabel.frame = NSRect(x: 40, y: yPosition, width: 200, height: 20)
lastCheckedLabel.font = NSFont.systemFont(ofSize: 11)
lastCheckedLabel.textColor = .secondaryLabelColor
contentView.addSubview(lastCheckedLabel)

yPosition -= 25
checkNowButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdatesNow))
checkNowButton.frame = NSRect(x: 40, y: yPosition, width: 150, height: 24)
checkNowButton.bezelStyle = .rounded
contentView.addSubview(checkNowButton)
```

- [ ] **Step 3: Load autoUpdate state**

In `loadDisplaySettings()` after line 205, add:
```swift
autoUpdateCheckbox.state = SettingsHelper.autoUpdateEnabled ? .on : .off
```

- [ ] **Step 4: Add handler methods**

After `launchAtLoginChanged()` (after line 257), add:
```swift
@objc private func autoUpdateChanged(_ sender: NSButton) {
    let enabled = sender.state == .on
    SettingsHelper.autoUpdateEnabled = enabled

    if enabled {
        // Access AppDelegate's updateController via NotificationCenter or shared instance
        NotificationCenter.default.post(name: .enableAutoUpdate, object: nil)
    } else {
        NotificationCenter.default.post(name: .disableAutoUpdate, object: nil)
    }
}

@objc private func checkForUpdatesNow() {
    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    lastCheckedLabel.stringValue = "Last checked: Just now"
}
```

- [ ] **Step 5: Add notification names**

In SettingsHelper.swift or a new extension, add:
```swift
extension Notification.Name {
    static let enableAutoUpdate = Notification.Name("enableAutoUpdate")
    static let disableAutoUpdate = Notification.Name("disableAutoUpdate")
    static let checkForUpdates = Notification.Name("checkForUpdates")
}
```

- [ ] **Step 6: Handle notifications in AppDelegate**

In AppDelegate.swift, add observers in `applicationDidFinishLaunching()`:
```swift
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
```

- [ ] **Step 7: Increase window height**

In `PreferencesWindow.swift` line 38, change contentView height from 480 to 560:
```swift
let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 560))
```

And window height from 380 to 440:
```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 450, height: 440),
    ...
)
```

- [ ] **Step 8: Commit**

```bash
git add MiniMaxUsage/Sources/PreferencesWindow.swift MiniMaxUsage/Sources/AppDelegate.swift MiniMaxUsage/Sources/SettingsHelper.swift
git commit -m "feat: add Updates section to PreferencesWindow with Sparkle integration"
```

---

## Task 6: Configure Info.plist for Sparkle

**Files:**
- Modify: `MiniMaxUsage/Resources/Info.plist`

- [ ] **Step 1: Add Sparkle configuration**

Add before `</dict>`:
```xml
<key>SPU-standard-update-driver-prompt-color-map</key>
<dict/>
```

- [ ] **Step 2: Commit**

```bash
git add MiniMaxUsage/Resources/Info.plist
git commit -m "chore: add Sparkle Info.plist keys"
```

---

## Verification

- [ ] **Build:** `xcodegen generate && xcodebuild -project MiniMaxUsage.xcodeproj -scheme MiniMaxUsage -configuration Release build 2>&1 | tail -20`
- [ ] **Open Preferences:** Verify "Updates" section appears
- [ ] **Toggle automatic updates:** Verify setting persists
- [ ] **Click "Check for Updates":** Verify Sparkle dialog appears (or "no updates" if current)
- [ ] **Verify DMG signing:** For Sparkle to work, the app bundle needs proper code signing
