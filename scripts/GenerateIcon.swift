#!/usr/bin/env swift

import AppKit
import Foundation

/// 生成应用图标：珊瑚色圆角方块 + 音符 + 逐字扫光的歌词条
/// 用法：swift scripts/GenerateIcon.swift [输出路径，默认 Support/AppIcon.icns]

let canvas: CGFloat = 1024
let bodyInset: CGFloat = 100
let bodySide: CGFloat = canvas - bodyInset * 2
let cornerRadius: CGFloat = 185

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let backgroundTop = color(0xFF7E70)
let backgroundBottom = color(0xE0403C)
let ink = color(0xFFD9D4)
let inkDim = color(0xFFD9D4, alpha: 0.32)

func drawSymbol(_ name: String, pointSize: CGFloat, color: NSColor, center: CGPoint) {
    let palette = NSImage.SymbolConfiguration(paletteColors: [color])
    let config = palette.applying(
        NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    )
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return }
    let size = image.size
    image.draw(
        in: NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    )
}

func drawLyricBar(width: CGFloat, center: CGPoint, progress: CGFloat) {
    let height: CGFloat = 62
    let rect = NSRect(
        x: center.x - width / 2,
        y: center.y - height / 2,
        width: width,
        height: height
    )
    let path = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
    inkDim.setFill()
    path.fill()

    guard progress > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    let played = NSRect(x: rect.minX, y: rect.minY, width: rect.width * progress, height: rect.height)
    NSBezierPath(rect: played).addClip()
    ink.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

let body = NSRect(x: bodyInset, y: bodyInset, width: bodySide, height: bodySide)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: cornerRadius, yRadius: cornerRadius)

NSGradient(starting: backgroundBottom, ending: backgroundTop)?
    .draw(in: bodyPath, angle: 90)

// 自上而下很淡的高光，避免大面积纯色发闷
NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
NSGradient(
    starting: NSColor.white.withAlphaComponent(0),
    ending: NSColor.white.withAlphaComponent(0.16)
)?.draw(in: body, angle: 90)
NSGraphicsContext.restoreGraphicsState()

// 内侧亮边
NSColor.white.withAlphaComponent(0.18).setStroke()
bodyPath.lineWidth = 6
bodyPath.stroke()

// 音符 + 两条歌词，第二条短一些，和逐字扫光一起构成“歌词”意象
drawSymbol("music.note", pointSize: 350, color: ink, center: CGPoint(x: canvas / 2, y: 648))
drawLyricBar(width: 466, center: CGPoint(x: canvas / 2, y: 388), progress: 0.62)
drawLyricBar(width: 306, center: CGPoint(x: canvas / 2, y: 292), progress: 0.28)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("无法渲染图标\n".utf8))
    exit(1)
}

let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Support/AppIcon.icns")
let workDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("splayer-finder-lyrics-icon-\(UUID().uuidString)")
let iconset = workDir.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: workDir) }

let master = workDir.appendingPathComponent("icon-1024.png")
try png.write(to: master)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func run(_ tool: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/\(tool)")
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: tool, code: Int(process.terminationStatus))
    }
}

for size in sizes {
    if size.pixels == 1024 {
        try FileManager.default.copyItem(at: master, to: iconset.appendingPathComponent(size.name))
    } else {
        try run("sips", [
            "-z", "\(size.pixels)", "\(size.pixels)",
            master.path,
            "--out", iconset.appendingPathComponent(size.name).path,
        ])
    }
}

try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try run("iconutil", ["-c", "icns", iconset.path, "-o", output.path])
print("图标已生成：\(output.path)")
