//
//  GameScene.swift
//  Themed long arenas (caves, weather, parallax) with camera follow, animated
//  robots, twin-stick controls, weapons + pickups, a practice bot, synced
//  multiplayer deathmatch / team deathmatch / capture-the-flag, and a round timer.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // Injected by GameView
    var net: MultipeerManager?
    var settings: GameSettings?
    var practiceMapIndex = 0
    private var isMultiplayer: Bool { net != nil }
    private var localName: String { net?.myPeerID.displayName ?? "me" }

    // World
    private var map: MapDef!
    private var levelWidth: CGFloat = 4800
    private let cam = SKCameraNode()
    /// Camera zoom-out factor: >1 shows more of the map (Mini Militia feel).
    /// 2.0 = twice the map on screen, robots at half size.
    private var zoom: CGFloat = 2.0
    private var camRestY: CGFloat = 0
    private var hillsLayer = SKNode()
    private var cloudsLayer = SKNode()
    private var groundTopY: CGFloat = 80

    // Actors
    private var player: Robot!
    private var remotePlayers: [String: Robot] = [:]
    private var remoteTargets: [String: PlayerState] = [:]

    // Controls
    private let moveStick = Joystick()
    private let aimStick = Joystick()
    private var moveTouch: UITouch?
    private var aimTouch: UITouch?
    private var leftHanded = false

    // Movement / fuel
    private let moveSpeed: CGFloat = 320
    private let thrustVelocity: CGFloat = 330
    private let maxFuel: CGFloat = 100
    private var fuel: CGFloat = 100

    // Weapons
    private var currentWeapon: WeaponType = .rifle
    private var ammo = 0
    private var unlimitedAmmo = false
    private var fireCooldown: CGFloat = 0
    private let myBulletColor = SKColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
    private let foeBulletColor = SKColor(red: 1, green: 0.5, blue: 0.3, alpha: 1)

    // Match config
    private var mode = 0                  // 0 DM, 1 TDM, 2 CTF
    private var target = 10
    private var timeRemaining: CGFloat = 300
    private var assignments: [String: Int] = [:]
    private var localTeam = -1
    private var localSkin = PlayerColors.skin(0)
    private var matchOver = false

    // Scores
    private var kills = 0
    private var myCaptures = 0
    private var peerKills: [String: Int] = [:]
    private var peerCaptures: [String: Int] = [:]
    private var peerTeams: [String: Int] = [:]

    // CTF
    private enum FlagStatus { case home, carried(String), dropped(CGPoint) }
    private var flagNodes: [FlagNode] = []
    private var flagStatus: [FlagStatus] = [.home, .home]
    private var basePos: [CGPoint] = []
    private var myCarrying = -1

    // Pickups
    private var pickups: [Int: PickupNode] = [:]
    private var pickupCycles: [Int: Int] = [:]
    private let pickupPattern: [PickupKind] = [
        .health, .weapon(.shotgun), .weapon(.uzi), .weapon(.sniper), .nades,
        .weapon(.ak47), .health, .weapon(.magnum), .weapon(.mp5),
        .weapon(.rocket), .nades, .weapon(.flamer)
    ]
    private var grenades = 3
    private var flameShotCount = 0
    private let nadeButton = SKNode()
    private var nadeTouch: UITouch?
    private var nadeAimVec = CGVector.zero
    private let nadePreview = SKNode()
    private var nadeDots: [SKSpriteNode] = []
    private let nadeQuickPower: CGFloat = 540
    private var liveGrenades: [Grenade] = []
    private let nadeGravity: CGFloat = -3000   // applied manually so the preview matches the real arc

    // Practice bot
    private struct BotProfile {
        let name: String
        let speed: CGFloat          // horizontal points/sec
        let fireMin: CGFloat        // seconds between shots (min...max)
        let fireMax: CGFloat
        let aimError: CGFloat       // radians of random aim wobble
        let range: CGFloat          // engagement distance
        let chaseBias: CGFloat      // 0-1: how often it moves toward the player
        let standoff: CGFloat       // preferred fighting distance
        let dodgeProb: CGFloat      // 0-1: jetpack-burst chance per think tick
        let lead: CGFloat           // 0-1: how much it leads a moving target
        let respawnDelay: CGFloat
        let maxAlive: Int           // most bots on the field at once
    }
    private static let botProfiles: [BotProfile] = [
        BotProfile(name: "Easy",   speed: 190, fireMin: 0.85, fireMax: 1.40, aimError: 0.160,
                   range: 700,  chaseBias: 0.30, standoff: 330, dodgeProb: 0.00, lead: 0.0, respawnDelay: 3.0, maxAlive: 3),
        BotProfile(name: "Normal", speed: 240, fireMin: 0.55, fireMax: 0.90, aimError: 0.090,
                   range: 950,  chaseBias: 0.55, standoff: 300, dodgeProb: 0.25, lead: 0.35, respawnDelay: 2.5, maxAlive: 4),
        BotProfile(name: "Hard",   speed: 285, fireMin: 0.34, fireMax: 0.58, aimError: 0.050,
                   range: 1150, chaseBias: 0.80, standoff: 270, dodgeProb: 0.50, lead: 0.7, respawnDelay: 2.0, maxAlive: 5),
        BotProfile(name: "Pro",    speed: 320, fireMin: 0.22, fireMax: 0.40, aimError: 0.022,
                   range: 1400, chaseBias: 0.95, standoff: 240, dodgeProb: 0.75, lead: 1.0, respawnDelay: 1.4, maxAlive: 5)
    ]
    private var botLevel = 1
    private var bot: BotProfile { Self.botProfiles[max(0, min(Self.botProfiles.count - 1, botLevel))] }

    /// One live practice opponent and its AI state.
    private final class BotAgent {
        let robot: Robot
        var thinkTimer: CGFloat = 0
        var fireTimer: CGFloat = .random(in: 0.6...1.4)
        var moveDir: CGFloat = 0
        var wantsDodge = false
        init(robot: Robot) { self.robot = robot }
    }
    private var bots: [BotAgent] = []
    private var pendingSpawns: [CGFloat] = []        // countdowns to upcoming bot arrivals
    private var reinforceTimer: CGFloat = 9
    private static let botNames = ["Raju", "Pappu", "Chintu", "Golu", "Bunty", "Montu", "Tillu", "Babloo"]
    private var botNameBag: [String] = []

    // Networking cadence
    private var netTimer: CGFloat = 0
    private let netSendInterval: CGFloat = 0.05

    // HUD
    private var fuelFill: SKSpriteNode!
    private var healthFill: SKSpriteNode!
    private var infoLabel: SKLabelNode!
    private var timerLabel: SKLabelNode!
    private var weaponLabel: SKLabelNode!

    private var lastTime: TimeInterval = 0
    private var shakeMag: CGFloat = 0
    private var jetSoundOn = false

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        physicsWorld.gravity = CGVector(dx: 0, dy: -20)
        physicsWorld.contactDelegate = self

        let cfg = net?.matchConfig
        mode = cfg?.mode ?? 0
        target = cfg?.target ?? (settings?.killsToWin ?? 10)
        timeRemaining = CGFloat((cfg?.minutes ?? 5) * 60)
        assignments = cfg?.assignments ?? [:]
        // Multiplayer: the host's rule (from MatchConfig) applies on every device.
        // Practice: the local setting applies.
        unlimitedAmmo = cfg?.unlimitedAmmo ?? (settings?.unlimitedAmmo ?? false)
        let mapIdx = cfg?.mapIndex ?? practiceMapIndex
        map = Maps.all[max(0, min(Maps.all.count - 1, mapIdx))]
        levelWidth = map.length

        leftHanded = settings?.leftHanded ?? false
        zoom = CGFloat(settings?.zoom ?? 2.0)
        botLevel = settings?.botLevel ?? 1
        localTeam = mode >= 1 ? (assignments[localName] ?? 0) : -1
        // Teams override the skin with the team color; otherwise use the player's build.
        localSkin = mode >= 1 ? PlayerColors.skin(localTeam == 0 ? 0 : 1)
                              : (settings?.skin ?? PlayerColors.skin(0))

        let s0 = map.theme.skyStops[0]
        backgroundColor = SKColor(red: s0.r / 255, green: s0.g / 255, blue: s0.b / 255, alpha: 1)
        AudioManager.shared.soundEnabled = settings?.soundOn ?? true
        AudioManager.shared.playTrack(.battle)

        setupCameraAndSky()
        buildParallax()
        buildLevel()
        setupActors()
        setupControls()
        setupHUD()
        setupNadeButton()
        setupWeather()
        spawnAllPickups()
        if mode == 2 { setupCTF() }
        showHint()

        if let net {
            net.onMessage = { [weak self] message, peer in self?.handle(message, from: peer) }
            net.onPeerLeft = { [weak self] peer in self?.removeRemote(peer.displayName) }
        }
    }

    // MARK: Spawns

    private func localSpawn() -> CGPoint {
        if mode >= 1 {
            let baseX: CGFloat = localTeam == 0 ? 350 : levelWidth - 350
            let gy = map.groundTop(at: baseX) ?? groundTopY
            return CGPoint(x: baseX + CGFloat.random(in: -90...90), y: gy + 90)
        }
        return map.ffaSpawns.randomElement() ?? CGPoint(x: 350, y: groundTopY + 90)
    }

    // MARK: World building

    private func setupCameraAndSky() {
        addChild(cam)
        camera = cam
        cam.setScale(zoom)
        // Rest height: keep the ground just above the bottom edge of the screen.
        camRestY = size.height * zoom / 2 - 24
        cam.position = CGPoint(x: size.width * zoom / 2, y: camRestY)
        let sky = SKSpriteNode(texture: Art.skyTexture(size: size, stops: map.theme.skyStops))
        sky.size = CGSize(width: size.width * 1.4, height: size.height * 1.4)
        sky.zPosition = -1000
        cam.addChild(sky)
    }

    private func buildParallax() {
        hillsLayer.zPosition = -900
        addChild(hillsLayer)
        let span = 0.5 * levelWidth + size.width * (zoom + 0.5)
        var x: CGFloat = -120
        while x < span {
            switch map.theme.hillStyle {
            case .buildings:
                let bw = CGFloat.random(in: 60...140)
                let bh = CGFloat.random(in: 120...360)
                let b = SKShapeNode(rectOf: CGSize(width: bw, height: bh), cornerRadius: 4)
                b.fillColor = map.theme.hill; b.strokeColor = .clear
                b.position = CGPoint(x: x + bw / 2, y: 80 + bh / 2 - 24)
                hillsLayer.addChild(b)
                x += bw + CGFloat.random(in: 30...90)
            case .trees:
                let trunkH = CGFloat.random(in: 90...200)
                let trunk = SKShapeNode(rectOf: CGSize(width: 14, height: trunkH))
                trunk.fillColor = map.theme.hill; trunk.strokeColor = .clear
                trunk.position = CGPoint(x: x, y: 60 + trunkH / 2)
                hillsLayer.addChild(trunk)
                let canopy = SKShapeNode(circleOfRadius: CGFloat.random(in: 38...70))
                canopy.fillColor = map.theme.hill; canopy.strokeColor = .clear
                canopy.position = CGPoint(x: x, y: 70 + trunkH)
                hillsLayer.addChild(canopy)
                x += CGFloat.random(in: 90...170)
            case .mountains:
                let mw = CGFloat.random(in: 220...420)
                let mh = CGFloat.random(in: 160...380)
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -mw / 2, y: 0))
                path.addLine(to: CGPoint(x: 0, y: mh))
                path.addLine(to: CGPoint(x: mw / 2, y: 0))
                path.closeSubpath()
                let m = SKShapeNode(path: path)
                m.fillColor = map.theme.hill; m.strokeColor = .clear
                m.position = CGPoint(x: x, y: 56)
                hillsLayer.addChild(m)
                let capPath = CGMutablePath()
                capPath.move(to: CGPoint(x: -mw * 0.13, y: mh * 0.74))
                capPath.addLine(to: CGPoint(x: 0, y: mh))
                capPath.addLine(to: CGPoint(x: mw * 0.13, y: mh * 0.74))
                capPath.closeSubpath()
                let cap = SKShapeNode(path: capPath)
                cap.fillColor = SKColor(white: 0.92, alpha: 1); cap.strokeColor = .clear
                cap.position = m.position
                hillsLayer.addChild(cap)
                x += mw * CGFloat.random(in: 0.55...0.8)
            case .rocks:
                // Distant mesas / boulder humps.
                let rw = CGFloat.random(in: 170...340)
                let rh = CGFloat.random(in: 90...230)
                let mesa = SKShapeNode(rectOf: CGSize(width: rw, height: rh),
                                       cornerRadius: min(26, rh * 0.3))
                mesa.fillColor = map.theme.hill; mesa.strokeColor = .clear
                mesa.position = CGPoint(x: x, y: 60 + rh / 2 - 10)
                hillsLayer.addChild(mesa)
                x += rw * CGFloat.random(in: 0.6...0.95)
            }
        }
    }

    private func buildLevel() {
        groundTopY = map.grounds.first?.top ?? 95

        // Ground segments (gaps between them are bottomless death pits).
        for seg in map.grounds {
            let w = seg.x1 - seg.x0
            let body = SKNode()
            body.position = CGPoint(x: seg.x0 + w / 2, y: seg.top / 2)
            body.physicsBody = staticBody(of: CGSize(width: w, height: seg.top))
            addChild(body)
            if map.kenneyTiles {
                addTiledGround(seg)
            } else {
                addBakedChunk(rect: CGRect(x: seg.x0, y: 0, width: w, height: seg.top),
                              deepBottom: 250, grassTop: true)
            }
        }

        // Floating island platforms.
        for p in map.platforms {
            let body = SKNode()
            body.position = CGPoint(x: p.x, y: p.y)
            body.physicsBody = staticBody(of: CGSize(width: p.w, height: 24))
            addChild(body)
            if map.kenneyTiles {
                addTiledPlatform(x: p.x, y: p.y, w: p.w)
            } else {
                addBakedChunk(rect: CGRect(x: p.x - p.w / 2, y: p.y - 12, width: p.w, height: 24),
                              deepBottom: CGFloat.random(in: 14...34), grassTop: true)
            }
        }

        // Solid blocks (cave roofs, pillars, towers).
        for b in map.blocks {
            let body = SKNode()
            body.position = CGPoint(x: b.x, y: b.y)
            body.physicsBody = staticBody(of: CGSize(width: b.w, height: b.h))
            addChild(body)
            addBakedChunk(rect: CGRect(x: b.x - b.w / 2, y: b.y - b.h / 2, width: b.w, height: b.h),
                          deepBottom: 0, grassTop: true, hangDeco: b.hangDeco)
        }

        // Decorative buildings.
        for s in map.structures { addStructure(s) }

        scatterProps()
        buildClouds()

        for wx in [CGFloat(0), levelWidth] {
            let wall = SKNode()
            wall.position = CGPoint(x: wx, y: size.height / 2)
            let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: size.height * 4))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody = body
            addChild(wall)
        }
    }

    /// Ground strip built from Kenney's official grass tiles (70pt grid).
    /// Fills all the way down to below the screen so tall hills have no gap.
    private func addTiledGround(_ seg: GroundSeg) {
        let tile: CGFloat = 70
        let cols = max(1, Int(ceil((seg.x1 - seg.x0) / tile)))
        let rows = max(3, Int(ceil((seg.top + 60) / tile)))
        for c in 0..<cols {
            let x = min(seg.x0 + CGFloat(c) * tile + tile / 2, seg.x1 - tile / 2)
            let topName = c == 0 ? "kenney_grassLeft"
                        : (c == cols - 1 ? "kenney_grassRight" : "kenney_grassMid")
            let top = SKSpriteNode(imageNamed: topName)
            top.position = CGPoint(x: x, y: seg.top - tile / 2)
            top.zPosition = -10
            addChild(top)
            for r in 1...rows {
                let fill = SKSpriteNode(imageNamed: "kenney_grassCenter")
                fill.position = CGPoint(x: x, y: seg.top - tile / 2 - CGFloat(r) * tile)
                fill.zPosition = -10
                addChild(fill)
            }
        }
    }

    /// Floating platform from Kenney half-tiles.
    private func addTiledPlatform(x: CGFloat, y: CGFloat, w: CGFloat) {
        let tile: CGFloat = 70
        let cols = max(1, Int(round(w / tile)))
        for c in 0..<cols {
            let name = cols == 1 ? "kenney_grassHalfMid"
                     : (c == 0 ? "kenney_grassHalfLeft"
                        : (c == cols - 1 ? "kenney_grassHalfRight" : "kenney_grassHalfMid"))
            let sprite = SKSpriteNode(imageNamed: name)
            sprite.position = CGPoint(x: x - w / 2 + CGFloat(c) * tile + tile / 2, y: y - 8)
            sprite.zPosition = -10
            addChild(sprite)
        }
    }

    /// Sprinkle Kenney CC0 decoration sprites along the ground and platforms.
    private func scatterProps() {
        let names = map.theme.props
        guard !names.isEmpty else { return }

        for seg in map.grounds {
            var x = seg.x0 + CGFloat.random(in: 70...160)
            while x < seg.x1 - 60 {
                placeProp(names.randomElement()!, x: x, surfaceY: seg.top,
                          scale: CGFloat.random(in: 0.65...0.95))
                x += CGFloat.random(in: 260...520)
            }
        }
        // Small props on some islands (big ones look odd up there).
        let small = names.filter { !$0.contains("igloo") && !$0.contains("deadTree") && !$0.contains("fence") }
        guard !small.isEmpty else { return }
        for p in map.platforms where Int.random(in: 0...9) < 4 {
            placeProp(small.randomElement()!,
                      x: p.x + CGFloat.random(in: -p.w / 4...p.w / 4),
                      surfaceY: p.y + 10,
                      scale: CGFloat.random(in: 0.5...0.7))
        }
    }

    private func placeProp(_ name: String, x: CGFloat, surfaceY: CGFloat, scale: CGFloat) {
        let sprite = SKSpriteNode(imageNamed: name)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: x, y: surfaceY - 3)
        sprite.setScale(scale)
        if Bool.random() { sprite.xScale = -scale }
        sprite.zPosition = -7
        addChild(sprite)
    }

    /// Slow-drifting parallax clouds (Kenney CC0).
    private func buildClouds() {
        guard map.theme.cloudAlpha > 0.02 else { return }
        cloudsLayer.zPosition = -880
        addChild(cloudsLayer)
        var x: CGFloat = 60
        let span = 0.65 * levelWidth + size.width * (zoom + 0.5)
        while x < span {
            let cloud = SKSpriteNode(imageNamed: "kenney_cloud\(Int.random(in: 1...3))")
            cloud.position = CGPoint(x: x, y: CGFloat.random(in: 660...1080))
            cloud.setScale(CGFloat.random(in: 0.9...1.8))
            cloud.alpha = map.theme.cloudAlpha * CGFloat.random(in: 0.7...1.0)
            cloudsLayer.addChild(cloud)
            x += CGFloat.random(in: 320...640)
        }
    }

    // MARK: Organic terrain rendering

    /// Builds a jagged, textured rock chunk over the given physics rect and
    /// bakes it to a texture (one sprite per chunk — cheap to render).
    private func addBakedChunk(rect: CGRect, deepBottom: CGFloat, grassTop: Bool,
                               hangDeco: Bool = false) {
        let chunk = organicChunkNode(rect: rect, deepBottom: deepBottom,
                                     grassTop: grassTop, hangDeco: hangDeco)
        guard let view = self.view else {
            chunk.zPosition = -10
            addChild(chunk)
            return
        }
        // Wide chunks are baked in vertical strips — a single texture would
        // exceed Metal's size limit (the crop cuts are seamless).
        let frame = chunk.calculateAccumulatedFrame()
        let tileW: CGFloat = 1200
        if frame.width <= tileW * 1.4 {
            if let tex = view.texture(from: chunk) {
                let sprite = SKSpriteNode(texture: tex)
                sprite.position = CGPoint(x: frame.midX, y: frame.midY)
                sprite.zPosition = -10
                addChild(sprite)
            } else {
                chunk.zPosition = -10
                addChild(chunk)
            }
            return
        }
        var sx = frame.minX
        while sx < frame.maxX - 1 {
            let w = min(tileW, frame.maxX - sx)
            let crop = CGRect(x: sx, y: frame.minY, width: w, height: frame.height)
            if let tex = view.texture(from: chunk, crop: crop) {
                let sprite = SKSpriteNode(texture: tex)
                sprite.position = CGPoint(x: crop.midX, y: crop.midY)
                sprite.zPosition = -10
                addChild(sprite)
            }
            sx += w
        }
    }

    private func organicChunkNode(rect: CGRect, deepBottom: CGFloat, grassTop: Bool,
                                  hangDeco: Bool) -> SKNode {
        let t = map.theme
        let container = SKNode()
        let bottomY = rect.minY - deepBottom
        let jag: CGFloat = min(8, rect.height * 0.3)

        // Jagged outline: top (L→R), right side down, bottom (R→L), left side up.
        var topPts: [CGPoint] = [CGPoint(x: rect.minX - 4, y: rect.maxY - 1)]
        var x = rect.minX + CGFloat.random(in: 18...30)
        while x < rect.maxX - 14 {
            topPts.append(CGPoint(x: x, y: rect.maxY + CGFloat.random(in: -jag...jag * 0.5)))
            x += CGFloat.random(in: 22...38)
        }
        topPts.append(CGPoint(x: rect.maxX + 4, y: rect.maxY - 1))

        var pts = topPts
        var y = rect.maxY - CGFloat.random(in: 14...26)
        while y > bottomY + 16 {
            pts.append(CGPoint(x: rect.maxX + CGFloat.random(in: -8...7), y: y))
            y -= CGFloat.random(in: 24...44)
        }
        pts.append(CGPoint(x: rect.maxX - CGFloat.random(in: 2...14), y: bottomY))
        var bx = rect.maxX - CGFloat.random(in: 30...50)
        while bx > rect.minX + 30 {
            pts.append(CGPoint(x: bx, y: bottomY + CGFloat.random(in: -7...9)))
            bx -= CGFloat.random(in: 36...70)
        }
        pts.append(CGPoint(x: rect.minX + CGFloat.random(in: 2...14), y: bottomY))
        y = bottomY + CGFloat.random(in: 22...40)
        while y < rect.maxY - 14 {
            pts.append(CGPoint(x: rect.minX + CGFloat.random(in: -7...8), y: y))
            y += CGFloat.random(in: 24...44)
        }

        let path = CGMutablePath()
        path.addLines(between: pts)
        path.closeSubpath()
        let rock = SKShapeNode(path: path)
        rock.fillColor = t.rockFill
        rock.strokeColor = t.rockEdge
        rock.lineWidth = 2.5
        rock.lineJoin = .round
        container.addChild(rock)

        // Speckle shading inside the rock.
        let speckles = max(2, Int(rect.width / 70))
        for _ in 0..<speckles {
            let s = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 6...16),
                                                  height: CGFloat.random(in: 3...8)))
            s.fillColor = t.rockDark; s.strokeColor = .clear
            s.zRotation = CGFloat.random(in: -0.5...0.5)
            s.position = CGPoint(x: CGFloat.random(in: rect.minX + 14...rect.maxX - 14),
                                 y: CGFloat.random(in: (bottomY + 12)...(rect.maxY - 10)))
            container.addChild(s)
        }

        // Grass / snow strip hugging the jagged top edge.
        if grassTop && t.grassStyle != .none {
            let depth: CGFloat = t.grassStyle == .snow ? 11 : 9
            let gPath = CGMutablePath()
            gPath.move(to: topPts[0])
            for p in topPts.dropFirst() { gPath.addLine(to: p) }
            for p in topPts.reversed() {
                gPath.addLine(to: CGPoint(x: p.x, y: p.y - depth + CGFloat.random(in: -2...2)))
            }
            gPath.closeSubpath()
            let strip = SKShapeNode(path: gPath)
            strip.fillColor = t.grass
            strip.strokeColor = .clear
            container.addChild(strip)

            if t.grassStyle == .grass {
                for p in topPts.dropFirst().dropLast() where Bool.random() {
                    let tuft = CGMutablePath()
                    tuft.move(to: CGPoint(x: p.x - 4, y: p.y))
                    tuft.addLine(to: CGPoint(x: p.x - 1, y: p.y + CGFloat.random(in: 5...9)))
                    tuft.addLine(to: CGPoint(x: p.x + 2, y: p.y))
                    tuft.closeSubpath()
                    let blade = SKShapeNode(path: tuft)
                    blade.fillColor = t.grass
                    blade.strokeColor = .clear
                    container.addChild(blade)
                }
            }
        }

        // Stalactites / icicles under cave roofs.
        if hangDeco {
            var dx = rect.minX + 36
            while dx < rect.maxX - 24 {
                let len = CGFloat.random(in: 16...46)
                let spike = CGMutablePath()
                spike.move(to: CGPoint(x: dx - 7, y: rect.minY + 2))
                spike.addLine(to: CGPoint(x: dx, y: rect.minY - len))
                spike.addLine(to: CGPoint(x: dx + 7, y: rect.minY + 2))
                spike.closeSubpath()
                let node = SKShapeNode(path: spike)
                node.fillColor = t.rockEdge
                node.strokeColor = .clear
                container.addChild(node)
                dx += CGFloat.random(in: 50...110)
            }
        }
        return container
    }

    /// Decorative buildings: bunker / watchtower / pitched-roof house.
    private func addStructure(_ s: Structure) {
        let t = map.theme
        let wallColor = SKColor(red: 0.32, green: 0.31, blue: 0.30, alpha: 1)
        let roofColor = t.rockEdge
        let amber = SKColor(red: 1.0, green: 0.76, blue: 0.35, alpha: 1)
        let node = SKNode()

        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                 _ color: SKColor, _ radius: CGFloat = 3) {
            let r = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: radius)
            r.fillColor = color
            r.strokeColor = t.rockEdge
            r.lineWidth = 1.5
            r.position = CGPoint(x: x, y: y)
            node.addChild(r)
        }
        func glowWindow(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 14, _ h: CGFloat = 12) {
            let win = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            win.fillColor = amber; win.strokeColor = .clear; win.glowWidth = 2
            win.position = CGPoint(x: x, y: y)
            node.addChild(win)
        }

        switch s.kind {
        case .bunker:
            box(0, 30, 128, 60, wallColor, 5)
            box(0, 64, 144, 13, roofColor, 4)              // roof slab
            box(-46, 12, 22, 13, t.rockDark, 6)            // sandbags
            box(46, 12, 22, 13, t.rockDark, 6)
            box(0, 22, 24, 36, t.rockEdge, 3)              // door
            glowWindow(-34, 38); glowWindow(34, 38)
        case .tower:
            box(0, 80, 70, 160, wallColor, 4)
            for mx in [-24, 0, 24] { box(CGFloat(mx), 168, 18, 16, wallColor, 2) }  // crenellations
            box(0, 156, 78, 9, roofColor, 3)
            glowWindow(0, 120, 10, 18); glowWindow(0, 76, 10, 18)
            let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 28))
            pole.fillColor = t.rockEdge; pole.strokeColor = .clear
            pole.position = CGPoint(x: 0, y: 192)
            node.addChild(pole)
            let flag = CGMutablePath()
            flag.move(to: CGPoint(x: 2, y: 204))
            flag.addLine(to: CGPoint(x: 22, y: 198))
            flag.addLine(to: CGPoint(x: 2, y: 192))
            flag.closeSubpath()
            let banner = SKShapeNode(path: flag)
            banner.fillColor = SKColor(red: 0.85, green: 0.3, blue: 0.25, alpha: 1)
            banner.strokeColor = .clear
            node.addChild(banner)
        case .house:
            box(0, 32, 116, 64, wallColor, 4)
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: -68, y: 60))
            roof.addLine(to: CGPoint(x: 0, y: 98))
            roof.addLine(to: CGPoint(x: 68, y: 60))
            roof.closeSubpath()
            let r = SKShapeNode(path: roof)
            r.fillColor = roofColor; r.strokeColor = t.rockEdge; r.lineWidth = 1.5
            node.addChild(r)
            box(30, 96, 14, 26, wallColor, 2)               // chimney
            box(-26, 24, 22, 38, t.rockEdge, 3)             // door
            glowWindow(22, 36)
        }

        node.position = CGPoint(x: s.x, y: s.floorY)
        if let view = self.view {
            let frame = node.calculateAccumulatedFrame()
            if let tex = view.texture(from: node) {
                let sprite = SKSpriteNode(texture: tex)
                sprite.position = CGPoint(x: frame.midX, y: frame.midY)
                sprite.zPosition = -6
                addChild(sprite)
                return
            }
        }
        node.zPosition = -6
        addChild(node)
    }

    private func staticBody(of size: CGSize) -> SKPhysicsBody {
        let b = SKPhysicsBody(rectangleOf: size)
        b.isDynamic = false
        b.friction = map.theme.slippery ? 0.02 : 0.4
        b.restitution = 0
        b.categoryBitMask = PhysicsCategory.ground
        return b
    }

    private func setupWeather() {
        if case .none = map.theme.weather { return }
        let e = SKEmitterNode()
        e.particleTexture = Art.softCircle
        e.zPosition = -500
        e.particleColorBlendFactor = 1
        switch map.theme.weather {
        case .embers:
            e.position = CGPoint(x: 0, y: -size.height / 2 - 10)
            e.particlePositionRange = CGVector(dx: size.width * 1.2, dy: 10)
            e.emissionAngle = .pi / 2
            e.particleBirthRate = 12
            e.particleLifetime = 7
            e.particleSpeed = 32; e.particleSpeedRange = 18
            e.particleScale = 0.08; e.particleScaleRange = 0.05
            e.particleAlpha = 0.5; e.particleAlphaSpeed = -0.07
            e.particleColor = SKColor(red: 1, green: 0.7, blue: 0.4, alpha: 1)
            e.particleBlendMode = .add
        case .leaves:
            e.position = CGPoint(x: 0, y: size.height / 2 + 10)
            e.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 10)
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.5
            e.particleBirthRate = 9
            e.particleLifetime = 9
            e.particleSpeed = 46; e.particleSpeedRange = 22
            e.particleScale = 0.12; e.particleScaleRange = 0.05
            e.particleAlpha = 0.75
            e.particleRotationRange = .pi
            e.particleRotationSpeed = 1.2
            e.particleColor = SKColor(red: 0.55, green: 0.78, blue: 0.30, alpha: 1)
        case .snow:
            e.position = CGPoint(x: 0, y: size.height / 2 + 10)
            e.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 10)
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.35
            e.particleBirthRate = 34
            e.particleLifetime = 10
            e.particleSpeed = 52; e.particleSpeedRange = 26
            e.particleScale = 0.09; e.particleScaleRange = 0.05
            e.particleAlpha = 0.8
            e.particleColor = .white
        case .none:
            break
        }
        cam.addChild(e)
    }

    private func setupActors() {
        player = Robot(team: .player, skin: localSkin)
        player.setName(settings?.resolvedName ?? "You")
        player.setOverlayScale(zoom * 0.85)
        player.position = localSpawn()
        addChild(player)
        player.flame.targetNode = self
        // Start with the camera already on the player (no opening pan).
        let halfW = size.width / 2 * zoom
        cam.position = CGPoint(x: max(halfW, min(levelWidth - halfW, player.position.x)),
                               y: camRestY)

        if !isMultiplayer {
            queueWave(initialDelay: 0.8)             // first opponents teleport in shortly
        }
    }

    private func setupControls() {
        for stick in [moveStick, aimStick] {
            stick.zPosition = 600
            stick.isHidden = true
            cam.addChild(stick)
        }
    }

    private func setupCTF() {
        let yA = map.groundTop(at: 350) ?? groundTopY
        let yB = map.groundTop(at: levelWidth - 350) ?? groundTopY
        basePos = [CGPoint(x: 350, y: yA), CGPoint(x: levelWidth - 350, y: yB)]
        for t in 0...1 {
            let shades = PlayerColors.shades(t == 0 ? 0 : 1)
            let flag = FlagNode(teamColor: shades.main)
            flag.position = basePos[t]
            addChild(flag)
            flagNodes.append(flag)

            // Base pad marker
            let pad = SKShapeNode(rectOf: CGSize(width: 130, height: 8), cornerRadius: 4)
            pad.fillColor = shades.main.withAlphaComponent(0.55)
            pad.strokeColor = .clear
            pad.position = CGPoint(x: basePos[t].x, y: basePos[t].y + 2)
            pad.zPosition = 5
            addChild(pad)
        }
    }

    // MARK: Pickups

    private func pickupContent(spot: Int) -> PickupKind {
        let cycle = pickupCycles[spot] ?? 0
        return pickupPattern[(spot + cycle) % pickupPattern.count]
    }

    private func spawnAllPickups() {
        for i in 0..<map.pickupSpots.count { spawnPickup(spot: i) }
    }

    private func spawnPickup(spot: Int) {
        guard pickups[spot] == nil, spot < map.pickupSpots.count else { return }
        let node = PickupNode(kind: pickupContent(spot: spot), spot: spot)
        node.position = map.pickupSpots[spot]
        addChild(node)
        pickups[spot] = node
    }

    private func removeAndRespawnPickup(spot: Int) {
        pickups[spot]?.removeFromParent()
        pickups[spot] = nil
        pickupCycles[spot] = (pickupCycles[spot] ?? 0) + 1
        run(.sequence([.wait(forDuration: 15), .run { [weak self] in
            self?.spawnPickup(spot: spot)
        }]))
    }

    private func checkPickupGrabs() {
        guard !player.isDead, !matchOver else { return }
        for (spot, node) in pickups {
            let dx = node.position.x - player.position.x
            let dy = node.position.y - (player.position.y + 24)
            if dx * dx + dy * dy < 52 * 52 {
                switch node.kind {
                case .health:
                    player.heal(40)
                case .weapon(let w):
                    currentWeapon = w
                    ammo = w.startAmmo ?? 0
                    player.setWeapon(w)
                case .nades:
                    grenades = min(grenades + 2, 6)
                }
                updateWeaponHUD()
                AudioManager.shared.play(.pickup)
                net?.send(.pickup(PickupEvent(spot: spot)), reliable: true)
                removeAndRespawnPickup(spot: spot)
                break
            }
        }
    }

    // MARK: HUD

    private func setupHUD() {
        let left = -size.width / 2 + 24
        let top = size.height / 2 - 22

        addHUDLabel("JET FUEL", at: CGPoint(x: left, y: top))
        let fuelBar = makeBar(width: 170, color: SKColor(red: 0.96, green: 0.62, blue: 0.10, alpha: 1),
                              at: CGPoint(x: left, y: top - 18))
        fuelFill = fuelBar.fill
        cam.addChild(fuelBar.bg); cam.addChild(fuelBar.fill)

        addHUDLabel("HEALTH", at: CGPoint(x: left, y: top - 44))
        let hpBar = makeBar(width: 170, color: SKColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1),
                            at: CGPoint(x: left, y: top - 62))
        healthFill = hpBar.fill
        cam.addChild(hpBar.bg); cam.addChild(hpBar.fill)

        weaponLabel = SKLabelNode(text: "")
        weaponLabel.fontName = "AvenirNext-Bold"; weaponLabel.fontSize = 14
        weaponLabel.fontColor = SKColor(red: 0.96, green: 0.78, blue: 0.30, alpha: 1)
        weaponLabel.horizontalAlignmentMode = .left
        weaponLabel.verticalAlignmentMode = .top
        weaponLabel.position = CGPoint(x: left, y: top - 88)
        weaponLabel.zPosition = 600
        cam.addChild(weaponLabel)
        updateWeaponHUD()

        timerLabel = SKLabelNode(text: "5:00")
        timerLabel.fontName = "AvenirNext-Heavy"; timerLabel.fontSize = 24
        timerLabel.fontColor = .white
        timerLabel.verticalAlignmentMode = .top
        timerLabel.position = CGPoint(x: 0, y: top + 6)
        timerLabel.zPosition = 600
        cam.addChild(timerLabel)

        // Score + map tag sit under the timer (top-center) so the top-right
        // corner stays clear for the pause button.
        infoLabel = SKLabelNode(text: "")
        infoLabel.fontName = "AvenirNext-Bold"; infoLabel.fontSize = 17
        infoLabel.fontColor = .white
        infoLabel.horizontalAlignmentMode = .center
        infoLabel.verticalAlignmentMode = .top
        infoLabel.position = CGPoint(x: 0, y: top - 24)
        infoLabel.zPosition = 600
        cam.addChild(infoLabel)

        let tagText = isMultiplayer ? map.name.uppercased()
                                    : "\(map.name.uppercased())  •  \(bot.name.uppercased()) BOT"
        let mapTag = SKLabelNode(text: tagText)
        mapTag.fontName = "AvenirNext-Bold"; mapTag.fontSize = 11
        mapTag.fontColor = SKColor.white.withAlphaComponent(0.5)
        mapTag.horizontalAlignmentMode = .center
        mapTag.verticalAlignmentMode = .top
        mapTag.position = CGPoint(x: 0, y: top - 44)
        mapTag.zPosition = 600
        cam.addChild(mapTag)
    }

    private func updateWeaponHUD() {
        let ammoText = (unlimitedAmmo || currentWeapon.startAmmo == nil) ? "∞" : "\(ammo)"
        let nadeText = unlimitedAmmo ? "∞" : "\(grenades)"
        weaponLabel.text = "\(currentWeapon.displayName)  \(ammoText)   •   NADES \(nadeText)"
    }

    private func addHUDLabel(_ text: String, at p: CGPoint) {
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Bold"; l.fontSize = 12
        l.fontColor = SKColor.white.withAlphaComponent(0.65)
        l.horizontalAlignmentMode = .left; l.verticalAlignmentMode = .top
        l.position = p; l.zPosition = 600
        cam.addChild(l)
    }

    private func makeBar(width: CGFloat, color: SKColor, at p: CGPoint) -> (bg: SKSpriteNode, fill: SKSpriteNode) {
        let h: CGFloat = 12
        let bg = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.18), size: CGSize(width: width, height: h))
        bg.anchorPoint = CGPoint(x: 0, y: 1); bg.position = p; bg.zPosition = 600
        let fill = SKSpriteNode(color: color, size: CGSize(width: width, height: h))
        fill.anchorPoint = CGPoint(x: 0, y: 1); fill.position = p; fill.zPosition = 601
        return (bg, fill)
    }

    /// Re-apply live-changeable settings — called when the pause menu closes.
    func applySettings() {
        AudioManager.shared.soundEnabled = settings?.soundOn ?? true
        leftHanded = settings?.leftHanded ?? false
        nadeButton.position = nadeButtonPosition()

        let z = CGFloat(settings?.zoom ?? 2.0)
        if abs(z - zoom) > 0.001 {
            zoom = z
            cam.setScale(zoom)
            camRestY = size.height * zoom / 2 - 24
            cam.position = CGPoint(x: cam.position.x, y: camRestY)
            player.setOverlayScale(zoom * 0.85)
            for r in remotePlayers.values { r.setOverlayScale(zoom * 0.85) }
            for b in bots { b.robot.setOverlayScale(zoom * 0.85) }
        }
    }

    private func nadeButtonPosition() -> CGPoint {
        let side: CGFloat = leftHanded ? -1 : 1
        return CGPoint(x: side * (size.width / 2 - 74), y: -size.height / 2 + 204)
    }

    private func setupNadeButton() {
        nadeButton.position = nadeButtonPosition()
        nadeButton.zPosition = 620

        let ring = SKShapeNode(circleOfRadius: 31)
        ring.fillColor = SKColor.black.withAlphaComponent(0.35)
        ring.strokeColor = SKColor.white.withAlphaComponent(0.45)
        ring.lineWidth = 1.5
        nadeButton.addChild(ring)

        let shell = SKShapeNode(circleOfRadius: 10)
        shell.fillColor = SKColor(red: 0.30, green: 0.44, blue: 0.24, alpha: 1)
        shell.strokeColor = SKColor(red: 0.16, green: 0.24, blue: 0.12, alpha: 1)
        shell.lineWidth = 1.5
        shell.position = CGPoint(x: 0, y: -2)
        nadeButton.addChild(shell)
        let lever = SKShapeNode(rectOf: CGSize(width: 6, height: 7), cornerRadius: 1.5)
        lever.fillColor = SKColor(white: 0.78, alpha: 1); lever.strokeColor = .clear
        lever.position = CGPoint(x: 5, y: 9)
        nadeButton.addChild(lever)

        cam.addChild(nadeButton)

        // Trajectory preview dots (world space).
        nadePreview.zPosition = 95
        nadePreview.isHidden = true
        for i in 0..<16 {
            let dot = SKSpriteNode(texture: Art.softCircle,
                                   size: CGSize(width: i == 15 ? 22 : 11, height: i == 15 ? 22 : 11))
            dot.color = SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
            dot.colorBlendFactor = 1
            dot.blendMode = .add
            nadeDots.append(dot)
            nadePreview.addChild(dot)
        }
        addChild(nadePreview)
    }

    /// Simulates the grenade arc (same gravity/damping as the real one) and
    /// lays the dotted line along it, ending where it would land.
    private func updateNadePreview() {
        guard nadeTouch != nil,
              hypot(nadeAimVec.dx, nadeAimVec.dy) > 18,
              !player.isDead else {
            nadePreview.isHidden = true
            return
        }
        nadePreview.isHidden = false
        let (angle, power) = nadeAim()
        var pos = nadeStartPoint(for: angle)
        var v = CGVector(dx: cos(angle) * power, dy: sin(angle) * power + 230)
        let dt: CGFloat = 0.055
        let g = nadeGravity        // exact match with the grenade's manual gravity
        var landed = false
        for (i, dot) in nadeDots.enumerated() {
            if landed { dot.isHidden = true; continue }
            for _ in 0..<2 {
                v.dy += g * dt
                v.dx *= (1 - 0.25 * dt)
                v.dy *= (1 - 0.25 * dt)
                pos.x += v.dx * dt
                pos.y += v.dy * dt
            }
            if let top = map.groundTop(at: pos.x), pos.y <= top + 6 {
                pos.y = top + 6
                landed = true
            } else if pos.y < -80 {
                landed = true
            }
            dot.isHidden = false
            dot.position = pos
            dot.alpha = landed ? 1.0 : max(0.25, 0.95 - CGFloat(i) * 0.045)
            if landed && i < nadeDots.count - 1 {
                // Move the big landing marker here and hide the rest.
                let marker = nadeDots[nadeDots.count - 1]
                marker.isHidden = false
                marker.position = pos
                marker.alpha = 1
                for j in (i + 1)..<(nadeDots.count - 1) { nadeDots[j].isHidden = true }
                return
            }
        }
    }

    private func nadeAim() -> (angle: CGFloat, power: CGFloat) {
        let len = hypot(nadeAimVec.dx, nadeAimVec.dy)
        let angle = atan2(nadeAimVec.dy, nadeAimVec.dx)
        let t = min(1, max(0, (len - 18) / 110))
        return (angle, 360 + t * 400)               // drag farther = throw farther
    }

    private func nadeStartPoint(for angle: CGFloat) -> CGPoint {
        CGPoint(x: player.position.x + (cos(angle) >= 0 ? 16 : -16),
                y: player.position.y + 46)
    }

    private func showHint() {
        var text = leftHanded ? "Right = move / jetpack   •   Left = aim & shoot"
                              : "Left = move / jetpack   •   Right = aim & shoot"
        if mode == 2 { text = "Steal the enemy flag ⚑ and bring it home!   •   " + text }
        let h = SKLabelNode(text: text)
        h.fontName = "AvenirNext-Medium"; h.fontSize = 15
        h.fontColor = SKColor.white.withAlphaComponent(0.6)
        h.verticalAlignmentMode = .bottom
        h.position = CGPoint(x: 0, y: -size.height / 2 + 22)
        h.zPosition = 600
        cam.addChild(h)
        h.run(.sequence([.wait(forDuration: 9), .fadeOut(withDuration: 1.2), .removeFromParent()]))
    }

    // MARK: Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : CGFloat(min(currentTime - lastTime, 1.0 / 30))
        lastTime = currentTime

        updatePlayer(dt: dt)
        if isMultiplayer {
            updateRemotes(dt: dt)
            broadcastState(dt: dt)
        } else {
            updateBots(dt: dt)
        }
        checkPickupGrabs()
        for g in liveGrenades { g.physicsBody?.velocity.dy += nadeGravity * dt }
        updateNadePreview()
        if mode == 2 { updateCTF() }
        updateCamera()
        hillsLayer.position.x = 0.5 * cam.position.x
        cloudsLayer.position.x = 0.62 * cam.position.x

        fuelFill.xScale = max(0.001, fuel / maxFuel)
        healthFill.xScale = max(0.001, player.health / player.maxHealth)
        updateScoreHUD()
        updateTimer(dt: dt)
        checkWin()
    }

    private func updateScoreHUD() {
        switch mode {
        case 1: infoLabel.text = "A \(teamKills(0)) — \(teamKills(1)) B"
        case 2: infoLabel.text = "⚑ A \(teamCaptures(0)) — \(teamCaptures(1)) B"
        default: infoLabel.text = isMultiplayer ? "Kills \(kills) / \(target)" : "Kills \(kills)"
        }
    }

    private func updateTimer(dt: CGFloat) {
        guard !matchOver else { return }
        timeRemaining = max(0, timeRemaining - dt)
        let m = Int(timeRemaining) / 60
        let s = Int(timeRemaining) % 60
        timerLabel.text = String(format: "%d:%02d", m, s)
        timerLabel.fontColor = timeRemaining < 31 ? SKColor(red: 1, green: 0.4, blue: 0.35, alpha: 1) : .white
    }

    private func updatePlayer(dt: CGFloat) {
        guard let body = player.physicsBody else { return }
        if matchOver || player.isDead {
            player.setThrusting(false)
            setJetSound(false)
            return
        }

        let move = moveStick.vector
        var v = body.velocity
        if map.theme.slippery {
            v.dx = lerp(v.dx, move.dx * moveSpeed, 0.07)   // ice: slide into speed
        } else {
            v.dx = move.dx * moveSpeed
        }
        let up = move.dy
        let wantThrust = up > 0.15 && fuel > 0
        if wantThrust {
            v.dy = thrustVelocity * max(0.7, up)
            fuel = max(0, fuel - 40 * dt)
        } else {
            fuel = min(maxFuel, fuel + 26 * dt)
        }
        body.velocity = v
        player.setThrusting(wantThrust)
        setJetSound(wantThrust)

        let aim = aimStick.vector
        if aim.dx * aim.dx + aim.dy * aim.dy > 0.09 {
            let angle = atan2(aim.dy, aim.dx)
            player.aim(angle: angle)
            fireCooldown -= dt
            if fireCooldown <= 0 {
                fireLocal(angle: angle)
                fireCooldown = currentWeapon.fireInterval
            }
        } else {
            if move.dx > 0.1 { player.aim(angle: 0) }
            else if move.dx < -0.1 { player.aim(angle: .pi) }
            fireCooldown = 0
        }

        player.animate(dt: dt, grounded: abs(v.dy) < 28, horizontalSpeed: v.dx)
        clampInsideLevel(player)
    }

    private func setJetSound(_ on: Bool) {
        if on != jetSoundOn {
            jetSoundOn = on
            AudioManager.shared.setJetpack(on)
        }
    }

    // MARK: Firing

    private func playFireSound(_ w: WeaponType, volume: Float = 1) {
        switch w {
        case .rifle, .ak47: AudioManager.shared.play(.rifle, volume: volume)
        case .uzi, .mp5: AudioManager.shared.play(.uzi, volume: volume)
        case .shotgun: AudioManager.shared.play(.shotgun, volume: volume)
        case .sniper: AudioManager.shared.play(.sniper, volume: volume)
        case .magnum: AudioManager.shared.play(.sniper, volume: volume * 0.8)
        case .flamer:
            flameShotCount += 1
            if flameShotCount % 3 == 0 { AudioManager.shared.play(.flame, volume: volume) }
        case .rocket: AudioManager.shared.play(.rocket, volume: volume)
        }
    }

    private func fireLocal(angle: CGFloat) {
        let muzzle = player.muzzlePosition(in: self)
        switch currentWeapon.special {
        case .rocketLauncher:
            spawnRocket(at: muzzle, angle: angle, owner: localName)
        case .bullet, .flame:
            let isFlame = currentWeapon.special == .flame
            for _ in 0..<currentWeapon.pellets {
                let a = angle + CGFloat.random(in: -currentWeapon.spread...currentWeapon.spread)
                let bullet = Bullet(team: .player, color: myBulletColor,
                                    damage: currentWeapon.damage, visualOnly: isMultiplayer,
                                    flame: isFlame)
                bullet.ownerName = localName
                placeBullet(bullet, at: muzzle, angle: a, speed: currentWeapon.bulletSpeed,
                            lifetime: currentWeapon.bulletLifetime)
            }
            if !isFlame { spawnMuzzleFlash(at: muzzle, color: myBulletColor) }
        }
        playFireSound(currentWeapon)
        net?.send(.fire(FireEvent(x: muzzle.x, y: muzzle.y, angle: angle,
                                  weapon: currentWeapon.rawValue)))

        if !unlimitedAmmo && currentWeapon.startAmmo != nil {
            ammo -= 1
            if ammo <= 0 { currentWeapon = .rifle; ammo = 0; player.setWeapon(.rifle) }
            updateWeaponHUD()
        }
    }

    private func spawnIncomingFire(_ f: FireEvent, owner: String) {
        let w = WeaponType(rawValue: f.weapon) ?? .rifle
        let origin = CGPoint(x: f.x, y: f.y)
        switch w.special {
        case .rocketLauncher:
            spawnRocket(at: origin, angle: f.angle, owner: owner)
        case .bullet, .flame:
            let isFlame = w.special == .flame
            for _ in 0..<w.pellets {
                let a = f.angle + CGFloat.random(in: -w.spread...w.spread)
                let bullet = Bullet(team: .enemy, color: foeBulletColor, damage: w.damage,
                                    flame: isFlame)
                bullet.ownerName = owner
                placeBullet(bullet, at: origin, angle: a, speed: w.bulletSpeed,
                            lifetime: w.bulletLifetime)
            }
            if !isFlame { spawnMuzzleFlash(at: origin, color: foeBulletColor) }
        }
        playFireSound(w)
    }

    private func placeBullet(_ bullet: Bullet, at p: CGPoint, angle: CGFloat, speed: CGFloat,
                             lifetime: TimeInterval = 1.5) {
        bullet.position = p
        bullet.zRotation = angle
        bullet.zPosition = 40
        bullet.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        addChild(bullet)
        bullet.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]))
    }

    // MARK: Rockets & grenades

    private func spawnRocket(at p: CGPoint, angle: CGFloat, owner: String) {
        let rocket = Rocket(owner: owner, color: SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1))
        rocket.position = p
        rocket.zRotation = angle
        rocket.physicsBody?.velocity = CGVector(dx: cos(angle) * WeaponType.rocket.bulletSpeed,
                                                dy: sin(angle) * WeaponType.rocket.bulletSpeed)
        addChild(rocket)
        rocket.run(.sequence([.wait(forDuration: 0.1), .run { [weak rocket] in rocket?.armed = true }]))
        // Smoke trail.
        let trail = SKEmitterNode()
        trail.particleTexture = Art.softCircle
        trail.particleBirthRate = 90
        trail.particleLifetime = 0.5
        trail.particleSpeed = 30
        trail.particleAlpha = 0.5; trail.particleAlphaSpeed = -1
        trail.particleScale = 0.22; trail.particleScaleSpeed = -0.25
        trail.particleColor = SKColor(white: 0.8, alpha: 1)
        trail.particleColorBlendFactor = 1
        trail.position = CGPoint(x: -16, y: 0)
        trail.targetNode = self
        rocket.addChild(trail)
        rocket.run(.sequence([.wait(forDuration: 4), .removeFromParent()]))
        spawnMuzzleFlash(at: p, color: SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1))
    }

    private func explodeRocket(_ rocket: Rocket) {
        let p = rocket.position
        rocket.removeFromParent()
        spawnExplosion(at: p)
        shake(8)
        areaDamage(at: p, radius: rocket.blastRadius, damage: rocket.damage, owner: rocket.ownerName)
    }

    private func throwGrenade(angle: CGFloat, power: CGFloat) {
        guard !player.isDead, !matchOver, grenades > 0 || unlimitedAmmo else { return }
        if !unlimitedAmmo { grenades -= 1 }
        updateWeaponHUD()
        let start = nadeStartPoint(for: angle)
        let v = CGVector(dx: cos(angle) * power, dy: sin(angle) * power + 230)
        spawnGrenade(at: start, velocity: v, owner: localName)
        AudioManager.shared.play(.nadeThrow)
        net?.send(.nade(NadeEvent(x: start.x, y: start.y, vx: v.dx, vy: v.dy)))
    }

    private func spawnGrenade(at p: CGPoint, velocity: CGVector, owner: String) {
        let nade = Grenade(owner: owner)
        nade.position = p
        addChild(nade)
        nade.physicsBody?.affectedByGravity = false   // gravity applied manually (matches the aim preview)
        liveGrenades.append(nade)
        nade.physicsBody?.velocity = velocity
        nade.physicsBody?.angularVelocity = -6
        run(.sequence([.wait(forDuration: 2.2), .run { [weak self, weak nade] in
            guard let self, let nade, nade.parent != nil else { return }
            let bp = nade.position
            self.liveGrenades.removeAll { $0 === nade }
            nade.removeFromParent()
            self.spawnExplosion(at: bp)
            self.shake(9)
            self.areaDamage(at: bp, radius: nade.blastRadius, damage: nade.damage, owner: owner)
        }]))
    }

    /// Splash damage: hurts the LOCAL player (victim-authoritative in MP)
    /// and, in practice, any bots in range. Self-damage applies.
    private func areaDamage(at p: CGPoint, radius: CGFloat, damage: CGFloat, owner: String) {
        if !player.isDead && !matchOver {
            let d = hypot(player.position.x - p.x, player.position.y + 22 - p.y)
            if d < radius {
                let friendly = isMultiplayer && mode >= 1 && localTeam >= 0
                    && owner != localName && teamOf(owner) == localTeam
                if !friendly {
                    let amount = damage * max(0.45, 1 - d / radius)
                    AudioManager.shared.play(.hit)
                    let died = player.takeDamage(amount)
                    shake(died ? 12 : 7)
                    if died {
                        spawnExplosion(at: player.position)
                        dropFlagOnDeath()
                        respawnPlayerSoon()
                    }
                    net?.send(.hit(HitEvent(x: p.x, y: p.y, health: player.health,
                                            dead: died, killedBy: died ? owner : nil)))
                }
            }
        }
        if !isMultiplayer {
            for agent in bots {
                let robot = agent.robot
                guard !robot.isDead else { continue }
                let d = hypot(robot.position.x - p.x, robot.position.y + 22 - p.y)
                if d < radius {
                    let died = robot.takeDamage(damage * max(0.45, 1 - d / radius))
                    if died {
                        spawnExplosion(at: robot.position)
                        if owner == localName { kills += 1 }
                        removeBot(robot)
                    }
                }
            }
        }
    }

    // MARK: Multiplayer

    private func teamOf(_ name: String) -> Int {
        if name == localName { return localTeam }
        return assignments[name] ?? peerTeams[name] ?? -1
    }

    private func teamKills(_ t: Int) -> Int {
        var total = (localTeam == t) ? kills : 0
        for (n, k) in peerKills where teamOf(n) == t { total += k }
        return total
    }

    private func teamCaptures(_ t: Int) -> Int {
        var total = (localTeam == t) ? myCaptures : 0
        for (n, c) in peerCaptures where teamOf(n) == t { total += c }
        return total
    }

    private func broadcastState(dt: CGFloat) {
        netTimer -= dt
        if netTimer > 0 { return }
        netTimer = netSendInterval
        guard let body = player.physicsBody else { return }
        let s = PlayerState(x: player.position.x, y: player.position.y,
                            vx: body.velocity.dx, vy: body.velocity.dy,
                            aim: player.aimAngle, thrusting: player.isThrusting,
                            health: player.health, dead: player.isDead,
                            name: settings?.resolvedName ?? "Player",
                            team: localTeam, skin: localSkin,
                            weapon: currentWeapon.rawValue,
                            kills: kills, captures: myCaptures, carryingFlag: myCarrying)
        net?.send(.state(s))
    }

    private func updateRemotes(dt: CGFloat) {
        for (name, robot) in remotePlayers {
            guard let t = remoteTargets[name] else { continue }
            robot.position = CGPoint(x: lerp(robot.position.x, t.x, 0.25),
                                     y: lerp(robot.position.y, t.y, 0.25))
            robot.aim(angle: t.aim)
            robot.setThrusting(t.thrusting)
            robot.setWeapon(WeaponType(rawValue: t.weapon) ?? .rifle)
            robot.applyNetwork(health: t.health, dead: t.dead)
            robot.animate(dt: dt, grounded: abs(t.vy) < 28, horizontalSpeed: t.vx)
            // Self-heal flag carry state from snapshots in case an event was missed.
            if mode == 2 && t.carryingFlag >= 0 && t.carryingFlag <= 1 {
                flagStatus[t.carryingFlag] = .carried(name)
            }
        }
    }

    private func handle(_ message: GameMessage, from peer: Peer) {
        switch message {
        case .state(let s):
            let name = peer.displayName
            if remotePlayers[name] == nil {
                let r = Robot(team: .enemy, skin: s.skin)
                r.physicsBody = nil
                r.position = CGPoint(x: s.x, y: s.y)
                r.setName(s.name)
                r.setOverlayScale(zoom * 0.85)
                r.flame.targetNode = self
                addChild(r)
                remotePlayers[name] = r
            }
            remoteTargets[name] = s
            peerKills[name] = s.kills
            peerCaptures[name] = s.captures
            peerTeams[name] = s.team
        case .fire(let f):
            spawnIncomingFire(f, owner: peer.displayName)
        case .nade(let n):
            spawnGrenade(at: CGPoint(x: n.x, y: n.y),
                         velocity: CGVector(dx: n.vx, dy: n.vy),
                         owner: peer.displayName)
            AudioManager.shared.play(.nadeThrow, volume: 0.6)
        case .hit(let h):
            spawnSpark(at: CGPoint(x: h.x, y: h.y), color: .orange)
            AudioManager.shared.play(.hit, volume: 0.6)
            if let r = remotePlayers[peer.displayName] {
                r.flashHit()
                r.applyNetwork(health: h.health, dead: h.dead)
                if h.dead { spawnExplosion(at: r.position) }
            }
            if let killer = h.killedBy, killer == localName {
                kills += 1
                shake(6)
            }
        case .pickup(let p):
            removeAndRespawnPickup(spot: p.spot)
        case .flag(let f):
            applyFlagEvent(f, from: peer.displayName)
        case .hello, .startGame:
            break
        }
    }

    private func removeRemote(_ name: String) {
        // If they were carrying a flag, send it home.
        for t in 0...1 {
            if case .carried(let by) = flagStatus[t], by == name { flagStatus[t] = .home }
        }
        remotePlayers[name]?.removeFromParent()
        remotePlayers[name] = nil
        remoteTargets[name] = nil
        peerKills[name] = nil
        peerCaptures[name] = nil
        peerTeams[name] = nil
    }

    // MARK: CTF

    private func applyFlagEvent(_ f: FlagEvent, from name: String) {
        guard mode == 2, f.team >= 0, f.team <= 1 else { return }
        switch f.kind {
        case 0: flagStatus[f.team] = .carried(name)
        case 1: flagStatus[f.team] = .dropped(CGPoint(x: f.x, y: f.y))
        case 2: flagStatus[f.team] = .home
        case 3:
            flagStatus[f.team] = .home
            AudioManager.shared.play(.capture)
        default: break
        }
    }

    private func updateCTF() {
        // Move flag nodes to where their state says they are.
        for t in 0...1 {
            switch flagStatus[t] {
            case .home:
                flagNodes[t].position = basePos[t]
            case .dropped(let p):
                flagNodes[t].position = p
            case .carried(let by):
                if by == localName {
                    flagNodes[t].position = CGPoint(x: player.position.x, y: player.position.y + 78)
                } else if let r = remotePlayers[by] {
                    flagNodes[t].position = CGPoint(x: r.position.x, y: r.position.y + 78)
                }
            }
        }

        guard !player.isDead, !matchOver, localTeam >= 0 else { return }
        let enemyTeam = 1 - localTeam

        if myCarrying == -1 {
            // Try to take the enemy flag…
            var canTake = false
            switch flagStatus[enemyTeam] {
            case .home: canTake = near(basePos[enemyTeam], 64)
            case .dropped(let p): canTake = near(p, 64)
            case .carried: canTake = false
            }
            if canTake {
                flagStatus[enemyTeam] = .carried(localName)
                myCarrying = enemyTeam
                AudioManager.shared.play(.pickup)
                net?.send(.flag(FlagEvent(kind: 0, team: enemyTeam, x: 0, y: 0)), reliable: true)
            }
            // …or return my own dropped flag.
            if case .dropped(let p) = flagStatus[localTeam], near(p, 64) {
                flagStatus[localTeam] = .home
                AudioManager.shared.play(.pickup)
                net?.send(.flag(FlagEvent(kind: 2, team: localTeam, x: 0, y: 0)), reliable: true)
            }
        } else if near(basePos[localTeam], 70) {
            // Capture! (only if my own flag is safely home)
            if case .home = flagStatus[localTeam] {
                flagStatus[myCarrying] = .home
                net?.send(.flag(FlagEvent(kind: 3, team: myCarrying, x: 0, y: 0)), reliable: true)
                myCarrying = -1
                myCaptures += 1
                AudioManager.shared.play(.capture)
                shake(7)
            }
        }
    }

    private func near(_ p: CGPoint, _ dist: CGFloat) -> Bool {
        let dx = p.x - player.position.x
        let dy = p.y - player.position.y
        return dx * dx + dy * dy < dist * dist
    }

    private func dropFlagOnDeath() {
        guard mode == 2, myCarrying >= 0 else { return }
        let p = CGPoint(x: player.position.x, y: max(groundTopY, player.position.y))
        flagStatus[myCarrying] = .dropped(p)
        net?.send(.flag(FlagEvent(kind: 1, team: myCarrying, x: p.x, y: p.y)), reliable: true)
        myCarrying = -1
    }

    // MARK: Practice bot

    /// Spawner + AI for every live bot. Bots arrive in random-size waves
    /// (sometimes 1, sometimes 2-3, occasionally 4-5) with staggered entries,
    /// plus an occasional lone reinforcement while a fight is on.
    private func updateBots(dt: CGFloat) {
        guard !matchOver else { return }

        // Tick queued arrivals.
        var i = 0
        while i < pendingSpawns.count {
            pendingSpawns[i] -= dt
            if pendingSpawns[i] <= 0 {
                pendingSpawns.remove(at: i)
                spawnBot()
            } else {
                i += 1
            }
        }

        // Field empty → roll the next wave. Mid-fight → occasional reinforcement.
        if bots.isEmpty && pendingSpawns.isEmpty {
            queueWave(initialDelay: CGFloat.random(in: 1.0...2.2))
        } else if !bots.isEmpty {
            reinforceTimer -= dt
            if reinforceTimer <= 0 {
                reinforceTimer = CGFloat.random(in: 7...13)
                if bots.count + pendingSpawns.count < bot.maxAlive && Bool.random() {
                    pendingSpawns.append(CGFloat.random(in: 0.2...1.0))
                }
            }
        }

        for agent in bots { runBotAI(agent, dt: dt) }
    }

    private func queueWave(initialDelay: CGFloat) {
        let roll = Int.random(in: 1...100)
        var size = roll <= 30 ? 1 : roll <= 60 ? 2 : roll <= 80 ? 3 : roll <= 92 ? 4 : 5
        size = min(size, bot.maxAlive - bots.count - pendingSpawns.count)
        guard size > 0 else { return }
        var delay = initialDelay
        for _ in 0..<size {
            pendingSpawns.append(delay)
            delay += CGFloat.random(in: 0.5...1.3)
        }
        if size >= 2 { showIncoming(size) }
    }

    private func spawnBot() {
        guard bots.count < bot.maxAlive else { return }
        if botNameBag.isEmpty { botNameBag = Self.botNames.shuffled() }
        let name = botNameBag.removeFirst()

        // Bots wear random looks — palette colors or army uniforms (not the player's).
        var pool = (0..<PlayerColors.all.count).map { PlayerColors.skin($0) }
            + ArmySkins.all.map { $0.skin }
        pool.removeAll { $0 == localSkin }
        let robot = Robot(team: .enemy, skin: pool.randomElement() ?? PlayerColors.skin(1))
        robot.setName(name)
        robot.setOverlayScale(zoom * 0.85)

        // Teleport in somewhere off the player's screen when possible.
        let offscreen = size.width * zoom / 2 + 80
        let far = map.ffaSpawns.filter { abs($0.x - player.position.x) > offscreen }
        robot.position = far.randomElement() ?? map.ffaSpawns.randomElement()
            ?? CGPoint(x: levelWidth / 2, y: groundTopY + 90)
        addChild(robot)
        robot.flame.targetNode = self

        bots.append(BotAgent(robot: robot))
        spawnFlash(at: robot.position)
    }

    private func removeBot(_ robot: Robot) {
        bots.removeAll { $0.robot === robot }
        robot.run(.sequence([.wait(forDuration: 0.1), .removeFromParent()]))
    }

    private func spawnFlash(at p: CGPoint) {
        let flash = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 90, height: 90))
        flash.position = CGPoint(x: p.x, y: p.y + 26)
        flash.color = .white; flash.colorBlendFactor = 1; flash.blendMode = .add
        flash.zPosition = 60
        flash.setScale(0.2)
        addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.4, duration: 0.18), .fadeOut(withDuration: 0.25)]),
                             .removeFromParent()]))
    }

    private func showIncoming(_ n: Int) {
        let l = SKLabelNode(text: "+\(n) INCOMING!")
        l.fontName = "AvenirNext-Heavy"; l.fontSize = 18
        l.fontColor = SKColor(red: 1, green: 0.55, blue: 0.35, alpha: 1)
        l.verticalAlignmentMode = .top
        l.position = CGPoint(x: 0, y: size.height / 2 - 54)
        l.zPosition = 600
        l.alpha = 0
        cam.addChild(l)
        l.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 1.4),
                         .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    private func runBotAI(_ agent: BotAgent, dt: CGFloat) {
        let enemy = agent.robot
        guard !enemy.isDead, let body = enemy.physicsBody else { return }

        let dx = player.position.x - enemy.position.x
        let dy = player.position.y - enemy.position.y
        let dist = sqrt(dx * dx + dy * dy)

        agent.thinkTimer -= dt
        if agent.thinkTimer <= 0 {
            agent.thinkTimer = CGFloat.random(in: 0.4...0.9)
            if !player.isDead && CGFloat.random(in: 0...1) < bot.chaseBias {
                // Hunt the player, but hold a preferred fighting distance.
                if abs(dx) > bot.standoff + 60 {
                    agent.moveDir = dx > 0 ? 1 : -1
                } else if abs(dx) < bot.standoff - 60 {
                    agent.moveDir = dx > 0 ? -1 : 1
                } else {
                    agent.moveDir = [CGFloat(-1), 0, 1].randomElement()!
                }
            } else {
                agent.moveDir = [CGFloat(-1), 0, 1].randomElement()!
            }
            agent.wantsDodge = CGFloat.random(in: 0...1) < bot.dodgeProb
        }

        var v = body.velocity
        v.dx = agent.moveDir * bot.speed
        let wantThrust = (player.position.y > enemy.position.y + 40 && Bool.random())
            || agent.wantsDodge
            || enemy.position.y < (map.groundTop(at: enemy.position.x) ?? -60) + 30
        if wantThrust { v.dy = 300 }
        body.velocity = v
        enemy.setThrusting(wantThrust)

        // Aim — higher levels lead the target based on its velocity.
        let pv = player.physicsBody?.velocity ?? .zero
        let flight = dist / WeaponType.rifle.bulletSpeed
        let tx = dx + pv.dx * flight * bot.lead
        let ty = dy + pv.dy * flight * bot.lead
        let angle = atan2(ty, tx)
        enemy.aim(angle: angle)

        agent.fireTimer -= dt
        if agent.fireTimer <= 0 && !player.isDead && dist < bot.range {
            let a = angle + CGFloat.random(in: -bot.aimError...bot.aimError)
            let bullet = Bullet(team: .enemy, color: foeBulletColor, damage: WeaponType.rifle.damage)
            bullet.ownerName = enemy.name ?? "Bot"
            placeBullet(bullet, at: enemy.muzzlePosition(in: self), angle: a,
                        speed: WeaponType.rifle.bulletSpeed)
            spawnMuzzleFlash(at: enemy.muzzlePosition(in: self), color: foeBulletColor)
            playFireSound(.rifle, volume: Float(max(0.2, 1 - dist / 1600)))
            agent.fireTimer = CGFloat.random(in: bot.fireMin...bot.fireMax)
        }

        enemy.animate(dt: dt, grounded: abs(v.dy) < 28, horizontalSpeed: v.dx)
        clampInsideLevel(enemy)
    }

    // MARK: Camera & bounds

    private func updateCamera() {
        let halfW = size.width / 2 * zoom        // half of the zoomed-out viewport
        let targetX = player.isDead ? cam.position.x
                                    : max(halfW, min(levelWidth - halfW, player.position.x))
        let nx = lerp(cam.position.x, targetX, 0.12)
        let ny = lerp(cam.position.y, camRestY, 0.12)
        var sx: CGFloat = 0, sy: CGFloat = 0
        if shakeMag > 0.1 {
            sx = CGFloat.random(in: -shakeMag...shakeMag)
            sy = CGFloat.random(in: -shakeMag...shakeMag)
            shakeMag *= 0.82
        } else {
            shakeMag = 0
        }
        cam.position = CGPoint(x: nx + sx, y: ny + sy)
    }

    private func clampInsideLevel(_ robot: Robot) {
        let m: CGFloat = 30
        if robot.position.x < m { robot.position.x = m }
        if robot.position.x > levelWidth - m { robot.position.x = levelWidth - m }
        // Fell into a pit → death.
        if robot.position.y < -150 && !robot.isDead {
            if robot === player {
                playerFellInPit()
            } else {
                spawnExplosion(at: CGPoint(x: robot.position.x, y: -120))
                removeBot(robot)
            }
        }
    }

    private func playerFellInPit() {
        guard !player.isDead, !matchOver else { return }
        _ = player.takeDamage(player.maxHealth + 1)
        spawnExplosion(at: CGPoint(x: player.position.x, y: max(-110, player.position.y)))
        shake(11)
        dropFlagOnDeath()
        respawnPlayerSoon()
        net?.send(.hit(HitEvent(x: player.position.x, y: player.position.y,
                                health: 0, dead: true, killedBy: nil)))
    }

    // MARK: FX

    private func spawnMuzzleFlash(at p: CGPoint, color: SKColor) {
        let flash = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 40, height: 40))
        flash.position = p
        flash.color = color; flash.colorBlendFactor = 1; flash.blendMode = .add
        flash.zPosition = 45
        addChild(flash)
        flash.run(.sequence([.group([.scale(to: 0.3, duration: 0.08), .fadeOut(withDuration: 0.08)]),
                             .removeFromParent()]))
    }

    private func spawnSpark(at p: CGPoint, color: SKColor) {
        let e = SKEmitterNode()
        e.particleTexture = Art.softCircle
        e.position = p; e.zPosition = 60
        e.numParticlesToEmit = 10
        e.particleBirthRate = 900
        e.particleLifetime = 0.25
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 170; e.particleSpeedRange = 90
        e.particleScale = 0.18; e.particleScaleSpeed = -0.5
        e.particleColor = color; e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.particleAlpha = 0.9; e.particleAlphaSpeed = -3
        addChild(e)
        e.run(.sequence([.wait(forDuration: 0.4), .removeFromParent()]))
    }

    private func spawnExplosion(at p: CGPoint) {
        let e = SKEmitterNode()
        e.particleTexture = Art.softCircle
        e.position = p; e.zPosition = 70
        e.numParticlesToEmit = 44
        e.particleBirthRate = 2200
        e.particleLifetime = 0.6; e.particleLifetimeRange = 0.3
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 300; e.particleSpeedRange = 170
        e.particleScale = 0.55; e.particleScaleSpeed = -0.7
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [SKColor.white, SKColor.orange, SKColor.red], times: [0, 0.4, 1])
        e.particleBlendMode = .add
        e.particleAlpha = 1; e.particleAlphaSpeed = -1.6
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
        AudioManager.shared.play(.explosion)
    }

    private func shake(_ intensity: CGFloat) { shakeMag = max(shakeMag, intensity) }

    private func respawnPlayerSoon() {
        run(.sequence([.wait(forDuration: 1.8), .run { [weak self] in
            guard let self, !self.matchOver else { return }
            self.player.respawn(at: self.localSpawn())
            self.player.flame.targetNode = self
            self.fuel = self.maxFuel
            self.currentWeapon = .rifle
            self.ammo = 0
            self.player.setWeapon(.rifle)
            self.updateWeaponHUD()
        }]))
    }

    // MARK: Win conditions

    private func checkWin() {
        guard !matchOver else { return }

        switch mode {
        case 1:
            if teamKills(0) >= target { showWinner("Team A Wins!"); return }
            if teamKills(1) >= target { showWinner("Team B Wins!"); return }
        case 2:
            if teamCaptures(0) >= target { showWinner("Team A Wins!"); return }
            if teamCaptures(1) >= target { showWinner("Team B Wins!"); return }
        default:
            // Practice is a timed survival — enemies keep coming until time runs out.
            if isMultiplayer {
                var best = kills, bestName = localName
                for (n, k) in peerKills where k > best { best = k; bestName = n }
                if best >= target {
                    showWinner(bestName == localName ? "You Win!" : "\(displayName(bestName)) Wins!")
                    return
                }
            }
        }

        if timeRemaining <= 0 { timeUp() }
    }

    private func displayName(_ peerID: String) -> String {
        remoteTargets[peerID]?.name ?? peerID
    }

    private func timeUp() {
        switch mode {
        case 1:
            let a = teamKills(0), b = teamKills(1)
            showWinner(a == b ? "Time Up — Draw!" : "Time Up — Team \(a > b ? "A" : "B") Wins!")
        case 2:
            let a = teamCaptures(0), b = teamCaptures(1)
            showWinner(a == b ? "Time Up — Draw!" : "Time Up — Team \(a > b ? "A" : "B") Wins!")
        default:
            if !isMultiplayer {
                showWinner("Time Up — \(kills) Kills!")
                return
            }
            var best = kills, bestName = localName, tie = false
            for (n, k) in peerKills {
                if k > best { best = k; bestName = n; tie = false }
                else if k == best && n != bestName { tie = true }
            }
            if tie { showWinner("Time Up — Draw!") }
            else {
                showWinner(bestName == localName ? "Time Up — You Win!"
                                                 : "Time Up — \(displayName(bestName)) Wins!")
            }
        }
    }

    private func showWinner(_ text: String) {
        matchOver = true
        moveStick.deactivate(); aimStick.deactivate()
        setJetSound(false)
        AudioManager.shared.play(.win)

        let dim = SKSpriteNode(color: .black, size: CGSize(width: size.width * 1.3, height: size.height * 1.3))
        dim.alpha = 0; dim.zPosition = 800
        cam.addChild(dim)
        dim.run(.fadeAlpha(to: 0.55, duration: 0.4))

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"; label.fontSize = 44; label.fontColor = .white
        label.verticalAlignmentMode = .center; label.zPosition = 801
        label.setScale(0.4)
        cam.addChild(label)
        label.run(.scale(to: 1, duration: 0.4))

        let sub = SKLabelNode(text: "Tap  ‹  (top-left) to return to menu")
        sub.fontName = "AvenirNext-Medium"; sub.fontSize = 16
        sub.fontColor = SKColor.white.withAlphaComponent(0.85)
        sub.position = CGPoint(x: 0, y: -46); sub.zPosition = 801
        cam.addChild(sub)
    }

    // MARK: Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB

        // Rockets explode on anything they touch.
        if let rocket = (a.node as? Rocket) ?? (b.node as? Rocket) {
            let other = (a.node === rocket) ? b.node : a.node
            if !rocket.armed, let r = other as? Robot, r === player, rocket.ownerName == localName {
                return      // just left the muzzle — don't pop on the shooter
            }
            if rocket.parent != nil { explodeRocket(rocket) }
            return
        }

        let bulletBody = a.categoryBitMask == PhysicsCategory.bullet ? a
                       : (b.categoryBitMask == PhysicsCategory.bullet ? b : nil)
        guard let bb = bulletBody, let bullet = bb.node as? Bullet else { return }
        let other = (bb === a) ? b : a

        if let robot = other.node as? Robot {
            if isMultiplayer {
                if robot === player && !player.isDead && !matchOver {
                    let friendly = mode >= 1 && localTeam >= 0 && teamOf(bullet.ownerName) == localTeam
                    if !friendly {
                        spawnSpark(at: bullet.position, color: .orange)
                        AudioManager.shared.play(.hit)
                        let died = player.takeDamage(bullet.damage)
                        shake(died ? 11 : 4)
                        var killedBy: String? = nil
                        if died {
                            spawnExplosion(at: player.position)
                            killedBy = bullet.ownerName
                            dropFlagOnDeath()
                            respawnPlayerSoon()
                        }
                        net?.send(.hit(HitEvent(x: bullet.position.x, y: bullet.position.y,
                                                health: player.health, dead: died, killedBy: killedBy)))
                    }
                }
            } else if !robot.isDead && !matchOver {
                spawnSpark(at: bullet.position, color: .orange)
                AudioManager.shared.play(.hit)
                let died = robot.takeDamage(bullet.damage)
                if robot.team == .player { shake(died ? 11 : 4) }
                if died {
                    spawnExplosion(at: robot.position)
                    if robot.team == .enemy {
                        kills += 1
                        shake(8)
                        removeBot(robot)
                    } else {
                        respawnPlayerSoon()
                    }
                }
            }
        } else {
            spawnSpark(at: bullet.position, color: .white)
        }
        bullet.removeFromParent()
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: cam)
            // Grenade button: hold & drag to aim, release to throw (tap = quick throw).
            if nadeTouch == nil,
               nadeButton.calculateAccumulatedFrame().insetBy(dx: -14, dy: -14).contains(p) {
                nadeTouch = t
                nadeAimVec = .zero
                continue
            }
            let moveSide = leftHanded ? (p.x > 0) : (p.x < 0)
            if moveSide {
                if moveTouch == nil { moveTouch = t; moveStick.activate(at: p) }
            } else {
                if aimTouch == nil { aimTouch = t; aimStick.activate(at: p) }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: cam)
            if t == nadeTouch {
                nadeAimVec = CGVector(dx: p.x - nadeButton.position.x,
                                      dy: p.y - nadeButton.position.y)
            }
            else if t == moveTouch { moveStick.update(to: p) }
            else if t == aimTouch { aimStick.update(to: p) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            if t == nadeTouch {
                if hypot(nadeAimVec.dx, nadeAimVec.dy) > 18 {
                    let aim = nadeAim()
                    throwGrenade(angle: aim.angle, power: aim.power)
                } else {
                    throwGrenade(angle: player.aimAngle, power: nadeQuickPower)
                }
                nadeTouch = nil
                nadeAimVec = .zero
                nadePreview.isHidden = true
            }
            else if t == moveTouch { moveStick.deactivate(); moveTouch = nil }
            else if t == aimTouch { aimStick.deactivate(); aimTouch = nil }
        }
    }
}
