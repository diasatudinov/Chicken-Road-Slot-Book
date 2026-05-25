//
//  ChickenRoadSlotBookerApp.swift
//  Chicken Road Slot Book
//
//


import SwiftUI

// MARK: - Models

enum AppTab: Int, CaseIterable {
    case book, live, history, stats, profile

    var title: String {
        switch self {
        case .book: return "Book"
        case .live: return "Live"
        case .history: return "History"
        case .stats: return "Stats"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .book: return "book"
        case .live: return "play"
        case .history: return "clock.arrow.circlepath"
        case .stats: return "chart.bar"
        case .profile: return "person"
        }
    }
}

enum SessionStatus: String, Codable {
    case booked
    case active
    case completed
    case stopped

    var title: String {
        switch self {
        case .booked: return "Booked"
        case .active: return "Live"
        case .completed: return "Completed"
        case .stopped: return "Stopped"
        }
    }
}

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case won = "Won"
    case lost = "Lost"
    case week = "This Week"
}

struct GameSession: Identifiable, Codable, Equatable {
    let id: UUID
    var platform: String
    var startDate: Date
    var durationMinutes: Int
    var bankrollLimit: Double
    var takeProfit: Double
    var status: SessionStatus

    var startedBalance: Double
    var currentBalance: Double
    var finalBalance: Double?
    var result: Double?
    var playedSeconds: Int
    var completedAt: Date?
    var stoppedByLimit: Bool
    var bestMultiplier: Double

    init(
        id: UUID = UUID(),
        platform: String,
        startDate: Date,
        durationMinutes: Int,
        bankrollLimit: Double,
        takeProfit: Double,
        status: SessionStatus = .booked,
        startedBalance: Double,
        currentBalance: Double? = nil,
        finalBalance: Double? = nil,
        result: Double? = nil,
        playedSeconds: Int = 0,
        completedAt: Date? = nil,
        stoppedByLimit: Bool = false,
        bestMultiplier: Double = 1.0
    ) {
        self.id = id
        self.platform = platform
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.bankrollLimit = bankrollLimit
        self.takeProfit = takeProfit
        self.status = status
        self.startedBalance = startedBalance
        self.currentBalance = currentBalance ?? startedBalance
        self.finalBalance = finalBalance
        self.result = result
        self.playedSeconds = playedSeconds
        self.completedAt = completedAt
        self.stoppedByLimit = stoppedByLimit
        self.bestMultiplier = bestMultiplier
    }

    var durationSeconds: Int { durationMinutes * 60 }

    var remainingSeconds: Int {
        max(durationSeconds - playedSeconds, 0)
    }

    var isFinished: Bool {
        status == .completed || status == .stopped
    }

    var pnl: Double {
        if let result { return result }
        return currentBalance - startedBalance
    }

    var isWin: Bool { pnl >= 0 }
}

struct Achievement: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let unlocked: Bool
}

struct PlatformStat: Identifiable {
    let id = UUID()
    let platform: String
    let winRate: Double
}

// MARK: - ViewModel

