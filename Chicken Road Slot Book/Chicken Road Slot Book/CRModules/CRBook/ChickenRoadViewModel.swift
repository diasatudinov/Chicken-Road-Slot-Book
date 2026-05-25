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