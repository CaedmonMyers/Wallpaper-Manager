import SwiftUI
import AppKit
import Darwin

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
                        // Use private API to set across *all* spaces on this display
                        self.setWallpaperForAllSpaces(url: url, display: screen)
                    } else {
                        // Use the standard “current desktop” call
                        self.setWallpaper(wallpaperImage, for: screen)
                    }
                }
            }
        }
    }

    private func _CGSDefaultConnection() -> UInt32 {
            return CGSMainConnectionID()
        }

        private func setWallpaperForAllSpaces(url: URL, display: NSScreen) {
            let connection = _CGSDefaultConnection()
            guard let displayID = self.displayID(for: display) else { return }
            guard let spacesArray = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
                print("Failed to get Spaces using SkyLight.")
                return
            }

            // Loop through spaces and set wallpaper
            for displaySpaces in spacesArray {
                if let managedDisplayID = displaySpaces["Display Identifier"] as? String,
                   managedDisplayID.contains(String(displayID)) {

                    if let spaces = displaySpaces["Spaces"] as? [[String: Any]] {
                        for space in spaces {
                            if let spaceID = space["id64"] as? Int64 {
                                let imageURL = url as CFURL
                                let result = CGSSetDesktopImageURL(connection, spaceID, imageURL, [:] as CFDictionary)
                                if result != 0 {
                                    print("Failed to set wallpaper for space \(spaceID) on display \(display.localizedName)")
                                } else {
                                    print("Successfully set wallpaper for space \(spaceID) on display \(display.localizedName)")
                                }
                            }
                        }
                    }
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
                let data = try Data(contentsOf: sourceURL)
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
            self.saveData()
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

    /// Example get current wallpaper fileName
    func getCurrentWallpaperFileName(for screen: NSScreen) -> String? {
        guard let screenID = displayID(for: screen) else { return nil }
        if let imageID = scenes.first?.assignments["\(screenID)"],
           let wallpaper = images.first(where: { $0.id == imageID }) {
            return wallpaper.fileName
        }
        return nil
    }
}


class SkyLightLoader {
    static let shared = SkyLightLoader()
    private var handle: UnsafeMutableRawPointer?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        if handle == nil {
            fatalError("Failed to load SkyLight framework.")
        }
    }

    func loadSymbol<T>(_ symbolName: String, as type: T.Type) -> T {
        guard let symbol = dlsym(handle, symbolName) else {
            fatalError("Symbol \(symbolName) not found in SkyLight.")
        }
        return unsafeBitCast(symbol, to: type)
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }
}

// MARK: - SkyLight Function Declarations

typealias CGSCopyManagedDisplaySpacesFunc = @convention(c) (UInt32) -> CFArray?
typealias CGSSetDesktopImageURLFunc = @convention(c) (UInt32, Int64, CFURL, CFDictionary) -> Int32
typealias CGSMainConnectionIDFunc = @convention(c) () -> UInt32

let CGSCopyManagedDisplaySpaces: CGSCopyManagedDisplaySpacesFunc = SkyLightLoader.shared.loadSymbol("CGSCopyManagedDisplaySpaces", as: CGSCopyManagedDisplaySpacesFunc.self)
let CGSSetDesktopImageURL: CGSSetDesktopImageURLFunc = SkyLightLoader.shared.loadSymbol("CGSSetDesktopImageURL", as: CGSSetDesktopImageURLFunc.self)
let CGSMainConnectionID: CGSMainConnectionIDFunc = SkyLightLoader.shared.loadSymbol("CGSMainConnectionID", as: CGSMainConnectionIDFunc.self)
