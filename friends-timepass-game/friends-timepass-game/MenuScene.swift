//
//  MenuScene.swift
//  Animated SpriteKit background for the main menu: dusk skyline, drifting
//  embers, and two robots idly jetpack-hopping.
//

import SpriteKit

final class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.10, blue: 0.20, alpha: 1)

        let sky = SKSpriteNode(texture: Art.skyTexture(size: size))
        sky.size = CGSize(width: size.width * 1.25, height: size.height * 1.25)
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -100
        addChild(sky)

        var x: CGFloat = -40
        while x < size.width + 60 {
            let bw = CGFloat.random(in: 50...120)
            let bh = CGFloat.random(in: 90...260)
            let b = SKShapeNode(rectOf: CGSize(width: bw, height: bh), cornerRadius: 4)
            b.fillColor = SKColor(red: 0.13, green: 0.11, blue: 0.24, alpha: 1)
            b.strokeColor = .clear
            b.position = CGPoint(x: x + bw / 2, y: 64 + bh / 2 - 20)
            b.zPosition = -80
            addChild(b)
            x += bw + CGFloat.random(in: 20...60)
        }

        let ground = SKSpriteNode(color: SKColor(red: 0.12, green: 0.13, blue: 0.20, alpha: 1),
                                  size: CGSize(width: size.width, height: 70))
        ground.position = CGPoint(x: size.width / 2, y: 35)
        ground.zPosition = -70
        addChild(ground)

        let embers = makeEmbers()
        embers.position = CGPoint(x: size.width / 2, y: -10)
        embers.particlePositionRange = CGVector(dx: size.width, dy: 10)
        embers.zPosition = -60
        addChild(embers)

        addRobot(colorIndex: 0, at: CGPoint(x: size.width * 0.34, y: 120), faceRight: true, delay: 0.0)
        addRobot(colorIndex: 1, at: CGPoint(x: size.width * 0.66, y: 120), faceRight: false, delay: 0.8)
    }

    private func addRobot(colorIndex: Int, at p: CGPoint, faceRight: Bool, delay: TimeInterval) {
        let r = Robot(team: .player, colorIndex: colorIndex)
        r.physicsBody = nil
        r.position = p
        r.setName("")
        r.aim(angle: faceRight ? 0 : .pi)
        r.flame.targetNode = self
        r.zPosition = 10
        addChild(r)

        let up = SKAction.moveBy(x: 0, y: 70, duration: 0.7); up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -70, duration: 0.9); down.timingMode = .easeIn
        let on = SKAction.run { r.setThrusting(true) }
        let off = SKAction.run { r.setThrusting(false) }
        let loop = SKAction.sequence([on, up, off, down, .wait(forDuration: 1.3)])
        r.run(.sequence([.wait(forDuration: delay), .repeatForever(loop)]))
    }

    private func makeEmbers() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Art.softCircle
        e.particleBirthRate = 14
        e.particleLifetime = 6
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 30
        e.particleSpeedRange = 20
        e.particleAlpha = 0.5
        e.particleAlphaSpeed = -0.08
        e.particleScale = 0.08
        e.particleScaleRange = 0.05
        e.particleColor = SKColor(red: 1, green: 0.7, blue: 0.4, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        return e
    }
}
