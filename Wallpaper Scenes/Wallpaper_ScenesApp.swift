//
// Wallpaper Scenes
// Wallpaper_ScenesApp.swift
//
// Created on 19/1/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI

@main
struct WallpaperManagerApp: App {
    @StateObject private var wallpaperManager = WallpaperManager()
    @StateObject var backgroundManager = BackgroundManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Your custom background as the bottom layer
//                BackgroundAnimation()
//                    .ignoresSafeArea()  // Let it fill the entire window

                // Your main content on top
                MainView()
                    .environmentObject(wallpaperManager)
                    .environmentObject(backgroundManager)
            }.containerBackground(for: .window) {
                BackgroundAnimation()
                    .ignoresSafeArea()
                    .environmentObject(backgroundManager)
                    //.opacity(0.5)
            }.onAppear() {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let image = getMainDisplayWallpaper() {
                        DispatchQueue.main.async {
                            backgroundManager.updateColors(with: image)
                        }
                    }
                }
            }
        }
        // Remove or customize the title bar / window style if desired
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}


func getMainDisplayWallpaper() -> NSImage? {
    guard let screen = NSScreen.main,
          let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
          let image = NSImage(contentsOf: wallpaperURL) else {
        return nil
    }
    return image
}
