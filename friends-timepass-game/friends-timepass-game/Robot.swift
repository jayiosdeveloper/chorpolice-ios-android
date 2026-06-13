//
//  Robot.swift
//  A fully procedural, modular side-view shooter character ("operative"):
//  helmet + visor, tactical vest, strong shoulders, two bent arms that brace
//  the weapon, legs that walk, and a jetpack. Built from shape parts so it can
//  flip (facing), aim (the whole arm rig rotates) and animate. Colours come
//  from the networked RobotSkin so customisation + multiplayer stay intact.
//
//  Public API is unchanged from the old Robot — GameScene/MenuScene untouched.
//

import SpriteKit
import UIKit

final class Robot: SKNode {

    enum Team { case player, enemy }

    let team: Team
    let maxHealth: CGFloat = 100
    private(set) var health: CGFloat = 100
    private(set) var isDead = false

    let flame: SKEmitterNode

    // Layer hierarchy
    private let visual = SKNode()        // scaled, never flips
    private let bodyGroup = SKNode()     // flips L/R (torso, head, legs, pack)
    private let armRig = SKNode()        // arms + gun, rotates to aim
    private let weaponMount = SKNode()   // gun + hands inside the rig
    private let leftLeg = SKNode()
    private let rightLeg = SKNode()
    private let healthBar = SKNode()
    private var healthFill: SKSpriteNode!
    private let nameLabel = SKLabelNode()

    private(set) var weaponType: WeaponType = .rifle

    private var runPhase: CGFloat = 0
    private(set) var facing: CGFloat = 1
    private var thrusting = false
    private var aimStored: CGFloat = 0

    var aimAngle: CGFloat { aimStored }
    var isThrusting: Bool { thrusting }

    // Colours
    private let jacket: SKColor
    private let jacket2: SKColor
    private let jacketDark: SKColor
    private let helmetColor: SKColor
    private let pants: SKColor
    private let accent: SKColor
    private let skinTone: SKColor
    private let boot = SKColor(red: 0.16, green: 0.15, blue: 0.18, alpha: 1)
    private let gear = SKColor(red: 0.26, green: 0.28, blue: 0.34, alpha: 1)
    private let outline = SKColor.black.withAlphaComponent(0.22)
    private let visualScale: CGFloat = 0.8
    private let gunScale: CGFloat = 1.35     // enlarge the weapon so it reads clearly

    convenience init(team: Team, colorIndex: Int) {
        self.init(team: team, skin: PlayerColors.skin(colorIndex))
    }

    init(team: Team, skin: RobotSkin) {
        self.team = team
        jacket = Robot.rgb(skin.bodyRGB)
        jacket2 = Robot.rgb(skin.jacket2RGB)
        jacketDark = Robot.mix(jacket, 0.68)
        helmetColor = Robot.rgb(skin.helmetRGB)
        pants = Robot.rgb(skin.pantsRGB)
        accent = Robot.rgb(skin.accentRGB)
        skinTone = Robot.rgb(skin.toneRGB)
        flame = Robot.makeFlame()
        super.init()
        addChild(visual)
        visual.setScale(visualScale)
        visual.addChild(bodyGroup)
        visual.addChild(armRig)
        buildBackpack()
        buildLegs()
        buildTorso()
        buildHead()
        buildArmRig()
        buildHud()
        setupPhysics()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func mix(_ c: SKColor, _ f: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: r * f, green: g * f, blue: b * f, alpha: a)
    }

    private static func rgb(_ a: [Double]) -> SKColor {
        SKColor(red: a[0], green: a[1], blue: a[2], alpha: 1)
    }

