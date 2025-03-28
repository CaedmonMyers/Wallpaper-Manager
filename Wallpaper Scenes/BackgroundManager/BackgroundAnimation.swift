//
// Wallpaper Manager
// BackgroundAnimation.swift
//
// Created on 7/3/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI

struct BackgroundAnimation: View {
    @EnvironmentObject var backgroundManager: BackgroundManager
    
    var timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if #available(iOS 18.0, *) {
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ], colors: backgroundManager.colors)
            }
            else {
                LinearGradient(colors: Array(backgroundManager.colors.prefix(4)), startPoint: .top, endPoint: .bottom)
            }
            
            Color.white.opacity(0.2)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 3)) {
                backgroundManager.colors.shuffle()
            }
        }
//        .onAppear() {
//            withAnimation(.linear(duration: 5)) {
//                backgroundManager.colors = [
//                    Color(hex: "EA96FF"), .purple, .indigo,
//                    Color(hex: "FAE8FF"), Color(hex: "F1C0FD"), Color(hex: "A6A6D6"),
//                    .indigo, .purple, Color(hex: "EA96FF")
//                ]
//            }
//        }
    }
}

#Preview {
    BackgroundAnimation()
}