@MainActor
final class ChickenRoadViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .book
    @Published var sessions: [GameSession] = [] {
        didSet { saveSessions() }
    }

    @Published var liveSessionID: UUID?
    @Published var isLivePaused = false
    @Published var showBookingSheet = false
    @Published var showConfirmBooking = false
    @Published var showStopConfirmation = false
    @Published var showCompletionSheet = false
    @Published var historyFilter: HistoryFilter = .all

    @Published var draftStartDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @Published var draftDurationMinutes: Int = 120
    @Published var draftBankrollLimit: Double = 500
    @Published var draftTakeProfit: Double = 750
    @Published var draftPlatform: String = "Stake.com"

    @Published var resultInput: String = ""
    @Published var notificationsEnabled = true
    @Published var bankrollRemindersEnabled = true
    @Published var soundEffectsEnabled = false
    @Published var darkModeEnabled = true

    private var timer: Timer?

    private var sessionsFileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent("chicken_road_sessions.json")
    }

    init() {
        loadSessions()
        seedIfNeeded()
        selectActualLiveSessionIfNeeded()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    var bookedSessions: [GameSession] {
        sessions
            .filter { $0.status == .booked }
            .sorted { $0.startDate < $1.startDate }
    }

    var historySessions: [GameSession] {
        let completed = sessions.filter { $0.isFinished }
            .sorted { ($0.completedAt ?? $0.startDate) > ($1.completedAt ?? $1.startDate) }

        switch historyFilter {
        case .all:
            return completed
        case .won:
            return completed.filter { $0.pnl >= 0 }
        case .lost:
            return completed.filter { $0.pnl < 0 }
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return completed.filter { ($0.completedAt ?? $0.startDate) >= weekAgo }
        }
    }

    var nextSession: GameSession? {
        bookedSessions.first
    }

    var liveSession: GameSession? {
        guard let liveSessionID else { return sessions.first(where: { $0.status == .active }) }
        return sessions.first(where: { $0.id == liveSessionID })
    }

    var totalPnL: Double {
        sessions.filter { $0.isFinished }.reduce(0) { $0 + $1.pnl }
    }

    var totalWins: Int {
        sessions.filter { $0.isFinished && $0.pnl >= 0 }.count
    }

    var totalCompleted: Int {
        sessions.filter { $0.isFinished }.count
    }

    var winRate: Double {
        guard totalCompleted > 0 else { return 0 }
        return Double(totalWins) / Double(totalCompleted)
    }

    var averageDurationMinutes: Int {
        let finished = sessions.filter { $0.isFinished }
        guard !finished.isEmpty else { return 0 }
        let seconds = finished.reduce(0) { $0 + $1.playedSeconds }
        return max(seconds / finished.count / 60, 1)
    }

    var disciplinePercent: Int {
        let finished = sessions.filter { $0.isFinished }
        guard !finished.isEmpty else { return 100 }
        let disciplined = finished.filter { $0.playedSeconds <= $0.durationSeconds || $0.stoppedByLimit }.count
        return Int((Double(disciplined) / Double(finished.count) * 100).rounded())
    }

    var bestPlatform: String {
        platformStats.sorted { $0.winRate > $1.winRate }.first?.platform ?? "—"
    }

    var topMultiplier: Double {
        sessions.map(\.bestMultiplier).max() ?? 1.0
    }

    var longestWinStreak: Int {
        let ordered = sessions.filter { $0.isFinished }.sorted { $0.startDate < $1.startDate }
        var current = 0
        var best = 0

        for session in ordered {
            if session.pnl >= 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    var averageBankroll: Double {
        let finished = sessions.filter { $0.isFinished }
        guard !finished.isEmpty else { return 0 }
        let total = finished.reduce(0) { $0 + $1.startedBalance }
        return total / Double(finished.count)
    }

    var platformStats: [PlatformStat] {
        let grouped = Dictionary(grouping: sessions.filter { $0.isFinished }, by: { $0.platform })
        return grouped.map { platform, items in
            let wins = items.filter { $0.pnl >= 0 }.count
            let rate = items.isEmpty ? 0 : Double(wins) / Double(items.count)
            return PlatformStat(platform: platform, winRate: rate)
        }
        .sorted { $0.platform < $1.platform }
    }

    var bankrollTrend: [Double] {
        let finished = sessions.filter { $0.isFinished }.sorted { $0.startDate < $1.startDate }
        var current = 0.0
        var points: [Double] = []
        for session in finished.suffix(7) {
            current += session.pnl
            points.append(current)
        }
        return points.isEmpty ? [0, 0, 0, 0, 0, 0, 0] : points
    }

    var achievements: [Achievement] {
        [
            Achievement(icon: "🔥", title: "Hot Streak", subtitle: "5 wins in a row", unlocked: longestWinStreak >= 5),
            Achievement(icon: "🛡️", title: "Iron Will", subtitle: "Followed all limits", unlocked: disciplinePercent >= 90),
            Achievement(icon: "🏆", title: "Big Winner", subtitle: "$500+ profit session", unlocked: sessions.contains { $0.pnl >= 500 }),
            Achievement(icon: "⚡️", title: "Speed Run", subtitle: "Complete in under 1h", unlocked: sessions.contains { $0.isFinished && $0.playedSeconds < 3600 }),
            Achievement(icon: "🎯", title: "Sniper", subtitle: "Hit take-profit goal", unlocked: sessions.contains { $0.pnl >= $0.takeProfit }),
            Achievement(icon: "🐔", title: "Lucky Cluck", subtitle: "First session booked", unlocked: !sessions.isEmpty)
        ]
    }

    func resetDraft() {
        draftStartDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        draftDurationMinutes = 120
        draftBankrollLimit = 500
        draftTakeProfit = 750
        draftPlatform = "Stake.com"
    }

    func createBooking() {
        let session = GameSession(
            platform: draftPlatform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Official Site" : draftPlatform,
            startDate: draftStartDate,
            durationMinutes: draftDurationMinutes,
            bankrollLimit: draftBankrollLimit,
            takeProfit: draftTakeProfit,
            startedBalance: draftBankrollLimit,
            bestMultiplier: Double.random(in: 1.1...12.5)
        )
        sessions.append(session)
        sessions.sort { $0.startDate < $1.startDate }
        showConfirmBooking = false
        showBookingSheet = false
    }

    func startSession(_ session: GameSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index].status = .active
        sessions[index].playedSeconds = max(sessions[index].playedSeconds, 0)
        sessions[index].currentBalance = sessions[index].startedBalance
        liveSessionID = session.id
        isLivePaused = false
        selectedTab = .live
    }

    func pauseOrResumeLiveSession() {
        isLivePaused.toggle()
    }

    func changeCurrentBalance(by amount: Double) {
        guard let id = liveSessionID ?? sessions.first(where: { $0.status == .active })?.id,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].currentBalance += amount
        checkFinancialLimits(for: sessions[index])
    }

    func setCurrentBalance(from text: String) {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized),
              let id = liveSessionID ?? sessions.first(where: { $0.status == .active })?.id,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].currentBalance = value
        checkFinancialLimits(for: sessions[index])
    }

    func askStopSession() {
        showStopConfirmation = true
    }

    func stopLiveSessionByUser() {
        finishLiveSession(stoppedByLimit: true)
        showStopConfirmation = false
        showCompletionSheet = true
    }

    func completeLiveSession() {
        finishLiveSession(stoppedByLimit: false)
        showCompletionSheet = true
    }

    func saveResultInput() {
        guard let id = liveSessionID,
              let index = sessions.firstIndex(where: { $0.id == id }) else {
            showCompletionSheet = false
            return
        }

        let normalized = resultInput.replacingOccurrences(of: ",", with: ".")
        if let enteredResult = Double(normalized) {
            sessions[index].result = enteredResult
            sessions[index].finalBalance = sessions[index].startedBalance + enteredResult
            sessions[index].currentBalance = sessions[index].startedBalance + enteredResult
        } else {
            let result = sessions[index].currentBalance - sessions[index].startedBalance
            sessions[index].result = result
            sessions[index].finalBalance = sessions[index].currentBalance
        }

        sessions[index].status = sessions[index].stoppedByLimit ? .stopped : .completed
        sessions[index].completedAt = Date()
        liveSessionID = nil
        resultInput = ""
        showCompletionSheet = false
        selectedTab = .history
    }

    func deleteSession(_ session: GameSession) {
        sessions.removeAll { $0.id == session.id }
    }

    func updateSession(_ session: GameSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
    }

    func seedIfNeeded() {
        guard sessions.isEmpty else { return }
        let calendar = Calendar.current
        let now = Date()

        sessions = [
            GameSession(
                platform: "BC Game",
                startDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                durationMinutes: 90,
                bankrollLimit: 300,
                takeProfit: 450,
                startedBalance: 300
            ),
            GameSession(
                platform: "Rollbit",
                startDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                durationMinutes: 120,
                bankrollLimit: 400,
                takeProfit: 700,
                startedBalance: 400
            ),
            GameSession(
                platform: "Stake.com",
                startDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                durationMinutes: 135,
                bankrollLimit: 500,
                takeProfit: 750,
                status: .completed,
                startedBalance: 500,
                currentBalance: 720,
                finalBalance: 720,
                result: 220,
                playedSeconds: 8100,
                completedAt: calendar.date(byAdding: .hour, value: -18, to: now),
                bestMultiplier: 12.4
            ),
            GameSession(
                platform: "BC Game",
                startDate: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                durationMinutes: 90,
                bankrollLimit: 300,
                takeProfit: 450,
                status: .stopped,
                startedBalance: 300,
                currentBalance: 220,
                finalBalance: 220,
                result: -80,
                playedSeconds: 5400,
                completedAt: calendar.date(byAdding: .day, value: -3, to: now),
                stoppedByLimit: true,
                bestMultiplier: 3.2
            ),
            GameSession(
                platform: "Rollbit",
                startDate: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                durationMinutes: 180,
                bankrollLimit: 600,
                takeProfit: 850,
                status: .completed,
                startedBalance: 600,
                currentBalance: 850,
                finalBalance: 850,
                result: 250,
                playedSeconds: 10800,
                completedAt: calendar.date(byAdding: .day, value: -5, to: now),
                bestMultiplier: 45.2
            )
        ]
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        selectActualLiveSessionIfNeeded()

        guard !isLivePaused,
              let id = liveSessionID ?? sessions.first(where: { $0.status == .active })?.id,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        guard sessions[index].status == .active else { return }
        sessions[index].playedSeconds += 1

        if sessions[index].remainingSeconds <= 0 {
            finishLiveSession(stoppedByLimit: false)
            showCompletionSheet = true
            selectedTab = .live
        }
    }

    private func selectActualLiveSessionIfNeeded() {
        if let active = sessions.first(where: { $0.status == .active }) {
            liveSessionID = active.id
            return
        }

        guard let dueSession = sessions
            .filter({ $0.status == .booked && $0.startDate <= Date() })
            .sorted(by: { $0.startDate < $1.startDate })
            .first else { return }

        startSession(dueSession)
    }

    private func checkFinancialLimits(for session: GameSession) {
        let loss = session.startedBalance - session.currentBalance
        let profit = session.currentBalance - session.startedBalance

        if loss >= session.bankrollLimit || profit >= session.takeProfit {
            finishLiveSession(stoppedByLimit: loss >= session.bankrollLimit)
            showCompletionSheet = true
            selectedTab = .live
        }
    }

    private func finishLiveSession(stoppedByLimit: Bool) {
        guard let id = liveSessionID ?? sessions.first(where: { $0.status == .active })?.id,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        sessions[index].stoppedByLimit = stoppedByLimit
        sessions[index].status = stoppedByLimit ? .stopped : .completed
        sessions[index].completedAt = Date()
        sessions[index].finalBalance = sessions[index].currentBalance
        sessions[index].result = sessions[index].currentBalance - sessions[index].startedBalance
        resultInput = String(format: "%.0f", sessions[index].result ?? 0)
    }

    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL, options: [.atomic])
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    private func loadSessions() {
        guard FileManager.default.fileExists(atPath: sessionsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            sessions = try JSONDecoder().decode([GameSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var viewModel = ChickenRoadViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background.ignoresSafeArea())

            BottomTabBar(selectedTab: $viewModel.selectedTab)
        }
        .environmentObject(viewModel)
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch viewModel.selectedTab {
        case .book:
            SessionBookerView()
        case .live:
            LiveSessionView()
        case .history:
            SessionHistoryView()
        case .stats:
            AnalyticsView()
        case .profile:
            ProfileView()
        }
    }
}

