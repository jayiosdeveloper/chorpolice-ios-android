//
//  SplashView.swift
//  Animated intro over the live menu scene — logo drops in, the player's
//  character struts up, then a pulsing "Tap to start" waits for a tap.
//

import SwiftUI
import SpriteKit

struct SplashView: View {
    @ObservedObject var settings: GameSettings
    let onStart: () -> Void

    @State private var scene: MenuScene = {
        let s = MenuScene(size: CGSize(width: 1334, height: 750))
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var showLogo = false
    @State private var showSub = false
    @State private var showChar = false
    @State private var showTap = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.2), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                Text("CHOR POLICE")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
                    .scaleEffect(showLogo ? 1 : 0.4)
                    .opacity(showLogo ? 1 : 0)

                Text("Friends • WiFi & Bluetooth • Arena Shooter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .opacity(showSub ? 1 : 0)
                    .offset(y: showSub ? 0 : 10)

                RobotPreview(skin: settings.skin)
                    .frame(width: 86, height: 112)
                    .opacity(showChar ? 1 : 0)
                    .offset(y: showChar ? 0 : 26)
                    .padding(.top, 6)

                Spacer()

                Text("TAP TO START")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26).padding(.vertical, 12)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                    .opacity(showTap ? (pulse ? 1 : 0.45) : 0)
                    .scaleEffect(pulse ? 1.05 : 1)
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if showTap { onStart() } }
        .onAppear {
            AudioManager.shared.soundEnabled = settings.soundOn
            AudioManager.shared.setMusic(settings.musicOn)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { showLogo = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) { showSub = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.7)) { showChar = true }
            withAnimation(.easeIn(duration: 0.4).delay(1.1)) { showTap = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(1.3)) {
                pulse = true
            }
        }
    }
}
