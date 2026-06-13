//
//  MapSubdivision.swift
//  Layout: two multi-floor BUILDINGS (rooftop + two interior levels via
//  stacked slabs) joined by a central gap with stacked bridges. Night.
//  Tight indoor corridors vs. an exposed rooftop high road.
//

import SpriteKit

enum MapSubdivision {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(10, 12, 20), (28, 34, 44), (62, 74, 82)],
            rockFill: SKColor(red: 0.29, green: 0.32, blue: 0.31, alpha: 1),
            rockEdge: SKColor(red: 0.16, green: 0.18, blue: 0.17, alpha: 1),
            rockDark: SKColor(red: 0.22, green: 0.24, blue: 0.23, alpha: 1),
            grass: SKColor(red: 0.27, green: 0.38, blue: 0.22, alpha: 1),
            grassStyle: .grass,
            hill: SKColor(red: 0.09, green: 0.12, blue: 0.13, alpha: 1),
            hillStyle: .buildings,
            weather: .embers,
            slippery: false
        )
        theme.props = ["kenney_box", "kenney_boxWarning", "kenney_fenceBroken", "kenney_rock"]
        theme.cloudAlpha = 0.12

        let grounds = [
            GroundSeg(x0: 0,    x1: 3150, top: 100),
            GroundSeg(x0: 3850, x1: 7000, top: 100)
        ]
        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            (470, 320, 150),
            // West building interior (low road) + entrances
            (1150, 200, 150), (1750, 200, 150), (2350, 200, 150),
            (1450, 360, 150), (2050, 360, 150),                 // mid-floor walkways
            // Central stacked bridges across the gap
            (3500, 250, 180), (3500, 470, 160),
            // East building interior (mirrored)
            (4650, 200, 150), (5250, 200, 150), (5850, 200, 150),
            (4950, 360, 150), (5550, 360, 150),
            (6530, 320, 150)
        ]
        let blocks = [
            // West building shell: rooftop slab + pillars
            Block(x: 1750, y: 540, w: 1820, h: 64, hangDeco: true),
            Block(x: 900,  y: 200, w: 56, h: 200),
            Block(x: 2600, y: 200, w: 56, h: 200),
            // East building shell (mirrored)
            Block(x: 5250, y: 540, w: 1820, h: 64, hangDeco: true),
            Block(x: 4400, y: 200, w: 56, h: 200),
            Block(x: 6100, y: 200, w: 56, h: 200)
        ]
        let structures = [
            Structure(x: 1750, floorY: 572, kind: .house),
            Structure(x: 5250, floorY: 572, kind: .house)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 470, y: 390), CGPoint(x: 1450, y: 270), CGPoint(x: 1750, y: 270),
            CGPoint(x: 2350, y: 430), CGPoint(x: 3500, y: 320), CGPoint(x: 3500, y: 540),
            CGPoint(x: 4650, y: 270), CGPoint(x: 5250, y: 270), CGPoint(x: 5850, y: 430),
            CGPoint(x: 6530, y: 390)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 300, y: 170), CGPoint(x: 1150, y: 270), CGPoint(x: 2350, y: 270),
            CGPoint(x: 1750, y: 620), CGPoint(x: 3500, y: 320), CGPoint(x: 4650, y: 270),
            CGPoint(x: 5850, y: 270), CGPoint(x: 6700, y: 170)
        ]
        return MapDef(name: "Subdivision", shortName: "Subdiv", length: 7000, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: blocks,
                      structures: structures, pickupSpots: pickups, ffaSpawns: spawns)
    }
}
