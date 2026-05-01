#!/usr/bin/env swift
// Generates installer/dmg-background.png for create-dmg.
// Run from the project root: swift installer/make-dmg-bg.swift

import AppKit
import CoreGraphics
import CoreText
import Foundation

let width: CGFloat = 700
let height: CGFloat = 460
let colorSpace = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
}

func drawCenteredText(
    _ text: String,
    in context: CGContext,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: CGColor,
    top: CGFloat,
    tracking: CGFloat = 0
) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .white,
        .kern: tracking,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, [])
    let x = (width - bounds.width) / 2 - bounds.origin.x
    let baseline = height - top - bounds.height - bounds.origin.y

    context.saveGState()
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, context)
    context.restoreGState()
}

guard let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create image context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

if let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(14, 16, 24), rgb(7, 9, 13)] as CFArray,
    locations: [0, 1]
) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: width / 2, y: height),
        end: CGPoint(x: width / 2, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

context.setStrokeColor(rgb(255, 255, 255, alpha: 0.055))
context.setLineWidth(1)
for x in stride(from: CGFloat(40), through: width - 40, by: 40) {
    context.move(to: CGPoint(x: x, y: 72))
    context.addLine(to: CGPoint(x: x, y: height - 72))
}
for y in stride(from: CGFloat(80), through: height - 80, by: 40) {
    context.move(to: CGPoint(x: 40, y: y))
    context.addLine(to: CGPoint(x: width - 40, y: y))
}
context.strokePath()

let centerY = height / 2
let startX: CGFloat = 230
let endX: CGFloat = 470
let controlY: CGFloat = centerY - 68

context.setStrokeColor(rgb(202, 219, 170, alpha: 0.72))
context.setLineWidth(2.5)
context.setLineCap(.round)
context.move(to: CGPoint(x: startX, y: centerY - 4))
context.addQuadCurve(to: CGPoint(x: endX, y: centerY - 4), control: CGPoint(x: width / 2, y: controlY))
context.strokePath()

let arrowTip = CGPoint(x: endX, y: centerY - 4)
context.setFillColor(rgb(202, 219, 170, alpha: 0.72))
context.move(to: arrowTip)
context.addLine(to: CGPoint(x: arrowTip.x - 17, y: arrowTip.y + 9))
context.addLine(to: CGPoint(x: arrowTip.x - 12, y: arrowTip.y - 11))
context.closePath()
context.fillPath()

for (index, radius) in [78, 114, 150].enumerated() {
    context.setStrokeColor(rgb(202, 219, 170, alpha: 0.08 - CGFloat(index) * 0.018))
    context.setLineWidth(1)
    context.addEllipse(in: CGRect(
        x: 175 - CGFloat(radius),
        y: centerY - CGFloat(radius),
        width: CGFloat(radius * 2),
        height: CGFloat(radius * 2)
    ))
    context.strokePath()
}

drawCenteredText(
    "Convene",
    in: context,
    fontSize: 30,
    weight: .thin,
    color: rgb(255, 255, 255, alpha: 0.88),
    top: 34,
    tracking: 2
)

drawCenteredText(
    "Meeting transcription for macOS",
    in: context,
    fontSize: 13,
    weight: .light,
    color: rgb(255, 255, 255, alpha: 0.36),
    top: 70
)

drawCenteredText(
    "DRAG TO INSTALL",
    in: context,
    fontSize: 11,
    weight: .light,
    color: rgb(255, 255, 255, alpha: 0.28),
    top: 414,
    tracking: 2
)

guard let image = context.makeImage() else {
    fatalError("Could not render image")
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: "installer/dmg-background.png"))
print("Wrote installer/dmg-background.png")
