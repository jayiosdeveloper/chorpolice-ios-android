//
//  MapHighTower.swift
//  Layout: a tall CENTRAL TOWER over a deep central pit, with stepped ledges
//  spiralling up both sides — a vertical fight. Two end forts. Overcast.
//

import SpriteKit

enum MapHighTower {
    static func make() -> MapDef {
        var theme = MapTheme(
            skyStops: [(44, 52, 70), (110, 120, 140), (196, 196, 204)],
            rockFill: SKColor(red: 0.46, green: 0.46, blue: 0.49, alpha: 1),
            rockEdge: SKColor(red: 0.26, green: 0.26, blue: 0.29, alpha: 1),
            rockDark: SKColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1),
            grass: SKColor(red: 0.38, green: 0.51, blue: 0.25, alpha: 1),
            grassStyle: .grass,
            hill: SKColor(red: 0.27, green: 0.29, blue: 0.34, alpha: 1),
            hillStyle: .mountains,
            weather: .none,
            slippery: false
        )
        theme.props = ["kenney_rock", "kenney_fenceBroken", "kenney_plantPurple", "kenney_plant"]
        theme.cloudAlpha = 0.95

        let grounds = [
            GroundSeg(x0: 0,    x1: 2350, top: 100),
            GroundSeg(x0: 3650, x1: 6000, top: 100)
        ]
        let platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
            // West climb
            (560, 320, 170), (1050, 470, 150), (1550, 330, 150), (2000, 520, 150),
            (2300, 330, 130),
            // Tower spiral ledges (left/right alternating up the column)
            (2680, 250, 120), (3320, 250, 120),
            (2720, 430, 120), (3280, 430, 120),
            (2680, 610, 120), (3320, 610, 120),
            (3000, 770, 280),                       // tower top deck
            // East climb
            (3700, 330, 130), (4000, 520, 150), (4450, 330, 150), (4950, 470, 150),
            (5440, 320, 170)
        ]
        let blocks = [
            Block(x: 3000, y: 270, w: 210, h: 800),   // the tower column (rises out of the pit)
            Block(x: 560, y: 240, w: 130, h: 280),    // west fort
            Block(x: 5440, y: 240, w: 130, h: 280)    // east fort
        ]
        let structures = [
            Structure(x: 3000, floorY: 783, kind: .tower),
            Structure(x: 560, floorY: 380, kind: .bunker),
            Structure(x: 5440, floorY: 380, kind: .bunker)
        ]
        let pickups: [CGPoint] = [
            CGPoint(x: 360, y: 170), CGPoint(x: 1050, y: 540), CGPoint(x: 2000, y: 590),
            CGPoint(x: 2700, y: 320), CGPoint(x: 3300, y: 500), CGPoint(x: 3000, y: 850),
            CGPoint(x: 4000, y: 590), CGPoint(x: 4950, y: 540), CGPoint(x: 5640, y: 170)
        ]
        let spawns: [CGPoint] = [
            CGPoint(x: 300, y: 170), CGPoint(x: 1550, y: 400), CGPoint(x: 2000, y: 590),
            CGPoint(x: 2720, y: 500), CGPoint(x: 3280, y: 500), CGPoint(x: 3000, y: 845),
            CGPoint(x: 4450, y: 400), CGPoint(x: 5700, y: 170)
        ]
        return MapDef(name: "High Tower", shortName: "Tower", length: 6000, theme: theme,
                      grounds: grounds, platforms: platforms, blocks: blocks,
                      structures: structures, pickupSpots: pickups, ffaSpawns: spawns)
    }
}
