//
//  MultipeerManager.swift
//  Local multiplayer over plain UDP + JSON — the SAME wire protocol as the Godot
//  (Android) build's `net.gd`, so iOS↔Android AND iOS↔iOS both work over a WiFi /
//  hotspot LAN. The host is a relay hub: clients send to the host, the host fans
//  out to everyone. Discovery is a UDP broadcast beacon → hosts appear and the
//  client auto-connects to the first one found (no manual host ID).
//
//  Wire format (must stay byte-compatible with net.gd):
//    • Discovery (UDP 7712, host broadcasts):
//        {"magic":"CHORPOLICE/2","name":<str>,"players":<int>,"map":<int>}
//    • Game (UDP 7711):
//        client→host  join : {"t":"join","name","color","jr","jg","jb"}
//        host→client  welcome: {"t":"welcome","id":<int>,"peers":<roster>}
//                     roster : {"t":"roster","peers":<roster>}
//                     start  : {"t":"start","cfg":{map,mode,target,minutes,unlimited,assign}}
//        either       m      : {"t":"m",[ "from":<int> ],"d":<game dict>,"r":0|1,"s":<seq>}
//      roster = { "<id>": {name,color,jr,jg,jb}, ... }   (id 1 = host, 2,3… = clients)
//
//  The in-game `d` payload uses Godot's flat short-key dicts (see net.gd / game.gd);
//  this file translates between the typed Swift `GameMessage` and that wire shape,
//  including the coordinate flip (SpriteKit y-UP ↔ Godot y-DOWN: godot_y = -ios_y).
//
//  iOS requirements (set these up in Xcode):
//    • Info.plist → NSLocalNetworkUsageDescription (any LAN UDP needs the prompt).
//    • To HOST (broadcast beacons) on iOS 14+ you also need the multicast
//      entitlement `com.apple.developer.networking.multicast` (request from Apple).
//      JOINING an Android/iOS host needs only the Local Network permission.
//

import Foundation
import Combine
import CoreGraphics
import Darwin

/// A player in the match. `displayName` ("p<id>") is the stable key used across the
/// app (replaces MCPeerID); `id` is the integer used on the wire (host = 1, …).
struct Peer: Hashable {
    let id: Int
    var displayName: String { "p\(id)" }
}

// MARK: - Low-level UDP socket (POSIX), mirrors Godot's PacketPeerUDP

private final class UDPSocket {
    let fd: Int32
    private var source: DispatchSourceRead?
    var onPacket: ((Data, String, UInt16) -> Void)?

