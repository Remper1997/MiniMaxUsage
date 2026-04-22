import SwiftUI
import Charts
import UniformTypeIdentifiers

struct StatisticsTabView: View {
    @State private var selectedTimeframe: Timeframe = .sevenDays
    @State private var snapshots: [UsageSnapshot] = []
    @State private var selectedQuotaType: QuotaType = .fiveHour
    @State private var isLoading = false
    @State private var showExportSuccess = false

    enum Timeframe: String, CaseIterable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                // Summary Card
                SummaryCardView(snapshots: snapshots)
                    .padding(.horizontal)

                if snapshots.isEmpty && !isLoading {
                    Text("No data available yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Timeframe Toggle
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { tf in
                        Text(tf.rawValue).tag(tf)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedTimeframe) { _ in
                    loadData()
                }

                // Chart
                if #available(macOS 13.0, *) {
                    UsageChartView(snapshots: snapshots, selectedQuotaType: selectedQuotaType, selectedTimeframe: selectedTimeframe)
                        .frame(minHeight: 180)
                        .padding(.horizontal)
                } else {
                    Text("Charts require macOS 13 or later")
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Bottom buttons
                HStack(spacing: 12) {
                    Button(action: refreshData) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button(action: exportCSV) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    // Quota type selector
                    Picker("Quota", selection: $selectedQuotaType) {
                        ForEach(QuotaType.allCases, id: \.self) { qt in
                            Text(qt.displayName).tag(qt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .onChange(of: selectedQuotaType) { newValue in
                        // Default to 7 days for daily, keep current for others
                        if newValue == .daily {
                            selectedTimeframe = .sevenDays
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
        }
        .frame(minWidth: 430, minHeight: 480)
        .onAppear {
            selectedQuotaType = QuotaType(rawValue: SettingsHelper.quotaType.rawValue) ?? .fiveHour
            loadData()
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Usage data exported to CSV.")
        }
    }

    private var mostRecentSnapshot: UsageSnapshot? {
        snapshots.last
    }

    private func loadData() {
        isLoading = true
        DispatchQueue.global().async {
            let data: [UsageSnapshot]
            switch self.selectedTimeframe {
            case .sevenDays:
                data = HistoryStorage.shared.loadSnapshots7d()
            case .thirtyDays:
                data = HistoryStorage.shared.loadSnapshots30d()
            }
            DispatchQueue.main.async {
                self.snapshots = data
                self.isLoading = false
            }
        }
    }

    private func refreshData() {
        NotificationCenter.default.post(name: .forceRefreshStats, object: nil)
        loadData()
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "MiniMaxUsage_Export.csv"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                var csvContent = "Date,5h Used,Weekly Used,Daily Used,Daily Budget\n"
                for snapshot in snapshots {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                    let dateStr = dateFormatter.string(from: snapshot.timestamp)
                    csvContent += "\(dateStr),\(snapshot.fiveHourUsed),\(snapshot.weeklyUsed),\(snapshot.dailyUsed),\(snapshot.dailyBudget)\n"
                }
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    showExportSuccess = true
                } catch {
                    print("Failed to export CSV: \(error)")
                }
            }
        }
    }
}

struct SummaryCardView: View {
    let snapshots: [UsageSnapshot]

    private var mostRecentSnapshot: UsageSnapshot? {
        snapshots.last
    }

    // Use UTC timezone to avoid day boundary issues with local time
    private var utcCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var dailyAverageUsage: Int {
        guard !snapshots.isEmpty else { return 0 }
        // Group snapshots by day and take only the LAST snapshot of each day
        // (dailyUsed is cumulative, so last snapshot of day = final total for that day)
        let calendar = utcCalendar
        var lastSnapshotOfDay: [Date: UsageSnapshot] = [:]

        for snapshot in snapshots {
            let dayStart = calendar.startOfDay(for: snapshot.timestamp)
            if let existing = lastSnapshotOfDay[dayStart] {
                if snapshot.timestamp > existing.timestamp {
                    lastSnapshotOfDay[dayStart] = snapshot
                }
            } else {
                lastSnapshotOfDay[dayStart] = snapshot
            }
        }

        let uniqueDays = lastSnapshotOfDay.count
        guard uniqueDays > 0 else { return 0 }

        let totalUsage = lastSnapshotOfDay.values.reduce(0) { $0 + $1.dailyUsed }
        return totalUsage / uniqueDays
    }

    private var dailyTrend: String {
        guard snapshots.count >= 2 else { return "--" }
        let calendar = utcCalendar
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        let recentSnapshots = snapshots.filter { $0.timestamp >= sevenDaysAgo }
        let olderSnapshots = snapshots.filter { $0.timestamp >= fourteenDaysAgo && $0.timestamp < sevenDaysAgo }

        guard !recentSnapshots.isEmpty, !olderSnapshots.isEmpty else { return "--" }

        let recentAvg = averageDailyUsageFromSnapshots(snapshots: recentSnapshots)
        let olderAvg = averageDailyUsageFromSnapshots(snapshots: olderSnapshots)

        guard olderAvg > 0 else { return "--" }

        let changePercent = Double(recentAvg - olderAvg) / Double(olderAvg) * 100
        if changePercent > 0 {
            return "↑ \(Int(abs(changePercent)))%"
        } else if changePercent < 0 {
            return "↓ \(Int(abs(changePercent)))%"
        } else {
            return "→ 0%"
        }
    }

    private func averageDailyUsageFromSnapshots(snapshots: [UsageSnapshot]) -> Int {
        let calendar = utcCalendar
        var lastSnapshotOfDay: [Date: UsageSnapshot] = [:]

        for snapshot in snapshots {
            let dayStart = calendar.startOfDay(for: snapshot.timestamp)
            if let existing = lastSnapshotOfDay[dayStart] {
                if snapshot.timestamp > existing.timestamp {
                    lastSnapshotOfDay[dayStart] = snapshot
                }
            } else {
                lastSnapshotOfDay[dayStart] = snapshot
            }
        }

        let uniqueDays = lastSnapshotOfDay.count
        guard uniqueDays > 0 else { return 0 }

        let totalUsage = lastSnapshotOfDay.values.reduce(0) { $0 + $1.dailyUsed }
        return totalUsage / uniqueDays
    }

    var body: some View {
        HStack(spacing: 0) {
            // Today's Usage column
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S USAGE")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let snapshot = mostRecentSnapshot {
                    HStack(spacing: 4) {
                        statusIcon(for: snapshot.dailyUsedPercent)
                        Text("\(Int(snapshot.dailyUsedPercent * 100))%")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("\(snapshot.dailyUsed)/\(snapshot.dailyBudget)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("Avg: \(formatNumber(dailyAverageUsage))/day")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(dailyTrend)
                            .font(.system(size: 10))
                            .foregroundColor(dailyTrend.contains("↑") ? .red : (dailyTrend.contains("↓") ? .green : .secondary))
                    }
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 50)

            // Weekly Usage column
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY USAGE")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let snapshot = mostRecentSnapshot {
                    HStack(spacing: 4) {
                        statusIcon(for: snapshot.weeklyUsedPercent)
                        Text("\(Int(snapshot.weeklyUsedPercent * 100))%")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("\(snapshot.weeklyUsed)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Reset: \(daysUntilWeeklyReset)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private func statusIcon(for percent: Double) -> some View {
        let color: Color = percent < 0.5 ? .green : (percent < 0.8 ? .yellow : .red)
        let icon: String = percent < 0.5 ? "🟢" : (percent < 0.8 ? "🟡" : "🔴")
        return Text(icon).font(.system(size: 14))
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000)
        }
        return "\(num)"
    }

    private var daysUntilWeeklyReset: String {
        guard let snapshot = mostRecentSnapshot else { return "--" }
        // Estimate days until reset based on weekly usage
        let weeklyTotal = snapshot.weeklyUsed + (snapshot.dailyBudget * 7)
        if weeklyTotal > 0 {
            let usageRate = Double(snapshot.dailyUsed) / 7.0
            if usageRate > 0 {
                let daysLeft = Int(Double(weeklyTotal - snapshot.weeklyUsed) / usageRate)
                return "\(max(0, daysLeft))d"
            }
        }
        return "?"
    }
}

extension Notification.Name {
    static let forceRefreshStats = Notification.Name("forceRefreshStats")
}

@available(macOS 13.0, *)
struct UsageChartView: View {
    let snapshots: [UsageSnapshot]
    let selectedQuotaType: QuotaType
    let selectedTimeframe: StatisticsTabView.Timeframe

    // For daily: show only the peak (maximum) of each day
    private var displaySnapshots: [UsageSnapshot] {
        if selectedQuotaType != .daily {
            return snapshots
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var peakOfDay: [Date: UsageSnapshot] = [:]

        for snapshot in snapshots {
            let dayStart = calendar.startOfDay(for: snapshot.timestamp)
            if let existing = peakOfDay[dayStart] {
                if snapshot.dailyUsed > existing.dailyUsed {
                    peakOfDay[dayStart] = snapshot
                }
            } else {
                peakOfDay[dayStart] = snapshot
            }
        }

        return peakOfDay.values.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        Chart {
            ForEach(displaySnapshots, id: \.timestamp) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.timestamp),
                    y: .value("Used", usageFor(snapshot))
                )
                .foregroundStyle(colorForUsage(snapshot))

                if selectedQuotaType == .daily {
                    // Budget line at 100%
                    LineMark(
                        x: .value("Date", snapshot.timestamp),
                        y: .value("Budget", 100)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: selectedTimeframe == .sevenDays ? 1 : 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                if selectedQuotaType == .daily {
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(doubleValue))%")
                        }
                    }
                } else {
                    AxisValueLabel()
                }
            }
        }
        .chartYScale(domain: selectedQuotaType == .daily ? 0...150 : 0...5000)
    }

    private func usageFor(_ snapshot: UsageSnapshot) -> Double {
        switch selectedQuotaType {
        case .fiveHour:
            return Double(snapshot.fiveHourUsed)
        case .weekly:
            return Double(snapshot.weeklyUsed)
        case .daily:
            return snapshot.dailyUsedPercent * 100  // Return as percentage 0-100+
        }
    }

    private func colorForUsage(_ snapshot: UsageSnapshot) -> Color {
        let percent: Double
        switch selectedQuotaType {
        case .fiveHour:
            percent = snapshot.fiveHourUsedPercent
        case .weekly:
            percent = snapshot.weeklyUsedPercent
        case .daily:
            percent = snapshot.dailyUsedPercent
        }

        if percent < 0.5 {
            return .green
        } else if percent < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}
