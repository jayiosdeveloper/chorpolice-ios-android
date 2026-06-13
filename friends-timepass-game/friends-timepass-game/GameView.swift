//
//  GameView.swift
//  Hosts the SpriteKit GameScene inside SwiftUI, with a pause/settings overlay.
//  `net` non-nil → multiplayer mode; `mapIndex` picks the practice map
//  (multiplayer reads the map from the host's MatchConfig instead).
//

import SwiftUI
import SpriteKit

struct GameView: View {
    let net: MultipeerManager?
    @ObservedObject var settings: GameSettings
    let onExit: () -> Void
    @State private var scene: GameScene
    @State private var paused = false

    init(net: MultipeerManager?, settings: GameSettings, mapIndex: Int, onExit: @escaping () -> Void) {
        self.net = net
        self.settings = settings
        self.onExit = onExit
        let s = GameScene(size: CGSize(width: 1334, height: 750))
        s.scaleMode = .resizeFill
        s.net = net
        s.settings = settings
        s.practiceMapIndex = mapIndex
        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // Pause / settings button (top-right)
            Button(action: openPause) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 14)

            if paused {
                PausePanel(settings: settings,
                           onResume: closePause,
                           onQuit: { AudioManager.shared.setJetpack(false); onExit() })
            }
        }
    }

    private func openPause() {
        scene.isPaused = true
        AudioManager.shared.setJetpack(false)
        withAnimation(.easeOut(duration: 0.15)) { paused = true }
    }

    private func closePause() {
        scene.applySettings()
        scene.isPaused = false
        withAnimation(.easeOut(duration: 0.15)) { paused = false }
    }
}

// MARK: - In-game pause panel

private struct PausePanel: View {
    @ObservedObject var settings: GameSettings
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onResume() }

            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    toggleRow("Music", systemImage: "music.note", isOn: $settings.musicOn)
                        .onChange(of: settings.musicOn) { AudioManager.shared.setMusic($0) }
                    toggleRow("Sound effects", systemImage: "speaker.wave.2.fill", isOn: $settings.soundOn)
                        .onChange(of: settings.soundOn) { AudioManager.shared.soundEnabled = $0 }
                    toggleRow("Left-handed", systemImage: "hand.point.left.fill", isOn: $settings.leftHanded)

                    HStack {
                        Label("Camera", systemImage: "camera.viewfinder")
                            .foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Picker("", selection: $settings.zoom) {
                            Text("Close").tag(1.7)
                            Text("Normal").tag(2.0)
                            Text("Far").tag(2.4)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxWidth: 380)

                HStack(spacing: 12) {
                    Button(action: onQuit) {
                        Label("Quit", systemImage: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.white.opacity(0.14)).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color(red: 0.20, green: 0.72, blue: 0.36)).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .frame(maxWidth: 380)
            }
            .padding(26)
            .background(Color(red: 0.10, green: 0.11, blue: 0.20).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(24)
        }
    }

    private func toggleRow(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .foregroundColor(.white).font(.system(size: 15, weight: .semibold))
        }
        .tint(Color(red: 0.20, green: 0.72, blue: 0.36))
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
