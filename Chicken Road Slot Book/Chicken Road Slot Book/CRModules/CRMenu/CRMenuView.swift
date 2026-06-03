//
//  CRMenuView.swift
//  Chicken Road Slot Book
//
//

import SwiftUI

struct CRMenuContainer: View {
    @AppStorage("firstOpenSC") var firstOpen: Bool = true
    
    var body: some View {
        ZStack {
            if firstOpen {
                CROnboardingView(getStartBtnTapped: {
                    firstOpen = false
                })
            } else {
                CRMenuView()
            }
        }
        
    }
}

struct CRMenuView: View {
    @StateObject private var viewModel = ChickenRoadViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            selectedScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background.ignoresSafeArea())
            
            BottomTabBar(selectedTab: $viewModel.selectedTab)
        }
        .environmentObject(viewModel)
        .hideKeyboardOnTap()
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

#Preview {
    CRMenuView()
}

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
        .background(AppColors.tabBar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}
