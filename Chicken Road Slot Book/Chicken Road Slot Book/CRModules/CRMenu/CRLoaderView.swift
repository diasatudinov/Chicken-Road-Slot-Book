//
//  CRLoaderView.swift
//  Chicken Road Slot Book
//
//

import SwiftUI

struct CRLoaderView: View {
    @State private var scale: CGFloat = 1.0
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?
    var body: some View {
        ZStack {
            ZStack {
                Image("CRLoaderImage")
                    .resizable()
                    .ignoresSafeArea()
                    .scaledToFill()
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
            }
            
            
            VStack(spacing: 0) {
                
                Image("CRLoaderImage")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(16)
                    .scaleEffect(scale)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: scale
                    )
                    .onAppear {
                        scale = 0.8
                    }
                
                VStack(spacing: 12) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: UIScreen.main.bounds.width/2, height: 8)
                        .tint(.blue)
                        .padding(5)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding()
                .onAppear { startTimer() }
                .onDisappear { timer?.invalidate() }
            }
            
            
            
        }
        .onAppear {
            startTimer()
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { timer in
            if progress < 1 {
                progress += 0.01
            } else {
                timer.invalidate()
            }
        }
    }
}


#Preview {
    CRLoaderView()
}
