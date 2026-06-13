//
//  MapOutpost.swift
//  Layout: scattered SKY ISLANDS over four wide death pits — vertical
//  zig-zag hopping, plus one low overhang cave near the start. Dusk.
//

import SpriteKit

enum MapOutpost {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(30, 24, 38), (96, 58, 54), (196, 120, 66)],
            rockFill: SKColor(red: 0.38, green: 0.31, blue: 0.23, alpha: 1),
            rockEdge: SKColor(red: 0.23, green: 0.18, blue: 0.13, alpha: 1),
            rockDark: SKColor(red: 0.27, green: 0.22, blue: 0.16, alpha: 1),
            grass: SKColor(red: 0.34, green: 0.50, blue: 0.20, alpha: 1),
            grassStyle: .grass,
            hill: SKColor(red: 0.20, green: 0.16, blue: 0.17, alpha: 1),
            hillStyle: .rocks,
            weather: .embers,
            slippery: false
        )
        theme.props = ["kenney_bush", "kenney_mushroomBrown", "kenney_mushroomRed",
                       "kenney_plant", "kenney_rock", "kenney_fence", "kenney_sign"]
        theme.cloudAlpha = 0.7

        // Short solid footholds separated by four bottomless pits.
        let grounds = [
            GroundSeg(x0: 0,    x1: 1150, top: 100),
            GroundSeg(x0: 1650, x1: 2750, top: 120),
            GroundSeg(x0: 3250, x1: 4250, top: 100),
            GroundSeg(x0: 4750, x1: 5750, top: 140),
            GroundSeg(x0: 6250, x1: 7400, top: 100)
        ]
        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            (620, 300, 160), (980, 450, 140),
            (1430, 360, 150),                       // bridge over pit 1
            (1950, 300, 170), (2430, 470, 150),
            (3000, 350, 150),                       // bridge over pit 2
            (3500, 300, 150), (3870, 450, 150), (4180, 300, 140),
            (4520, 380, 150),                       // bridge over pit 3
            (5050, 300, 160), (5480, 470, 150),
            (6020, 360, 150),                       // bridge over pit 4
            (6520, 300, 160), (6900, 450, 150), (7220, 300, 150)
        ]
        let blocks = [
            Block(x: 2200, y: 520, w: 760, h: 80, hangDeco: true),   // overhang cave
            Block(x: 1900, y: 175, w: 60, h: 110),
            Block(x: 2500, y: 360, w: 60, h: 130)
        ]
        let structures = [
            Structure(x: 300, floorY: 100, kind: .bunker),
            Structure(x: 3700, floorY: 100, kind: .bunker),
            Structure(x: 7250, floorY: 100, kind: .tower)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 620, y: 360), CGPoint(x: 1430, y: 420), CGPoint(x: 1950, y: 360),
            CGPoint(x: 2430, y: 530), CGPoint(x: 3000, y: 410), CGPoint(x: 3870, y: 510),
            CGPoint(x: 4520, y: 440), CGPoint(x: 5050, y: 360), CGPoint(x: 6020, y: 420),
            CGPoint(x: 6900, y: 510), CGPoint(x: 7220, y: 360)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 250, y: 170), CGPoint(x: 980, y: 520), CGPoint(x: 1950, y: 370),
            CGPoint(x: 3500, y: 370), CGPoint(x: 4180, y: 370), CGPoint(x: 5050, y: 370),
            CGPoint(x: 6520, y: 370), CGPoint(x: 7220, y: 370)
        ]
        return MapDef(name: "Outpost", shortName: "Outpost", length: 7400, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: blocks,
                      structures: structures, pickupSpots: pickups, ffaSpawns: spawns)
    }
}
