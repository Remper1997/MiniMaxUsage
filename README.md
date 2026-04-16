# MiniMaxUsage

**macOS Menu Bar App for MiniMax API Usage Monitoring**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

MiniMaxUsage is a lightweight menu bar application that monitors and displays your MiniMax API usage quotas in real-time. It runs silently in your menu bar without a Dock icon, showing your usage statistics at a glance.

## Features

### 📊 Multiple Quota Views

- **5-Hour Window**: Track your requests within the current 5-hour rolling window
- **Weekly**: Monitor your weekly quota usage and reset countdown
- **Daily Budget**: Dynamic daily budget calculated from your weekly remaining requests divided by days left until reset

### 🎨 Color-Coded Status

| Indicator | Meaning |
|-----------|---------|
| 🟢 Green | Usage under threshold (normal) |
| 🟡 Yellow/Orange | Usage approaching limit (warning) |
| 🔴 Red | Usage exceeded or critical |

Thresholds:
- **5h/Weekly**: 🟢 <50%, 🟡 50-80%, 🔴 >80%
- **Daily Budget**: 🟢 <80%, 🟡 80-100%, 🔴 >100%

### ⚙️ Customizable Display

Choose what to show in your menu bar:
- Percentage of usage
- Requests used/total
- Time until reset
- Color indicator

### 🔒 Secure API Key Storage

Your MiniMax API key is stored securely in the macOS Keychain, never in plain text.

### ⏱️ Automatic Refresh

Configurable refresh interval from 30 seconds to 30 minutes.

## Installation

### Option 1: Homebrew (Recommended)

```bash
brew install --cask minimaxusage
```

> Note: If the Homebrew formula isn't available yet, you can install via Option 2.

### Option 2: Download Release

1. Go to the [Releases page](https://github.com/Remper1997/MiniMaxUsage/releases)
2. Download the latest `.dmg` file
3. Open the DMG and drag **MiniMaxUsage.app** to your Applications folder
4. Launch MiniMaxUsage from Applications

### Option 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/Remper1997/MiniMaxUsage.git
cd MiniMaxUsage

# Generate Xcode project (requires XcodeGen)
xcodegen generate

# Open in Xcode and build
open MiniMaxUsage.xcodeproj
```

**Requirements for building from source:**
- macOS 14.0 or later
- Xcode 15.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

1. **Launch MiniMaxUsage** from your Applications folder or via Spotlight
2. Click on the menu bar icon and select **Preferences...**
3. Enter your MiniMax API key (starts with `sk-cp-`)
4. Click **Save & Test** to verify your key works

Your API key is securely stored in your macOS Keychain.

## Usage

### Menu Bar Display

The menu bar shows colored indicators and usage stats:

```
🟢 45% 1200/3000 4h 30m
```

You can customize which elements are shown in Preferences.

### Dropdown Menu

Click the menu bar icon to see:
- **Refresh**: Manually refresh usage data
- **Preferences...**: Open settings
- **Quit MiniMaxUsage**: Exit the app

The dropdown also shows the "other" quota types not currently selected as your primary view.

### Quota Type Selection

In Preferences, choose which quota type to display:
- **5-hour window**: Best for tracking short-term burst usage
- **Weekly**: Monitor your weekly quota consumption
- **Daily Budget**: Dynamic budget to pace your usage across the week

## How It Works

MiniMaxUsage polls the MiniMax API endpoint `/coding_plan/remains` at your chosen interval to fetch your current usage statistics.

For the **Daily Budget** feature:
- Budget = Weekly Remaining ÷ Days Left until reset
- Today's usage is tracked by comparing your remaining quota at the start of each day vs. now
- Colors indicate if your daily usage is on track (🟢), warning (🟡), or exceeded (🔴)

The daily budget is calculated once at the start of each day and remains fixed for the entire day.

## Privacy

- MiniMaxUsage only communicates with MiniMax's API servers
- No usage data is collected or sent elsewhere
- Your API key is stored only in your local macOS Keychain

## Uninstall

```bash
# If installed via Homebrew
brew uninstall --cask minimaxusage

# Remove from Applications
rm -rf /Applications/MiniMaxUsage.app

# Optional: Remove user preferences
rm -rf ~/Library/Preferences/com.minimaxusage.MiniMaxUsage.plist
rm -rf ~/Library/Application\ Support/MiniMaxUsage/
```

To remove the API key from Keychain:
```bash
security delete-generic-password -s com.minimaxusage.MiniMaxUsage
```

## License

This project is available under the MIT License.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.