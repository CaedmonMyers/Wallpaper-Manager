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
    case display(CGDirectDisplayID)
    case scene(UUID)
}

struct MainView: View {
    @EnvironmentObject var manager: WallpaperManager

    // Track which item is currently selected in the sidebar
    @State private var selection: SidebarSelection? = nil

    // For importing an image into the library
    @State private var isImportingImage = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
//        .fileImporter(
//            isPresented: $isImportingImage,
//            allowedContentTypes: [.image],
//            allowsMultipleSelection: false
//        ) { result in
//            handleImageImport(result: result)
//        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Library") {
                NavigationLink("All Wallpapers") {
                    LibraryView()
                }
            }
            
            Section(header: Text("Displays")) {
                let screens = manager.getConnectedDisplays()
                ForEach(screens, id: \.self) { screen in
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
//        .toolbar {
//            Button {
//                isImportingImage = true
//            } label: {
//                Label("Import Image", systemImage: "plus")
//            }
//        }
        .navigationTitle("Wallpaper Manager")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .none:
            // Nothing selected – just a placeholder.
            Text("Select a display or scene from the sidebar.")
                .font(.title2)
                .foregroundColor(.secondary)
        case .display(let screenID):
            // Show a detail editor for a single display
            if let screen = manager.getConnectedDisplays().first(where: {
                manager.displayID(for: $0) == screenID
            }) {
                DisplayDetailView(screen: screen)
            } else {
                Text("This display is not currently connected.")
                    .font(.title2)
                    .foregroundColor(.secondary)
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

    // MARK: - File Import Helper

//    private func handleImageImport(result: Result<[URL], Error>) {
//        switch result {
//        case .success(let urls):
//            if let url = urls.first {
//                manager.addImage(from: url)
//            }
//        case .failure(let error):
//            print("Import error: \(error.localizedDescription)")
//        }
//    }
}