// MARK: - Book Screen

struct SessionBookerView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let next = viewModel.nextSession {
                    NextSessionCard(session: next) {
                        viewModel.startSession(next)
                    }
                } else {
                    EmptyNextSessionCard()
                }

                Button {
                    viewModel.resetDraft()
                    viewModel.showBookingSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Book New Session")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.purpleGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }

                UpcomingSessionsSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $viewModel.showBookingSheet) {
            BookingSheetView()
                .presentationDetents([.large])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good evening,")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text("Alex 👋")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }

            Spacer()

            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(AppColors.card))
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: -8, y: 8)
                }
            }
        }
    }
}

struct NextSessionCard: View {
    let session: GameSession
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEXT SESSION")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(4)
                        Text(session.platform)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(session.status.title)
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                ProgressView(value: min(max(Date().timeIntervalSince(session.startDate.addingTimeInterval(-24 * 60 * 60)) / (24 * 60 * 60), 0), 1))
                    .tint(.white.opacity(0.5))

                HStack {
                    InfoColumn(title: "DURATION", value: "\(session.durationMinutes / 60) Hours")
                    Spacer()
                    InfoColumn(title: "LIMIT", value: money(session.bankrollLimit))
                    Spacer()
                    InfoColumn(title: "TARGET", value: money(session.takeProfit))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(AppColors.purpleGradient)
            .cornerRadius(20)
            .shadow(color: .purple.opacity(0.35), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyNextSessionCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34))
            Text("No booked sessions")
                .font(.headline)
            Text("Create a session with time, duration, bankroll limit and take-profit.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white)
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(AppColors.card)
        .cornerRadius(20)
    }
}