    /// A small top→bottom gradient texture used to fill the vest for gradient skins.
    private static func verticalGradient(_ top: SKColor, _ bottom: SKColor) -> SKTexture {
        let size = CGSize(width: 8, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            guard let grad = CGGradient(colorsSpace: space,
                                        colors: [top.cgColor, bottom.cgColor] as CFArray,
                                        locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(grad, start: .zero,
                                             end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: img)
    }

    // MARK: Shape helpers

    private func roundRect(_ size: CGSize, _ radius: CGFloat, _ fill: SKColor,
                           stroke: SKColor? = nil, lw: CGFloat = 0) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: radius)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = lw
        return n
    }
    private func dot(_ r: CGFloat, _ fill: SKColor, glow: CGFloat = 0) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: r)
        n.fillColor = fill; n.strokeColor = .clear; n.glowWidth = glow
        return n
    }
    /// A capsule limb segment running a → b.
    private func limb(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ color: SKColor) -> SKShapeNode {
        let len = max(w, hypot(b.x - a.x, b.y - a.y))
        let n = SKShapeNode(rectOf: CGSize(width: w, height: len), cornerRadius: w / 2)
        n.fillColor = color
        n.strokeColor = outline; n.lineWidth = 1.2     // subtle outline for depth
        n.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        n.zRotation = atan2(b.y - a.y, b.x - a.x) - .pi / 2
        return n
    }

    // MARK: Build — body

    private func buildBackpack() {
        let pack = roundRect(CGSize(width: 18, height: 32), 6, gear,
                             stroke: Robot.mix(gear, 0.7), lw: 1.5)
        pack.position = CGPoint(x: -16, y: 58); pack.zPosition = -3
        bodyGroup.addChild(pack)
        let vent = roundRect(CGSize(width: 6, height: 18), 3, accent)
        vent.position = CGPoint(x: -20, y: 58); vent.alpha = 0.9; vent.zPosition = -2
        bodyGroup.addChild(vent)
        let nozzle = roundRect(CGSize(width: 12, height: 8), 3, Robot.mix(gear, 0.6))
        nozzle.position = CGPoint(x: -16, y: 40); nozzle.zPosition = -3
        bodyGroup.addChild(nozzle)
        flame.position = CGPoint(x: -16, y: 30); flame.zPosition = -4
        bodyGroup.addChild(flame)
    }

    private func buildLegs() {
        // Soft contact shadow under the feet.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 48, height: 13))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -1); shadow.zPosition = -6
        bodyGroup.addChild(shadow)

        for (leg, dx) in [(leftLeg, CGFloat(-8)), (rightLeg, CGFloat(8))] {
            leg.position = CGPoint(x: dx, y: 40)
            leg.zPosition = -1
            let thigh = limb(CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -38), 15, pants)
            leg.addChild(thigh)
            let knee = dot(5, Robot.mix(pants, 0.78))           // knee pad
            knee.position = CGPoint(x: 1, y: -18); leg.addChild(knee)
            let bootNode = roundRect(CGSize(width: 17, height: 11), 4, boot,
                                     stroke: SKColor.black.withAlphaComponent(0.3), lw: 1)
            bootNode.position = CGPoint(x: 3, y: -40)
            leg.addChild(bootNode)
            let bootShine = roundRect(CGSize(width: 13, height: 3), 1.5,
                                      SKColor.white.withAlphaComponent(0.18))
            bootShine.position = CGPoint(x: 3, y: -37); leg.addChild(bootShine)
            bodyGroup.addChild(leg)
        }
    }

    private func buildTorso() {
        // Vest
        let vest = roundRect(CGSize(width: 37, height: 36), 11, jacket,
                             stroke: jacketDark, lw: 2)
        if jacket2 != jacket {                       // unique vertical gradient jacket
            vest.fillColor = .white
            vest.fillTexture = Robot.verticalGradient(jacket, jacket2)
        }
        vest.position = CGPoint(x: 0, y: 53); vest.zPosition = 0
        bodyGroup.addChild(vest)
        // Top highlight + bottom shade for a lit, rounded look
        let hi = roundRect(CGSize(width: 31, height: 11), 6, SKColor.white.withAlphaComponent(0.16))
        hi.position = CGPoint(x: 0, y: 64); hi.zPosition = 1
        bodyGroup.addChild(hi)
        let lo = roundRect(CGSize(width: 35, height: 12), 6, SKColor.black.withAlphaComponent(0.16))
        lo.position = CGPoint(x: 0, y: 42); lo.zPosition = 1
        bodyGroup.addChild(lo)
        // Belt
        let belt = roundRect(CGSize(width: 37, height: 8), 3, pants)
        belt.position = CGPoint(x: 0, y: 40); belt.zPosition = 2
        bodyGroup.addChild(belt)
        // Utility pouches
        for px in [CGFloat(-11), 11] {
            let pouch = roundRect(CGSize(width: 9, height: 9), 2.5, jacketDark)
            pouch.position = CGPoint(x: px, y: 43); pouch.zPosition = 2
            bodyGroup.addChild(pouch)
        }
        // Diagonal strap
        let strap = limb(CGPoint(x: -14, y: 66), CGPoint(x: 12, y: 42), 6, jacketDark)
        strap.zPosition = 1
        bodyGroup.addChild(strap)
        // Chest light
        let light = dot(4, accent, glow: 4)
        light.position = CGPoint(x: -4, y: 56); light.zPosition = 2
        bodyGroup.addChild(light)
        // Strong shoulder pads
        for sx in [CGFloat(-16), 16] {
            let pad = roundRect(CGSize(width: 18, height: 15), 6, jacket, stroke: jacketDark, lw: 1.5)
            pad.position = CGPoint(x: sx, y: 67); pad.zPosition = 3
            bodyGroup.addChild(pad)
        }
    }

    private func buildHead() {
        // Skin base (jaw shows under the helmet)
        let head = roundRect(CGSize(width: 30, height: 28), 11, skinTone)
        head.position = CGPoint(x: 3, y: 82); head.zPosition = 4
        bodyGroup.addChild(head)
        // Ear
        let ear = dot(4, Robot.mix(skinTone, 0.92))
        ear.position = CGPoint(x: -10, y: 80); ear.zPosition = 4
        bodyGroup.addChild(ear)
        // Helmet (upper head)
        let helmet = roundRect(CGSize(width: 34, height: 22), 11, helmetColor,
                               stroke: Robot.mix(helmetColor, 0.62), lw: 2)
        helmet.position = CGPoint(x: 3, y: 92); helmet.zPosition = 6
        bodyGroup.addChild(helmet)
        // Helmet sheen
        let sheen = SKShapeNode(ellipseOf: CGSize(width: 14, height: 7))
        sheen.fillColor = SKColor.white.withAlphaComponent(0.22); sheen.strokeColor = .clear
        sheen.position = CGPoint(x: -3, y: 97); sheen.zPosition = 7
        bodyGroup.addChild(sheen)
        let brim = roundRect(CGSize(width: 26, height: 6), 3, Robot.mix(helmetColor, 0.62))
        brim.position = CGPoint(x: 8, y: 84); brim.zPosition = 7
        bodyGroup.addChild(brim)
        // Glowing visor / goggles + shine
        let visor = roundRect(CGSize(width: 21, height: 8), 4, accent)
        visor.glowWidth = 4
        visor.position = CGPoint(x: 9, y: 85); visor.zPosition = 7
        bodyGroup.addChild(visor)
        let shine = dot(2, SKColor.white.withAlphaComponent(0.9))
        shine.position = CGPoint(x: 14, y: 86); shine.zPosition = 8
        bodyGroup.addChild(shine)
        // Antenna
        let antenna = roundRect(CGSize(width: 3, height: 12), 1, jacketDark)
        antenna.position = CGPoint(x: -10, y: 104); antenna.zPosition = 5
        bodyGroup.addChild(antenna)
        let tip = dot(3, accent, glow: 3)
        tip.position = CGPoint(x: -10, y: 111); tip.zPosition = 5
        bodyGroup.addChild(tip)
    }

    // MARK: Build — arm rig (rotates to aim; gun centreline at y = 0)

    private func buildArmRig() {
        armRig.position = CGPoint(x: 2, y: 62)
        armRig.zPosition = 5
        armRig.addChild(weaponMount)
        setWeapon(.rifle)
    }

    /// Builds the held weapon + two bracing arms whose hands sit on its grips.
    func setWeapon(_ type: WeaponType) {
        if type == weaponType && !weaponMount.children.isEmpty { return }
        weaponType = type
        weaponMount.removeAllChildren()

        let grips = type.grips
        let backX = (grips.first?.x ?? 22) * gunScale
        let frontX = (grips.count > 1 ? grips[1].x : (grips.first?.x ?? 22)) * gunScale

        let shoulder = CGPoint(x: 0, y: 0)

        // Back arm (behind the gun)
        let backElbow = CGPoint(x: backX * 0.45, y: -15)
        weaponMount.addChild(node(limb(shoulder, backElbow, 12, jacketDark), z: 0))
        weaponMount.addChild(node(limb(backElbow, CGPoint(x: backX, y: 0), 11, jacketDark), z: 0))

        // Gun — enlarged so it's clearly visible past the hands
        let gun = WeaponArt.node(for: type)
        gun.setScale(gunScale); gun.zPosition = 2
        weaponMount.addChild(gun)

        // Back hand gripping the trigger
        let backHand = gripHand(); backHand.position = CGPoint(x: backX, y: 0); backHand.zPosition = 2.6
        weaponMount.addChild(backHand)

        // Front arm (in front of the gun) + support hand on the foregrip
        if grips.count > 1 {
            let frontElbow = CGPoint(x: frontX * 0.5, y: -16)
            weaponMount.addChild(node(limb(shoulder, frontElbow, 12, jacket), z: 4))
            weaponMount.addChild(node(limb(frontElbow, CGPoint(x: frontX, y: 0), 11, jacket), z: 4))
            let frontHand = gripHand(); frontHand.position = CGPoint(x: frontX, y: 0); frontHand.zPosition = 4.6
            weaponMount.addChild(frontHand)
        }

        // Shoulder pad capping the arm root
        weaponMount.addChild(node(roundRect(CGSize(width: 16, height: 14), 6, jacket,
                                            stroke: jacketDark, lw: 1.5),
                                  at: CGPoint(x: 0, y: 1), z: 3))
    }

    /// A hand wrapped around the gun: fist + 3 finger creases + fingertips
    /// curling over the top + a thumb. Compact so the weapon stays visible.
    private func gripHand() -> SKNode {
        let n = SKNode()
        let cuff = Robot.mix(skinTone, 0.7)
        let fist = roundRect(CGSize(width: 12, height: 15), 5, skinTone, stroke: cuff, lw: 1.2)
        n.addChild(node(fist, z: 0))
        for i in 0..<3 {
            let crease = roundRect(CGSize(width: 12, height: 1.6), 0.8, cuff)
            n.addChild(node(crease, at: CGPoint(x: 0, y: 4.5 - CGFloat(i) * 4), z: 1))
        }
        for fx in [CGFloat(-3.5), 0.5, 4.5] {
            let tip = roundRect(CGSize(width: 3.2, height: 3.6), 1.4, skinTone, stroke: cuff, lw: 0.7)
            n.addChild(node(tip, at: CGPoint(x: fx, y: 8), z: 2))
        }
        let thumb = roundRect(CGSize(width: 4.6, height: 7.5), 2.2, skinTone, stroke: cuff, lw: 1)
        thumb.zRotation = 0.35
        n.addChild(node(thumb, at: CGPoint(x: -5, y: 4), z: 2))
        return n
    }
    private func node(_ n: SKShapeNode, at p: CGPoint = .zero, z: CGFloat) -> SKShapeNode {
        if p != .zero { n.position = p }
        n.zPosition = z
        return n
    }

    private func setupPhysics() {
        let s = visualScale
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 32 * s, height: 78 * s),
                                 center: CGPoint(x: 0, y: 40 * s))
        body.allowsRotation = false
        body.restitution = 0
        body.friction = 0.2
        body.linearDamping = 0.1
        body.categoryBitMask = team == .player ? PhysicsCategory.player : PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.bullet
        physicsBody = body
    }

    private func buildHud() {
        healthBar.position = CGPoint(x: 0, y: 124)
        healthBar.zPosition = 20
        let w: CGFloat = 46, h: CGFloat = 6
        healthBar.addChild(node(roundRect(CGSize(width: w, height: h), 3,
                                          SKColor.black.withAlphaComponent(0.5)), z: 0))
        healthFill = SKSpriteNode(color: SKColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1),
                                  size: CGSize(width: w, height: h))
        healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFill.position = CGPoint(x: -w / 2, y: 0)
        healthBar.addChild(healthFill)
        visual.addChild(healthBar)

        nameLabel.fontName = "AvenirNext-Bold"
        nameLabel.fontSize = 13
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 140)
        nameLabel.zPosition = 20
        visual.addChild(nameLabel)
    }

    private static func makeFlame() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.softCircle
        e.particleBirthRate = 0
        e.particleLifetime = 0.4
        e.particleLifetimeRange = 0.15
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = .pi / 7
        e.particleSpeed = 300
        e.particleSpeedRange = 100
        e.yAcceleration = -700        // speeds up downward → fuller trailing plume (like Android)
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -2.2
        e.particleScale = 0.6
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = -0.7
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 1),
                             SKColor.orange,
                             SKColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1)],
            times: [0, 0.4, 1])
        e.particleBlendMode = .add
        return e
    }

    // MARK: Per-frame animation

    func animate(dt: CGFloat, grounded: Bool, horizontalSpeed: CGFloat) {
        if !grounded {
            leftLeg.zRotation = lerp(leftLeg.zRotation, 0.45, 0.2)   // tuck while airborne
            rightLeg.zRotation = lerp(rightLeg.zRotation, -0.3, 0.2)
        } else if abs(horizontalSpeed) > 12 {
            runPhase += dt * (abs(horizontalSpeed) / 34)
            let swing = sin(runPhase) * 0.62
            leftLeg.zRotation = swing
            rightLeg.zRotation = -swing
        } else {
            leftLeg.zRotation = lerp(leftLeg.zRotation, 0, 0.25)
            rightLeg.zRotation = lerp(rightLeg.zRotation, 0, 0.25)
        }
        healthFill.xScale = max(0.001, health / maxHealth)
    }

    // MARK: Control

    func setThrusting(_ on: Bool) {
        if on == thrusting { return }
        thrusting = on
        flame.particleBirthRate = on ? 520 : 0
    }

    func aim(angle: CGFloat) {
        aimStored = angle
        facing = cos(angle) >= 0 ? 1 : -1
        bodyGroup.xScale = facing
        // Rotate the whole arm rig as one rigid unit; yScale = facing keeps the
        // elbows pointing down and the gun upright when aiming left.
        armRig.yScale = facing
        armRig.zRotation = angle
    }

    /// Muzzle tip in scene coordinates (accounts for scale, flip and aim).
    func muzzlePosition(in scene: SKScene) -> CGPoint {
        armRig.convert(CGPoint(x: weaponType.muzzleLength * gunScale, y: 0), to: scene)
    }

    func setName(_ name: String) {
        nameLabel.text = name
        self.name = name        // SKNode name too, so bullets can credit their owner
    }

    func setOverlayScale(_ s: CGFloat) {
        healthBar.setScale(s)
        nameLabel.setScale(s)
        nameLabel.position = CGPoint(x: 0, y: 120 + 22 * s)
        healthBar.position = CGPoint(x: 0, y: 108 + 14 * s)
    }

    // MARK: Damage / life

    func flashHit() {
        let flash = SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.04),
                                       .fadeAlpha(to: 1, duration: 0.12)])
        bodyGroup.run(flash); armRig.run(flash)
    }

    func heal(_ amount: CGFloat) {
        guard !isDead else { return }
        health = min(maxHealth, health + amount)
        healthFill.xScale = max(0.001, health / maxHealth)
    }

    @discardableResult
    func takeDamage(_ amount: CGFloat) -> Bool {
        guard !isDead else { return false }
        health = max(0, health - amount)
        flashHit()
        if health <= 0 { die(); return true }
        return false
    }

    private func die() {
        isDead = true
        setThrusting(false)
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = 0
        bodyGroup.isHidden = true
        armRig.isHidden = true
        healthBar.isHidden = true
    }

    func respawn(at point: CGPoint) {
        position = point
        health = maxHealth
        isDead = false
        bodyGroup.isHidden = false; bodyGroup.alpha = 1
        armRig.isHidden = false; armRig.alpha = 1
        healthBar.isHidden = false
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = team == .player ? PhysicsCategory.player : PhysicsCategory.enemy
    }

    /// Apply networked health / life for a remote player (no local physics).
    func applyNetwork(health: CGFloat, dead: Bool) {
        self.health = health
        healthFill.xScale = max(0.001, health / maxHealth)
        isDead = dead
        bodyGroup.isHidden = dead
        armRig.isHidden = dead
        healthBar.isHidden = dead
        if !dead { bodyGroup.alpha = 1; armRig.alpha = 1 }
    }
}
