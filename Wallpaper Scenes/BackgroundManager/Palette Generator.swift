import SwiftUI
import AppKit
import CoreImage

func extractColorPalette(from image: NSImage) -> [String] {
    print("Starting color extraction...")

    // Step 1: Downscale the image to a max of 600x600 while keeping aspect ratio
    let resizedImage = downscaleImage(image, maxDimension: 600)

    // Convert to CIImage
    guard let tiffData = resizedImage.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        print("Failed to convert NSImage to CIImage")
        return []
    }

    // Step 2: Apply Gaussian blur
    let blurredImage = ciImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 10])

    // Convert to CGImage
    let context = CIContext()
    guard let cgImage = context.createCGImage(blurredImage, from: blurredImage.extent) else {
        print("Failed to create CGImage from blurred CIImage")
        return []
    }

    // Step 3: Convert back to NSImage
    let blurredNSImage = NSImage(size: resizedImage.size)
    blurredNSImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
    print("Image successfully resized, blurred, and converted")

    // Step 4: Extract colors
    return extractColors(from: blurredNSImage)
}

// ✅ Function to downscale image while maintaining aspect ratio
func downscaleImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
    let originalWidth = image.size.width
    let originalHeight = image.size.height
    
    // If already smaller, return original
    if originalWidth <= maxDimension && originalHeight <= maxDimension {
        print("Image is already within the max dimensions. Skipping resizing.")
        return image
    }

    // Maintain aspect ratio
    let aspectRatio = originalWidth / originalHeight
    let newWidth: CGFloat
    let newHeight: CGFloat
    
    if originalWidth > originalHeight {
        newWidth = maxDimension
        newHeight = maxDimension / aspectRatio
    } else {
        newHeight = maxDimension
        newWidth = maxDimension * aspectRatio
    }

    let newSize = NSSize(width: newWidth, height: newHeight)
    let resizedImage = NSImage(size: newSize)

    resizedImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    resizedImage.unlockFocus()

    print("Image resized to: \(Int(newWidth))x\(Int(newHeight))")
    return resizedImage
}

// ✅ Extract 6 colors from the blurred image
func extractColors(from image: NSImage) -> [String] {
    guard let bitmapRep = NSBitmapImageRep(data: image.tiffRepresentation!) else {
        print("Failed to get bitmap representation of image")
        return []
    }

    let width = bitmapRep.pixelsWide
    let height = bitmapRep.pixelsHigh
    let sectionHeight = height / 2
    let sectionWidth = width / 3

    var hexColors: [String] = []

    print("Image dimensions after processing: \(width)x\(height)")

    for row in 0..<2 {
        for col in 0..<3 {
            let xStart = col * sectionWidth
            let yStart = row * sectionHeight
            print("Processing section (\(row), \(col)) at x:\(xStart) y:\(yStart)")

            let averageColor = averageColor(in: bitmapRep, x: xStart, y: yStart, width: sectionWidth, height: sectionHeight)
            let hex = averageColor.toHex()

            print("Average color for section (\(row), \(col)): \(hex)")
            hexColors.append(hex)
        }
    }

    if hexColors.allSatisfy({ $0 == "#FFFFFF" }) {
        print("All extracted colors are white. This might indicate an issue.")
    }

    print("Extracted Colors: \(hexColors)")
    return hexColors
}

// ✅ Compute the average color for a section
func averageColor(in bitmap: NSBitmapImageRep, x: Int, y: Int, width: Int, height: Int) -> NSColor {
    var redTotal: CGFloat = 0, greenTotal: CGFloat = 0, blueTotal: CGFloat = 0
    var pixelCount = 0

    for i in x..<(x + width) {
        for j in y..<(y + height) {
            guard let color = bitmap.colorAt(x: i, y: j) else {
                print("Failed to get color at x:\(i), y:\(j)")
                continue
            }

            redTotal += color.redComponent
            greenTotal += color.greenComponent
            blueTotal += color.blueComponent
            pixelCount += 1
        }
    }

    if pixelCount == 0 {
        print("No valid pixels found in the section! Defaulting to black.")
        return .black
    }

    let avgColor = NSColor(
        red: redTotal / CGFloat(pixelCount),
        green: greenTotal / CGFloat(pixelCount),
        blue: blueTotal / CGFloat(pixelCount),
        alpha: 1.0
    )

    return avgColor
}

// ✅ Convert NSColor to HEX String
extension NSColor {
    func toHex() -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            print("Failed to convert NSColor to sRGB space")
            return "#000000"
        }

        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)

        let hex = String(format: "#%02X%02X%02X", red, green, blue)
        if hex == "#FFFFFF" {
            print("Detected white color in palette, consider filtering out excessive white.")
        }
        return hex
    }
}
