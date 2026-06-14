//
//  OnlineLobbyView.swift
//  Online play over the WebSocket relay server — mirrors the Android (Godot) design:
//  a menu (Quick Play / Public Rooms / Create Room / Join with Code), a room browser,
//  a create form (public/private + password), a join-by-code form, and the in-room
//  lobby where the OWNER picks the match settings (which apply to everyone) and starts.
//  The existing LAN LobbyView and the game scene are untouched.
//

import SwiftUI

struct OnlineLobbyView: View {
    @ObservedObject var net: MultipeerManager
    @ObservedObject var settings: GameSettings
    let onStart: () -> Void
    let onBack: () -> Void

    enum Sub { case menu, list, create, joinCode, room, players, friends, profile }
    @State private var sub: Sub = .menu
    @State private var profilePid = ""

    // owner match settings
    @State private var mode = 0
    @State private var mapIndex = 0
    @State private var target = 10
    @State private var minutes = 5
    // create / join inputs
    @State private var createPublic = true
    @State private var password = ""
    @State private var joinCode = ""
    @State private var joinPassword = ""
    @State private var quickPending = false

    private let accent = Color(red: 0.55, green: 0.45, blue: 0.95)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.23),
                                    Color(red: 0.27, green: 0.21, blue: 0.43)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            switch sub {
            case .menu:     menuView
            case .list:     listView
            case .create:   createView
            case .joinCode: joinCodeView
            case .room:     roomView
            case .players:  playersView
            case .friends:  friendsView
            case .profile:  profileView
            }

            if !net.socialNotice.isEmpty {
                VStack { Spacer()
                    Text(net.socialNotice).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.black.opacity(0.5)).clipShape(Capsule()).padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            net.makeHello = { [weak settings] in
                HelloInfo(name: settings?.resolvedName ?? "Player", skin: settings?.skin ?? PlayerColors.skin(0))
            }
            net.onlineConnect()
            target = settings.killsToWin
        }
        .onChange(of: net.didStart) { started in if started { onStart() } }
        .onChange(of: net.inRoom) { inRoom in sub = inRoom ? .room : .menu }
        .onChange(of: net.serverReady) { ready in if ready && (sub == .list || quickPending) { net.listRooms() } }
        .onChange(of: net.rooms.count) { _ in handleQuick() }
        .onChange(of: net.onlineCount) { _ in if sub == .players { net.reqPlayers(net.playersPage) } }
        .onChange(of: mode) { m in target = m == 2 ? 3 : settings.killsToWin }
    }

    // MARK: menu

    private var menuView: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ONLINE")
                    .font(.system(size: 52, weight: .heavy, design: .rounded)).foregroundColor(.white)
                RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 130, height: 6)
                Text("Play with friends & players over the internet")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.75))
                RobotPreview(skin: settings.skin).frame(width: 74, height: 96).padding(.top, 8)
                statusLine.padding(.top, 4)
            }
            VStack(spacing: 10) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        card("Quick Play", "Join any open room", "bolt.fill", Color(red: 0.20, green: 0.72, blue: 0.36)) { quickPlay() }
                        card("Public Rooms", "Browse open rooms", "list.bullet", Color(red: 0.18, green: 0.52, blue: 0.92)) { sub = .list; net.listRooms() }
                        card("Create Room", "Public or private", "plus.circle.fill", accent) { sub = .create }
                        card("Join with Code", "Enter a room code", "number", Color(red: 0.93, green: 0.57, blue: 0.16)) { sub = .joinCode }
                        card("Players & Friends", "\(net.onlineCount) online", "person.2.fill", Color(red: 0.30, green: 0.70, blue: 0.95)) { net.reqPlayers(0); sub = .players }
                    }
                    .padding(.vertical, 2)
                }
                Button(action: onBack) { Text("Back").foregroundColor(.white.opacity(0.7)) }
            }
            .frame(width: 330)
        }
        .padding(.horizontal, 40)
    }

    // MARK: public rooms list

    private var listView: some View {
        VStack(spacing: 14) {
            Text("Public Rooms").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
            if net.rooms.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("No open rooms yet — create one or use Quick Play.")
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(net.rooms) { r in
                            Button { net.joinRoom(code: r.code, password: "") } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(r.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                        Text("\(modeName(r.mode)) · \(mapName(r.map))")
                                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Text("\(r.players)/\(r.max)").font(.system(size: 15, weight: .heavy)).foregroundColor(accent)
                                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
                .frame(maxWidth: 560)
            }
            HStack(spacing: 12) {
                pill("Refresh", "arrow.clockwise") { net.listRooms() }
                pill("Back", "chevron.left") { sub = .menu }
            }
        }
        .padding(28)
    }

    // MARK: create room

    private var createView: some View {
        VStack(spacing: 18) {
            Text("Create Room").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
            Picker("", selection: $createPublic) {
                Text("Public").tag(true); Text("Private").tag(false)
            }
            .pickerStyle(.segmented).frame(width: 320)
            if !createPublic {
                TextField("", text: $password, prompt: Text("Room password (optional)").foregroundColor(.white.opacity(0.4)))
                    .textFieldStyle(.plain).foregroundColor(.white)
                    .padding(14).frame(width: 320)
                    .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(createPublic ? "Public · max 20 players" : "Private · share the code to invite")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            bigButton("Create Room", color: Color(red: 0.20, green: 0.75, blue: 0.35)) {
                net.createRoom(isPublic: createPublic, password: createPublic ? "" : password, settings: cfg())
            }
            Button { sub = .menu } label: { Text("Back").foregroundColor(.white.opacity(0.7)) }
        }
        .padding(28)
    }

    // MARK: join with code

    private var joinCodeView: some View {
        VStack(spacing: 16) {
            Text("Join with Code").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
            TextField("", text: $joinCode, prompt: Text("Room code (e.g. ABC12)").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain).foregroundColor(.white).multilineTextAlignment(.center)
                .autocorrectionDisabled().textInputAutocapitalization(.characters)
                .font(.system(size: 22, weight: .bold))
                .padding(14).frame(width: 320)
                .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            TextField("", text: $joinPassword, prompt: Text("Password (if any)").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain).foregroundColor(.white)
                .padding(14).frame(width: 320)
                .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            if !net.onlineError.isEmpty {
                Text(errorText(net.onlineError)).font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
            }
            bigButton("Join Room", color: Color(red: 0.20, green: 0.75, blue: 0.35)) {
                let c = joinCode.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty { net.joinRoom(code: c, password: joinPassword) }
            }
            Button { sub = .menu } label: { Text("Back").foregroundColor(.white.opacity(0.7)) }
        }
        .padding(28)
    }

    // MARK: in-room lobby

    private var roomView: some View {
        HStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("ROOM  \(net.roomCode)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
                Text("Share this code with friends to let them join")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                avatarField
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("\(playerIDs.count) players in room")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
            }
            VStack(spacing: 12) {
                if net.isOwner {
                    VStack(alignment: .leading, spacing: 10) {
                        row("MODE") {
                            Picker("", selection: $mode) {
                                Text("Deathmatch").tag(0); Text("Teams").tag(1); Text("Flag").tag(2)
                            }.pickerStyle(.segmented)
                        }
                        row("MAP") {
                            Picker("", selection: $mapIndex) {
                                ForEach(0..<Maps.all.count, id: \.self) { i in Text(Maps.all[i].shortName).tag(i) }
                            }.pickerStyle(.segmented)
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
                    .padding(14).background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    bigButton("START MATCH", color: Color(red: 0.20, green: 0.75, blue: 0.35)) { startTapped() }
                } else {
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Waiting for the host to start…")
                            .foregroundColor(.white.opacity(0.85)).font(.system(size: 14, weight: .semibold))
                    }.padding(.vertical, 40)
                }
                Button { net.leaveRoom() } label: { Text("Leave").foregroundColor(.white.opacity(0.7)) }
            }
            .frame(width: 320)
        }
        .padding(18)
    }

    // MARK: social — players online + friends

    private var playersView: some View {
        VStack(spacing: 14) {
            Text("Players Online (\(net.onlineCount))")
                .font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
            if net.onlinePlayers.isEmpty {
                Spacer()
                Text("No other players online right now.").font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                Spacer()
            } else {
                ScrollView { VStack(spacing: 10) { ForEach(net.onlinePlayers) { socialRow($0, showAdd: true) } } }
                    .frame(maxWidth: 560)
            }
            if net.playersPages > 1 {
                HStack(spacing: 16) {
                    Button { net.reqPlayers(max(0, net.playersPage - 1)) } label: { Text("‹ Prev") }.disabled(net.playersPage <= 0)
                    Text("Page \(net.playersPage + 1) / \(net.playersPages)")
                    Button { net.reqPlayers(min(net.playersPages - 1, net.playersPage + 1)) } label: { Text("Next ›") }.disabled(net.playersPage >= net.playersPages - 1)
                }.foregroundColor(.white)
            }
            HStack(spacing: 12) {
                pill("Friends", "person.2") { net.reqFriends(); net.reqRequests(); sub = .friends }
                pill("Back", "chevron.left") { sub = .menu }
            }
        }
        .padding(28)
    }

    private var friendsView: some View {
        VStack(spacing: 12) {
            Text("Friends").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
            ScrollView {
                VStack(spacing: 10) {
                    if !net.requests.isEmpty {
                        sectionLabel("Requests (\(net.requests.count))")
                        ForEach(net.requests) { r in
                            HStack {
                                Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                Spacer()
                                Button { net.friendAccept(r.pid) } label: {
                                    Text("Accept").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 9).background(Color(red: 0.2, green: 0.72, blue: 0.36)).clipShape(Capsule())
                                }
                                Button { net.friendDecline(r.pid) } label: {
                                    Text("Decline").font(.system(size: 14)).foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 14).padding(.vertical, 9).background(Color.white.opacity(0.12)).clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    sectionLabel("Your Friends (\(net.friends.count))")
                    if net.friends.isEmpty {
                        Text("No friends yet — add players from the Players list.")
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                    } else {
                        ForEach(net.friends) { socialRow($0, showAdd: false) }
                    }
                }
            }
            .frame(maxWidth: 560)
            HStack(spacing: 12) {
                pill("Players", "person.3") { net.reqPlayers(0); sub = .players }
                pill("Back", "chevron.left") { sub = .menu }
            }
        }
        .padding(28)
    }

    private var profileView: some View {
        VStack(spacing: 14) {
            if let pr = net.profile {
                let skin = RobotSkin(mr: pr.jr, mg: pr.jg, mb: pr.jb,
                                     ar: min(1, pr.jr + 0.3), ag: min(1, pr.jg + 0.3), ab: min(1, pr.jb + 0.3))
                ZStack {
                    Circle().fill(Color(red: pr.jr, green: pr.jg, blue: pr.jb).opacity(0.18))
                        .frame(width: 120, height: 120).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                    RobotPreview(skin: skin).frame(width: 80, height: 104)
                }
                Text(pr.name).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.white)
                Text(pr.online ? "● Online" : "○ Offline").font(.system(size: 15))
                    .foregroundColor(pr.online ? .green : .white.opacity(0.6))
                Text("\(pr.friends) friends").font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                if net.friends.contains(where: { $0.pid == pr.pid }) {
                    bigButton("Unfriend", color: Color.white.opacity(0.18)) { net.unfriend(pr.pid); net.reqPlayers(0); sub = .players }
                } else if net.requests.contains(where: { $0.pid == pr.pid }) {
                    bigButton("Accept Request", color: Color(red: 0.2, green: 0.75, blue: 0.35)) { net.friendAccept(pr.pid) }
                } else {
                    bigButton("+ Add Friend", color: Color(red: 0.2, green: 0.75, blue: 0.35)) { net.friendRequest(pr.pid) }
                }
            } else {
                ProgressView().tint(.white)
            }
            Button { sub = .players } label: { Text("Back").foregroundColor(.white.opacity(0.7)) }
        }
        .padding(28)
    }

    private func socialRow(_ p: SocialPlayer, showAdd: Bool) -> some View {
        HStack(spacing: 8) {
            Button { profilePid = p.pid; net.reqProfile(p.pid); sub = .profile } label: {
                HStack(spacing: 10) {
                    Circle().fill(p.online ? Color.green : Color.gray.opacity(0.6)).frame(width: 10, height: 10)
                    Text(p.name).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if showAdd && !p.friend {
                Button { net.friendRequest(p.pid) } label: {
                    Text("+ Add").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(red: 0.2, green: 0.72, blue: 0.36)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("✓").font(.system(size: 18, weight: .bold)).foregroundColor(.green).frame(width: 40)
            }
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        HStack { Text(t).font(.system(size: 13, weight: .heavy)).foregroundColor(.white.opacity(0.55)); Spacer() }
    }

    // MARK: avatars

    private var playerIDs: [String] { [net.myPeerID.displayName] + net.connectedPeers.map { $0.displayName } }

    private func nameFor(_ id: String) -> String {
        id == net.myPeerID.displayName ? settings.resolvedName : (net.peerInfo[id]?.name ?? id)
    }
    private func skinFor(_ id: String) -> RobotSkin {
        id == net.myPeerID.displayName ? settings.skin : (net.peerInfo[id]?.skin ?? PlayerColors.skin(1))
    }

    private var avatarField: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 16) {
                ForEach(playerIDs, id: \.self) { id in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(Color(red: skinFor(id).mr, green: skinFor(id).mg, blue: skinFor(id).mb).opacity(0.18))
                                .frame(width: 66, height: 66)
                                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 3))
                            RobotPreview(skin: skinFor(id)).frame(width: 44, height: 56).frame(width: 66, height: 66)
                        }
                        Text(id == net.myPeerID.displayName ? "\(nameFor(id)) (You)" : nameFor(id))
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: helpers

    private var statusLine: some View {
        HStack(spacing: 8) {
            if !net.serverReady { ProgressView().tint(.white) }
            Text(net.serverReady ? "Connected — choose a room" : "Connecting to server…")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
        }
    }

    private func cfg() -> MatchConfig {
        MatchConfig(mode: mode, target: target, minutes: minutes, mapIndex: mapIndex,
                    unlimitedAmmo: settings.unlimitedAmmo, assignments: teamAssign())
    }

    private func teamAssign() -> [String: Int] {
        guard mode >= 1 else { return [:] }
        var a: [String: Int] = [:]
        for (i, id) in playerIDs.enumerated() { a[id] = i % 2 }
        return a
    }

    private func startTapped() { net.startMatch(config: cfg()); onStart() }

    private func quickPlay() { quickPending = true; net.listRooms() }

    private func handleQuick() {
        guard quickPending else { return }
        quickPending = false
        if net.rooms.isEmpty { net.createRoom(isPublic: true, password: "", settings: cfg()) }
        else { net.joinRoom(code: net.rooms[0].code, password: "") }
    }

    private func modeName(_ m: Int) -> String { ["Deathmatch", "Teams", "Flag"][max(0, min(2, m))] }
    private func mapName(_ i: Int) -> String { Maps.all[max(0, min(Maps.all.count - 1, i))].shortName }
    private func errorText(_ c: String) -> String {
        ["room_full": "Room is full", "bad_password": "Wrong password",
         "no_room": "Room not found", "not_owner": "Only the host can do that"][c] ?? c
    }

    @ViewBuilder private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .heavy)).foregroundColor(.white.opacity(0.55))
            content()
        }
    }

    private func card(_ title: String, _ subtitle: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack { Circle().fill(color); Image(systemName: icon).font(.system(size: 19, weight: .bold)).foregroundColor(.white) }
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
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.85), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func bigButton(_ title: String, color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 17, weight: .heavy, design: .rounded))
                .frame(maxWidth: 320).padding(.vertical, 14)
                .background(color).foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func pill(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(title) }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Color.white.opacity(0.12)).clipShape(Capsule())
        }
    }
}
