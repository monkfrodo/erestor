#if os(iOS)
import SwiftUI
import Charts

// MARK: - Data Models

struct InsightsApiResponse: Codable {
    let ok: Bool
    let data: InsightsChartData
}

struct InsightsChartData: Codable {
    let energyTrend: [EnergyPoint]
    let qualityDistribution: QualityDist
    let timerHours: [TimerPoint]

    enum CodingKeys: String, CodingKey {
        case energyTrend = "energy_trend"
        case qualityDistribution = "quality_distribution"
        case timerHours = "timer_hours"
    }
}

struct EnergyPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let level: String  // Backend sends "4-boa", "3-ok", etc.

    var numericLevel: Int {
        Int(String(level.prefix(while: { $0.isNumber }))) ?? 3
    }
}

struct QualityDist: Codable {
    let perdi: Int
    let meh: Int
    let ok: Int
    let flow: Int
}

struct TimerPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let hours: Double
}

// MARK: - Insights View

struct iOS_InsightsView: View {
    @ObservedObject var chatService: ChatService

    @State private var chartData: InsightsChartData?
    @State private var selectedPeriod = "14d"
    @State private var isLoading = false
    @State private var loadError = false

    private let periods = ["7d", "14d", "30d"]
    private let periodLabels = ["7 dias", "14 dias", "30 dias"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period picker
                Picker("Periodo", selection: $selectedPeriod) {
                    ForEach(Array(zip(periods, periodLabels)), id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isLoading && chartData == nil {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(DS.green)
                        Text("Carregando dados...")
                            .font(DS.body(13))
                            .foregroundColor(DS.subtle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else if let data = chartData {
                    // Summary cards
                    summaryCards(data: data)

                    // Energy trend chart
                    chartCard(title: "Energia") {
                        energyChart(data: data.energyTrend)
                    }

                    // Quality distribution chart
                    chartCard(title: "Qualidade dos blocos") {
                        qualityChart(data: data.qualityDistribution)
                    }

                    // Timer hours chart
                    chartCard(title: "Horas trabalhadas") {
                        timerChart(data: data.timerHours)
                    }
                } else if loadError {
                    // Error state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 28))
                            .foregroundColor(DS.muted)
                        Text("Sem dados disponiveis")
                            .font(DS.body(14))
                            .foregroundColor(DS.subtle)
                        Text("Tente novamente mais tarde")
                            .font(DS.body(11))
                            .foregroundColor(DS.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.bottom, 20)
        }
        .background(DS.bg)
        .onChange(of: selectedPeriod) { _ in
            Task { await fetchChartData() }
        }
        .task {
            await fetchChartData()
        }
    }

    // MARK: - Summary Cards

    @ViewBuilder
    private func summaryCards(data: InsightsChartData) -> some View {
        HStack(spacing: 10) {
            summaryCard(
                label: "Energia",
                value: data.energyTrend.last.map { "\($0.numericLevel)" } ?? "--",
                icon: "bolt.fill",
                color: DS.green
            )
            summaryCard(
                label: "Blocos",
                value: "\(data.qualityDistribution.perdi + data.qualityDistribution.meh + data.qualityDistribution.ok + data.qualityDistribution.flow)",
                icon: "square.stack.fill",
                color: DS.blue
            )
            summaryCard(
                label: "Horas",
                value: String(format: "%.1f", data.timerHours.reduce(0) { $0 + $1.hours }),
                icon: "clock.fill",
                color: DS.amber
            )
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func summaryCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(DS.body(18, weight: .medium))
                .foregroundColor(DS.bright)
            Text(label)
                .font(DS.mono(9))
                .foregroundColor(DS.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DS.s2)
        .cornerRadius(10)
    }

    // MARK: - Chart Card Wrapper

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DS.body(14, weight: .medium))
                .foregroundColor(DS.bright)

            content()
                .frame(height: 180)
        }
        .padding(16)
        .background(DS.s2)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - Energy Trend Chart

    @ViewBuilder
    private func energyChart(data: [EnergyPoint]) -> some View {
        if data.isEmpty {
            emptyChartPlaceholder()
        } else {
            Chart(data) { point in
                LineMark(
                    x: .value("Data", shortDate(point.date)),
                    y: .value("Energia", point.numericLevel)
                )
                .foregroundStyle(DS.green)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Data", shortDate(point.date)),
                    y: .value("Energia", point.numericLevel)
                )
                .foregroundStyle(DS.green)
                .symbolSize(20)
            }
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(DS.border)
                    AxisValueLabel()
                        .foregroundStyle(DS.subtle)
                        .font(DS.mono(9))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(DS.subtle)
                        .font(DS.mono(8))
                }
            }
        }
    }

    // MARK: - Quality Distribution Chart

    @ViewBuilder
    private func qualityChart(data: QualityDist) -> some View {
        let bars: [(label: String, value: Int, color: Color)] = [
            ("perdi", data.perdi, DS.red),
            ("meh", data.meh, DS.amber),
            ("ok", data.ok, DS.text),
            ("flow", data.flow, DS.green),
        ]

        Chart(bars, id: \.label) { bar in
            BarMark(
                x: .value("Qualidade", bar.label),
                y: .value("Blocos", bar.value)
            )
            .foregroundStyle(bar.color)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(DS.border)
                AxisValueLabel()
                    .foregroundStyle(DS.subtle)
                    .font(DS.mono(9))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(DS.subtle)
                    .font(DS.mono(10))
            }
        }
    }

    // MARK: - Timer Hours Chart

    @ViewBuilder
    private func timerChart(data: [TimerPoint]) -> some View {
        if data.isEmpty {
            emptyChartPlaceholder()
        } else {
            Chart(data) { point in
                BarMark(
                    x: .value("Data", shortDate(point.date)),
                    y: .value("Horas", point.hours)
                )
                .foregroundStyle(DS.green)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(DS.border)
                    AxisValueLabel()
                        .foregroundStyle(DS.subtle)
                        .font(DS.mono(9))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(DS.subtle)
                        .font(DS.mono(8))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func emptyChartPlaceholder() -> some View {
        Text("Sem dados")
            .font(DS.body(12))
            .foregroundColor(DS.dim)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shortDate(_ iso: String) -> String {
        // "2026-03-09" -> "09/03"
        let parts = iso.split(separator: "-")
        guard parts.count >= 3 else { return iso }
        return "\(parts[2])/\(parts[1])"
    }

    // MARK: - Network

    private func fetchChartData() async {
        isLoading = true
        loadError = false

        guard let url = ErestorConfig.url(for: "/v1/insights/chart-data?period=\(selectedPeriod)") else {
            isLoading = false
            loadError = true
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        ErestorConfig.authorize(&request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isLoading = false
                loadError = true
                return
            }

            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(InsightsApiResponse.self, from: data)
            chartData = apiResponse.data
            isLoading = false
        } catch {
            isLoading = false
            loadError = true
        }
    }
}
#endif
