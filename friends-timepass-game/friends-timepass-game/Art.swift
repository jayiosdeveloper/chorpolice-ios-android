//
//  Art.swift
//  Shared physics categories, the player color palette, generated textures
//  and small helpers.
//

import SpriteKit

enum PhysicsCategory {
    static let ground: UInt32 = 0x1 << 0
    static let player: UInt32 = 0x1 << 1
    static let enemy:  UInt32 = 0x1 << 2
    static let bullet: UInt32 = 0x1 << 3
    static let wall:   UInt32 = 0x1 << 4
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

/// The shared player-color palette (single source of truth for SpriteKit + SwiftUI).
enum PlayerColors {
    // 20 colours — first 10 solid, last 10 unique vertical gradients (b2 = bottom).
    static let all: [(name: String, r: CGFloat, g: CGFloat, b: CGFloat, b2: (CGFloat, CGFloat, CGFloat)?)] = [
        ("Blue",   0.27, 0.55, 0.97, nil),
        ("Red",    0.93, 0.30, 0.32, nil),
        ("Green",  0.30, 0.78, 0.40, nil),
        ("Purple", 0.62, 0.45, 0.95, nil),
        ("Orange", 0.96, 0.60, 0.20, nil),
        ("Cyan",   0.20, 0.80, 0.85, nil),
        ("Pink",   0.95, 0.40, 0.70, nil),
        ("Yellow", 0.95, 0.85, 0.25, nil),
        ("Teal",   0.15, 0.65, 0.60, nil),
        ("Slate",  0.50, 0.55, 0.66, nil),
        ("Sunset", 1.00, 0.58, 0.15, (0.95, 0.22, 0.45)),
        ("Ocean",  0.25, 0.85, 0.95, (0.15, 0.35, 0.88)),
        ("Grape",  0.70, 0.35, 0.97, (0.96, 0.28, 0.70)),
        ("Lime",   0.72, 0.95, 0.28, (0.13, 0.62, 0.36)),
        ("Fire",   1.00, 0.85, 0.25, (0.90, 0.18, 0.15)),
        ("Aurora", 0.28, 0.96, 0.66, (0.13, 0.52, 0.78)),
        ("Berry",  1.00, 0.45, 0.66, (0.52, 0.18, 0.72)),
        ("Steel",  0.58, 0.72, 0.97, (0.24, 0.28, 0.52)),
        ("Mango",  1.00, 0.80, 0.30, (0.95, 0.42, 0.10)),
        ("Galaxy", 0.38, 0.46, 0.97, (0.66, 0.24, 0.86)),
    ]

    static func wrap(_ i: Int) -> Int { ((i % all.count) + all.count) % all.count }

    /// Main / dark / glow shades for a robot of the given color index.
    static func shades(_ index: Int) -> (main: SKColor, dark: SKColor, glow: SKColor) {
        shades(of: skin(index))
    }

    /// The palette color as a full skin (accent = lightened body color).
    static func skin(_ index: Int) -> RobotSkin {
        let c = all[wrap(index)]
        var s = RobotSkin(mr: Double(c.r), mg: Double(c.g), mb: Double(c.b),
                          ar: Double(c.r + (1 - c.r) * 0.55),
                          ag: Double(c.g + (1 - c.g) * 0.55),
                          ab: Double(c.b + (1 - c.b) * 0.55))
        if let b2 = c.b2 { s.jacket2 = [Double(b2.0), Double(b2.1), Double(b2.2)] }
        return s
    }

    /// Main / dark / glow shades for any skin (dark is derived from the body color).
    static func shades(of s: RobotSkin) -> (main: SKColor, dark: SKColor, glow: SKColor) {
        let main = SKColor(red: s.mr, green: s.mg, blue: s.mb, alpha: 1)
        let dark = SKColor(red: s.mr * 0.45, green: s.mg * 0.45, blue: s.mb * 0.5, alpha: 1)
        let glow = SKColor(red: s.ar, green: s.ag, blue: s.ab, alpha: 1)
        return (main, dark, glow)
    }
}

/// Country-themed army uniforms (body = uniform tone, accent = flag color).
enum ArmySkins {
    struct Uniform {
        let name: String
        let flag: String
        let skin: RobotSkin
    }

    static let all: [Uniform] = [
        Uniform(name: "India",    flag: "🇮🇳", skin: RobotSkin(mr: 0.33, mg: 0.42, mb: 0.18, ar: 1.00, ag: 0.60, ab: 0.20)),
        Uniform(name: "USA",      flag: "🇺🇸", skin: RobotSkin(mr: 0.16, mg: 0.22, mb: 0.38, ar: 0.90, ag: 0.25, ab: 0.30)),
        Uniform(name: "Russia",   flag: "🇷🇺", skin: RobotSkin(mr: 0.24, mg: 0.32, mb: 0.20, ar: 0.92, ag: 0.20, ab: 0.20)),
        Uniform(name: "China",    flag: "🇨🇳", skin: RobotSkin(mr: 0.72, mg: 0.16, mb: 0.16, ar: 1.00, ag: 0.82, ab: 0.20)),
        Uniform(name: "UK",       flag: "🇬🇧", skin: RobotSkin(mr: 0.13, mg: 0.18, mb: 0.32, ar: 0.92, ag: 0.92, ab: 0.96)),
        Uniform(name: "Japan",    flag: "🇯🇵", skin: RobotSkin(mr: 0.84, mg: 0.85, mb: 0.88, ar: 0.90, ag: 0.15, ab: 0.20)),
        Uniform(name: "Germany",  flag: "🇩🇪", skin: RobotSkin(mr: 0.35, mg: 0.37, mb: 0.33, ar: 0.95, ag: 0.75, ab: 0.20)),
        Uniform(name: "Brazil",   flag: "🇧🇷", skin: RobotSkin(mr: 0.10, mg: 0.55, mb: 0.30, ar: 0.98, ag: 0.85, ab: 0.20)),
        Uniform(name: "France",   flag: "🇫🇷", skin: RobotSkin(mr: 0.20, mg: 0.30, mb: 0.60, ar: 0.88, ag: 0.22, ab: 0.26)),
        Uniform(name: "Pakistan", flag: "🇵🇰", skin: RobotSkin(mr: 0.05, mg: 0.40, mb: 0.25, ar: 0.95, ag: 0.95, ab: 0.95))
    ]
}

enum Art {
    static let softCircle: SKTexture = {
        let s = 64
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let c = CGPoint(x: s / 2, y: s / 2)
        let grad = CGGradient(colorsSpace: cs, colors: [
            CGColor(colorSpace: cs, components: [1, 1, 1, 1])!,
            CGColor(colorSpace: cs, components: [1, 1, 1, 0])!
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                               endCenter: c, endRadius: CGFloat(s) / 2, options: [])
        return SKTexture(cgImage: ctx.makeImage()!)
    }()

    static func skyTexture(size: CGSize) -> SKTexture {
        skyTexture(size: size, stops: [(18, 20, 46), (60, 48, 96), (150, 78, 54)])
    }

    static func skyTexture(size: CGSize, stops: [(r: CGFloat, g: CGFloat, b: CGFloat)]) -> SKTexture {
        let w = max(2, Int(size.width)), h = max(2, Int(size.height))
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let colors = stops.map {
            CGColor(colorSpace: cs, components: [$0.r / 255, $0.g / 255, $0.b / 255, 1])!
        }
        let grad = CGGradient(colorsSpace: cs, colors: colors as CFArray,
                              locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(h)),
                               end: CGPoint(x: 0, y: 0), options: [])
        return SKTexture(cgImage: ctx.makeImage()!)
    }
}
