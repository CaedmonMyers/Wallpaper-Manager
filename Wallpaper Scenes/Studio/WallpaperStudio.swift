//
// Wallpaper Manager
// WallpaperStudio.swift
//
// Created on 12/3/25
//
// Copyright ©2025 DoorHinge Apps.
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - WallpaperStudio

struct WallpaperStudio: View {
    @EnvironmentObject var manager: WallpaperManager
    @State private var selectedWallpaper: WallpaperImage? = nil
    @State private var isEditing = false

    var body: some View {
        VStack {
            if !isEditing {
                // Wallpaper Picker Mode
                WallpaperPickerView(selectedWallpaper: $selectedWallpaper)
                Button("Next") {
                    if selectedWallpaper != nil {
                        isEditing = true
                    }
                }
                .disabled(selectedWallpaper == nil)
                .padding()
            } else {
                // Editor Mode: display the editor and a Back button.
                WallpaperEditorView(wallpaper: selectedWallpaper!)
                Button("Back") {
                    isEditing = false
                }
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - WallpaperPickerView

struct WallpaperPickerView: View {
    @EnvironmentObject var manager: WallpaperManager
    @Binding var selectedWallpaper: WallpaperImage?
    
    // Use a grid layout similar to your library.
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(manager.images) { wallpaper in
                    Button {
                        selectedWallpaper = wallpaper
                    } label: {
                        ZStack {
                            if let nsImage = manager.loadNSImage(for: wallpaper) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipped()
                            } else {
                                Rectangle().fill(Color.gray)
                            }
                            // Highlight selection.
                            if selectedWallpaper?.id == wallpaper.id {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: 4)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

// MARK: - WallpaperEditorView

struct WallpaperEditorView: View {
    @EnvironmentObject var manager: WallpaperManager
    let wallpaper: WallpaperImage

    // Simple effects state.
    @State private var appliedEffects: Set<EffectType> = []
    // Repeating filter state.
    @State private var repeatingFilterEnabled: Bool = false
    @State private var darkGlass: Bool = false
    @State private var numberOfSections: Double = 40  // default sections

    // Core Image context for the blur effect.
    let ciContext = CIContext()

    enum EffectType: String, Hashable {
        case redOverlay
        case blur
    }
    
    var body: some View {
        VStack {
            if let nsImage = manager.loadNSImage(for: wallpaper) {
                // Calculate scaled dimensions for preview.
                let originalSize = nsImage.size
                let scaledHeight: CGFloat = 200
                let scaledWidth: CGFloat = (originalSize.width / originalSize.height) * scaledHeight
                
                // Preview rendered at low resolution.
                previewView(targetWidth: scaledWidth, targetHeight: scaledHeight)
                    .border(Color.secondary, width: 1)
                    .fixedSize()
            } else {
                Rectangle().fill(Color.gray)
                    .frame(height: 200)
            }
            
            // MARK: - Controls
            
            VStack(spacing: 10) {
                HStack {
                    Toggle("Red Overlay", isOn: Binding(
                        get: { appliedEffects.contains(.redOverlay) },
                        set: { newValue in
                            if newValue { appliedEffects.insert(.redOverlay) }
                            else { appliedEffects.remove(.redOverlay) }
                        }
                    ))
                    Toggle("Blur", isOn: Binding(
                        get: { appliedEffects.contains(.blur) },
                        set: { newValue in
                            if newValue { appliedEffects.insert(.blur) }
                            else { appliedEffects.remove(.blur) }
                        }
                    ))
                }
                Toggle("Glass Effect", isOn: $repeatingFilterEnabled)
                if repeatingFilterEnabled {
                    HStack {
                        Toggle("Dark Glass", isOn: $darkGlass)
                        
                        Text("Sections: \(Int(numberOfSections))")
                        Slider(value: $numberOfSections, in: 10...100, step: 1)
                    }
                }
            }
            .onChange(of: darkGlass, { oldValue, newValue in
                repeatingFilterEnabled.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    repeatingFilterEnabled.toggle()
                }
            })
            .padding()
            
            Button("Save New Image") {
                saveNewImage()
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Preview Builder
    
    /// Builds the preview view with the base image and overlays.
    /// The targetWidth/targetHeight parameters determine the rendered size.
    private func previewView(targetWidth: CGFloat, targetHeight: CGFloat) -> some View {
        Group {
            if let nsImage = manager.loadNSImage(for: wallpaper) {
                ZStack {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: targetWidth, height: targetHeight)
                        .clipped()
                    ForEach(Array(appliedEffects), id: \.self) { effect in
                        simpleEffectOverlay(for: effect)
                            .frame(width: targetWidth, height: targetHeight)
                    }
                    if repeatingFilterEnabled {
                        RepeatingFilterOverlay(numberOfSections: Int(numberOfSections), darkGlass: darkGlass)
                            .frame(width: targetWidth, height: targetHeight)
                    }
                }
            }
        }
    }
    
    // MARK: - Save Function
    
    private func saveNewImage() {
        if repeatingFilterEnabled {
            // Save full resolution image with the repeating filter applied.
            guard let nsImage = manager.loadNSImage(for: wallpaper) else { return }
            let fullSize = nsImage.size
            if let snapshot = snapshotPreview(targetWidth: fullSize.width, targetHeight: fullSize.height) {
                manager.addImageFromNSImage(snapshot,
                                            displayName: "Edited " + (wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName),
                                            groups: wallpaper.groups)
            }
        } else {
            // Otherwise, composite simple effects over the full resolution base image.
            guard let baseImage = manager.loadNSImage(for: wallpaper) else { return }
            let imageSize = baseImage.size
            let newImage = NSImage(size: imageSize)
            newImage.lockFocus()
            baseImage.draw(in: NSRect(origin: .zero, size: imageSize))
            
            if appliedEffects.contains(.redOverlay) {
                NSColor.red.withAlphaComponent(0.2).setFill()
                NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
            }
            if appliedEffects.contains(.blur) {
                if let tiffData = baseImage.tiffRepresentation,
                   let ciImage = CIImage(data: tiffData) {
                    let filter = CIFilter.gaussianBlur()
                    filter.inputImage = ciImage
                    filter.radius = 5.0
                    if let outputCIImage = filter.outputImage,
                       let cgImage = ciContext.createCGImage(outputCIImage, from: ciImage.extent) {
                        let blurredImage = NSImage(cgImage: cgImage, size: imageSize)
                        blurredImage.draw(in: NSRect(origin: .zero, size: imageSize),
                                          from: .zero,
                                          operation: .sourceOver,
                                          fraction: 0.3)
                    }
                }
            }
            
            newImage.unlockFocus()
            
            guard let newImageData = newImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: newImageData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return
            }
            
            manager.addImageFromNSImage(newImage,
                                        displayName: "Edited " + (wallpaper.displayName.isEmpty ? wallpaper.fileName : wallpaper.displayName),
                                        groups: wallpaper.groups)
        }
    }
    
    /// Captures a snapshot of the preview view as an NSImage using the given target dimensions.
    private func snapshotPreview(targetWidth: CGFloat, targetHeight: CGFloat) -> NSImage? {
        let preview = previewView(targetWidth: targetWidth, targetHeight: targetHeight)
        let hostingView = NSHostingView(rootView: preview)
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: targetHeight))
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return nil }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        let image = NSImage(size: hostingView.bounds.size)
        image.addRepresentation(rep)
        return image
    }
    
    // MARK: - Simple Effects Overlay
    
    @ViewBuilder
    private func simpleEffectOverlay(for effect: EffectType) -> some View {
        switch effect {
        case .redOverlay:
            Color.red.opacity(0.2)
        case .blur:
            BlurView(material: .contentBackground, blendingMode: .withinWindow)
                .opacity(0.3)
        }
    }
}

// MARK: - Repeating Filter Overlay

struct RepeatingFilterOverlay: View {
    let numberOfSections: Int
    @State var darkGlass: Bool
    var body: some View {
        GeometryReader { geo in
            let sectionWidth = geo.size.width / CGFloat(numberOfSections)
            HStack(spacing: 0) {
                ForEach(0..<numberOfSections, id: \.self) { _ in
                    RepeatingFilterSectionView(darkGlass: darkGlass)
                        .frame(width: sectionWidth, height: geo.size.height)
                }
            }
        }
    }
}

// MARK: - Repeating Filter Section View

struct RepeatingFilterSectionView: View {
    @State var darkGlass: Bool
    var body: some View {
        ZStack {
            // Draw the horizontal gradient:
            // Left half: white at 0% opacity; right half: fading to white at 30% opacity.
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: darkGlass ? Color.black.opacity(0): Color.white.opacity(0), location: 0.0),
                    .init(color: darkGlass ? Color.black.opacity(0): Color.white.opacity(0), location: 0.4),
                    .init(color: darkGlass ? Color.black.opacity(0.3): Color.white.opacity(0.3), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - BlurView

struct BlurView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - WallpaperManager Extension

extension WallpaperManager {
    /// Saves an NSImage as a PNG and adds it to the library.
    func addImageFromNSImage(_ nsImage: NSImage, displayName: String, groups: [String]) {
        let newID = UUID()
        let fileName = "\(newID).png"
        let destinationURL = imagesFolderURL.appendingPathComponent(fileName)
        
        guard let imageData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        do {
            try pngData.write(to: destinationURL)
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
            print("Error saving edited image: \(error)")
        }
    }
}
