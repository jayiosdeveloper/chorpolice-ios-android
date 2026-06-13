//
//  LobbyView.swift
//  Pre-match lobby: players appear as round avatars scattered over the arena
//  preview (colored with each player's robot color). The host picks the mode
//  (Deathmatch / Teams / Capture the Flag), the map, the win target and the
//  round time, and can tap avatars to switch their team.
//

import SwiftUI

struct LobbyView: View {
    @ObservedObject var net: MultipeerManager
    @ObservedObject var settings: GameSettings
    let isHost: Bool
    let onStart: () -> Void
    let onBack: () -> Void

    @State private var mode = 0                  // 0 DM, 1 TDM, 2 CTF
    @State private var mapIndex = 0
    @State private var target = 10
    @State private var minutes = 5
    @State private var teamOverride: [String: Int] = [:]

    private var teamsActive: Bool { mode >= 1 }

    private var playerIDs: [String] {
        [net.myPeerID.displayName] + net.connectedPeers.map { $0.displayName }
    }

    private func team(_ id: String, _ index: Int) -> Int { teamOverride[id] ?? (index % 2) }

    private func displayName(_ id: String) -> String {
        if id == net.myPeerID.displayName { return settings.resolvedName }
        return net.peerInfo[id]?.name ?? id
    }

    private func playerSkin(_ id: String) -> RobotSkin {
        if id == net.myPeerID.displayName { return settings.skin }
        return net.peerInfo[id]?.skin ?? PlayerColors.skin(1)
    }

    private func teamColor(_ t: Int) -> Color {
        t == 0 ? Color(red: 0.27, green: 0.55, blue: 0.97) : Color(red: 0.93, green: 0.30, blue: 0.32)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.23),
                                    Color(red: 0.27, green: 0.21, blue: 0.43)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            HStack(spacing: 18) {
                // ---- Left: player arena ----
                VStack(spacing: 8) {
                    Text(isHost ? "HOSTING GAME" : "JOINING GAME")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Nearby friends connect over WiFi / Bluetooth")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))

                    AvatarField(ids: playerIDs,
                                meID: net.myPeerID.displayName,
                                name: displayName,
                                skin: playerSkin,
                                teamsActive: teamsActive,
                                team: team,
                                teamColor: teamColor,
                                canEdit: isHost && teamsActive,
                                onTap: { id, idx in
                                    if isHost && teamsActive { teamOverride[id] = 1 - team(id, idx) }
                                })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if net.connectedPeers.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Searching for players nearby…")
                                .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        Text("\(playerIDs.count) players ready" + (isHost && teamsActive ? "  •  tap a player to switch team" : ""))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    }
                }

