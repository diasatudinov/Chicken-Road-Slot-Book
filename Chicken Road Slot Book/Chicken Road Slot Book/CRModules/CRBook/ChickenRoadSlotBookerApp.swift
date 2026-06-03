//
//  ChickenRoadSlotBookerApp.swift
//  Chicken Road Slot Book
//
//


import SwiftUI

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
        .hideKeyboardOnTap()
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
        .hideKeyboardOnTap()
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
        .hideKeyboardOnTap()
    }
}

