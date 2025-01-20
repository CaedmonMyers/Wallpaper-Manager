import SwiftUI
import AppKit

struct LibraryView: View {
    @EnvironmentObject var manager: WallpaperManager

    // Which groups the user has selected in the multi‐select menu
    @State private var selectedGroups: [String] = []

    // Whether we’re showing the “Import Wallpaper” sheet
    @State private var showingImportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter + Add button
            HStack {
                // Multi‐select group filter (simulated with a Menu of checkable items)
                Menu("Filter by Groups") {
                    ForEach(allGroups, id: \.self) { group in
                        Button {
                            toggleGroupFilter(group)
                        } label: {
                            // Show a checkmark if this group is currently selected
                            Label(group, systemImage: selectedGroups.contains(group) ? "checkmark" : "")
                        }
                    }
                }

                Spacer()

                Button("Add New Wallpaper") {
                    showingImportSheet = true
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Show matching wallpapers
            List(filteredWallpapers) { wallpaper in
                HStack {
                    // Thumbnail
                    if let nsimg = manager.loadNSImage(for: wallpaper) {
                        Image(nsImage: nsimg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipped()
                    } else {
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 50, height: 50)
                    }

                    VStack(alignment: .leading) {
                        // If displayName is non‐empty, show that; else show fileName
                        Text(wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName)
                            .font(.headline)
                        if !wallpaper.groups.isEmpty {
                            Text("Groups: \(wallpaper.groups.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        // Sheet for importing a wallpaper
        .sheet(isPresented: $showingImportSheet) {
            ImportWallpaperSheetView()
                .environmentObject(manager)
        }
    }

    // MARK: - Data Helpers

    /// All distinct groups across all images
    private var allGroups: [String] {
        let groupSet = Set(manager.images.flatMap { $0.groups })
        return groupSet.sorted()
    }

    /// Only wallpapers whose groups contain ALL of the user’s selected groups
    private var filteredWallpapers: [WallpaperImage] {
        if selectedGroups.isEmpty {
            return manager.images
        } else {
            return manager.images.filter { wallpaper in
                selectedGroups.allSatisfy { wallpaper.groups.contains($0) }
            }
        }
    }

    private func toggleGroupFilter(_ group: String) {
        if let idx = selectedGroups.firstIndex(of: group) {
            // Remove if currently selected
            selectedGroups.remove(at: idx)
        } else {
            // Add if not already selected
            selectedGroups.append(group)
        }
    }
}