                // ---- Right: match setup ----
                VStack(spacing: 12) {
                    if isHost {
                        VStack(alignment: .leading, spacing: 10) {
                            row("MODE") {
                                Picker("", selection: $mode) {
                                    Text("Deathmatch").tag(0)
                                    Text("Teams").tag(1)
                                    Text("Flag").tag(2)
                                }
                                .pickerStyle(.segmented)
                            }
                            row("MAP") {
                                Picker("", selection: $mapIndex) {
                                    ForEach(0..<Maps.all.count, id: \.self) { i in
                                        Text(Maps.all[i].shortName).tag(i)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            row(mode == 2 ? "FLAGS TO WIN" : "KILLS TO WIN") {
                                Stepper(value: $target, in: mode == 2 ? 1...10 : 3...30) {
                                    Text("\(target)").foregroundColor(.white).fontWeight(.bold)
                                }
                            }
                            row("ROUND TIME") {
                                Stepper(value: $minutes, in: 2...15) {
                                    Text("\(minutes) min").foregroundColor(.white).fontWeight(.bold)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button(action: startTapped) {
                            Text("START MATCH")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(net.connectedPeers.isEmpty ? Color.gray.opacity(0.5)
                                                                       : Color(red: 0.20, green: 0.75, blue: 0.35))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(net.connectedPeers.isEmpty)
                    } else {
                        VStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Waiting for host to start…")
                                .foregroundColor(.white.opacity(0.85))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 30)
                    }

                    Button(action: onBack) {
                        Text("Back").foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(width: 320)
            }
            .padding(18)
        }
        .onAppear {
            net.makeHello = { [weak settings] in
                HelloInfo(name: settings?.resolvedName ?? "Player",
                          skin: settings?.skin ?? PlayerColors.skin(0))
            }
            net.start(asHost: isHost)
            target = settings.killsToWin
        }
        .onChange(of: mode) { m in
            target = m == 2 ? 3 : settings.killsToWin
        }
        .onChange(of: net.didStart) { started in
            if started && !isHost { onStart() }
        }
    }

    @ViewBuilder
    private func row<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .heavy)).foregroundColor(.white.opacity(0.55))
            content()
        }
    }

    private func startTapped() {
        var assignments: [String: Int] = [:]
        if teamsActive {
            for (idx, id) in playerIDs.enumerated() { assignments[id] = team(id, idx) }
        }
        net.startMatch(config: MatchConfig(mode: mode, target: target, minutes: minutes,
                                           mapIndex: mapIndex,
                                           unlimitedAmmo: settings.unlimitedAmmo,
                                           assignments: assignments))
        onStart()
    }
}

// MARK: - Scattered round avatars

private struct AvatarField: View {
    let ids: [String]
    let meID: String
    let name: (String) -> String
    let skin: (String) -> RobotSkin
    let teamsActive: Bool
    let team: (String, Int) -> Int
    let teamColor: (Int) -> Color
    let canEdit: Bool
    let onTap: (String, Int) -> Void

    // Hand-scattered slots (relative 0-1), assigned by join order.
    private let slots: [(x: CGFloat, y: CGFloat)] = [
        (0.22, 0.32), (0.55, 0.22), (0.78, 0.40), (0.38, 0.55),
        (0.65, 0.68), (0.18, 0.72), (0.88, 0.74), (0.45, 0.84)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(ids.enumerated()), id: \.element) { idx, id in
                    let slot = slots[idx % slots.count]
                    let jx = CGFloat((stableHash(id) % 9)) - 4   // ±4% organic jitter
                    let jy = CGFloat((stableHash(id) / 9 % 9)) - 4
                    AvatarBubble(skin: skin(id),
                                 label: id == meID ? "\(name(id)) (You)" : name(id),
                                 ring: teamsActive ? teamColor(team(id, idx)) : .white.opacity(0.35),
                                 teamBadge: teamsActive ? (team(id, idx) == 0 ? "A" : "B") : nil,
                                 badgeColor: teamColor(team(id, idx)),
                                 wiggleSeed: Double(idx))
                        .position(x: geo.size.width * (slot.x + jx / 100),
                                  y: geo.size.height * (slot.y + jy / 100))
                        .onTapGesture { onTap(id, idx) }
                }
            }
        }
    }

    private func stableHash(_ s: String) -> Int {
        var h = 0
        for u in s.unicodeScalars { h = (h &* 31 &+ Int(u.value)) % 1000 }
        return abs(h)
    }
}

private struct AvatarBubble: View {
    let skin: RobotSkin
    let label: String
    let ring: Color
    let teamBadge: String?
    let badgeColor: Color
    let wiggleSeed: Double

    @State private var floatUp = false

    private var fill: Color { Color(red: skin.mr, green: skin.mg, blue: skin.mb) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(fill.opacity(0.18))
                    .frame(width: 66, height: 66)
                    .overlay(Circle().stroke(ring, lineWidth: 3))
                    .shadow(color: fill.opacity(0.55), radius: 9, y: 3)
                RobotPreview(skin: skin)
                    .frame(width: 44, height: 56)
                    .frame(width: 66, height: 66)
                if let badge = teamBadge {
                    Text(badge)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(badgeColor)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 5, y: -4)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
        }
        .offset(y: floatUp ? -5 : 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6 + wiggleSeed * 0.25).repeatForever(autoreverses: true)) {
                floatUp.toggle()
            }
        }
    }
}
