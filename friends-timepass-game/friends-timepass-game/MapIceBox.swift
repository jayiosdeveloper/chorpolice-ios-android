//
//  MapIceBox.swift
//  Layout: an ENCLOSED slippery arena (no pits) packed with stacked ice
//  ledges and two hanging shelves — close-quarters, low gravity-of-control
//  feel from the ice. Corner watchtowers. Snow.
//

import SpriteKit

enum MapIceBox {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(10, 14, 44), (34, 58, 118), (150, 196, 228)],
            rockFill: SKColor(red: 0.66, green: 0.77, blue: 0.87, alpha: 1),
            rockEdge: SKColor(red: 0.42, green: 0.55, blue: 0.70, alpha: 1),
            rockDark: SKColor(red: 0.55, green: 0.66, blue: 0.78, alpha: 1),
            grass: SKColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1),
            grassStyle: .snow,
            hill: SKColor(red: 0.16, green: 0.24, blue: 0.43, alpha: 1),
            hillStyle: .mountains,
            weather: .snow,
            slippery: true
        )
        theme.props = ["kenney_deadTree", "kenney_igloo", "kenney_pineSapling",
                       "kenney_rockIce", "kenney_snowBall", "kenney_plantSnow"]
        theme.cloudAlpha = 0.85

        // One continuous icy floor — a closed box, so no death pits.
        let grounds = [GroundSeg(x0: 0, x1: 6600, top: 95)]

        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            (560, 300, 170), (980, 470, 150), (1430, 320, 160),
            // left tier stack
            (1850, 250, 150), (1850, 470, 150),
            (2400, 360, 170), (2850, 560, 160),
            // center high arena
            (3300, 320, 200), (3300, 560, 170),
            (3750, 400, 150),
            // right tier stack
            (4200, 250, 150), (4200, 470, 150),
            (4750, 360, 170), (5200, 560, 160),
            (5650, 320, 170), (6080, 470, 150)
        ]
        let blocks = [
            Block(x: 1430, y: 560, w: 900, h: 80, hangDeco: true),   // hanging ice shelf (left)
            Block(x: 5200, y: 560, w: 900, h: 80, hangDeco: true),   // hanging ice shelf (right)
            Block(x: 2650, y: 200, w: 80, h: 210),                   // ice pillars
            Block(x: 3950, y: 200, w: 80, h: 210)
        ]
        let structures = [
            Structure(x: 360, floorY: 95, kind: .tower),
            Structure(x: 6240, floorY: 95, kind: .tower)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 560, y: 370), CGPoint(x: 1430, y: 390), CGPoint(x: 1850, y: 320),
            CGPoint(x: 2400, y: 430), CGPoint(x: 3300, y: 390), CGPoint(x: 3300, y: 630),
            CGPoint(x: 4200, y: 320), CGPoint(x: 4750, y: 430), CGPoint(x: 5650, y: 390),
            CGPoint(x: 6080, y: 540)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 300, y: 165), CGPoint(x: 1100, y: 165), CGPoint(x: 2400, y: 430),
            CGPoint(x: 3300, y: 390), CGPoint(x: 3750, y: 470), CGPoint(x: 4200, y: 540),
            CGPoint(x: 5500, y: 165), CGPoint(x: 6300, y: 165)
        ]
        return MapDef(name: "Ice Box", shortName: "Ice", length: 6600, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: blocks,
                      structures: structures, pickupSpots: pickups, ffaSpawns: spawns)
    }
}