struct UpcomingSessionsSection: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Sessions")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("See All")
                    .font(.caption.bold())
                    .foregroundColor(AppColors.accent)
            }

            ForEach(viewModel.bookedSessions) { session in
                SessionRow(session: session) {
                    viewModel.startSession(session)
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: GameSession
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                Image(systemName: "book")
                    .foregroundColor(AppColors.accent)
                    .frame(width: 42, height: 42)
                    .background(AppColors.accent.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.platform)
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                    Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.gray)
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(money(session.bankrollLimit))
                        .foregroundColor(.orange)
                        .font(.subheadline.bold())
                    Text(session.status.title)
                        .font(.caption2.bold())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(AppColors.card)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Booking Sheet

struct BookingSheetView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ZStack {
            AppColors.sheetBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Session setup")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            viewModel.showBookingSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                    }

                    DatePickerRow(date: $viewModel.draftStartDate)
                    DurationPicker(value: $viewModel.draftDurationMinutes)
                    MoneyInputRow(title: "Bankroll Limit", icon: "wallet.pass", color: .orange, value: $viewModel.draftBankrollLimit)
                    MoneyInputRow(title: "Take Profit", icon: "target", color: .mint, value: $viewModel.draftTakeProfit)
                    PlatformInputRow(text: $viewModel.draftPlatform)

                    Text("You'll be notified 15 minutes before the session starts.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.showBookingSheet = false
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.input)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button {
                            viewModel.showConfirmBooking = true
                        } label: {
                            Label("Book Session", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.purpleGradient)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .confirmationDialog("Confirm Booking", isPresented: $viewModel.showConfirmBooking, titleVisibility: .visible) {
            Button("Book Session") { viewModel.createBooking() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(viewModel.draftPlatform), \(viewModel.draftStartDate.formatted(date: .abbreviated, time: .shortened)), \(viewModel.draftDurationMinutes) minutes")
        }
    }
}

struct DatePickerRow: View {
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Date", systemImage: "calendar")
                .foregroundColor(.gray)
                .font(.caption)
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(AppColors.accent)
                .padding()
                .background(AppColors.input)
                .cornerRadius(14)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

struct DurationPicker: View {
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Duration", systemImage: "clock")
                .foregroundColor(.gray)
                .font(.caption)

            HStack {
                ForEach([60, 120, 180], id: \.self) { minutes in
                    Button("\(minutes / 60)h") {
                        value = minutes
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(value == minutes ? AppColors.accent : AppColors.input)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }

                Button("Custom") {
                    if ![60, 120, 180].contains(value) { value = 120 }
                }
                .font(.caption.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(![60, 120, 180].contains(value) ? AppColors.accent : AppColors.input)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }

            Slider(value: Binding(get: {
                Double(value)
            }, set: {
                value = Int($0)
            }), in: 10...240, step: 5)
            .tint(AppColors.accent)

            Text("\(value) minutes")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

struct MoneyInputRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(.gray)
                    .font(.caption)
                Spacer()
                Text(money(value))
                    .foregroundColor(color)
                    .font(.subheadline.bold())
            }

            TextField("$", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .padding()
                .background(AppColors.input)
                .cornerRadius(12)
                .foregroundColor(.white)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

struct PlatformInputRow: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Platform", systemImage: "star")
                .foregroundColor(.gray)
                .font(.caption)

            TextField("Name Platform", text: $text)
                .padding()
                .background(AppColors.input)
                .cornerRadius(12)
                .foregroundColor(.white)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

// MARK: - Live Screen

struct LiveSessionView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Live Session")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("● LIVE")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.18))
                        .clipShape(Capsule())
                }

                if let session = viewModel.liveSession {
                    LiveSessionContent(session: session)
                } else {
                    NoLiveSessionView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 112)
        }
        .alert("Stop Session?", isPresented: $viewModel.showStopConfirmation) {
            Button("Keep Playing", role: .cancel) {}
            Button("Stop Session", role: .destructive) {
                viewModel.stopLiveSessionByUser()
            }
        } message: {
            if let session = viewModel.liveSession {
                Text("Current P&L: \(money(session.pnl)). Stopping early will be logged in your history.")
            }
        }
        .sheet(isPresented: $viewModel.showCompletionSheet) {
            CompletionSheetView()
                .presentationDetents([.medium])
        }
    }
}

struct LiveSessionContent: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel
    let session: GameSession
    @State private var balanceText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PLAYING ON")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.45))
                    Text(session.platform)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("SESSION")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.45))
                    Text("#\(session.id.uuidString.prefix(3).uppercased())")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(AppColors.purpleGradient)
            .cornerRadius(14)

            RoadChickenView()

            TimerCard(session: session)

            HStack(spacing: 12) {
                BalanceCard(
                    title: "CURRENT",
                    value: money(session.currentBalance),
                    subtitle: "Started: \(money(session.startedBalance))",
                    editAction: {
                        balanceText = String(format: "%.0f", session.currentBalance)
                    }
                )

                MetricCard(
                    title: "P&L",
                    value: signedMoney(session.pnl),
                    subtitle: "\(Int((session.pnl / max(session.bankrollLimit, 1)) * 100))% of limit",
                    color: session.pnl >= 0 ? .mint : .red
                )
            }

            HStack(spacing: 1) {
                InfoBox(title: "Limit", value: money(session.bankrollLimit), color: .orange)
                InfoBox(title: "Target", value: money(session.takeProfit), color: .mint)
                InfoBox(title: "Best Multi", value: String(format: "%.1fx", session.bestMultiplier), color: AppColors.accent)
            }
            .padding()
            .background(AppColors.card)
            .cornerRadius(16)

            HStack(spacing: 12) {
                Button {
                    viewModel.askStopSession()
                } label: {
                    Label("Stop Session", systemImage: "stop")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.35)))
                        .cornerRadius(14)
                }

                Button {
                    viewModel.pauseOrResumeLiveSession()
                } label: {
                    Label(viewModel.isLivePaused ? "Resume" : "Pause", systemImage: viewModel.isLivePaused ? "play" : "pause")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mint)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }

            Button {
                viewModel.completeLiveSession()
            } label: {
                Label("Complete", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.mint.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            HStack(spacing: 10) {
                Button("− $10") { viewModel.changeCurrentBalance(by: -10) }
                Button("+ $10") { viewModel.changeCurrentBalance(by: 10) }
            }
            .buttonStyle(BalanceSmallButtonStyle())
        }
        .alert("Current Balance", isPresented: Binding(get: { !balanceText.isEmpty }, set: { if !$0 { balanceText = "" } })) {
            TextField("Balance", text: $balanceText)
                .keyboardType(.decimalPad)
            Button("Save") {
                viewModel.setCurrentBalance(from: balanceText)
                balanceText = ""
            }
            Button("Cancel", role: .cancel) { balanceText = "" }
        }
    }
}

