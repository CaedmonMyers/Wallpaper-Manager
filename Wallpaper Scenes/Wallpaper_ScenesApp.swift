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

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(wallpaperManager)
        }
    }
}
