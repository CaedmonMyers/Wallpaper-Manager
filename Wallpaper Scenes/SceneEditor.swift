import SwiftUI

struct SceneEditorView: View {
    @EnvironmentObject var manager: WallpaperManager
    @State var scene: WallpaperScene
    @State private var selectedDisplayID: CGDirectDisplayID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scene name
            Text("Scene Editor: \(scene.name)")
                .font(.headline)

            // Apply scene button
            HStack {
                Button("Apply This Scene") {
                    manager.applyScene(scene)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Toggle("Set This Wallpaper On All Desktops?", isOn: $scene.setForAllDesktops)

            Divider()

            // Horizontal scrolling display selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(manager.displays, id: \.self) { screen in
                        if let screenID = manager.displayID(for: screen) {
                            let screenKey = String(screenID)

                            VStack {
                                // Current wallpaper thumbnail or placeholder
                                if let imageID = scene.assignments[screenKey],
                                   let wallpaper = manager.images.first(where: { $0.id == imageID }),
                                   let nsimg = manager.loadNSImage(for: wallpaper) {
                                    Image(nsImage: nsimg)
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 120, height: 120 * 9 / 16)
                                        .clipped()
                                } else {
                                    // Placeholder if no wallpaper is assigned
                                    Rectangle()
                                        .foregroundColor(.gray)
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 120, height: 120 * 9 / 16)
                                        .overlay(Text("No Image").font(.caption))
                                }

                                // Display name
                                Text(screen.localizedName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 120)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(screenID == selectedDisplayID ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedDisplayID = screenID
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            // Wallpaper selection grid for the selected display
            if let displayID = selectedDisplayID {
                Text("Select a Wallpaper for Display \(displayID):")
                    .font(.subheadline)

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(manager.images) { wallpaper in
                            let screenKey = String(displayID)

                            WallpaperGridItem(
                                wallpaper: wallpaper,
                                nsImage: manager.loadNSImage(for: wallpaper),
                                isSelected: scene.assignments[screenKey] == wallpaper.id,
                                onSelect: {
                                    scene.assignments[screenKey] = wallpaper.id
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("Select a display to edit its wallpaper.")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()

            // Save changes button
            HStack {
                Spacer()
                Button("Save Changes") {
                    manager.createOrUpdateScene(scene: scene)
                }
            }
        }
        .padding()
        .onAppear {
            // Automatically select the first display when the view appears
            if let firstScreen = manager.displays.first,
               let screenID = manager.displayID(for: firstScreen) {
                selectedDisplayID = screenID
            }
        }
    }
}
