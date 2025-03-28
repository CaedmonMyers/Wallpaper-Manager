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
    case studio
    case display(CGDirectDisplayID)
    case scene(UUID)
}

struct MainView: View {
    @EnvironmentObject var manager: WallpaperManager
    @EnvironmentObject var backgroundManager: BackgroundManager

    // Track which item is currently selected in the sidebar
    @State private var selection: SidebarSelection? = .library // Default to Library

    // For importing an image into the library
    @State private var isImportingImage = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.regularMaterial, lineWidth: 2)
                )
                .frame(width: 220)
                .padding(10)
                .padding(.top, 20)
                .ignoresSafeArea()

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            BackgroundAnimation()
                .scaleEffect(x: -1, y: 1)
                .environmentObject(backgroundManager)
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        GeometryReader { sidebarGeo in
            VStack(alignment: .leading, spacing: 10) {
                Text("Wallpaper Manager")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Divider()
                
                Group {
                    Text("Library")
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal)
                    
                    sidebarButton(
                        title: "All Wallpapers",
                        sidebarGeo: sidebarGeo,
                        selection: .library
                    )
                    
                    sidebarButton(
                        title: "Wallpaper Studio",
                        sidebarGeo: sidebarGeo,
                        selection: .studio
                    )
                }
                
                Divider()
                
                Group {
                    Text("Displays")
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal)
                    
                    ForEach(manager.displays, id: \.self) { screen in
                        if let screenID = manager.displayID(for: screen) {
                            sidebarButton(
                                title: "Display \(screenID): \(screen.localizedName)",
                                sidebarGeo: sidebarGeo,
                                selection: .display(screenID)
                            )
                        }
                    }
                }
                
                Divider()
                
                Group {
                    Text("Scenes")
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal)
                    
                    ForEach(manager.scenes) { scene in
                        sidebarButton(
                            title: scene.name,
                            sidebarGeo: sidebarGeo,
                            selection: .scene(scene.id)
                        )
                    }
                }
                
                Spacer()
            }
            // Align the content to the top
            .frame(width: sidebarGeo.size.width, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
    }

    /// A custom sidebar button that fills the width (minus padding) of the sidebar.
    private func sidebarButton(title: String, sidebarGeo: GeometryProxy, selection value: SidebarSelection) -> some View {
        Button(action: {
            withAnimation {
                selection = value
            }
        }) {
            HStack {
                Text(title)
//                    .font(.system(.body, design: .default, weight: selection == value ? .bold: .regular))
                    .foregroundColor(selection == value ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            // Subtract 10 points from the width to account for any extra outer padding
            .frame(width: sidebarGeo.size.width - 20, alignment: .leading)
            .background(selection == value ? Color.black.opacity(0.2) : Color.clear)
            .cornerRadius(6)
//            .overlay(
//                RoundedRectangle(cornerRadius: 6)
//                    .stroke(.regularMaterial, lineWidth: 5)
//            )
            .background(Color.white.opacity(0.001))
        }
        .padding(.horizontal, 10)
        .buttonStyle(PlainButtonStyle())
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
            if let scene = manager.scenes.first(where: { $0.id == sceneID }) {
                SceneEditorView(scene: scene)
            } else {
                Text("Scene not found.")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        case .studio:
            WallpaperStudio()
        }
    }
}
