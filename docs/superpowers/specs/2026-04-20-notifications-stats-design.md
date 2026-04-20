# Phase 1 — Notifications & Statistics Tab

> **Date:** 2026-04-20
> **Project:** MiniMaxUsage macOS Menu Bar App
> **Phase:** 1 of 3 (Multi-Provider expansion future roadmap)

## Overview

Add two major features to MiniMaxUsage:
1. **Proactive notifications** with customizable threshold sliders
2. **Statistics tab** in Preferences showing usage history with 7d/30d charts

---

## Feature 1: Notification System

### Trigger Configuration (Segmented Dual Slider)

Located in **Preferences → Notifications** section (new section or integrated into existing).

**UI:** Three-segment slider (green → yellow → red) with draggable dividers.
- **Green zone:** Normal operation, no notification
- **Yellow zone:** Warning alert triggers at this percentage
- **Red zone:** Critical alert triggers at this percentage

**Default values:**
- Warning: 50%
- Critical: 80%

**Quota-specific behavior:**
- 5h/Weekly quotas: Warning at user-set %, Critical at user-set %
- Daily Budget: Warning at user-set %, Critical at user-set % (separate thresholds per quota type possible in future)

**Notification events:**
- Usage crosses warning threshold
- Usage crosses critical threshold
- Quota resets (5h reset, weekly reset)
- Daily budget exceeded

**Notification types (per event toggle):**
- 🔔 Warning threshold crossed
- 🚨 Critical threshold crossed
- 🔄 Quota reset
- ⚠️ Daily budget exceeded

### Notification Storage
- User preferences stored in `UserDefaults`
- Keys: `notifyWarningEnabled`, `notifyCriticalEnabled`, `notifyResetEnabled`, `notifyDailyBudgetEnabled`
- Thresholds: `warningThreshold` (Double), `criticalThreshold` (Double)

---

## Feature 2: Statistics Tab

### Location
New tab in Preferences window called **"Statistics"** (tab icon: `chart.bar.fill` SF Symbol).

### Tab Layout (Top to Bottom)

#### 1. Summary Card (Current Status)
Displays at-a-glance current quota status:

```
┌─────────────────────────────────────────────┐
│  TODAY'S USAGE          WEEKLY USAGE        │
│  🟢 45%  450/1k        🟡 32%  8200/25k   │
│  Budget: 1.8k/day       Reset: 3d 6h        │
└─────────────────────────────────────────────┘
```

- Two-column layout
- Each column shows: quota name, percentage + status icon, usage numbers, budget or reset time
- Colors match current thresholds
- Clicking a column filters the chart below to that quota type

#### 2. Timeframe Toggle
Segmented control above chart:
- **[7 Days] [30 Days]**
- Default selection: whichever quota type user has selected in menu bar preferences

#### 3. Usage Chart
Swift Charts line graph:

**Axes:**
- X-axis: Date/time
- Y-axis: Usage count (auto-scaling)

**Lines:**
- One line per quota type (5h, Weekly, Daily Budget)
- Color-coded matching status colors
- Dotted line for budget target (Daily only)

**Interactivity:**
- Hover to see exact values
- Click on legend to toggle line visibility

#### 4. Refresh & Export
Bottom bar:
- **Refresh** button (manual reload)
- **Export CSV** button (exports displayed data range)

### Data Storage for History
- Store usage snapshots in `UserDefaults` or JSON file in `Application Support`
- Schema version: 1
- Snapshot: timestamp, usage counts per model, quota type
- Retention: 30 days (auto-cleanup old entries)
- Save new snapshot on each API refresh

---

## Files to Modify

| File | Changes |
|------|---------|
| `MiniMaxUsage/Sources/PreferencesWindow.swift` | Add Statistics tab with SwiftUI hosted view |
| `MiniMaxUsage/Sources/ApiService.swift` | No changes |
| `MiniMaxUsage/Sources/MenuBarController.swift` | Trigger notifications on threshold cross |
| `MiniMaxUsage/Sources/SettingsHelper.swift` | Add notification preferences, history storage |
| `MiniMaxUsage/Sources/Models.swift` | Add history data model |

---

## Notification Flow

```
API refresh → Compare to previous → Check thresholds
           → If crossed warning AND notifyWarningEnabled → Send notification
           → If crossed critical AND notifyCriticalEnabled → Send notification
           → If reset detected AND notifyResetEnabled → Send notification
           → If daily budget exceeded AND notifyDailyBudgetEnabled → Send notification
```

### Notification Content
- **Warning:** "MiniMaxUsage: 5h window at [X]% — approaching limit"
- **Critical:** "MiniMaxUsage: 5h window at [X]% — critical!"
- **Reset:** "MiniMaxUsage: [Quota type] quota reset"
- **Budget exceeded:** "MiniMaxUsage: Daily budget exceeded!"

---

## Implementation Notes

### SwiftUI in AppKit
Use `NSHostingView` to embed SwiftUI views in AppKit window:
```swift
let hostingView = NSHostingView(rootView: StatisticsTabView())
preferencesWindow.contentView.addSubview(hostingView)
```

### Swift Charts
Use `Chart` from Swift Charts (macOS 13+). Data model:
```swift
struct UsageSnapshot: Codable {
    let timestamp: Date
    let fiveHourUsed: Int
    let fiveHourTotal: Int
    let weeklyUsed: Int
    let weeklyTotal: Int
    let dailyUsed: Int
    let dailyBudget: Int
}
```

### Notification Authorization
Request notification permission on first launch (macOS 11+):
```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in }
```

---

## Verification Checklist

- [ ] Statistics tab appears in Preferences with correct icon
- [ ] Summary card shows current status for all 3 quota types
- [ ] 7d/30d toggle switches chart timeframe
- [ ] Chart renders usage data correctly
- [ ] Notification sliders save and restore values
- [ ] Notifications fire when threshold crossed (test with simulated values)
- [ ] Notifications appear in macOS Notification Center
- [ ] CSV export produces valid file
- [ ] Old history data cleaned up after 30 days

---

## Status

**Design approved** — Ready to proceed to writing-plans skill.
