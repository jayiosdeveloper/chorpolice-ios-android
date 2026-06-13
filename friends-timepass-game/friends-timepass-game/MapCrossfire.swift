//
//  MapCrossfire.swift
//  Layout: a symmetric DESERT CANYON — two base forts at the ends, a deep
//  central canyon crossed by a thin high bridge with a lower cave route under
//  it. Mirror design for fair team play. Dusty sunset.
//

import SpriteKit

enum MapCrossfire {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(40, 22, 40), (140, 70, 50), (232, 150, 80)],
            rockFill: SKColor(red: 0.55, green: 0.41, blue: 0.27, alpha: 1),
            rockEdge: SKColor(red: 0.34, green: 0.24, blue: 0.15, alpha: 1),
            rockDark: SKColor(red: 0.44, green: 0.33, blue: 0.22, alpha: 1),
            grass: SKColor(red: 0.59, green: 0.50, blue: 0.24, alpha: 1),
            grassStyle: .grass,
            hill: SKColor(red: 0.35, green: 0.24, blue: 0.20, alpha: 1),
            hillStyle: .rocks,
            weather: .embers,
            slippery: false
        )
        theme.props = ["kenney_cactus", "kenney_rock", "kenney_sign", "kenney_fence"]
        theme.cloudAlpha = 0.5

        // Two base plateaus + a small mid ledge over a wide canyon.
        let grounds = [
            GroundSeg(x0: 0,    x1: 2600, top: 110),
            GroundSeg(x0: 3450, x1: 3950, top: 150),   // tiny mid pillar-top
            GroundSeg(x0: 4800, x1: 7400, top: 110)
        ]
        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            // West base approach
            (520, 340, 170), (1080, 300, 160), (1650, 430, 160), (2150, 320, 150),
            // Canyon: high bridge + low cave ledges
            (2950, 360, 170),
            (3700, 540, 200),                          // high bridge over canyon
            (3700, 260, 160),                          // lower cave ledge
            (4450, 360, 170),
            // East base approach (mirror)
            (5250, 320, 150), (5750, 430, 160), (6320, 300, 160), (6880, 340, 170)
        ]
        let blocks = [
            Block(x: 2680, y: 280, w: 150, h: 360),    // west canyon lip
            Block(x: 4720, y: 280, w: 150, h: 360),    // east canyon lip
            Block(x: 520, y: 245, w: 120, h: 250),     // west base tower
            Block(x: 6880, y: 245, w: 120, h: 250),    // east base tower
            Block(x: 3700, y: 150, w: 760, h: 70, hangDeco: true)   // canyon roof over the cave
        ]
        let structures = [
            Structure(x: 520, floorY: 425, kind: .bunker),
            Structure(x: 6880, floorY: 425, kind: .bunker),
            Structure(x: 3700, floorY: 640, kind: .tower)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 820, y: 180), CGPoint(x: 1080, y: 370), CGPoint(x: 1650, y: 500),
            CGPoint(x: 3700, y: 610), CGPoint(x: 3700, y: 330), CGPoint(x: 2950, y: 430),
            CGPoint(x: 4450, y: 430), CGPoint(x: 5750, y: 500), CGPoint(x: 6580, y: 180)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 300, y: 180), CGPoint(x: 1080, y: 370), CGPoint(x: 2150, y: 390),
            CGPoint(x: 3700, y: 610), CGPoint(x: 4450, y: 430), CGPoint(x: 5250, y: 390),
            CGPoint(x: 6880, y: 410), CGPoint(x: 7100, y: 180)
        ]
        return MapDef(name: "Crossfire", shortName: "Cross", length: 7400, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: blocks,
                      structures: structures, pickupSpots: pickups, ffaSpawns: spawns)
    }
}
