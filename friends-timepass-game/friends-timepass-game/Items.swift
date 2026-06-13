//
//  Items.swift
//  Weapons, pickup crates, and the CTF flag node.
//

import SpriteKit

// MARK: - Weapons

nonisolated enum WeaponType: Int, Codable, CaseIterable {
    case rifle = 0, uzi, shotgun, sniper, magnum, mp5, ak47, flamer, rocket

    /// How the weapon's shots behave.
    enum Special { case bullet, flame, rocketLauncher }

    var special: Special {
        switch self {
        case .flamer: return .flame
        case .rocket: return .rocketLauncher
        default: return .bullet
        }
    }

    var displayName: String {
        switch self {
        case .rifle: return "M4"
        case .uzi: return "UZI"
        case .shotgun: return "SHOTGUN"
        case .sniper: return "M14"
        case .magnum: return "MAGNUM"
        case .mp5: return "MP5"
        case .ak47: return "AK-47"
        case .flamer: return "FLAMER"
        case .rocket: return "SMAW"
        }
    }

    /// Distance from the arm pivot to the muzzle tip (per weapon model).
    var muzzleLength: CGFloat {
        switch self {
        case .rifle: return 54
        case .uzi: return 46
        case .shotgun: return 54
        case .sniper: return 64
        case .magnum: return 44
        case .mp5: return 47
        case .ak47: return 56
        case .flamer: return 50
        case .rocket: return 58
        }
    }

    var fireInterval: CGFloat {
        switch self {
        case .rifle: return 0.14
        case .uzi: return 0.07
        case .shotgun: return 0.6
        case .sniper: return 0.95
        case .magnum: return 0.45
        case .mp5: return 0.085
        case .ak47: return 0.16
        case .flamer: return 0.05
        case .rocket: return 1.3
        }
    }

    var damage: CGFloat {
        switch self {
        case .rifle: return 11
        case .uzi: return 7
        case .shotgun: return 9
        case .sniper: return 45
        case .magnum: return 28
        case .mp5: return 8
        case .ak47: return 14
        case .flamer: return 3
        case .rocket: return 62        // splash damage at the impact point
        }
    }

    var bulletSpeed: CGFloat {
        switch self {
        case .rifle: return 940
        case .uzi: return 900
        case .shotgun: return 800
        case .sniper: return 1450
        case .magnum: return 1150
        case .mp5: return 920
        case .ak47: return 950
        case .flamer: return 520
        case .rocket: return 470
        }
    }

    var pellets: Int { self == .shotgun ? 5 : 1 }

    var spread: CGFloat {
        switch self {
        case .rifle: return 0.015
        case .uzi: return 0.05
        case .shotgun: return 0.18
        case .sniper: return 0
        case .magnum: return 0.01
        case .mp5: return 0.04
        case .ak47: return 0.03
        case .flamer: return 0.12
        case .rocket: return 0
        }
    }

    /// How long a fired round lives (flame puffs are short-range).
    var bulletLifetime: TimeInterval {
        self == .flamer ? 0.30 : 1.5
    }

    /// Where the character's hands grip this weapon (arm-pivot coordinates).
    var grips: [(x: CGFloat, y: CGFloat)] {
        switch self {
        case .rifle: return [(24, -4), (42, -1)]
        case .uzi: return [(22, -5), (33, -2)]
        case .shotgun: return [(15, -3), (31, -4)]
        case .sniper: return [(13, -3), (33, -2)]
        case .magnum: return [(13, -5)]
        case .mp5: return [(20, -6), (37, -2)]
        case .ak47: return [(20, -5), (38, -1)]
        case .flamer: return [(19, -7), (39, -1)]
        case .rocket: return [(24, -7), (35, -6)]
        }
    }

    /// nil = infinite (default weapon)
    var startAmmo: Int? {
        switch self {
        case .rifle: return nil
        case .uzi: return 40
        case .shotgun: return 12
        case .sniper: return 8
        case .magnum: return 12
        case .mp5: return 45
        case .ak47: return 35
        case .flamer: return 90
        case .rocket: return 4
        }
    }
}

// MARK: - Weapon art (vector silhouettes of real guns, drawn in arm-pivot space)

