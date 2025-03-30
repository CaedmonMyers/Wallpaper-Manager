//
// Wallpaper Scenes
// Wallpaper_ScenesApp.swift
//
// Created on 19/1/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct WallpaperManagerApp: App {
    @StateObject private var wallpaperManager = WallpaperManager()
    @StateObject var backgroundManager = BackgroundManager()
    
    @State private var isDropTargeted = false

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
            .onDrop(
                of: [.fileURL],
                isTargeted: $isDropTargeted
            ) { providers in
                handleDrop(providers: providers)
            }
        }
        // Remove or customize the title bar / window style if desired
        .windowStyle(HiddenTitleBarWindowStyle())
    }
    
    // MARK: - Drag & Drop Handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // We'll attempt to load each provider as a fileURL
        var didLoadAny = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let data = item as? Data,
                       let urlString = String(data: data, encoding: .utf8),
                       let fileURL = URL(string: urlString) {
                        // For display name, let's use the file's base name
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        DispatchQueue.main.async {
                            wallpaperManager.addImage(from: fileURL, displayName: baseName, groups: [])
                        }
                        didLoadAny = true
                    }
                }
            }
        }
        return didLoadAny
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
