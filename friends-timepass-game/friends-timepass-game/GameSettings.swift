//
//  GameSettings.swift
//  User-customizable settings, persisted in UserDefaults.
//

import Foundation
import Combine
import UIKit

final class GameSettings: ObservableObject {
    @Published var playerName: String { didSet { defaults.set(playerName, forKey: "playerName") } }
    @Published var colorIndex: Int { didSet { defaults.set(colorIndex, forKey: "colorIndex") } }
    @Published var leftHanded: Bool { didSet { defaults.set(leftHanded, forKey: "leftHanded") } }
    @Published var killsToWin: Int { didSet { defaults.set(killsToWin, forKey: "killsToWin") } }
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: "soundOn") } }
    @Published var musicOn: Bool { didSet { defaults.set(musicOn, forKey: "musicOn") } }
    @Published var unlimitedAmmo: Bool { didSet { defaults.set(unlimitedAmmo, forKey: "unlimitedAmmo") } }
    @Published var botLevel: Int { didSet { defaults.set(botLevel, forKey: "botLevel") } }
    @Published var zoom: Double { didSet { defaults.set(zoom, forKey: "zoom") } }                  // camera zoom-out (1.7 close … 2.4 far)
    @Published var skinMode: Int { didSet { defaults.set(skinMode, forKey: "skinMode") } }        // 0 colors, 1 army, 2 custom
    @Published var armyIndex: Int { didSet { defaults.set(armyIndex, forKey: "armyIndex") } }
    @Published var customMain: [Double] { didSet { defaults.set(customMain, forKey: "customMain") } }
    @Published var customAccent: [Double] { didSet { defaults.set(customAccent, forKey: "customAccent") } }
    @Published var customHelmet: [Double] { didSet { defaults.set(customHelmet, forKey: "customHelmet") } }
    @Published var customPants: [Double] { didSet { defaults.set(customPants, forKey: "customPants") } }
    @Published var customTone: [Double] { didSet { defaults.set(customTone, forKey: "customTone") } }

    private let defaults = UserDefaults.standard

    init() {
        playerName = defaults.string(forKey: "playerName") ?? ""
        colorIndex = defaults.integer(forKey: "colorIndex")
        leftHanded = defaults.bool(forKey: "leftHanded")
        let k = defaults.integer(forKey: "killsToWin")
        killsToWin = k == 0 ? 10 : k
        soundOn = (defaults.object(forKey: "soundOn") as? Bool) ?? true
        musicOn = (defaults.object(forKey: "musicOn") as? Bool) ?? true
        unlimitedAmmo = defaults.bool(forKey: "unlimitedAmmo")
        botLevel = (defaults.object(forKey: "botLevel") as? Int) ?? 1   // default: Normal
        let z = defaults.double(forKey: "zoom"); zoom = z == 0 ? 2.0 : z
        skinMode = defaults.integer(forKey: "skinMode")
        armyIndex = defaults.integer(forKey: "armyIndex")
        customMain = (defaults.array(forKey: "customMain") as? [Double]) ?? [0.27, 0.55, 0.97]
        customAccent = (defaults.array(forKey: "customAccent") as? [Double]) ?? [0.50, 0.95, 1.00]
        customHelmet = (defaults.array(forKey: "customHelmet") as? [Double]) ?? [0.20, 0.42, 0.85]
        customPants = (defaults.array(forKey: "customPants") as? [Double]) ?? [0.16, 0.22, 0.42]
        customTone = (defaults.array(forKey: "customTone") as? [Double]) ?? [0.82, 0.62, 0.45]
    }

    /// The name shown to other players (falls back to the device name).
    var resolvedName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? UIDevice.current.name : trimmed
    }

    /// The robot look resolved from the current mode (palette / army / custom).
    var skin: RobotSkin {
        switch skinMode {
        case 1:
            let u = ArmySkins.all[min(max(armyIndex, 0), ArmySkins.all.count - 1)]
            return u.skin
        case 2:
            return RobotSkin(mr: customMain[0], mg: customMain[1], mb: customMain[2],
                             ar: customAccent[0], ag: customAccent[1], ab: customAccent[2],
                             helmet: customHelmet, pants: customPants, tone: customTone)
        default:
            return PlayerColors.skin(colorIndex)
        }
    }
}

import SwiftUI

extension GameSettings {
    var skinMainColor: Color {
        let s = skin
        return Color(red: s.mr, green: s.mg, blue: s.mb)
    }
    var skinAccentColor: Color {
        let s = skin
        return Color(red: s.ar, green: s.ag, blue: s.ab)
    }

    var customMainColor: Color {
        Color(red: customMain[0], green: customMain[1], blue: customMain[2])
    }
    var customAccentColor: Color {
        Color(red: customAccent[0], green: customAccent[1], blue: customAccent[2])
    }

    var customMainBinding: Binding<Color> { colorBinding(\.customMain) }
    var customAccentBinding: Binding<Color> { colorBinding(\.customAccent) }
    var customHelmetBinding: Binding<Color> { colorBinding(\.customHelmet) }
    var customPantsBinding: Binding<Color> { colorBinding(\.customPants) }
    var customToneBinding: Binding<Color> { colorBinding(\.customTone) }

    private func colorBinding(_ kp: ReferenceWritableKeyPath<GameSettings, [Double]>) -> Binding<Color> {
        Binding(
            get: { let a = self[keyPath: kp]; return Color(red: a[0], green: a[1], blue: a[2]) },
            set: { self[keyPath: kp] = Self.rgb(of: $0) }
        )
    }

    func setCustomMain(_ c: Color) { customMain = Self.rgb(of: c) }
    func setCustomAccent(_ c: Color) { customAccent = Self.rgb(of: c) }

    private static func rgb(of c: Color) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
}
