//
//  RobotPreview.swift
//  A SwiftUI mirror of the in-game operative (helmet + visor + vest + gun),
//  used in Settings tiles, lobby avatars and the menu chip so previews match.
//

import SwiftUI

struct RobotPreview: View {
    let skin: RobotSkin

    private var main: Color { Color(red: skin.mr, green: skin.mg, blue: skin.mb) }
    private var jacket2: Color {
        let j = skin.jacket2RGB; return Color(red: j[0], green: j[1], blue: j[2])
    }
    private var dark: Color { Color(red: skin.mr * 0.68, green: skin.mg * 0.68, blue: skin.mb * 0.68) }
    private var pants: Color { Color(red: skin.mr * 0.45, green: skin.mg * 0.45, blue: skin.mb * 0.5) }
    private var accent: Color { Color(red: skin.ar, green: skin.ag, blue: skin.ab) }
    private var skinTone: Color {
        let t: [(Double, Double, Double)] = [(0.95, 0.78, 0.62), (0.82, 0.62, 0.45),
                                             (0.66, 0.47, 0.34), (0.52, 0.37, 0.28)]
        let v = (Int(skin.mr * 255) * 31 + Int(skin.mg * 255) * 17 + Int(skin.mb * 255) * 7) % 4
        let c = t[v]; return Color(red: c.0, green: c.1, blue: c.2)
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 60, geo.size.height / 98)
            ZStack {
                // backpack
                rrect(11, 26, dark).position(x: 19, y: 50)
                // legs + boots
                rrect(8, 24, pants).position(x: 25, y: 70)
                rrect(8, 24, pants).position(x: 35, y: 70)
                rrect(11, 7, Color(red: 0.16, green: 0.15, blue: 0.18)).position(x: 25, y: 84)
                rrect(11, 7, Color(red: 0.16, green: 0.15, blue: 0.18)).position(x: 35, y: 84)
                // torso (vertical gradient when the skin has one; flat otherwise)
                gradRect(26, 26, main, jacket2).position(x: 30, y: 52)
                rrect(26, 6, pants).position(x: 30, y: 62)        // belt
                Circle().fill(accent).frame(width: 5, height: 5).position(x: 27, y: 49)
                // shoulder pads
                rrect(13, 11, main).position(x: 19, y: 41)
                rrect(13, 11, main).position(x: 41, y: 41)
                // head + helmet + visor
                rrect(22, 20, skinTone).position(x: 31, y: 30)
                rrect(25, 16, main).position(x: 31, y: 22)
                rrect(16, 6, accent).position(x: 34, y: 28)
                    .shadow(color: accent.opacity(0.8), radius: 3)
                // antenna
                rrect(2.5, 9, dark).position(x: 20, y: 14)
                Circle().fill(accent).frame(width: 4, height: 4).position(x: 20, y: 9)
                // arm holding a small gun (pointing right)
                Capsule().fill(main).frame(width: 9, height: 20)
                    .rotationEffect(.degrees(64)).position(x: 41, y: 50)
                rrect(20, 6, Color(red: 0.13, green: 0.14, blue: 0.18)).position(x: 50, y: 49)
                Circle().fill(skinTone).frame(width: 9, height: 9).position(x: 44, y: 49)
            }
            .frame(width: 60, height: 98)
            .scaleEffect(s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func rrect(_ w: CGFloat, _ h: CGFloat, _ c: Color) -> some View {
        RoundedRectangle(cornerRadius: min(w, h) * 0.32, style: .continuous)
            .fill(c).frame(width: w, height: h)
    }

    private func gradRect(_ w: CGFloat, _ h: CGFloat, _ top: Color, _ bottom: Color) -> some View {
        RoundedRectangle(cornerRadius: min(w, h) * 0.32, style: .continuous)
            .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
    }
}
