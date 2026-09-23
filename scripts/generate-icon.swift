#!/usr/bin/env swift
//
// Draws the Notchy app icon and the menu bar icon: a night squircle with the black notch hanging from its top edge and
// a few lines of script below it. The lines already read are faded, and the word being said glows orange, the way
// "follow my words" marks it on the prompter.
//
// Run from the repo root:
//     swift scripts/generate-icon.swift
//
// Output: Notchy/Resources/Assets.xcassets/AppIcon.appiconset and MenuBarIcon.imageset
//

import AppKit
import SwiftUI

private let orange = Color(red: 0.98, green: 0.45, blue: 0.09)
private let amber = Color(red: 1.0, green: 0.70, blue: 0.25)

private struct Notch: Shape {
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// One line of script as rounded word blocks. `read` fades it; `current` is the index of the glowing word.
private struct ScriptLine: View {
    let words: [CGFloat]
    var read = false
    var current: Int?

    var body: some View {
        HStack(spacing: 22) {
            ForEach(words.indices, id: \.self) { i in
                if i == current {
                    Capsule()
                        .fill(LinearGradient(colors: [amber, orange], startPoint: .top, endPoint: .bottom))
                        .frame(width: words[i], height: 58)
                        .shadow(color: orange.opacity(0.9), radius: 22)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(read ? 0.22 : 0.9))
                        .frame(width: words[i], height: 44)
                }
            }
        }
        .frame(width: 564, alignment: .leading)
    }
}

private struct Icon: View {
    var body: some View {
        // macOS icons sit on a 1024 canvas with an 824 body, leaving room for the shadow.
        ZStack {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.13, green: 0.12, blue: 0.20), Color(red: 0.04, green: 0.04, blue: 0.07)],
                        startPoint: .top, endPoint: .bottom))

                // Warm light from the reading line, as if the prompter glass caught it.
                RadialGradient(colors: [orange.opacity(0.28), .clear], center: UnitPoint(x: 0.42, y: 0.56),
                               startRadius: 10, endRadius: 420)

                Notch(corner: 60)
                    .fill(Color.black)
                    .frame(width: 400, height: 150)

                VStack(alignment: .leading, spacing: 44) {
                    ScriptLine(words: [150, 230, 120], read: true)
                    ScriptLine(words: [110, 190, 150], read: true)
                    ScriptLine(words: [170, 150, 200], current: 1)
                    ScriptLine(words: [230, 110, 160])
                    ScriptLine(words: [140, 250])
                }
                .padding(.top, 232)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// The menu bar glyph: a screen outline with the notch and two lines of text, drawn black for a template image.
private struct MenuBarGlyph: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                .strokeBorder(Color.black, lineWidth: 1.6)
                .frame(width: 18, height: 14)
            Notch(corner: 1.6)
                .fill(Color.black)
                .frame(width: 7, height: 3.6)
            VStack(alignment: .leading, spacing: 2.2) {
                Capsule().fill(Color.black).frame(width: 10, height: 1.8)
                Capsule().fill(Color.black).frame(width: 7, height: 1.8)
            }
            .frame(width: 18, alignment: .leading)
            .padding(.leading, 7)
            .padding(.top, 5.6)
        }
        .frame(width: 18, height: 14)
    }
}

@MainActor
private func png<V: View>(_ view: V, scale: CGFloat) -> Data {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.cgImage else { fatalError("render failed") }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

MainActor.assumeIsolated {
    let fm = FileManager.default
    let icons = URL(fileURLWithPath: "Notchy/Resources/Assets.xcassets/AppIcon.appiconset")
    try? fm.removeItem(at: icons)
    try! fm.createDirectory(at: icons, withIntermediateDirectories: true)
    let files: [(String, Int, Int, Int)] = [  // name, pixels, size, scale
        ("icon_16.png", 16, 16, 1), ("icon_16@2x.png", 32, 16, 2),
        ("icon_32.png", 32, 32, 1), ("icon_32@2x.png", 64, 32, 2),
        ("icon_128.png", 128, 128, 1), ("icon_128@2x.png", 256, 128, 2),
        ("icon_256.png", 256, 256, 1), ("icon_256@2x.png", 512, 256, 2),
        ("icon_512.png", 512, 512, 1), ("icon_512@2x.png", 1024, 512, 2),
    ]
    var images: [[String: String]] = []
    for (name, pixels, size, scale) in files {
        try! png(Icon(), scale: CGFloat(pixels) / 1024).write(to: icons.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)"])
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: icons.appendingPathComponent("Contents.json"))

    let menu = URL(fileURLWithPath: "Notchy/Resources/Assets.xcassets/MenuBarIcon.imageset")
    try? fm.removeItem(at: menu)
    try! fm.createDirectory(at: menu, withIntermediateDirectories: true)
    try! png(MenuBarGlyph(), scale: 1).write(to: menu.appendingPathComponent("menubar.png"))
    try! png(MenuBarGlyph(), scale: 2).write(to: menu.appendingPathComponent("menubar@2x.png"))
    let menuContents: [String: Any] = [
        "images": [
            ["filename": "menubar.png", "idiom": "mac", "scale": "1x"],
            ["filename": "menubar@2x.png", "idiom": "mac", "scale": "2x"],
        ],
        "info": ["author": "xcode", "version": 1],
        "properties": ["template-rendering-intent": "template"],
    ]
    try! JSONSerialization.data(withJSONObject: menuContents, options: [.prettyPrinted, .sortedKeys])
        .write(to: menu.appendingPathComponent("Contents.json"))

    // A large copy for the README.
    try? fm.createDirectory(at: URL(fileURLWithPath: "docs"), withIntermediateDirectories: true)
    try! png(Icon(), scale: 0.25).write(to: URL(fileURLWithPath: "docs/icon.png"))
    print("Wrote the app icon, the menu bar icon and docs/icon.png")
}
