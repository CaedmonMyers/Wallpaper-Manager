//
// Wallpaper Manager
// ImportSheet.swift
//
// Created on 19/1/25
//
// Copyright ©2025 DoorHinge Apps.
//


import SwiftUI

struct ImportWallpaperSheetView: View {
    @EnvironmentObject var manager: WallpaperManager
    @Environment(\.dismiss) private var dismiss

    // The file they picked
    @State private var selectedFileURL: URL?
    @State private var showingFileImporter = false

    // The display name the user enters
    @State private var displayName: String = ""

    // Groups
    @State private var groupSearchText: String = ""
    @State private var chosenGroups: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import New Wallpaper")
                .font(.title2)

            // File selection row
            HStack {
                Text(selectedFileURL?.lastPathComponent ?? "No file selected")
                    .foregroundColor(.secondary)
                Spacer()
                Button("Select File") {
                    showingFileImporter = true
                }
            }

            // Display name
            TextField("Display Name (optional)", text: $displayName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Groups
            Text("Groups: \(chosenGroups.joined(separator: ", "))")
                .font(.subheadline)
            TextField("Search or add group…", text: $groupSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: groupSearchText) { _ in
                    // Could update a filtered suggestion list
                }

            // Suggestions for groups that match the user’s typed text
            if !groupSearchText.isEmpty {
                let suggestions = managerGroupsMatching(groupSearchText)
                if suggestions.isEmpty {
                    // Option to add a brand new group
                    Button("Add \"\(groupSearchText)\"") {
                        addGroup(groupSearchText)
                    }
                    .buttonStyle(LinkButtonStyle())
                } else {
                    ForEach(suggestions, id: \.self) { grp in
                        Button(grp) {
                            addGroup(grp)
                        }
                        .buttonStyle(LinkButtonStyle())
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Add Wallpaper") {
                    if let fileURL = selectedFileURL {
                        manager.addImage(
                            from: fileURL,
                            displayName: displayName,
                            groups: chosenGroups
                        )
                    }
                    dismiss()
                }
                .disabled(selectedFileURL == nil)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let url):
                selectedFileURL = url.first
            case .failure(let error):
                print("File importer error: \(error.localizedDescription)")
            }
        }
    }

    private func addGroup(_ grp: String) {
        let trimmed = grp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !chosenGroups.contains(trimmed) {
            chosenGroups.append(trimmed)
        }
        groupSearchText = ""
    }

    private func managerGroupsMatching(_ searchText: String) -> [String] {
        let allGroups = Set(manager.images.flatMap { $0.groups })
        return allGroups
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .sorted()
    }
}
