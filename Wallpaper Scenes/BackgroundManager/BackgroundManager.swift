//
// Wallpaper Manager
// BackgroundManager.swift
//
// Created on 11/3/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI
import ColorsKit

class BackgroundManager: ObservableObject {
    @Published var colors: [Color] = [
        Color.white, Color.white, Color.white,
        Color.white, Color.white, Color.white,
        Color.white, Color.white, Color.white
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