struct NoLiveSessionView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accent)
            Text("No active session")
                .font(.headline)
                .foregroundColor(.white)
            Text("Start a booked session manually or wait until its start time.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            if let next = viewModel.nextSession {
                Button("Start \(next.platform)") {
                    viewModel.startSession(next)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.purpleGradient)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColors.card)
        .cornerRadius(18)
    }
}

struct RoadChickenView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [.indigo.opacity(0.8), .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))

            HStack(spacing: 26) {
                RoadLane(multiplier: "1.12x")
                Text("🐔")
                    .font(.system(size: 72))
                RoadLane(multiplier: "1.12x")
            }
        }
        .frame(height: 176)
    }
}

struct RoadLane: View {
    let multiplier: String

    var body: some View {
        VStack(spacing: 12) {
            Text(multiplier)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.2)))
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.5))
                .frame(width: 4, height: 80)
        }
    }
}

struct TimerCard: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: 12) {
            Text("ELAPSED TIME")
                .font(.caption2.bold())
                .foregroundColor(.gray)
                .tracking(5)

            Text(timeString(from: session.playedSeconds))
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(timerColor)

            Text("of \(timeString(from: session.durationSeconds)) · \(session.remainingSeconds / 60) min remaining")
                .font(.caption)
                .foregroundColor(.gray)

