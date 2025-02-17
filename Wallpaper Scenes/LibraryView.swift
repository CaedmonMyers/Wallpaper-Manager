import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @EnvironmentObject var manager: WallpaperManager

    // Groups filter – which groups are currently selected?
    @State private var selectedGroups: Set<String> = []

    // Show the Import wallpaper sheet
    @State private var showingImportSheet = false

    // Show the Create new Scene sheet
    @State private var showingSceneSheet = false

    // Whether the group drop-down is expanded
    @State private var isGroupDropdownOpen = false

    // For drag & drop highlighting
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with group filter, +, "Create Scene" button
            HStack {
                // Custom group filter drop-down
                VStack(alignment: .leading, spacing: 4) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 75, maximum: 120), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(allGroups, id: \.self) { group in
                            Button {
                                withAnimation {
                                    toggleGroupFilter(group)
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 50)
                                        .fill(Color(.systemBlue))
                                    
                                    HStack {
                                        Text(group)
                                        
                                        if selectedGroups.contains(group) {
                                            Image(systemName: "xmark")
                                                .padding(2)
                                                .bold()
                                        }
                                    }.foregroundStyle(.white)
                                        .padding(5)
                                }
                                
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                Button("Add New Wallpaper") {
                    showingImportSheet = true
                }

                Button("Create New Scene") {
                    showingSceneSheet = true
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // The grid of wallpapers
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(filteredWallpapers) { wallpaper in
                        LibraryItemView(wallpaper: wallpaper)
                    }
                }
                .padding()
            }
            .onDrop(
                of: [.fileURL],
                isTargeted: $isDropTargeted
            ) { providers in
                handleDrop(providers: providers)
            }
        }
        // Import sheet
        .sheet(isPresented: $showingImportSheet) {
            ImportWallpaperSheetView()
                .environmentObject(manager)
        }
        // Scene creation sheet
        .sheet(isPresented: $showingSceneSheet) {
            CreateSceneSheetView()
                .environmentObject(manager)
        }
        .overlay(
            // Optional highlight overlay while dragging
            isDropTargeted ? Color.accentColor.opacity(0.15) : Color.clear
        )
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
                            manager.addImage(from: fileURL, displayName: baseName, groups: [])
                        }
                        didLoadAny = true
                    }
                }
            }
        }
        return didLoadAny
    }

    // MARK: - Group Filtering

    /// A sorted list of **all** groups that exist among all wallpapers
    private var allGroups: [String] {
        let groupSet = Set(manager.images.flatMap { $0.groups })
        return groupSet.sorted()
    }

    /// The wallpapers that match the current group filter (i.e., must contain all selectedGroups).
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
        if selectedGroups.contains(group) {
            selectedGroups.remove(group)
        } else {
            selectedGroups.insert(group)
        }
    }
}



struct LibraryItemView: View {
    @EnvironmentObject var manager: WallpaperManager
    let wallpaper: WallpaperImage

    @State private var isEditing = false
    @State private var editedName = ""

    // Group editing
    @State private var groupSearchText = ""
    // Whether we are showing the list of matching group suggestions
    private var showSuggestions: Bool {
        !groupSearchText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 16x9 thumbnail
            if let nsimg = manager.loadNSImage(for: wallpaper) {
                GeometryReader { geo in
                    Image(nsImage: nsimg)
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

            // Display name + groups + Edit/Delete
            VStack(alignment: .leading, spacing: 6) {
                if isEditing {
                    // NAME editing
                    TextField("Enter new name", text: $editedName, onCommit: {
                        commitEditName()
                    })
                    .textFieldStyle(.roundedBorder)
                } else {
                    // NAME (read-only)
                    Text(wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName)
                        .font(.headline)
                        .lineLimit(1)
                }

                // GROUPS (if user is editing, show a textfield + suggestions)
                if isEditing {
                    // Existing groups, each with a remove button
                    if !wallpaper.groups.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(wallpaper.groups, id: \.self) { groupName in
                                HStack(spacing: 4) {
                                    Text(groupName)
                                        .font(.caption)
                                    Button {
                                        removeGroup(groupName)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }

                    // TextField to add or search for groups
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Add or search groups...", text: $groupSearchText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                // If user presses Return, try to add what's typed
                                tryAddGroup(groupSearchText)
                            }

                        // Suggestions
                        if showSuggestions {
                            let suggestions = managerGroupsMatching(groupSearchText)
                            if suggestions.isEmpty {
                                // Offer to add a brand new group
                                Button("Add “\(groupSearchText)”") {
                                    tryAddGroup(groupSearchText)
                                }
                                .buttonStyle(.link)
                            } else {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        tryAddGroup(suggestion)
                                    }
                                    .buttonStyle(.link)
                                }
                            }
                        }
                    }
                } else {
                    // GROUPS (read-only)
                    if !wallpaper.groups.isEmpty {
                        Text("Groups: \(wallpaper.groups.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Buttons row
                HStack {
                    Spacer()

                    // Edit button
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            commitEditName()
                        } else {
                            startEditing()
                        }
                    }

                    // Delete button
                    Button {
                        manager.deleteWallpaper(wallpaper)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete this wallpaper")
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            self.editedName = wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName
        }
    }

    // MARK: - Name Editing

    private func startEditing() {
        editedName = wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName
        groupSearchText = ""
        isEditing = true
    }

    private func commitEditName() {
        let newName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Update manager only if changed
        if let index = manager.images.firstIndex(of: wallpaper),
           !newName.isEmpty,
           manager.images[index].displayName != newName {
            manager.images[index].displayName = newName
            manager.saveData()
        }
        // End edit mode for name
        isEditing.toggle()
    }

    // MARK: - Group Editing

    private func removeGroup(_ groupName: String) {
        if let idx = manager.images.firstIndex(of: wallpaper) {
            manager.images[idx].groups.removeAll(where: { $0 == groupName })
            manager.saveData()
        }
    }

    private func tryAddGroup(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let idx = manager.images.firstIndex(of: wallpaper) {
            var groups = manager.images[idx].groups
            if !groups.contains(trimmed) {
                groups.append(trimmed)
                manager.images[idx].groups = groups
                manager.saveData()
            }
        }
        groupSearchText = ""
    }

    /// Returns existing groups in the entire library that contain the search text.
    private func managerGroupsMatching(_ text: String) -> [String] {
        let allGroups = Set(manager.images.flatMap { $0.groups })
        return allGroups
            .filter { $0.localizedCaseInsensitiveContains(text) }
            .sorted()
    }
}
