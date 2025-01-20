import SwiftUI
import AppKit

struct WallpaperImage: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var displayName: String
    var groups: [String]

    init(
        id: UUID = UUID(),
        fileName: String,
        displayName: String = "",
        groups: [String] = []
    ) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.groups = groups
    }
}


struct WallpaperScene: Identifiable, Codable {
    let id: UUID
    var name: String
    var assignments: [String: UUID]

    init(id: UUID = UUID(), name: String, assignments: [String: UUID] = [:]) {
        self.id = id
        self.name = name
        self.assignments = assignments
    }
}

class WallpaperManager: ObservableObject {
    @Published var images: [WallpaperImage] = []
    @Published var scenes: [WallpaperScene] = []

    private let imagesFolderURL: URL
    private let dataFileURL: URL

    init() {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let bundleID = Bundle.main.bundleIdentifier ?? "WallpaperManager"
            let containerURL = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            
            imagesFolderURL = containerURL.appendingPathComponent("WallpaperImages", isDirectory: true)
            dataFileURL = containerURL.appendingPathComponent("wallpaperData.json")

            // Create directories if needed
            do {
                try fm.createDirectory(at: containerURL, withIntermediateDirectories: true)
                try fm.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)
            } catch {
                fatalError("Failed to create required directories: \(error)")
            }
        } else {
            fatalError("Unable to locate Application Support directory.")
        }

        loadData()
    }

    // MARK: - Displays
    func getConnectedDisplays() -> [NSScreen] {
        NSScreen.screens
    }

    func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return screenID
    }

    // MARK: - Wallpaper
    func setWallpaper(_ image: WallpaperImage, for screen: NSScreen) {
        let url = imagesFolderURL.appendingPathComponent(image.fileName)
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        } catch {
            print("Error setting wallpaper for screen \(screen): \(error.localizedDescription)")
        }
    }

    /// FIXED METHOD: Now uses startAccessingSecurityScopedResource() to avoid “permission denied”.
    func addImage(from sourceURL: URL, displayName: String, groups: [String]) {
        let newID = UUID()
        let fileExtension = sourceURL.pathExtension
        let fileName = "\(newID).\(fileExtension)"
        let destinationURL = imagesFolderURL.appendingPathComponent(fileName)

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Copy the file into our container
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL)

            // Create the new image record
            let newImage = WallpaperImage(
                id: newID,
                fileName: fileName,
                displayName: displayName,
                groups: groups
            )
            images.append(newImage)
            saveData()

        } catch {
            print("Error adding image to \(destinationURL.path): \(error.localizedDescription)")
        }
    }
    
    func loadNSImage(for wallpaper: WallpaperImage) -> NSImage? {
        let url = imagesFolderURL.appendingPathComponent(wallpaper.fileName)
        return NSImage(contentsOf: url)
    }

    // MARK: - Scenes
    func applyScene(_ scene: WallpaperScene) {
        let connectedScreens = getConnectedDisplays()
        for screen in connectedScreens {
            guard let screenID = displayID(for: screen) else { continue }
            let screenKey = String(screenID)
            if let imageID = scene.assignments[screenKey],
               let wallpaperImage = images.first(where: { $0.id == imageID }) {
                setWallpaper(wallpaperImage, for: screen)
            }
        }
    }

    func createOrUpdateScene(scene: WallpaperScene) {
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index] = scene
        } else {
            scenes.append(scene)
        }
        saveData()
    }

    // MARK: - Persistence
    private func loadData() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoded = try JSONDecoder().decode(SavedData.self, from: data)
            self.images = decoded.images
            self.scenes = decoded.scenes
        } catch {
            print("Failed to load data: \(error.localizedDescription)")
        }
    }

    private func saveData() {
        let savedData = SavedData(images: images, scenes: scenes)
        do {
            let data = try JSONEncoder().encode(savedData)
            try data.write(to: dataFileURL, options: .atomic)
        } catch {
            print("Failed to save data: \(error.localizedDescription)")
        }
    }
}

fileprivate struct SavedData: Codable {
    var images: [WallpaperImage]
    var scenes: [WallpaperScene]
}
