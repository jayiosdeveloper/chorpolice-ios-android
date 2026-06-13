//
//  Maps.swift
//  Shared map types + the registry. Each arena lives in its own Map*.swift
//  file so layouts/routes can be designed independently.
//

import SpriteKit

enum HillStyle { case buildings, trees, mountains, rocks }
enum Weather { case embers, leaves, snow, none }
enum GrassStyle { case grass, snow, none }
enum StructureKind { case bunker, tower, house }

struct MapTheme {
    var skyStops: [(r: CGFloat, g: CGFloat, b: CGFloat)]   // 0-255, top → bottom
    var rockFill: SKColor
    var rockEdge: SKColor
    var rockDark: SKColor
    var grass: SKColor
    var grassStyle: GrassStyle
    var hill: SKColor
    var hillStyle: HillStyle
    var weather: Weather
    var slippery: Bool
    var props: [String] = []
    var cloudAlpha: CGFloat = 0.8
}

/// A strip of solid ground from x0 to x1 whose walkable surface is at `top`.
/// Gaps between segments are bottomless death pits.
struct GroundSeg {
    var x0: CGFloat
    var x1: CGFloat
    var top: CGFloat
}

/// A solid rectangular obstacle (cave roofs, pillars, towers). Center-based.
struct Block {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat
    var hangDeco = false
}

/// A decorative building standing on a floor surface (no physics).
struct Structure {
    var x: CGFloat
    var floorY: CGFloat
    var kind: StructureKind
}

struct MapDef {
    var name: String
    var shortName: String
    var length: CGFloat
    var theme: MapTheme
    var grounds: [GroundSeg]
    var platforms: [(x: CGFloat, y: CGFloat, w: CGFloat)]
    var blocks: [Block]
    var structures: [Structure]
    var pickupSpots: [CGPoint]
    var ffaSpawns: [CGPoint]
    var kenneyTiles = false

    /// Walkable ground height at x, or nil over a pit.
    func groundTop(at x: CGFloat) -> CGFloat? {
        for g in grounds where x >= g.x0 && x <= g.x1 { return g.top }
        return nil
    }
}

enum Maps {
    /// Registry — order must stay stable (multiplayer sends map index).
    static let all: [MapDef] = [
        MapOutpost.make(),
        MapHighTower.make(),
        MapSubdivision.make(),
        MapIceBox.make(),
        MapCrossfire.make(),
        MapGreenHills.make()
    ]
}
