//
//  MapGreenHills.swift
//  Layout: bright rolling country built from Kenney's CC0 grass tiles — STEPPED
//  ground at different heights (real hills), gaps between them, tiled floating
//  platforms. Open, sunny, the most "platformer" of the set.
//

import SpriteKit

enum MapGreenHills {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(96, 160, 230), (150, 200, 245), (208, 236, 255)],
            rockFill: SKColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1),
            rockEdge: SKColor(red: 0.28, green: 0.20, blue: 0.12, alpha: 1),
            rockDark: SKColor(red: 0.36, green: 0.26, blue: 0.16, alpha: 1),
            grass: SKColor(red: 0.45, green: 0.70, blue: 0.26, alpha: 1),
            grassStyle: .none,
            hill: SKColor(red: 0.24, green: 0.45, blue: 0.24, alpha: 1),
            hillStyle: .trees,
            weather: .none,
            slippery: false
        )
        theme.props = ["kenney_bush", "kenney_mushroomBrown", "kenney_mushroomRed",
                       "kenney_plant", "kenney_rock", "kenney_fence", "kenney_sign"]
        theme.cloudAlpha = 1.0

        // Stepped hills at different heights (gaps = pits to jetpack across).
        let grounds = [
            GroundSeg(x0: 0,    x1: 1500, top: 100),
            GroundSeg(x0: 1850, x1: 2900, top: 200),   // higher hill
            GroundSeg(x0: 3250, x1: 4200, top: 130),
            GroundSeg(x0: 4550, x1: 5400, top: 250),   // highest hill
            GroundSeg(x0: 5750, x1: 7200, top: 110)
        ]
        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            (560, 300, 210), (1120, 440, 210),
            (1650, 320, 140),                          // step up to hill 2
            (2350, 430, 210), (2880, 560, 210),
            (3060, 320, 140),                          // step down
            (3650, 380, 210), (4080, 520, 210),
            (4380, 360, 140),                          // step up to hill 4
            (4950, 480, 210),
            (5550, 360, 140),                          // step down
            (6050, 320, 210), (6550, 460, 210), (6950, 320, 210)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 700, y: 170), CGPoint(x: 1120, y: 510), CGPoint(x: 2350, y: 270),
            CGPoint(x: 2880, y: 630), CGPoint(x: 3650, y: 450), CGPoint(x: 4080, y: 590),
            CGPoint(x: 4950, y: 550), CGPoint(x: 6050, y: 390), CGPoint(x: 6550, y: 530)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 350, y: 170), CGPoint(x: 1120, y: 510), CGPoint(x: 2300, y: 270),
            CGPoint(x: 3650, y: 450), CGPoint(x: 4900, y: 320), CGPoint(x: 5550, y: 430),
            CGPoint(x: 6050, y: 390), CGPoint(x: 6950, y: 390)
        ]
        return MapDef(name: "Green Hills", shortName: "Hills", length: 7200, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: [],
                      structures: [], pickupSpots: pickups, ffaSpawns: spawns,
                      kenneyTiles: true)
    }
}
