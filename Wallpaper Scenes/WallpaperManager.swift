import SwiftUI
import AppKit

// MARK: - WallpaperImage

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

// MARK: - WallpaperScene

struct WallpaperScene: Identifiable, Codable {
    let id: UUID
    var name: String
    var assignments: [String: UUID]
    var setForAllDesktops: Bool

    init(
        id: UUID = UUID(),
        name: String,
        assignments: [String: UUID] = [:],
        setForAllDesktops: Bool = false
    ) {
        self.id = id
        self.name = name
        self.assignments = assignments
        self.setForAllDesktops = setForAllDesktops
    }
}


// MARK: - Codable container for saving/loading arrays

fileprivate struct SavedData: Codable {
    var images: [WallpaperImage]
    var scenes: [WallpaperScene]
}

// MARK: - WallpaperManager

class WallpaperManager: ObservableObject {
    @Published var images: [WallpaperImage] = []
    @Published var scenes: [WallpaperScene] = []

    // Store screens to avoid reloading repeatedly
    @Published var displays: [NSScreen] = []

    private let imagesFolderURL: URL
    private let dataFileURL: URL

    // In-memory NSImage cache for faster UI
    @Published var imageCache: [UUID: NSImage] = [:]

    init() {
        // Locate or create app support directories
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let bundleID = Bundle.main.bundleIdentifier ?? "WallpaperManager"
            let containerURL = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            
            imagesFolderURL = containerURL.appendingPathComponent("WallpaperImages", isDirectory: true)
            dataFileURL = containerURL.appendingPathComponent("wallpaperData.json")

            do {
                try fm.createDirectory(at: containerURL, withIntermediateDirectories: true)
                try fm.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)
            } catch {
                fatalError("Failed to create required directories: \(error)")
            }
        } else {
            fatalError("Unable to locate Application Support directory.")
        }

        // Load images & scenes from disk
        loadData()

        // Capture existing displays in an array
        self.displays = NSScreen.screens

        // Preload images to speed up UI
        preloadImagesInBackground()

        // Listen for screen changes (hot-plug monitors, etc.)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.displays = NSScreen.screens
            }
        )
    }

    // MARK: - Preload all images to cache (async)
    private func preloadImagesInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            var newCache: [UUID: NSImage] = [:]
            for wallpaper in self.images {
                let fileURL = self.imagesFolderURL.appendingPathComponent(wallpaper.fileName)
                if let loadedImage = NSImage(contentsOf: fileURL) {
                    newCache[wallpaper.id] = loadedImage
                }
            }
            DispatchQueue.main.async {
                self.imageCache = newCache
            }
        }
    }

    // MARK: - Retrieve an image from cache
    func loadNSImage(for wallpaper: WallpaperImage) -> NSImage? {
        return imageCache[wallpaper.id]
    }

    // MARK: - Set a wallpaper (background thread)
    func setWallpaper(_ image: WallpaperImage, for screen: NSScreen) {
        let url = imagesFolderURL.appendingPathComponent(image.fileName)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                print("Error setting wallpaper for \(screen.localizedName): \(error)")
            }
        }
    }

    // MARK: - Apply entire scene (background thread)
    func applyScene(_ scene: WallpaperScene) {
        DispatchQueue.global(qos: .userInitiated).async {
            for screen in self.displays {
                guard let screenID = self.displayID(for: screen) else { continue }
                let screenKey = String(screenID)
                
                if let imageID = scene.assignments[screenKey],
                   let wallpaperImage = self.images.first(where: { $0.id == imageID }) {
                    let url = self.imagesFolderURL.appendingPathComponent(wallpaperImage.fileName)
                    
                    if scene.setForAllDesktops {
                        // Use AppleScript to set across *all* spaces
                        self.setWallpaperForAllSpaces(url: url, display: screen)
                    } else {
                        // Use the standard “current desktop” call
                        self.setWallpaper(wallpaperImage, for: screen)
                    }
                }
            }
        }
    }

    /// Sets wallpaper for *all* spaces on a given display using AppleScript.
    private func setWallpaperForAllSpaces(url: URL, display: NSScreen) {
        let displayName = display.localizedName
        let pathString = url.path

        // AppleScript command to set the wallpaper on all desktops for the given display
        let source = """
        tell application \"System Events\"
            set allDesktops to every desktop whose display name is \"\(displayName)\"
            repeat with d in allDesktops
                set picture of d to \"\(pathString)\"
            end repeat
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Failed to set wallpaper for all desktops: \(error)")
            }
        }
    }


    // MARK: - Add image (copy file + store record)
    func addImage(from sourceURL: URL, displayName: String, groups: [String]) {
        let newID = UUID()
        let fileExtension = sourceURL.pathExtension
        let fileName = "\(newID).\(fileExtension)"
        let destinationURL = imagesFolderURL.appendingPathComponent(fileName)

        // Request temporary access
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: sourceURL) // **This line was failing before**
                try data.write(to: destinationURL)

                DispatchQueue.main.async {
                    let newImage = WallpaperImage(
                        id: newID,
                        fileName: fileName,
                        displayName: displayName,
                        groups: groups
                    )
                    self.images.append(newImage)
                    self.preloadImagesInBackground()
                    self.saveData()
                }
            } catch {
                print("Error adding image: \(error.localizedDescription)")
            }
        }
    }


    // MARK: - Delete wallpaper
    func deleteWallpaper(_ wallpaper: WallpaperImage) {
        // Remove from array
        if let idx = images.firstIndex(of: wallpaper) {
            images.remove(at: idx)
        }

        // Remove file from disk on background queue
        let fileURL = imagesFolderURL.appendingPathComponent(wallpaper.fileName)
        DispatchQueue.global(qos: .background).async {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to delete file: \(error)")
            }
        }

        // Save updated list (on main)
        DispatchQueue.main.async {
            self.saveData()
        }
    }

    // MARK: - Create or update scene
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
            DispatchQueue.main.async {
                self.images = decoded.images
                self.scenes = decoded.scenes
                // Now that the images array is updated, preload the images:
                self.preloadImagesInBackground()
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    func saveData() {
        let savedData = SavedData(images: images, scenes: scenes)
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(savedData)
                try data.write(to: self.dataFileURL, options: .atomic)
            } catch {
                print("Failed to save data: \(error)")
            }
        }
    }
    
    func deleteAllScenes() {
        DispatchQueue.main.async {
            self.scenes.removeAll()
            self.saveData() // Save immediately so the JSON file updates
        }
    }


    // MARK: - Display Helpers

    /// Returns a CGDirectDisplayID from an NSScreen
    func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenID = screen.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return screenID
    }

    /// Example “get current wallpaper fileName,” if you track it in `scenes.first`.
    func getCurrentWallpaperFileName(for screen: NSScreen) -> String? {
        guard let screenID = displayID(for: screen) else { return nil }
        if let imageID = scenes.first?.assignments["\(screenID)"],
           let wallpaper = images.first(where: { $0.id == imageID }) {
            return wallpaper.fileName
        }
        return nil
    }
}
