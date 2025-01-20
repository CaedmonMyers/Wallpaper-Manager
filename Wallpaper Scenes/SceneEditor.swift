import SwiftUI

struct SceneEditorView: View {
    @EnvironmentObject var manager: WallpaperManager
    @State var scene: WallpaperScene

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scene Editor: \(scene.name)")
                .font(.headline)

            HStack {
                Button("Apply This Scene") {
                    manager.applyScene(scene)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // For each connected display, let the user pick which image is assigned.
            let displays = manager.getConnectedDisplays()
            ForEach(displays, id: \.self) { screen in
                if let screenID = manager.displayID(for: screen) {
                    let screenKey = String(screenID)
                    HStack {
                        Text("Display \(screen.localizedName) (\(screenID))")
                        Spacer()
                        Picker("Wallpaper:", selection: bindingFor(screenKey: screenKey)) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(manager.images, id: \.id) { img in
                                Text(img.fileName).tag(Optional<UUID>(img.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            Spacer()
            // Save changes to the scene
            HStack {
                Spacer()
                Button("Save Changes") {
                    manager.createOrUpdateScene(scene: scene)
                }
            }
        }
        .padding()
    }

    /// Returns a binding that updates the `scene.assignments` for a given screen key.
    private func bindingFor(screenKey: String) -> Binding<UUID?> {
        Binding<UUID?>(
            get: {
                scene.assignments[screenKey]
            },
            set: { newValue in
                if let newValue = newValue {
                    scene.assignments[screenKey] = newValue
                } else {
                    // If user picks "None", remove assignment
                    scene.assignments.removeValue(forKey: screenKey)
                }
            }
        )
    }
}
