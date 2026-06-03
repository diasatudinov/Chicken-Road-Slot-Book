//
//  AnalyticsView.swift
//  Chicken Road Slot Book
//
//

import SwiftUI

// MARK: - Analytics

struct AnalyticsView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Analytics")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .padding(.top, 64)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AnalyticsMetric(title: "DISCIPLINE", value: "\(viewModel.disciplinePercent)%", subtitle: "+3% this week", icon: "shield", color: AppColors.accent)
                    AnalyticsMetric(title: "TOTAL P&L", value: signedMoney(viewModel.totalPnL), subtitle: "\(viewModel.totalCompleted) sessions", icon: "arrow.up.right", color: viewModel.totalPnL >= 0 ? .mint : .red)
                    AnalyticsMetric(title: "AVG DURATION", value: "\(viewModel.averageDurationMinutes / 60)h \(viewModel.averageDurationMinutes % 60)m", subtitle: "Per session", icon: "clock", color: .white)
                    AnalyticsMetric(title: "WIN RATE", value: "\(Int(viewModel.winRate * 100))%", subtitle: "\(viewModel.totalWins) of \(viewModel.totalCompleted) wins", icon: "trophy", color: .orange)
                }

                LineChartCard(title: "Bankroll Trend", values: viewModel.bankrollTrend)
                BarChartCard(stats: viewModel.platformStats)

                Text("Insights")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InsightCard(icon: "🏆", value: viewModel.bestPlatform, title: "Best Platform")
                    InsightCard(icon: "⚡️", value: String(format: "%.1fx", viewModel.topMultiplier), title: "Top Multiplier")
                    InsightCard(icon: "🔥", value: "\(viewModel.longestWinStreak) Wins", title: "Longest Streak")
                    InsightCard(icon: "💰", value: money(viewModel.averageBankroll), title: "Avg Bankroll")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }
}

struct AnalyticsMetric: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(AppColors.card)
        .cornerRadius(18)
    }
}

struct LineChartCard: View {
    let title: String
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("7 Days")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.accent.opacity(0.35))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = max(maxValue - minValue, 1)
                Path { path in
                    for index in values.indices {
                        let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                        let normalized = (values[index] - minValue) / range
                        let y = geo.size.height - (geo.size.height * CGFloat(normalized))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(AppColors.accent, lineWidth: 4)
            }
            .frame(height: 150)

            HStack {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(20)
    }
}

struct BarChartCard: View {
    let stats: [PlatformStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Platform Performance")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("Win Rate %")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(alignment: .bottom, spacing: 18) {
                ForEach(stats) { stat in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.purpleGradient)
                            .frame(height: max(CGFloat(stat.winRate) * 130, 12))
                        Text(stat.platform)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 165, alignment: .bottom)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(20)
    }

    private var mockStats: [PlatformStat] {
        [
            PlatformStat(platform: "Stake", winRate: 0.7),
            PlatformStat(platform: "BC Game", winRate: 0.55),
            PlatformStat(platform: "Rollbit", winRate: 0.62),
            PlatformStat(platform: "1xBet", winRate: 0.42)
        ]
    }
}

struct InsightCard: View {
    let icon: String
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(icon)
                .font(.title)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(value.hasPrefix("$") ? .mint : .orange)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(AppColors.card)
        .cornerRadius(18)
    }
}
