//
//  Bullet.swift
//  A glowing projectile. `visualOnly` bullets fly and spark but deal no damage.
//  `ownerName` identifies the shooter (for kill attribution in multiplayer).
//

import SpriteKit

final class Bullet: SKNode {

    let team: Robot.Team
    let damage: CGFloat
    let visualOnly: Bool
    var ownerName: String = ""

    init(team: Robot.Team, color: SKColor, damage: CGFloat = 11, visualOnly: Bool = false,
         flame: Bool = false) {
        self.team = team
        self.damage = damage
        self.visualOnly = visualOnly
        super.init()

        if flame {
            // A soft fire puff that swells and fades as it flies.
            let puff = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 34, height: 34))
            puff.color = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
            puff.colorBlendFactor = 1; puff.blendMode = .add; puff.alpha = 0.9
            addChild(puff)
            puff.setScale(0.5)
            puff.run(.group([.scale(to: 1.5, duration: 0.3), .fadeAlpha(to: 0.25, duration: 0.3)]))
        } else {
            let glow = SKSpriteNode(texture: Art.softCircle, size: CGSize(width: 28, height: 16))
            glow.color = color; glow.colorBlendFactor = 1; glow.blendMode = .add; glow.alpha = 0.75
            addChild(glow)

            let core = SKSpriteNode(color: color, size: CGSize(width: 18, height: 5))
            addChild(core)
        }

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 16, height: 5))
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.bullet
        body.collisionBitMask = 0
        // Always contact the opposing side so shots STOP on avatars instead of passing
        // through. `visualOnly` (your own networked shots) just don't deal damage —
        // the target's own device applies the hit (victim-authoritative).
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.wall |
            (team == .player ? PhysicsCategory.enemy : PhysicsCategory.player)
        body.usesPreciseCollisionDetection = true
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
