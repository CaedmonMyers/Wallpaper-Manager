// DisplayDetailView.swift

import SwiftUI
import AppKit

struct DisplayDetailView: View {
    @EnvironmentObject var manager: WallpaperManager
    @EnvironmentObject var backgroundManager: BackgroundManager
    let screen: NSScreen

    @State private var selectedWallpaperID: UUID?
    
    @State var screenNumber: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Display: \(screen.localizedName)")
                .font(.headline)
            Text("Screen ID: \(manager.displayID(for: screen) ?? 0)")
                .font(.subheadline)

            Divider()

            Text("Choose a Wallpaper:")
                .font(.subheadline)

            // Wallpaper grid
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(manager.images) { wallpaper in
                        WallpaperGridItem(
                            wallpaper: wallpaper,
                            nsImage: manager.loadNSImage(for: wallpaper),
                            isSelected: wallpaper.id == selectedWallpaperID,
                            onSelect: {
                                setWallpaper(wallpaper)
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .padding()
        .onAppear {
            // Load the currently assigned wallpaper for this display
            if let currentFileName = manager.getCurrentWallpaperFileName(for: screen),
               let currentWallpaper = manager.images.first(where: { $0.fileName == currentFileName }) {
                selectedWallpaperID = currentWallpaper.id
            }
        }
        .onChange(of: screenNumber) { oldValue, newValue in
            if let currentFileName = manager.getCurrentWallpaperFileName(for: screen),
               let currentWallpaper = manager.images.first(where: { $0.fileName == currentFileName }) {
                selectedWallpaperID = currentWallpaper.id
            }
        }
    }

    private func setWallpaper(_ wallpaper: WallpaperImage) {
        selectedWallpaperID = wallpaper.id
        manager.setWallpaper(wallpaper, for: screen)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Load the NSImage from the selected wallpaper
            if let image = manager.loadNSImage(for: wallpaper) {
                backgroundManager.updateColors(with: image)
            }
        }
    }
}






struct WallpaperGridItem: View {
    let wallpaper: WallpaperImage
    let nsImage: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail with 16:9 aspect ratio
            if let nsImage = nsImage {
                GeometryReader { geo in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(16.0/9.0, contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width * 9/16)
                        .clipped()
                }
                .aspectRatio(16.0/9.0, contentMode: .fit)
            } else {
                // Fallback placeholder
                Rectangle()
                    .foregroundColor(.gray)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
            }
//                Image(nsImage: nsImage)
//                    .resizable()
//                    .aspectRatio(16/9, contentMode: .fill)
//                    .frame(width: 200, height: 112)
//                    .clipped()
//            } else {
//                // Placeholder if image fails to load
//                Rectangle()
//                    .foregroundColor(.gray)
//                    .aspectRatio(16/9, contentMode: .fill)
//                    .frame(width: 200, height: 112)
//            }

            // Display name and groups
            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName)
                    .font(.caption)
                    .lineLimit(1)
                if !wallpaper.groups.isEmpty {
                    Text("Groups: \(wallpaper.groups.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 4)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