enum WeaponArt {

    private static let metal = SKColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1)
    private static let metalDark = SKColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1)
    private static let wood = SKColor(red: 0.36, green: 0.24, blue: 0.13, alpha: 1)

    static func node(for type: WeaponType) -> SKNode {
        let n = SKNode()

        func part(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                  _ color: SKColor, _ radius: CGFloat = 1.5, rot: CGFloat = 0) {
            let r = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: radius)
            r.fillColor = color; r.strokeColor = .clear
            r.position = CGPoint(x: x, y: y)
            r.zRotation = rot
            n.addChild(r)
        }

        switch type {
        case .rifle:        // M4 carbine
            part(6, -1, 8, 9, metalDark, 2)            // butt pad
            part(13, 0, 10, 6, metal, 1.5)             // stock tube
            part(27, 0, 18, 9, metal, 2)               // receiver
            part(29, 6, 12, 3, metalDark)              // carry handle / rail
            part(28, -8, 7, 12, metalDark, 1.5, rot: 0.22)   // magazine (slanted)
            part(42, 0, 12, 7, metal, 2)               // handguard
            part(50, 1, 10, 3.5, metalDark)            // barrel
            part(52, 5, 2.5, 6, metalDark)             // front sight
        case .uzi:          // UZI subgun
            part(8, 0, 8, 6, metalDark, 1)             // folded stock
            part(24, 0, 22, 10, metal, 2)              // boxy receiver
            part(24, -9, 6, 12, metalDark, 1)          // grip magazine
            part(40, 1, 11, 4, metalDark)              // stub barrel
        case .shotgun:      // pump shotgun
            part(5, -2, 9, 9, wood, 2)                 // stock
            part(16, 0, 12, 8, metal, 2)               // receiver
            part(33, 1.5, 32, 4.5, metalDark)          // barrel
            part(31, -3.5, 14, 4.5, wood, 2)           // pump grip
            part(50, 3.5, 3, 4, metalDark)             // bead sight
        case .sniper:       // M14 rifle
            part(4, -2, 9, 8, wood, 2)                 // butt
            part(19, -0.5, 24, 7, wood, 2)             // wooden stock body
            part(28, 6, 15, 5, metal, 2)               // scope
            part(21, 6, 3, 6, metalDark)               // scope mount
            part(36, 6, 3, 6, metalDark)
            part(46, 0.5, 32, 4, metalDark)            // long barrel
            part(61, 4, 2.5, 5, metalDark)             // front sight
        case .magnum:       // revolver
            part(20, 1, 16, 5.5, metal, 2)             // frame
            part(34, 1.5, 14, 3.5, metalDark, 1)       // barrel
            part(21, 0, 7, 8, metalDark, 2)            // cylinder
            part(13, -5, 6, 10, wood, 2, rot: 0.28)    // grip
            part(41, 4, 2, 4, metalDark)               // front sight
        case .mp5:          // submachine gun
            part(9, 0, 10, 5, metal, 1.5)              // sliding stock
            part(25, 0, 22, 8.5, metal, 2)             // receiver
            part(27, -8.5, 6, 11, metalDark, 2, rot: 0.32)   // curved mag
            part(20, -7, 5, 8, metalDark, 1.5)         // grip
            part(41, 1, 9, 3.5, metalDark)             // barrel
        case .ak47:         // AK-47
            part(6, -1.5, 11, 7, wood, 2)              // wooden stock
            part(22, 0, 20, 7.5, metal, 2)             // receiver
            part(38, 0.5, 10, 5, wood, 2)              // wooden handguard
            part(48, 1.5, 10, 3, metalDark)            // barrel
            part(25, -8.5, 7, 12, metalDark, 2, rot: 0.42)   // banana mag
            part(52, 4.5, 2, 5, metalDark)             // front sight
        case .flamer:       // flamethrower
            part(13, -8, 12, 8, SKColor(red: 0.62, green: 0.20, blue: 0.15, alpha: 1), 3)  // fuel tank
            part(23, 0, 22, 9, metal, 2)               // body
            part(40, 0, 13, 4.5, metalDark, 1)         // nozzle
            part(48, 0, 4, 7, metalDark, 2)            // burner tip
            part(19, -7, 5, 7, metalDark, 1.5)         // grip
        case .rocket:       // SMAW launcher
            part(28, 1, 44, 9.5, metalDark, 4)         // tube
            part(53, 1, 7, 6.5, SKColor(red: 0.78, green: 0.25, blue: 0.20, alpha: 1), 2)  // rocket tip
            part(24, -7.5, 5, 8, metal, 1.5)           // grip
            part(30, 7.5, 9, 4, metal, 1.5)            // sight
        }
        return n
    }
}

