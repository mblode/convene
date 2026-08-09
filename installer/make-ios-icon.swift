// Builds the iOS app icon from the exported artwork.
//
// The export at the repo root is the icon *after* the iOS squircle mask, so its corners are
// transparent — and an iOS app icon has to be an opaque square or App Store validation rejects it.
// Rather than guessing a fill, this redraws the background gradient Icon Composer uses
// (AppIcon.icon/icon.json) and composites the artwork over it, so the reconstructed corners are the
// colour the design actually calls for.
//
// Run from the repo root: swift installer/make-ios-icon.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let source = "AppIcon-iOS-Default-1024x1024@1x.png"
let destination = "apps/mobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let side = 1024

guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil),
    let artwork = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    fatalError("Could not read \(source)")
}

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
guard
    let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        // No alpha: the icon must be fully opaque.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    fatalError("Could not create the drawing context")
}

// The gradient from icon.json: display-p3 top to sRGB bottom, vertical, finishing at 70% height.
let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
let top = CGColor(colorSpace: p3, components: [0.35294, 0.46275, 0.58039, 1.0])!
let bottom = CGColor(colorSpace: srgb, components: [0.67059, 0.71765, 0.70980, 1.0])!

guard
    let gradient = CGGradient(
        colorsSpace: srgb,
        colors: [top, bottom] as CFArray,
        locations: [0.0, 1.0]
    )
else {
    fatalError("Could not build the background gradient")
}

// CoreGraphics origin is bottom-left, so the gradient runs from the top of the image downward.
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: 0, y: Double(side) * 0.3),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

context.draw(artwork, in: CGRect(x: 0, y: 0, width: side, height: side))

guard let output = context.makeImage() else { fatalError("Could not render the icon") }

let url = URL(fileURLWithPath: destination) as CFURL
guard let writer = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not open \(destination) for writing")
}
CGImageDestinationAddImage(writer, output, nil)
guard CGImageDestinationFinalize(writer) else { fatalError("Could not write \(destination)") }

print("Wrote \(destination) (\(side)x\(side), opaque)")