    init?(bindPort: UInt16?, broadcast: Bool) {
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        if fd < 0 { return nil }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))
        if broadcast {
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        }
        if let port = bindPort {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = INADDR_ANY
            let ok = withUnsafePointer(to: &addr) { p in
                p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                }
            }
            if !ok { Darwin.close(fd); return nil }
        }
        let fl = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, fl | O_NONBLOCK)
    }

    func startReading(on queue: DispatchQueue) {
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in self?.drain() }
        source = src
        src.resume()
    }

    private func drain() {
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            var sa = sockaddr_storage()
            var slen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let n = withUnsafeMutablePointer(to: &sa) { sp in
                sp.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                    recvfrom(fd, &buf, buf.count, 0, sap, &slen)
                }
            }
            if n <= 0 { break }
            let data = Data(bytes: buf, count: n)
            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var port: UInt16 = 0
            withUnsafePointer(to: &sa) { sp in
                sp.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { si in
                    var a = si.pointee.sin_addr
                    inet_ntop(AF_INET, &a, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                    port = UInt16(bigEndian: si.pointee.sin_port)
                }
            }
            onPacket?(data, String(cString: ipBuf), port)
        }
    }

    func send(_ data: Data, to ip: String, port: UInt16) {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, ip, &addr.sin_addr)
        _ = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                data.withUnsafeBytes { raw in
                    sendto(fd, raw.baseAddress, data.count, 0, sa,
                           socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    func close() {
        source?.cancel(); source = nil
        Darwin.close(fd)
    }
}

// MARK: - MultipeerManager (same public API as before, UDP underneath)

final class MultipeerManager: NSObject, ObservableObject {

    static let serviceType = "desi-militia"   // legacy; unused with UDP

    private let GAME_PORT: UInt16 = 7711
    private let DISC_PORT: UInt16 = 7712
    private let MAGIC = "CHORPOLICE/2"
    private let TIMEOUT: TimeInterval = 6.0

    // Published / public API (unchanged shape for LobbyView / GameScene / ContentView)
    @Published var connectedPeers: [Peer] = []
    @Published var didStart = false
    @Published var isRunning = false
    @Published var matchConfig: MatchConfig?
    @Published var peerInfo: [String: HelloInfo] = [:]   // keyed by displayName "p<id>"
    var isHost = false
    var makeHello: (() -> HelloInfo)?
    var onMessage: ((GameMessage, Peer) -> Void)?
    var onPeerLeft: ((Peer) -> Void)?

    var myPeerID: Peer { Peer(id: myID) }

    // Internal state — all mutated on `q`
    private var myID = 0
    private var nextID = 2
    private struct PlayerRec { var name: String; var skin: RobotSkin }
    private var players: [Int: PlayerRec] = [:]
    private struct ClientRec { var id: Int; var ip: String; var port: UInt16; var seen: TimeInterval }
    private var clients: [String: ClientRec] = [:]      // host only, "ip:port" -> rec
    private var hostIP: String?                          // client: discovered host
    private var welcomed = false
    private var lastHostSeen: TimeInterval = 0            // client: host-loss detection
    private var started = false
    private var seq = 0
    private var seenSeq: [Int: Set<Int>] = [:]
    private var localHello = HelloInfo(name: "Player", skin: PlayerColors.skin(0))

    private var game: UDPSocket?
    private var disc: UDPSocket?
    private let q = DispatchQueue(label: "chorpolice.net")
    private var ticker: Timer?

    override init() { super.init() }

    private func now() -> TimeInterval { Date().timeIntervalSince1970 }

    // MARK: start / stop

    func start(asHost: Bool) {
        let hello = makeHello?() ?? HelloInfo(name: "Player", skin: PlayerColors.skin(0))
        q.async {
            self.teardownSockets()
            self.isHost = asHost
            self.localHello = hello
            self.welcomed = false
            self.lastHostSeen = 0
            self.started = false
            self.seq = 0
            self.seenSeq = [:]
            self.clients = [:]
            self.players = [:]
            self.hostIP = nil
            if asHost {
                self.myID = 1
                self.nextID = 2
                self.players[1] = PlayerRec(name: hello.name, skin: hello.skin)
                self.game = UDPSocket(bindPort: self.GAME_PORT, broadcast: false)
                self.disc = UDPSocket(bindPort: self.DISC_PORT, broadcast: true)   // beacons + receive probes
                self.game?.onPacket = { [weak self] d, ip, p in self?.q.async { self?.onGame(d, ip, p) } }
                self.disc?.onPacket = { [weak self] d, ip, p in self?.q.async { self?.onProbe(d, ip, p) } }
                self.game?.startReading(on: self.q)
                self.disc?.startReading(on: self.q)
            } else {
                self.myID = 0
                self.game = UDPSocket(bindPort: 0, broadcast: false)    // ephemeral
                self.disc = UDPSocket(bindPort: self.DISC_PORT, broadcast: true) // receive beacons + send probes
                self.game?.onPacket = { [weak self] d, ip, p in self?.q.async { self?.onGame(d, ip, p) } }
                self.disc?.onPacket = { [weak self] d, ip, _ in self?.q.async { self?.onBeacon(d, ip) } }
                self.game?.startReading(on: self.q)
                self.disc?.startReading(on: self.q)
            }
            self.publishPeers()
            DispatchQueue.main.async { self.isRunning = true; self.didStart = false }
        }
        startTicker()
    }

    func stop() {
        ticker?.invalidate(); ticker = nil
        q.async { self.teardownSockets() }
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectedPeers = []
            self.didStart = false
            self.matchConfig = nil
            self.peerInfo = [:]
        }
    }

    private func teardownSockets() {
        game?.close(); game = nil
        disc?.close(); disc = nil
    }

    private func startTicker() {
        DispatchQueue.main.async {
            self.ticker?.invalidate()
            self.ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.q.async { self?.tick() }
            }
        }
    }

    private func tick() {
        let t = now()
        if isHost {
            if let d = try? JSONSerialization.data(withJSONObject: beaconDict()) {
                disc?.send(d, to: "255.255.255.255", port: DISC_PORT)
            }
            var changed = false
            for (k, c) in clients where t - c.seen > TIMEOUT {
                players[c.id] = nil
                clients[k] = nil
                DispatchQueue.main.async { self.onPeerLeft?(Peer(id: c.id)) }
                changed = true
            }
            if changed { publishPeers() }
        } else if hostIP != nil {
            if welcomed && now() - lastHostSeen > TIMEOUT {
                // host went silent — drop back to searching so the lobby doesn't hang
                hostIP = nil; welcomed = false; players = [:]
                publishPeers()
            } else {
                sendJoin()       // keep-alive so the host doesn't time us out
            }
        } else {
            sendProbe()          // ask hosts to reply (finds a host that can't broadcast)
        }
    }

    // MARK: discovery (client)

    private func onBeacon(_ data: Data, _ ip: String) {
        guard hostIP == nil,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["magic"] as? String == MAGIC,
              (obj["probe"] as? Bool) != true else { return }
        hostIP = ip                       // auto-connect to the first host found
        sendJoin()
    }

    private func beaconDict() -> [String: Any] {
        ["magic": MAGIC, "name": localHello.name, "players": players.count, "map": matchConfig?.mapIndex ?? 0]
    }

    private func sendProbe() {
        guard let d = try? JSONSerialization.data(withJSONObject: ["magic": MAGIC, "probe": true]) else { return }
        disc?.send(d, to: "255.255.255.255", port: DISC_PORT)
    }

    /// Host only: a client broadcast a probe → reply UNICAST with our beacon. This is what
    /// lets an iOS host be discovered without the multicast (broadcast-send) entitlement —
    /// the Android client broadcasts, the iOS host only ever unicasts its reply.
    private func onProbe(_ data: Data, _ ip: String, _ port: UInt16) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["magic"] as? String == MAGIC, (obj["probe"] as? Bool) == true else { return }
        if let d = try? JSONSerialization.data(withJSONObject: beaconDict()) {
            disc?.send(d, to: ip, port: port)
        }
    }

    private func sendJoin() {
        guard let ip = hostIP else { return }
        let j: [String: Any] = ["t": "join", "name": localHello.name, "color": 0,
                                "jr": localHello.skin.mr, "jg": localHello.skin.mg, "jb": localHello.skin.mb]
        sendRaw(j, to: ip, port: GAME_PORT, times: 1)
    }

    // MARK: receive

    private func onGame(_ data: Data, _ ip: String, _ port: UInt16) {
        guard let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if isHost { hostRecv(d, ip, port) } else { clientRecv(d) }
    }

    private func hostRecv(_ d: [String: Any], _ ip: String, _ port: UInt16) {
        let key = "\(ip):\(port)"
        switch d["t"] as? String {
        case "join":
            let isNew = clients[key] == nil
            if isNew {
                let id = nextID; nextID += 1
                clients[key] = ClientRec(id: id, ip: ip, port: port, seen: now())
                players[id] = PlayerRec(name: d["name"] as? String ?? "Player", skin: skinFromIdentity(d))
                publishPeers()
            }
            clients[key]?.seen = now()
            guard let cid = clients[key]?.id else { return }
            sendRaw(["t": "welcome", "id": cid, "peers": roster()], to: ip, port: port, times: 2)
            if isNew { broadcastRaw(["t": "roster", "peers": roster()], times: 3) }
        case "m":
            guard var c = clients[key] else { return }
            c.seen = now(); clients[key] = c
            let from = c.id
            let rel = intOf(d["r"]), s = intOf(d["s"])
            if rel == 1 && dup(from, s) { return }
            let inner = d["d"] as? [String: Any] ?? [:]
            deliver(inner, from: from)
            for (k2, c2) in clients where k2 != key {
                sendRaw(["t": "m", "from": from, "d": inner, "r": rel, "s": s],
                        to: c2.ip, port: c2.port, times: rel + 1)
            }
        default: break
        }
    }

    private func clientRecv(_ d: [String: Any]) {
        lastHostSeen = now()
        switch d["t"] as? String {
        case "welcome":
            if !welcomed {
                myID = intOf(d["id"], 2)
                applyRoster(d["peers"] as? [String: Any] ?? [:])
                welcomed = true
                publishPeers()
            }
        case "roster":
            applyRoster(d["peers"] as? [String: Any] ?? [:])
            publishPeers()
        case "start":
            if !started {
                started = true
                let cfg = matchConfigFromWire(d["cfg"] as? [String: Any] ?? [:])
                DispatchQueue.main.async { self.matchConfig = cfg; self.didStart = true }
            }
        case "m":
            let from = intOf(d["from"])
            let rel = intOf(d["r"]), s = intOf(d["s"])
            if rel == 1 && dup(from, s) { return }
            deliver(d["d"] as? [String: Any] ?? [:], from: from)
        default: break
        }
    }

    private func deliver(_ inner: [String: Any], from: Int) {
        guard let msg = wireToMessage(inner, from: from) else { return }
        DispatchQueue.main.async { self.onMessage?(msg, Peer(id: from)) }
    }

    // MARK: send

    func send(_ message: GameMessage, reliable: Bool = false) {
        q.async {
            guard self.isRunning, let inner = self.messageToWire(message) else { return }
            self.seq += 1
            let s = self.seq
            let rel = reliable ? 1 : 0
            if self.isHost {
                for (_, c) in self.clients {
                    self.sendRaw(["t": "m", "from": 1, "d": inner, "r": rel, "s": s],
                                 to: c.ip, port: c.port, times: rel + 1)
                }
            } else if let ip = self.hostIP {
                self.sendRaw(["t": "m", "d": inner, "r": rel, "s": s],
                             to: ip, port: self.GAME_PORT, times: rel + 1)
            }
        }
    }

    func startMatch(config: MatchConfig) {
        DispatchQueue.main.async { self.matchConfig = config; self.didStart = true }
        q.async {
            let cfg = self.wireFromMatchConfig(config)
            self.broadcastRaw(["t": "start", "cfg": cfg], times: 6)
        }
    }

    // MARK: roster helpers

    private func roster() -> [String: Any] {
        var r: [String: Any] = [:]
        for (id, rec) in players {
            r["\(id)"] = ["name": rec.name, "color": 0,
                          "jr": rec.skin.mr, "jg": rec.skin.mg, "jb": rec.skin.mb]
        }
        return r
    }

    private func applyRoster(_ r: [String: Any]) {
        for (sid, v) in r {
            guard let id = Int(sid), let p = v as? [String: Any] else { continue }
            players[id] = PlayerRec(name: p["name"] as? String ?? "P\(id)", skin: skinFromIdentity(p))
        }
    }

    /// Lobby identity carries only the jacket colour; the full skin arrives in `state`.
    private func skinFromIdentity(_ p: [String: Any]) -> RobotSkin {
        let jr = dbl(p["jr"], 0.3), jg = dbl(p["jg"], 0.5), jb = dbl(p["jb"], 0.9)
        return RobotSkin(mr: jr, mg: jg, mb: jb,
                         ar: min(1, jr + 0.3), ag: min(1, jg + 0.3), ab: min(1, jb + 0.3))
    }

    private func publishPeers() {
        let me = myID
        var peers: [Peer] = []
        var info: [String: HelloInfo] = [:]
        for (id, rec) in players {
            info["p\(id)"] = HelloInfo(name: rec.name, skin: rec.skin)
            if id != me { peers.append(Peer(id: id)) }
        }
        peers.sort { $0.id < $1.id }
        DispatchQueue.main.async { self.connectedPeers = peers; self.peerInfo = info }
    }

    // MARK: raw send + dedupe

    private func sendRaw(_ obj: [String: Any], to ip: String, port: UInt16, times: Int) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        for _ in 0..<max(1, times) { game?.send(data, to: ip, port: port) }
    }

    private func broadcastRaw(_ obj: [String: Any], times: Int) {
        for (_, c) in clients { sendRaw(obj, to: c.ip, port: c.port, times: times) }
    }

    private func dup(_ from: Int, _ s: Int) -> Bool {
        if seenSeq[from] == nil { seenSeq[from] = [] }
        if seenSeq[from]!.contains(s) { return true }
        seenSeq[from]!.insert(s)
        if seenSeq[from]!.count > 256 { seenSeq[from] = [s] }
        return false
    }

    // MARK: wire ⇄ MatchConfig

    private func wireFromMatchConfig(_ c: MatchConfig) -> [String: Any] {
        var assign: [String: Any] = [:]
        for (k, t) in c.assignments { assign[stripP(k)] = t }   // "p2" -> "2"
        return ["map": c.mapIndex, "mode": c.mode, "target": c.target,
                "minutes": c.minutes, "unlimited": c.unlimitedAmmo, "assign": assign]
    }

    private func matchConfigFromWire(_ d: [String: Any]) -> MatchConfig {
        var assign: [String: Int] = [:]
        if let a = d["assign"] as? [String: Any] {
            for (k, v) in a { assign["p\(k)"] = intOf(v) }       // "2" -> "p2"
        }
        return MatchConfig(mode: intOf(d["mode"]), target: intOf(d["target"], 10),
                           minutes: intOf(d["minutes"], 5), mapIndex: intOf(d["map"]),
                           unlimitedAmmo: (d["unlimited"] as? Bool) ?? false, assignments: assign)
    }

    // MARK: wire ⇄ GameMessage (with SpriteKit y-UP ↔ Godot y-DOWN flip)

    private func flipY(_ y: Double) -> Double { -y }
    private func flipA(_ a: Double) -> Double { -a }

    private func messageToWire(_ m: GameMessage) -> [String: Any]? {
        switch m {
        case .state(let s):
            return ["t": "state",
                    "x": Double(s.x), "y": flipY(Double(s.y)),
                    "vx": Double(s.vx), "vy": flipY(Double(s.vy)),
                    "aim": flipA(Double(s.aim)), "hp": Double(s.health), "dead": s.dead,
                    "w": s.weapon, "k": s.kills, "c": s.captures, "team": s.team, "fl": s.carryingFlag,
                    "jr": s.skin.mr, "jg": s.skin.mg, "jb": s.skin.mb,
                    "j2r": s.skin.jacket2RGB[0], "j2g": s.skin.jacket2RGB[1], "j2b": s.skin.jacket2RGB[2],
                    "ar": s.skin.ar, "ag": s.skin.ag, "ab": s.skin.ab,
                    "hr": s.skin.helmetRGB[0], "hg": s.skin.helmetRGB[1], "hb": s.skin.helmetRGB[2],
                    "pr": s.skin.pantsRGB[0], "pg": s.skin.pantsRGB[1], "pb": s.skin.pantsRGB[2],
                    "tr": s.skin.toneRGB[0], "tg": s.skin.toneRGB[1], "tb": s.skin.toneRGB[2]]
        case .fire(let f):
            return ["t": "fire", "x": Double(f.x), "y": flipY(Double(f.y)),
                    "ang": flipA(Double(f.angle)), "w": f.weapon]
        case .nade(let n):
            return ["t": "nade", "x": Double(n.x), "y": flipY(Double(n.y)),
                    "vx": Double(n.vx), "vy": flipY(Double(n.vy))]
        case .hit(let h):
            return ["t": "hit", "x": Double(h.x), "y": flipY(Double(h.y)),
                    "hp": Double(h.health), "dead": h.dead, "by": idFromKey(h.killedBy)]
        case .pickup(let p):
            return ["t": "pickup", "spot": p.spot]
        case .flag(let f):
            return ["t": "flag", "kind": f.kind, "team": f.team,
                    "x": Double(f.x), "y": flipY(Double(f.y))]
        case .hello, .startGame:
            return nil      // identity rides the join/roster; start is its own packet
        }
    }

    private func wireToMessage(_ d: [String: Any], from id: Int) -> GameMessage? {
        switch d["t"] as? String {
        case "state":
            let wireVy = dbl(d["vy"])
            let s = PlayerState(
                x: cg(d["x"]), y: cg(flipY(dbl(d["y"]))),
                vx: cg(d["vx"]), vy: cg(flipY(wireVy)),
                aim: cg(flipA(dbl(d["aim"]))),
                thrusting: wireVy < -120,                  // Godot derives thrust from y-down vy
                health: cg(d["hp"]), dead: boolOf(d["dead"]),
                name: players[id]?.name ?? "P\(id)",
                team: intOf(d["team"], -1),
                skin: skinFromWire(d),
                weapon: intOf(d["w"]), kills: intOf(d["k"]), captures: intOf(d["c"]),
                carryingFlag: intOf(d["fl"], -1))
            return .state(s)
        case "fire":
            return .fire(FireEvent(x: cg(d["x"]), y: cg(flipY(dbl(d["y"]))),
                                   angle: cg(flipA(dbl(d["ang"]))), weapon: intOf(d["w"])))
        case "nade":
            return .nade(NadeEvent(x: cg(d["x"]), y: cg(flipY(dbl(d["y"]))),
                                   vx: cg(d["vx"]), vy: cg(flipY(dbl(d["vy"])))))
        case "hit":
            return .hit(HitEvent(x: cg(d["x"]), y: cg(flipY(dbl(d["y"]))),
                                 health: cg(d["hp"]), dead: boolOf(d["dead"]),
                                 killedBy: keyFromId(intOf(d["by"]))))
        case "pickup":
            return .pickup(PickupEvent(spot: intOf(d["spot"])))
        case "flag":
            return .flag(FlagEvent(kind: intOf(d["kind"]), team: intOf(d["team"]),
                                   x: cg(d["x"]), y: cg(flipY(dbl(d["y"])))))
        default:
            return nil
        }
    }

    private func skinFromWire(_ d: [String: Any]) -> RobotSkin {
        func trip(_ a: String, _ b: String, _ c: String, _ da: Double, _ db: Double, _ dc: Double) -> [Double] {
            [dbl(d[a], da), dbl(d[b], db), dbl(d[c], dc)]
        }
        let body = trip("jr", "jg", "jb", 0.3, 0.5, 0.9)
        let j2 = trip("j2r", "j2g", "j2b", body[0], body[1], body[2])
        let acc = trip("ar", "ag", "ab", 0.6, 0.9, 1.0)
        let hel = trip("hr", "hg", "hb", body[0], body[1], body[2])
        let pan = trip("pr", "pg", "pb", body[0] * 0.45, body[1] * 0.45, body[2] * 0.5)
        let ton = trip("tr", "tg", "tb", 0.86, 0.66, 0.5)
        return RobotSkin(mr: body[0], mg: body[1], mb: body[2],
                         ar: acc[0], ag: acc[1], ab: acc[2],
                         helmet: hel, pants: pan, tone: ton, jacket2: j2)
    }

    // MARK: tiny coercion helpers (JSONSerialization yields NSNumber)

    private func dbl(_ a: Any?, _ def: Double = 0) -> Double { (a as? NSNumber)?.doubleValue ?? def }
    private func intOf(_ a: Any?, _ def: Int = 0) -> Int { (a as? NSNumber)?.intValue ?? def }
    private func boolOf(_ a: Any?) -> Bool { (a as? NSNumber)?.boolValue ?? (a as? Bool ?? false) }
    private func cg(_ a: Any?) -> CGFloat { CGFloat(dbl(a)) }

    private func idFromKey(_ key: String?) -> Int {
        guard let k = key else { return 0 }
        return Int(k.hasPrefix("p") ? String(k.dropFirst()) : k) ?? 0
    }
    private func keyFromId(_ id: Int) -> String? { id > 0 ? "p\(id)" : nil }
    private func stripP(_ k: String) -> String { k.hasPrefix("p") ? String(k.dropFirst()) : k }
}
