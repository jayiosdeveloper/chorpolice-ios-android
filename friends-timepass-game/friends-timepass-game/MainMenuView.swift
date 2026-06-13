//
//  Chor Police — gaming-style main menu over an animated SpriteKit background.
//  Two-column layout: branding + your character on the left, menu cards right.
//

import SwiftUI
import SpriteKit

struct MainMenuView: View {
    @ObservedObject var settings: GameSettings
    var onPlay: () -> Void
    var onHost: () -> Void
    var onJoin: () -> Void
    var onSettings: () -> Void

    @State private var scene: MenuScene = {
        let s = MenuScene(size: CGSize(width: 1334, height: 750))
        s.scaleMode = .resizeFill
        return s
    }()
    @State private var appear = false

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.15), .black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            HStack(alignment: .center, spacing: 36) {
                // Left — branding + your character
                VStack(alignment: .leading, spacing: 10) {
                    Text("CHOR POLICE")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
                    Text("Friends • WiFi & Bluetooth • Arena Shooter")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))

                    HStack(spacing: 14) {
                        RobotPreview(skin: settings.skin)
                            .frame(width: 74, height: 96)
                        Button(action: onSettings) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.resolvedName)
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("Edit character")
                                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                }
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .opacity(appear ? 1 : 0)
                .offset(x: appear ? 0 : -30)

                // Right — menu cards
                VStack(spacing: 12) {
                    MenuCard(title: "Practice", subtitle: "Warm up vs bots", icon: "target",
                             color: Color(red: 0.20, green: 0.72, blue: 0.36), action: onPlay)
                    MenuCard(title: "Host Game", subtitle: "Start a nearby match", icon: "wifi",
                             color: Color(red: 0.18, green: 0.52, blue: 0.92), action: onHost)
                    MenuCard(title: "Join Game", subtitle: "Join friends nearby",
                             icon: "antenna.radiowaves.left.and.right",
                             color: Color(red: 0.93, green: 0.57, blue: 0.16), action: onJoin)
                }
                .frame(width: 320)
                .opacity(appear ? 1 : 0)
                .offset(x: appear ? 0 : 30)
            }
            .padding(.horizontal, 40)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 16)
        }
        .onAppear {
            AudioManager.shared.playTrack(.menu)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appear = true }
        }
    }
}

private struct MenuCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.white.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.85), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
