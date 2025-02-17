//
// Wallpaper Scenes
// ContentView.swift
//
// Created on 19/1/25
//
// Copyright ©2025 DoorHinge Apps.
//

import SwiftUI
import AppKit

/// The types of items selectable in the sidebar.
enum SidebarSelection: Hashable, Equatable {
    case library
    case display(CGDirectDisplayID)
    case scene(UUID)
}

struct MainView: View {
    @EnvironmentObject var manager: WallpaperManager

    // Track which item is currently selected in the sidebar
    @State private var selection: SidebarSelection? = .library // Default to Library

    // For importing an image into the library
    @State private var isImportingImage = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Button("Delete All Scenes") {
                manager.deleteAllScenes()
            }
            .foregroundColor(.red)

            
            Section("Library") {
                NavigationLink(value: SidebarSelection.library) {
                    Text("All Wallpapers")
                }
            }

            Section(header: Text("Displays")) {
                ForEach(manager.displays, id: \.self) { screen in
                    if let screenID = manager.displayID(for: screen) {
                        NavigationLink(value: SidebarSelection.display(screenID)) {
                            Text("Display \(screenID): \(screen.localizedName)")
                        }
                    }
                }
            }

            Section(header: Text("Scenes")) {
                ForEach(manager.scenes) { scene in
                    NavigationLink(value: SidebarSelection.scene(scene.id)) {
                        Text(scene.name)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Wallpaper Manager")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .none, .library:
            LibraryView()
        case .display(let screenID):
            if let screen = manager.displays.first(where: {
                manager.displayID(for: $0) == screenID
            }) {
                DisplayDetailView(screen: screen, screenNumber: Int(screenID))
            }
        case .scene(let sceneID):
            // Show an editor for this scene
            if let scene = manager.scenes.first(where: { $0.id == sceneID }) {
                SceneEditorView(scene: scene)
            } else {
                Text("Scene not found.")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