// MARK: - Thrown grenade

final class Grenade: SKNode {

    let ownerName: String
    let damage: CGFloat = 52
    let blastRadius: CGFloat = 125

    init(owner: String) {
        ownerName = owner
        super.init()
        zPosition = 40

        let shell = SKShapeNode(circleOfRadius: 7)
        shell.fillColor = SKColor(red: 0.22, green: 0.32, blue: 0.18, alpha: 1)
        shell.strokeColor = SKColor(red: 0.10, green: 0.16, blue: 0.08, alpha: 1)
        shell.lineWidth = 1.5
        addChild(shell)
        let lever = SKShapeNode(rectOf: CGSize(width: 4, height: 6), cornerRadius: 1)
        lever.fillColor = SKColor(white: 0.7, alpha: 1); lever.strokeColor = .clear
        lever.position = CGPoint(x: 2, y: 8)
        addChild(lever)

        // Blinking fuse light.
        let light = SKShapeNode(circleOfRadius: 2.2)
        light.fillColor = .red; light.strokeColor = .clear; light.glowWidth = 2
        light.position = CGPoint(x: -2, y: 7)
        addChild(light)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.18),
                                            .fadeAlpha(to: 1, duration: 0.18)])))

        let body = SKPhysicsBody(circleOfRadius: 7)
        body.restitution = 0.45
        body.friction = 0.6
        body.linearDamping = 0.25
        body.angularDamping = 0.6
        body.categoryBitMask = 0
        body.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.wall
        body.contactTestBitMask = 0
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Rocket projectile

final class Rocket: SKNode {

    let ownerName: String
    let damage: CGFloat = 62
    let blastRadius: CGFloat = 115
    var armed = false       // briefly false at launch so it can't pop on the shooter

    init(owner: String, color: SKColor) {
        ownerName = owner
        super.init()
        zPosition = 41

        let glow = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 40, height: 22))
        glow.color = color; glow.colorBlendFactor = 1; glow.blendMode = .add; glow.alpha = 0.6
        glow.position = CGPoint(x: -8, y: 0)
        addChild(glow)

        let tube = SKShapeNode(rectOf: CGSize(width: 24, height: 7), cornerRadius: 3)
        tube.fillColor = SKColor(red: 0.25, green: 0.27, blue: 0.30, alpha: 1)
        tube.strokeColor = .clear
        addChild(tube)
        let tip = SKShapeNode(rectOf: CGSize(width: 7, height: 7), cornerRadius: 3)
        tip.fillColor = SKColor(red: 0.85, green: 0.28, blue: 0.22, alpha: 1)
        tip.strokeColor = .clear
        tip.position = CGPoint(x: 14, y: 0)
        addChild(tip)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 8))
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.bullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.wall |
                                  PhysicsCategory.player | PhysicsCategory.enemy
        body.usesPreciseCollisionDetection = true
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Pickups

enum PickupKind {
    case health
    case weapon(WeaponType)
    case nades                 // +2 frag grenades
}

final class PickupNode: SKNode {

    let kind: PickupKind
    let spot: Int

    init(kind: PickupKind, spot: Int) {
        self.kind = kind
        self.spot = spot
        super.init()
        zPosition = 25

        let accent: SKColor
        switch kind {
        case .health: accent = SKColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1)
        case .weapon: accent = SKColor(red: 0.96, green: 0.62, blue: 0.10, alpha: 1)
        case .nades: accent = SKColor(red: 0.55, green: 0.80, blue: 0.30, alpha: 1)
        }

