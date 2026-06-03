//
//  LiveSessionView.swift
//  Chicken Road Slot Book
//
//

import SwiftUI


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
                    viewModel: viewModel,
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
                    viewModel.completeLiveSession()
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
            Image(.chickenImageCR)
                .resizable()
                .scaledToFit()
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
    @ObservedObject var viewModel: ChickenRoadViewModel
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
            }
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 0) {
                Button {
                    viewModel.changeCurrentBalance(by: -10)
                } label: {
                    Text("−")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 0)
                        .background(.white.opacity(0.2))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 100, bottomLeadingRadius: 100))
                }
                
                Button {
                    viewModel.changeCurrentBalance(by: 10)
                } label: {
                    Text("+")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 0)
                        .background(.white.opacity(0.2))
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 100, topTrailingRadius: 100))
                }
            }
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
            
            HStack(spacing: 0) {
                Button {
                } label: {
                    Text("−")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 0)
                        .background(.white.opacity(0.2))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 100, bottomLeadingRadius: 100))
                }
                
                Button {
                } label: {
                    Text("+")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 0)
                        .background(.white.opacity(0.2))
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 100, topTrailingRadius: 100))
                }
            }.opacity(0)
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
            ScrollView {
                VStack(spacing: 18) {
                    Image(.screamChickenCR)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 138)
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
        .hideKeyboardOnTap()
    }
}

#Preview {
    LiveSessionView()
        .environmentObject(ChickenRoadViewModel())
}
