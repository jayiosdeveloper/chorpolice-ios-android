//
//  ContentView.swift
//  Root router: menu → settings / lobby → game. Owns the shared
//  MultipeerManager and GameSettings.
//

import SwiftUI

struct ContentView: View {
    enum Screen {
        case splash
        case menu
        case settings
        case practiceSetup
        case lobby(host: Bool)
        case game(multiplayer: Bool, map: Int)
    }

    @State private var screen: Screen
    @StateObject private var net = MultipeerManager()
    @StateObject private var settings = GameSettings()

    init() {
        let args = ProcessInfo.processInfo.arguments
        var initial: Screen = .splash
        if args.contains("-startInMenu") {
            initial = .menu
        } else if args.contains("-startInGame") {
            var map = 0
            if let i = args.firstIndex(of: "-practiceMap"), i + 1 < args.count {
                map = Int(args[i + 1]) ?? 0
            }
            initial = .game(multiplayer: false, map: map)
        } else if args.contains("-startInLobbyHost") {
            initial = .lobby(host: true)
        } else if args.contains("-startInSettings") {
            initial = .settings
        }
        _screen = State(initialValue: initial)
    }

    var body: some View {
        switch screen {
        case .splash:
            SplashView(settings: settings, onStart: { withAnimation { screen = .menu } })
        case .menu:
            MainMenuView(
                settings: settings,
                onPlay: { screen = .practiceSetup },
                onHost: { screen = .lobby(host: true) },
                onJoin: { screen = .lobby(host: false) },
                onSettings: { screen = .settings }
            )
            .onAppear {
                AudioManager.shared.soundEnabled = settings.soundOn
                AudioManager.shared.setMusic(settings.musicOn)
            }
        case .settings:
            SettingsView(settings: settings, onClose: { screen = .menu })
        case .practiceSetup:
            PracticeSetupView(settings: settings,
                              onStart: { m in screen = .game(multiplayer: false, map: m) },
                              onBack: { screen = .menu })
        case .lobby(let host):
            LobbyView(net: net, settings: settings, isHost: host,
                      onStart: { screen = .game(multiplayer: true, map: net.matchConfig?.mapIndex ?? 0) },
                      onBack: { net.stop(); screen = .menu })
        case .game(let multiplayer, let map):
            GameView(net: multiplayer ? net : nil, settings: settings, mapIndex: map,
                     onExit: { if multiplayer { net.stop() }; screen = .menu })
        }
    }
}

#Preview {
    ContentView()
}