        let glow = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 72, height: 72))
        glow.color = accent; glow.colorBlendFactor = 1; glow.blendMode = .add; glow.alpha = 0.30
        addChild(glow)

        let box = SKShapeNode(rectOf: CGSize(width: 44, height: 36), cornerRadius: 7)
        box.fillColor = SKColor(red: 0.15, green: 0.17, blue: 0.24, alpha: 1)
        box.strokeColor = accent.withAlphaComponent(0.9)
        box.lineWidth = 1.6
        addChild(box)

        let stripe = SKShapeNode(rectOf: CGSize(width: 44, height: 6), cornerRadius: 2)
        stripe.fillColor = accent; stripe.strokeColor = .clear
        stripe.position = CGPoint(x: 0, y: 14)
        addChild(stripe)

        // Light interior pane so the contents read clearly.
        let pane = SKShapeNode(rectOf: CGSize(width: 38, height: 22), cornerRadius: 4)
        pane.fillColor = SKColor(red: 0.80, green: 0.83, blue: 0.88, alpha: 1)
        pane.strokeColor = .clear
        pane.position = CGPoint(x: 0, y: -3)
        addChild(pane)

        switch kind {
        case .health:
            let v = SKShapeNode(rectOf: CGSize(width: 5, height: 16))
            v.fillColor = accent; v.strokeColor = .clear; v.position = CGPoint(x: 0, y: -3)
            addChild(v)
            let h = SKShapeNode(rectOf: CGSize(width: 16, height: 5))
            h.fillColor = accent; h.strokeColor = .clear; h.position = CGPoint(x: 0, y: -3)
            addChild(h)
        case .weapon(let w):
            // The actual gun, centered on the light pane.
            let icon = WeaponArt.node(for: w)
            let scale: CGFloat = 0.55
            icon.setScale(scale)
            let artCenter = (w.muzzleLength + 6) / 2
            icon.position = CGPoint(x: -artCenter * scale, y: -3)
            addChild(icon)
        case .nades:
            let shell = SKShapeNode(circleOfRadius: 7.5)
            shell.fillColor = SKColor(red: 0.22, green: 0.32, blue: 0.18, alpha: 1)
            shell.strokeColor = SKColor(red: 0.10, green: 0.16, blue: 0.08, alpha: 1)
            shell.lineWidth = 1.4
            shell.position = CGPoint(x: 0, y: -4)
            addChild(shell)
            let lever = SKShapeNode(rectOf: CGSize(width: 4.5, height: 5.5), cornerRadius: 1)
            lever.fillColor = SKColor(white: 0.55, alpha: 1); lever.strokeColor = .clear
            lever.position = CGPoint(x: 4, y: 4)
            addChild(lever)
        }

        let bobUp = SKAction.moveBy(x: 0, y: 7, duration: 0.9); bobUp.timingMode = .easeInEaseOut
        let bobDown = SKAction.moveBy(x: 0, y: -7, duration: 0.9); bobDown.timingMode = .easeInEaseOut
        run(.repeatForever(.sequence([bobUp, bobDown])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - CTF flag

final class FlagNode: SKNode {

    init(teamColor: SKColor) {
        super.init()
        zPosition = 30

        let glow = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 70, height: 70))
        glow.color = teamColor; glow.colorBlendFactor = 1; glow.blendMode = .add; glow.alpha = 0.25
        glow.position = CGPoint(x: 0, y: 40)
        addChild(glow)

        let pole = SKShapeNode(rectOf: CGSize(width: 4, height: 74), cornerRadius: 2)
        pole.fillColor = SKColor(white: 0.85, alpha: 1); pole.strokeColor = .clear
        pole.position = CGPoint(x: 0, y: 37)
        addChild(pole)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 2, y: 72))
        path.addLine(to: CGPoint(x: 36, y: 60))
        path.addLine(to: CGPoint(x: 2, y: 48))
        path.closeSubpath()
        let banner = SKShapeNode(path: path)
        banner.fillColor = teamColor
        banner.strokeColor = .clear
        addChild(banner)

        let base = SKShapeNode(circleOfRadius: 7)
        base.fillColor = SKColor(white: 0.6, alpha: 1); base.strokeColor = .clear
        addChild(base)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
