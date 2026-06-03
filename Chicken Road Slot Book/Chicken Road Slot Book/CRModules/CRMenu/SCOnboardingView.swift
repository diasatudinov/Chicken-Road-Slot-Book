//
//  SCOnboardingView.swift
//  Chicken Road Slot Book
//
//


import SwiftUI

struct CROnboardingView: View {
    var getStartBtnTapped: () -> ()
        @State var count = 0
        
        var onbIcon: Image {
            switch count {
            case 0:
                Image(.onboardingIcon1CR)
            case 1:
                Image(.onboardingIcon2CR)
            case 2:
                Image(.onboardingIcon3CR)
            default:
                Image(.onboardingIcon1CR)
            }
        }
        
        var onbTitle: String {
            switch count {
            case 0:
                "Your Perfect Lure.\nYour Best Catch."
            case 1:
                "Track Every Trophy"
            case 2:
                "AI-Based Lure\nSuggestions"
            default:
                "Spin Your Meals"
            }
        }
        
        var onbDescription: String {
            switch count {
            case 0:
                "Track your fishing journey with\nintelligent insights"
            case 1:
                "Log catches with photos, weather, and\nsuccessful lures"
            case 2:
                "Get smart recommendations based on\nconditions"
            default:
                ""
            }
        }
        
    var body: some View {
        
        ZStack {
            Image(.onbordingBg)
                .resizable()
                .padding(-4)
                .ignoresSafeArea()
        VStack {
            
            onbIcon
                .resizable()
                .scaledToFit()
                .padding(.horizontal)
            
            VStack {
                
                HStack {
                    if count == 0 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.accent)
                            .frame(width: 32, height: 8)
                        
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                    
                    
                    if count == 1 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.accent)
                            .frame(width: 32, height: 8)
                        
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                    
                    if count == 2 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.accent)
                            .frame(width: 32, height: 8)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.bottom, 24)
                
                VStack(spacing: 16) {
                    
                    Button {
                        if count < 2 {
                            count += 1
                            
                        } else {
                            getStartBtnTapped()
                        }
                    } label: {
                        HStack {
                            Text(count != 2 ? "Continue" : "Start Playing Smart")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.purpleGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 50))
                        .padding(.horizontal, 32)
                    }
                    VStack {
                        if count != 2 {
                            Button {
                                getStartBtnTapped()
                            } label: {
                                Text("Skip")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Skip")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .opacity(0)
                        }
                        
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
            
        }
        
        
        private func additionalInfoCell<Content: View>(
            text: String,
            @ViewBuilder content: () -> Content
        ) -> some View {
            HStack(alignment: .center, spacing: 8) {
                content()
                
                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
    }

#Preview {
    CROnboardingView(getStartBtnTapped: {})
}
