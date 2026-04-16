# Auto-Launch at Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "Apri all'accesso" option in Preferences using SMAppService

**Architecture:** Single setting persisted via UserDefaults, checkbox in PreferencesWindow toggles SMAppService.mainApp.register()/unregister()

**Tech Stack:** ServiceManagement (SMAppService), UserDefaults

---

## Task 1: Add `launchAtLogin` to SettingsHelper

**Files:**
- Modify: `MiniMaxUsage/Sources/SettingsHelper.swift:9-15`

- [ ] **Step 1: Add UserDefaults key constant**

After line 14 (`showResetTimeKey`), add:
```swift
private static let launchAtLoginKey = "launchAtLogin"
```

- [ ] **Step 2: Add launchAtLogin computed property**

After the `showResetTime` property (after line 79), add:
```swift
static var launchAtLogin: Bool {
    get {
        return UserDefaults.standard.bool(forKey: launchAtLoginKey)
    }
    set {
        UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MiniMaxUsage/Sources/SettingsHelper.swift
git commit -m "feat: add launchAtLogin setting to SettingsHelper

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Add checkbox UI to PreferencesWindow

**Files:**
- Modify: `MiniMaxUsage/Sources/PreferencesWindow.swift:1-15`
- Modify: `MiniMaxUsage/Sources/PreferencesWindow.swift:144-163`

- [ ] **Step 1: Add launchAtLoginCheckbox property**

After line 14 (`showResetCheckbox`), add:
```swift
private var launchAtLoginCheckbox: NSButton!
```

- [ ] **Step 2: Add separator and section before Refresh Interval**

After the closing brace of `showIndicatorChanged` (around line 206), add a new section before `refreshIntervalChanged`. Find line 149-153:
```swift
yPosition -= 40
let separatorLine2 = NSBox(frame: NSRect(x: 20, y: yPosition, width: 410, height: 1))
separatorLine2.boxType = .separator
contentView.addSubview(separatorLine2)

yPosition -= 30
let refreshTitleLabel = NSTextField(labelWithString: "Refresh Interval")
```

Replace with:
```swift
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
```

- [ ] **Step 3: Load launchAtLogin state**

In `loadDisplaySettings()` after line 186, add:
```swift
launchAtLoginCheckbox.state = SettingsHelper.launchAtLogin ? .on : .off
```

- [ ] **Step 4: Add launchAtLoginChanged handler**

After `showIndicatorChanged()` (after line 206), add:
```swift
@objc private func launchAtLoginChanged(_ sender: NSButton) {
    let enable = sender.state == .on
    SettingsHelper.launchAtLogin = enable

    if enable {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // If registration fails (e.g., requires approval), update checkbox to match actual state
            let actualStatus = SMAppService.mainApp.status
            if actualStatus != .enabled {
                sender.state = .off
                SettingsHelper.launchAtLogin = false
            }
        }
    } else {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            // If unregistration fails, restore checkbox
            sender.state = .on
            SettingsHelper.launchAtLogin = true
        }
    }
}
```

- [ ] **Step 5: Import ServiceManagement**

Add at the top of the file, after line 1:
```swift
import ServiceManagement
```

- [ ] **Step 6: Commit**

```bash
git add MiniMaxUsage/Sources/PreferencesWindow.swift
git commit -m "feat: add launch at login checkbox to PreferencesWindow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Verification

- [ ] **Build:** `xcodebuild -project MiniMaxUsage.xcodeproj -scheme MiniMaxUsage -configuration Release build 2>&1 | tail -20`
- [ ] **Open Preferences:** Verify "Startup" section with checkbox appears
- [ ] **Toggle on:** Verify `SMAppService.mainApp.status == .enabled`
- [ ] **Toggle off:** Verify `SMAppService.mainApp.status == .notRegistered`
- [ ] **Restart Mac:** Verify app launches automatically on login