            ProgressView(value: Double(session.playedSeconds), total: Double(max(session.durationSeconds, 1)))
                .tint(timerColor)
        }
        .padding(22)
        .background(AppColors.card)
        .cornerRadius(18)
    }

    private var timerColor: Color {
        if session.remainingSeconds < 120 { return .red }
        if session.remainingSeconds < 600 { return .yellow }
        return .white
    }
}

struct BalanceCard: View {
    let title: String
    let value: String
    let subtitle: String
    let editAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.gray)
                Spacer()
                Button(action: editAction) {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray)
                }
            }
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.gray)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

struct InfoBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompletionSheetView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ZStack {
            AppColors.sheetBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("🐔")
                    .font(.system(size: 72))
                Text("Session Complete!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Great discipline — you followed your plan.")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                if let session = viewModel.liveSession {
                    HStack(spacing: 12) {
                        InfoBox(title: "Duration", value: timeString(from: session.playedSeconds), color: .white)
                        InfoBox(title: "Result", value: signedMoney(session.pnl), color: session.pnl >= 0 ? .mint : .red)
                        InfoBox(title: "Discipline", value: "\(viewModel.disciplinePercent)%", color: AppColors.accent)
                    }
                    .padding()
                    .background(AppColors.card)
                    .cornerRadius(16)
                }

