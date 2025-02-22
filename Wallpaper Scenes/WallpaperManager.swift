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

    // For storing images on disk
    private let imagesFolderURL: URL
    private let dataFileURL: URL

    // In-memory NSImage cache for faster UI
    @Published var imageCache: [UUID: NSImage] = [:]

    // Key-code mappings for Control+digit (spaces 1–10)
    private let controlDigitKeyCodes: [Int: Int] = [
        1: 18,  // '1'
        2: 19,  // '2'
        3: 20,  // '3'
        4: 21,  // '4'
        5: 23,  // '5'
        6: 22,  // '6'
        7: 26,  // '7'
        8: 28,  // '8'
        9: 25,  // '9'
       10: 29   // '0'
    ]

    // Key-code mappings for Control+Option+digit (spaces 11–16)
    private let controlOptionDigitKeyCodes: [Int: Int] = [
       11: 18, // '1'
       12: 19, // '2'
       13: 20, // '3'
       14: 21, // '4'
       15: 23, // '5'
       16: 22  // '6'
    ]

    init() {
        // Locate or create app support directories
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Application Support directory.")
        }
        
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

        // Load images & scenes from disk
        loadData()

        // Capture existing displays
        self.displays = NSScreen.screens

        // Preload images to speed up UI
        preloadImagesInBackground()

        // Listen for screen changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.displays = NSScreen.screens
        }
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

    // Retrieve an image from cache
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
            if scene.setForAllDesktops {
                var spaceIndex = 1
                var continueSwitching = true

                while continueSwitching {
                    // Try switching to the space
                    print("Switching to space \(spaceIndex)...")
                    continueSwitching = self.trySwitchToSpace(spaceIndex)

                    if continueSwitching {
                        print("Successfully switched to space \(spaceIndex)")

                        // Set wallpapers for all displays on the current space
                        for screen in self.displays {
                            guard let screenID = self.displayID(for: screen) else { continue }
                            let screenKey = String(screenID)
                            
                            if let imageID = scene.assignments[screenKey],
                               let wallpaperImage = self.images.first(where: { $0.id == imageID }) {
                                print("Setting wallpaper for screen \(screen.localizedName) in space \(spaceIndex)")
                                self.setWallpaper(wallpaperImage, for: screen)
                            } else {
                                print("No wallpaper assignment found for screen \(screen.localizedName) in space \(spaceIndex)")
                            }
                        }

                        // Add a 3-second delay after every 4 spaces
//                        if spaceIndex % 4 == 0 {
//                            print("Completed 4 spaces. Pausing for 3 seconds...")
//                            Thread.sleep(forTimeInterval: 3.0)
//                            print("Resuming after delay.")
//                        }

                        spaceIndex += 1
                    } else {
                        print("No more spaces detected. Finished applying wallpapers.")
                    }
                }
            } else {
                // Apply wallpaper only to the current space
                print("Applying wallpaper to the current space only...")
                for screen in self.displays {
                    guard let screenID = self.displayID(for: screen) else { continue }
                    let screenKey = String(screenID)

                    if let imageID = scene.assignments[screenKey],
                       let wallpaperImage = self.images.first(where: { $0.id == imageID }) {
                        print("Setting wallpaper for screen \(screen.localizedName) on the current space.")
                        self.setWallpaper(wallpaperImage, for: screen)
                    } else {
                        print("No wallpaper assignment found for screen \(screen.localizedName) on the current space.")
                    }
                }
            }
        }
    }

    // MARK: - Helper: Switch to a specific space using AppleScript

    private func switchToSpace(_ spaceIndex: Int) {
        // For 1–10, use control + digit
        if let keyCode = controlDigitKeyCodes[spaceIndex] {
            let script = """
            tell application "System Events"
                key code \(keyCode) using control down
                --delay 0.5
            end tell
            """
            runAppleScript(script)
            return
        }

        // For 11–16, use control + option + digit
        if let keyCode = controlOptionDigitKeyCodes[spaceIndex] {
            let script = """
            tell application "System Events"
                key code \(keyCode) using {control down, option down}
                --delay 0.5
            end tell
            """
            runAppleScript(script)
            return
        }

        // If above 16, keep pressing Control+Option+F2 (key code 23) to open the Spaces view,
        // then arrow right multiple times
        if spaceIndex > 16 {
            let movesNeeded = spaceIndex - 16
            var script = """
            tell application "System Events"
                key code 23 using {control down, option down} -- Usually F2 on many keyboards
                --delay 0.5
            """
            for _ in 1...movesNeeded {
                script += """
                    key code 124 using control down
                    --delay 0.5
                """
            }
            script += "end tell"
            runAppleScript(script)
        }
    }

    // MARK: - Helper: Attempt to switch (with success/failure detection)

    private func trySwitchToSpace(_ spaceIndex: Int) -> Bool {
        // Build AppleScript to switch to space; same logic as switchToSpace(_:)
        // but we watch for an AppleScript error to detect if it actually worked.
        var script: String

        // 1–10: control + digit
        if let keyCode = controlDigitKeyCodes[spaceIndex] {
            script = """
            tell application "System Events"
                key code \(keyCode) using control down
                delay 0.5
            end tell
            """
        }
        // 11–16: control + option + digit
        else if let keyCode = controlOptionDigitKeyCodes[spaceIndex] {
            script = """
            tell application "System Events"
                key code \(keyCode) using {control down, option down}
                delay 0.5
            end tell
            """
        }
        // >16: open the spaces UI, then arrow right
        else {
            let movesNeeded = spaceIndex - 16
            script = """
            tell application "System Events"
                key code 23 using {control down, option down}
                delay 0.5
            """
            for _ in 1...movesNeeded {
                script += """
                    key code 124 using control down
                    delay 0.5
                """
            }
            script += """
            end tell
            """
        }

        let (success, errorMessage) = runAppleScript(script)
        if !success, let msg = errorMessage {
            print("Failed to switch to space \(spaceIndex): \(msg)")
            return false
        }
        return success
    }

    // MARK: - Helper: Estimate number of spaces by cycling through them

    private func getNumberOfSpaces() -> Int {
        var maxSpaces = 0
        let maxAttempts = 30  // Arbitrary upper limit for spaces

        for spaceIndex in 1...maxAttempts {
            print("Attempting to switch to space \(spaceIndex) to detect if it exists...")
            let success = self.trySwitchToSpace(spaceIndex)
            if success {
                maxSpaces = spaceIndex
            } else {
                print("Failed to switch to space \(spaceIndex). Assuming no more spaces.")
                break
            }
        }

        print("Detected \(maxSpaces) total spaces.")
        return maxSpaces
    }

    // MARK: - Helper: Set wallpaper for *all* spaces on a given display (AppleScript)

    private func setWallpaperForAllSpaces(url: URL, display: NSScreen) {
        let displayName = display.localizedName
        let pathString = url.path

        // We switch spaces up to however many exist, set the wallpaper each time
        // For demonstration, up to 16 direct spaces + arrow moves after that:
        let spaceScript = """
        on switchSpace(indexValue)
            tell application "System Events"
                if indexValue ≥ 1 and indexValue ≤ 10 then
                    -- control + digit for 1..10
                    set theKeyCode to {18, 19, 20, 21, 23, 22, 26, 28, 25, 29} -- keycodes for 1..9,0
                    key code (item indexValue of theKeyCode) using control down
                    delay 0.5
                else if indexValue ≥ 11 and indexValue ≤ 16 then
                    -- control + option + digit for 11..16
                    set adjIndex to indexValue - 10
                    set theKeyCode to {18, 19, 20, 21, 23, 22} -- keycodes for 1..6
                    key code (item adjIndex of theKeyCode) using {control down, option down}
                    delay 0.5
                else
                    -- spaces above 16: control+option+F2, then arrow right repeatedly
                    set movesNeeded to indexValue - 16
                    key code 23 using {control down, option down}
                    delay 0.5
                    repeat movesNeeded times
                        key code 124 using control down
                        delay 0.5
                    end repeat
                end if
            end tell
        end switchSpace
        """

        let wallpaperScript = """
        on setWallpaperForDisplay(displayName, imagePath)
            tell application "System Events"
                set targetDesktops to every desktop whose display name is displayName
                repeat with d in targetDesktops
                    set picture of d to imagePath
                end repeat
            end tell
        end setWallpaperForDisplay
        """

        // Main AppleScript body
        let mainScript = """
        set spaceCount to 16 -- or however many spaces you want to support automatically
        repeat with spaceIndex from 1 to spaceCount
            my switchSpace(spaceIndex)
            my setWallpaperForDisplay("\(displayName)", "\(pathString)")
        end repeat
        """

        let fullSource = """
        \(spaceScript)
        \(wallpaperScript)
        \(mainScript)
        """

        let (success, errorMsg) = runAppleScript(fullSource)
        if !success, let msg = errorMsg {
            print("Failed to set wallpaper for all spaces: \(msg)")
        }
    }

    // MARK: - Run AppleScript Helper

    @discardableResult
    private func runAppleScript(_ source: String) -> (Bool, String?) {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else {
            return (false, "Could not create NSAppleScript object.")
        }
        scriptObject.executeAndReturnError(&error)
        if let error = error {
            // Extract the error message if possible
            return (false, "\(error)")
        }
        return (true, nil)
    }

    // MARK: - Add image (copy file + store record)

    func addImage(from sourceURL: URL, displayName: String, groups: [String]) {
        let newID = UUID()
        let fileExtension = sourceURL.pathExtension
        let fileName = "\(newID).\(fileExtension)"
        let destinationURL = imagesFolderURL.appendingPathComponent(fileName)

        // Request temporary access if sandboxed
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

        // Save updated list on main
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
                // Now that the images array is updated, preload them:
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

    // Handy method to delete all scenes at once
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
