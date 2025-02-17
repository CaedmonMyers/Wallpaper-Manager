import SwiftUI

struct CreateSceneSheetView: View {
    @EnvironmentObject var manager: WallpaperManager
    @Environment(\.dismiss) private var dismiss

    @State private var sceneName = ""
    @State private var selectedDisplayID: CGDirectDisplayID? // The currently selected display
    @State private var displayAssignments: [CGDirectDisplayID: UUID] = [:] // Images assigned per display
    
    @State private var setForAllDesktops = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create New Scene")
                .font(.title2)

            // Scene name
            TextField("Scene Name", text: $sceneName)
                .textFieldStyle(.roundedBorder)
            
            Toggle("Set This Wallpaper On All Desktops?", isOn: $setForAllDesktops)

            Divider()

            // Display selection HStack
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(manager.displays, id: \.self) { screen in
                        if let screenID = manager.displayID(for: screen) {
                            displaySelectionThumbnail(screen: screen,
                                                      screenID: screenID,
                                                      isSelected: (screenID == selectedDisplayID))
                                .onTapGesture {
                                    selectedDisplayID = screenID
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(screenID == selectedDisplayID ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            // Image picker for the selected display
            if let displayID = selectedDisplayID {
                VStack(alignment: .leading) {
                    Text("Select Wallpaper for \(displayName(for: displayID))")
                        .font(.headline)

                    ScrollView {
                        LazyVGrid(
                            columns: [ GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 16) ],
                            spacing: 16
                        ) {
                            ForEach(manager.images) { wallpaper in
                                imageThumbnailView(for: wallpaper,
                                                   isSelected: (displayAssignments[displayID] == wallpaper.id))
                                    .onTapGesture {
                                        // Assign this image to the current display
                                        displayAssignments[displayID] = wallpaper.id
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                displayAssignments[displayID] == wallpaper.id ? Color.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                Text("Select a display to assign wallpapers.")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Create Scene") {
                    createScene()
                    dismiss()
                }
                .disabled(sceneName.isEmpty || displayAssignments.isEmpty) // Validation
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            // Automatically select the first display
            if let firstScreen = manager.displays.first,
               let screenID = manager.displayID(for: firstScreen) {
                selectedDisplayID = screenID
            }
        }
    }

    // MARK: - Helpers

    /// Returns a display's name for its ID
    private func displayName(for displayID: CGDirectDisplayID) -> String {
        manager.displays
            .first(where: { manager.displayID(for: $0) == displayID })?
            .localizedName ?? "Unknown Display"
    }

    /// Saves the scene to the manager
    private func createScene() {
        var assignments: [String: UUID] = [:]
        for (screenID, imageID) in displayAssignments {
            assignments["\(screenID)"] = imageID
        }
        let newScene = WallpaperScene(
            name: sceneName,
            assignments: assignments,
            setForAllDesktops: setForAllDesktops
        )
        manager.createOrUpdateScene(scene: newScene)
    }

    // MARK: - Sub-Views to Break Up Expressions

    /// Thumbnail for selecting a display in the horizontal scroll.
    private func displaySelectionThumbnail(screen: NSScreen,
                                           screenID: CGDirectDisplayID,
                                           isSelected: Bool) -> some View {
        VStack {
            // If there's already an assigned wallpaper, show it;
            // otherwise, show a generic placeholder
            if let wallpaperID = displayAssignments[screenID],
               let wallpaper = manager.images.first(where: { $0.id == wallpaperID }),
               let nsimg = manager.loadNSImage(for: wallpaper) {
                Image(nsImage: nsimg)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 120 * 9/16)
                    .clipped()
                    .cornerRadius(4)
            } else {
                // Placeholder SF Symbol
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120 * 9/16)
                    .foregroundColor(.secondary)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }

            // Display name
            Text(screen.localizedName)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 120)
    }

    /// Thumbnail for each wallpaper in the grid.
    private func imageThumbnailView(for wallpaper: WallpaperImage, isSelected: Bool) -> some View {
        VStack {
            // Image thumbnail
            if let nsimg = manager.loadNSImage(for: wallpaper) {
                Image(nsImage: nsimg)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 120 * 9/16)
                    .clipped()
            } else {
                // Fallback placeholder
                Rectangle()
                    .foregroundColor(.gray)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 120 * 9/16)
            }

            // Display name or file name
            Text(wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 120)
        }
    }
}