                TextField("Result, e.g. 220 or -85", text: $viewModel.resultInput)
                    .keyboardType(.numbersAndPunctuation)
                    .padding()
                    .background(AppColors.input)
                    .cornerRadius(12)
                    .foregroundColor(.white)

                Button {
                    viewModel.saveResultInput()
                } label: {
                    Label("Done", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.purpleGradient)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }
            .padding(24)
        }
    }
}

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
                ForEach(stats.isEmpty ? mockStats : stats) { stat in
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

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var viewModel: ChickenRoadViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Text("🐔")
                            .font(.system(size: 72))
                            .frame(width: 110, height: 110)
                            .background(Circle().fill(AppColors.accent))
                        Text("7")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.orange))
                    }

                    Text("Alex Johnson")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("Slot Master · Level 7")
                        .foregroundColor(.gray)

                    Text("🔥  12-Day Discipline Streak")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.2))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.35)))
                        .clipShape(Capsule())
                }
                .padding(.top, 70)

                HStack(spacing: 14) {
                    SummaryTile(value: "\(viewModel.totalCompleted)", title: "Sessions", color: .white)
                    SummaryTile(value: compactMoney(viewModel.totalPnL), title: "Total Won", color: .mint)
                    SummaryTile(value: "\(viewModel.achievements.filter { $0.unlocked }.count)/\(viewModel.achievements.count)", title: "Badges", color: .orange)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Achievements")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(viewModel.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    VStack(spacing: 0) {
                        SettingsToggle(title: "Notifications", icon: "bell", isOn: $viewModel.notificationsEnabled)
                        Divider().background(Color.white.opacity(0.08))
                        SettingsToggle(title: "Bankroll Reminders", icon: "wallet.pass", isOn: $viewModel.bankrollRemindersEnabled)
                        Divider().background(Color.white.opacity(0.08))
                        SettingsToggle(title: "Sound Effects", icon: "speaker.wave.2", isOn: $viewModel.soundEffectsEnabled)
                        Divider().background(Color.white.opacity(0.08))
                        SettingsToggle(title: "Dark Mode", icon: "moon", isOn: $viewModel.darkModeEnabled)
                    }
                    .background(AppColors.card)
                    .cornerRadius(22)
                }

                Button {} label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.16))
                        .foregroundColor(.red)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.red.opacity(0.45)))
                        .cornerRadius(18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 10) {
            Text(achievement.icon)
                .font(.title)
            Text(achievement.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(achievement.subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 116)
        .background(AppColors.card.opacity(achievement.unlocked ? 1 : 0.45))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(achievement.unlocked ? AppColors.accent.opacity(0.55) : Color.white.opacity(0.05)))
        .cornerRadius(16)
        .opacity(achievement.unlocked ? 1 : 0.45)
    }
}

