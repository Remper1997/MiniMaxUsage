import SwiftUI
import Charts

struct StatisticsTabView: View {
    @State private var selectedTimeframe: Timeframe = .sevenDays
    @State private var snapshots: [UsageSnapshot] = []
    @State private var selectedQuotaType: QuotaType = .fiveHour
    @State private var isLoading = false

    enum Timeframe: String, CaseIterable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
    }

    var body: some View {
        VStack(spacing: 16) {
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
                UsageChartView(snapshots: snapshots, selectedQuotaType: selectedQuotaType)
                    .frame(minHeight: 200)
                    .padding(.horizontal)
            } else {
                Text("Charts require macOS 13 or later")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.top)
        .onAppear {
            selectedQuotaType = QuotaType(rawValue: SettingsHelper.quotaType.rawValue) ?? .fiveHour
            loadData()
        }
    }

    private func loadData() {
        isLoading = true
        DispatchQueue.global().async {
            let data: [UsageSnapshot]
            switch selectedTimeframe {
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
}

@available(macOS 13.0, *)
struct UsageChartView: View {
    let snapshots: [UsageSnapshot]
    let selectedQuotaType: QuotaType

    var body: some View {
        Chart {
            ForEach(snapshots, id: \.timestamp) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.timestamp),
                    y: .value("Used", usageFor(snapshot))
                )
                .foregroundStyle(colorFor(selectedQuotaType))

                if selectedQuotaType == .daily {
                    LineMark(
                        x: .value("Date", snapshot.timestamp),
                        y: .value("Budget", snapshot.dailyBudget)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: selectedQuotaType == .sevenDays ? 1 : 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }

    private func usageFor(_ snapshot: UsageSnapshot) -> Int {
        switch selectedQuotaType {
        case .fiveHour:
            return snapshot.fiveHourUsed
        case .weekly:
            return snapshot.weeklyUsed
        case .daily:
            return snapshot.dailyUsed
        }
    }

    private func colorFor(_ quotaType: QuotaType) -> Color {
        switch quotaType {
        case .fiveHour, .weekly:
            return .green
        case .daily:
            return .orange
        }
    }
}
