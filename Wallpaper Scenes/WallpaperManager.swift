import SwiftUI
import AppKit
import SQLite

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
                        self.setWallpaperForAllSpacesViaDB(imagePath: url.path)
                    } else {
                        // Use the standard “current desktop” call
                        self.setWallpaper(wallpaperImage, for: screen)
                    }
                }
            }
        }
    }

    func setWallpaperForAllSpacesViaDB(imagePath: String) {
            do {
                // 1) Build path to the DB in ~/Library/Application Support/Dock/
                let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
                let dbPath = homeDirURL
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Application Support")
                    .appendingPathComponent("Dock")
                    .appendingPathComponent("desktoppicture.db").path

                // 2) Ensure the file to be set actually exists
                guard FileManager.default.fileExists(atPath: imagePath) else {
                    print("Error: File does not exist at path \(imagePath)")
                    return
                }

                // 3) Open the DB
                let db = try Connection(dbPath)

                // 4) Insert or find a row in the data table for this image path
                let dataId = try insertOrFindDataRow(db: db, imagePath: imagePath)

                // 5) Reset preferences to point them all to dataId
                try resetPreferences(db: db, dataId: dataId)

                // 6) Restart Dock to see changes
                try restartDock()

            } catch {
                print("Error in setWallpaperForAllSpacesViaDB: \(error)")
            }
        }

        /// Return the rowid in `data` for the given path, inserting if needed.
    private func insertOrFindDataRow(db: Connection, imagePath: String) throws -> Int64 {
        let dataTable = Table("data")
        let valueColumn = SQLite.Expression<String?>("value") // Change from "path" to "value"

        var foundRowId: Int64 = 0

        // Update your raw SQL query to select from 'value' instead of 'path'
        for row in try db.prepare("SELECT rowid, value FROM data") {
            let rowId = row[0] as? Int64
            let existingPath = row[1] as? String
            if existingPath == imagePath {
                foundRowId = rowId ?? 0
                break
            }
        }

        // Insert new record if not found
        if foundRowId == 0 {
            foundRowId = try db.run(dataTable.insert(valueColumn <- imagePath))
        }
        return foundRowId
    }



        /// Clears out `preferences` and re-inserts one row per `pictures` entry, all pointing to `dataId`.
        private func resetPreferences(db: Connection, dataId: Int64) throws {
            // We want to wipe out all existing preferences, then re-insert them so everything
            // references the same dataId. On Big Sur and later, the `pictures` table often has
            // one row per display or space, so we re-use that count for how many preference rows to add.
            let picturesTable = Table("pictures")
            let preferencesTable = Table("preferences")

            // columns in preferences
            let keyCol = SQLite.Expression<Int>("key")          // typically 1
            let dataIdCol = SQLite.Expression<Int64>("data_id") // which wallpaper row in `data`
            let pictureIdCol = SQLite.Expression<Int64>("picture_id")

            try db.transaction {
                // remove everything from preferences
                try db.run(preferencesTable.delete())

                // Insert new references in the preferences table
                var index = 1
                for _ in try db.prepare(picturesTable) {
                    try db.run(preferencesTable.insert(
                        keyCol <- 1,
                        dataIdCol <- dataId,
                        pictureIdCol <- Int64(index)
                    ))
                    index += 1
                }
            }
        }

        /// Tells the Dock to restart, applying the new wallpaper settings immediately.
    private func restartDock() throws {
        let source = """
        tell application "System Events"
            delay 0.5
            tell application "Dock" to quit
            delay 0.5
            tell application "Dock" to activate
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error restarting Dock: \(error)")
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
