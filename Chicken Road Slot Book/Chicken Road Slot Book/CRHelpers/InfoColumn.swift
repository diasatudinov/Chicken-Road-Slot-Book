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
