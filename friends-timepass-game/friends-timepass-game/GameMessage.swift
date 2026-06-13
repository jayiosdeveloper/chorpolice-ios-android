//
//  GameMessage.swift
//  Messages exchanged between peers over MultipeerConnectivity.
//

import Foundation
import CoreGraphics

nonisolated enum GameMessage: Codable {
    case hello(HelloInfo)          // name + color, sent on connect (lobby avatars)
    case state(PlayerState)        // periodic snapshot of the local player
    case fire(FireEvent)           // a shot was fired
    case nade(NadeEvent)           // a grenade was thrown
    case hit(HitEvent)             // the local player got hit (victim-authoritative)
    case pickup(PickupEvent)       // the local player grabbed a crate
    case flag(FlagEvent)           // CTF flag taken / dropped / returned / captured
    case startGame(MatchConfig)    // host starts the match
}

nonisolated struct NadeEvent: Codable {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
}

/// A robot's networked look: body color + accent (visor/glow) color.
/// Built from the basic palette, an army uniform, or fully custom colors.
nonisolated struct RobotSkin: Codable, Equatable {
    var mr: Double; var mg: Double; var mb: Double   // body / jacket
    var ar: Double; var ag: Double; var ab: Double   // accent / visor / glow
    // Optional extra zones for full customization (nil → derived defaults, so
    // old presets/army uniforms keep working unchanged).
    var helmet: [Double]? = nil
    var pants: [Double]? = nil
    var tone: [Double]? = nil
    var jacket2: [Double]? = nil      // gradient bottom for the jacket (nil → flat)

    var bodyRGB: [Double] { [mr, mg, mb] }
    var jacket2RGB: [Double] { jacket2 ?? [mr, mg, mb] }
    var accentRGB: [Double] { [ar, ag, ab] }
    var helmetRGB: [Double] { helmet ?? [mr, mg, mb] }
    var pantsRGB: [Double] { pants ?? [mr * 0.45, mg * 0.45, mb * 0.5] }
    var toneRGB: [Double] {
        if let t = tone { return t }
        let v = (Int(mr * 255) * 31 + Int(mg * 255) * 17 + Int(mb * 255) * 7) % 4
        return [[0.95, 0.78, 0.62], [0.82, 0.62, 0.45],
                [0.66, 0.47, 0.34], [0.52, 0.37, 0.28]][v]
    }
}

nonisolated struct HelloInfo: Codable {
    var name: String
    var skin: RobotSkin
}

nonisolated struct PlayerState: Codable {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var aim: CGFloat
    var thrusting: Bool
    var health: CGFloat
    var dead: Bool
    var name: String
    var team: Int          // -1 = free-for-all, 0 = Team A, 1 = Team B
    var skin: RobotSkin
    var weapon: Int        // WeaponType rawValue (for the held-gun visual)
    var kills: Int
    var captures: Int
    var carryingFlag: Int  // -1 = none, else the team whose flag I carry
}

nonisolated struct FireEvent: Codable {
    var x: CGFloat
    var y: CGFloat
    var angle: CGFloat
    var weapon: Int        // WeaponType rawValue
}

nonisolated struct HitEvent: Codable {
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var dead: Bool
    var killedBy: String?
}

nonisolated struct PickupEvent: Codable {
    var spot: Int
}

nonisolated struct FlagEvent: Codable {
    var kind: Int          // 0 taken, 1 dropped, 2 returned, 3 captured
    var team: Int          // whose flag
    var x: CGFloat
    var y: CGFloat
}

nonisolated struct MatchConfig: Codable {
    var mode: Int          // 0 = deathmatch, 1 = team deathmatch, 2 = capture the flag
    var target: Int        // kills (DM/TDM) or captures (CTF) to win
    var minutes: Int       // round timer
    var mapIndex: Int
    var unlimitedAmmo: Bool          // host's fire-bullets rule, applied on every device
    var assignments: [String: Int]   // peer displayName -> team (0/1)

    var teams: Bool { mode >= 1 }
}
