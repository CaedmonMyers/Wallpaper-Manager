//
// Wallpaper Manager
// BackgroundManager.swift
//
// Created on 11/3/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI

class BackgroundManager: ObservableObject {
//    @Published var colors: [Color] = [
//        Color.white, Color.white, Color.white,
//        Color.white, Color.white, Color.white,
//        Color.white, Color.white, Color.white
//    ]
    
    @Published var colors: [Color] = [
        Color(hex: "EA96FF"), .purple, .indigo,
        Color(hex: "FAE8FF"), Color(hex: "F1C0FD"), Color(hex: "A6A6D6"),
        .indigo, .purple, Color(hex: "EA96FF")
    ]
    
    func updateColors(with image: NSImage) {
        let hexColors = extractColorPalette(from: image)
        let newColors = hexColors.map { Color(hex: $0) }
        
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 5)) {
                self.colors = newColors + Array(repeating: .white, count: max(0, 9 - newColors.count))
            }
        }
    }
}