struct SettingsToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accent.opacity(0.16))
                .cornerRadius(12)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accent)
        }
        .padding()
    }
}

// MARK: - Bottom Tab Bar

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(tab.title)
                            .font(.caption2.bold())
                    }
                    .foregroundColor(selectedTab == tab ? AppColors.accent : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 28)
        .frame(height: 86)
        .background(AppColors.tabBar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

// MARK: - Reusable

struct InfoColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }
}

struct BalanceSmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppColors.card)
            .foregroundColor(.white)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

enum AppColors {
    static let background = Color(red: 0.04, green: 0.05, blue: 0.11)
    static let sheetBackground = Color(red: 0.09, green: 0.10, blue: 0.17)
    static let card = Color(red: 0.11, green: 0.12, blue: 0.20)
    static let input = Color(red: 0.06, green: 0.07, blue: 0.13)
    static let tabBar = Color(red: 0.08, green: 0.09, blue: 0.16)
    static let accent = Color(red: 0.36, green: 0.25, blue: 1.0)

    static let purpleGradient = LinearGradient(
        colors: [Color(red: 0.28, green: 0.25, blue: 1.0), Color(red: 0.56, green: 0.20, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

func money(_ value: Double) -> String {
    "$" + String(format: "%.0f", value)
}

func signedMoney(_ value: Double) -> String {
    let sign = value >= 0 ? "+" : "-"
    return sign + money(abs(value))
}

func compactMoney(_ value: Double) -> String {
    if abs(value) >= 1000 {
        return String(format: "$%.1fk", value / 1000)
    }
    return money(value)
}

func timeString(from seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%02d:%02d", minutes, secs)
    }
}
