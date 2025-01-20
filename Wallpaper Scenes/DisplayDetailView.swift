import SwiftUI
import AppKit

struct DisplayDetailView: View {
    @EnvironmentObject var manager: WallpaperManager
    let screen: NSScreen

    var body: some View {
        VStack(alignment: .leading) {
            Text("Display: \(screen.localizedName)")
                .font(.headline)
            Text("Screen ID: \(manager.displayID(for: screen) ?? 0)")

            Divider()

            Text("Choose a wallpaper:")
                .font(.subheadline)
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(manager.images) { img in
                        HStack {
                            Text(img.fileName)
                            Spacer()
                            Button("Set as Wallpaper") {
                                manager.setWallpaper(img, for: screen)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}
