// MARK: - History

struct SessionHistoryView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel
    @State private var sessionToDelete: GameSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Session History")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.top, 64)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue) {
                            viewModel.historyFilter = filter
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(viewModel.historyFilter == filter ? AppColors.accent : AppColors.card)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                SummaryTile(value: "\(viewModel.totalCompleted)", title: "Sessions", color: .white)
                SummaryTile(value: signedMoney(viewModel.totalPnL), title: "Total Profit", color: viewModel.totalPnL >= 0 ? .mint : .red)
                SummaryTile(value: "\(Int(viewModel.winRate * 100))%", title: "Win Rate", color: .orange)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(viewModel.historySessions) { session in
                        HistorySessionCard(session: session) {
                            sessionToDelete = session
                        }
                    }
                }
                .padding(.bottom, 110)
            }
        }
        .padding(.horizontal, 20)
        .alert("Delete Session?", isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } })) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let sessionToDelete {
                    viewModel.deleteSession(sessionToDelete)
                }
                sessionToDelete = nil
            }
        } message: {
            Text("This action cannot be undone. All session data will be permanently removed.")
        }
    }
}

struct SummaryTile: View {
    let value: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.card)
        .cornerRadius(14)
    }
}

struct HistorySessionCard: View {
    let session: GameSession
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.platform)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text(session.startDate.formatted(date: .abbreviated, time: .omitted) + " · " + "\(session.playedSeconds / 60) min")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(session.pnl >= 0 ? "WIN" : "LOSS")
                    .font(.caption.bold())
                    .foregroundColor(session.pnl >= 0 ? .mint : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background((session.pnl >= 0 ? Color.mint : Color.red).opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack {
                SmallHistoryMetric(title: "Start", value: money(session.startedBalance))
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                SmallHistoryMetric(title: "End", value: money(session.finalBalance ?? session.currentBalance))
                Spacer()
                SmallHistoryMetric(title: "P&L", value: signedMoney(session.pnl), color: session.pnl >= 0 ? .mint : .red)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(18)
    }
}

struct SmallHistoryMetric: View {
    let title: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }
}
