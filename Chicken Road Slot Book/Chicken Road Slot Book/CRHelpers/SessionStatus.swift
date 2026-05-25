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
