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