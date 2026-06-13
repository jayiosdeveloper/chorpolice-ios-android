//
//  Joystick.swift
//  A floating on-screen joystick. Reports a normalized vector in [-1, 1].
//

import SpriteKit

final class Joystick: SKNode {

    private let radius: CGFloat = 48
    private let base = SKShapeNode(circleOfRadius: 48)
    private let knob = SKShapeNode(circleOfRadius: 23)

    /// Current stick direction. dx/dy each range from -1 to 1.
    private(set) var vector: CGVector = .zero

    override init() {
        super.init()

        base.fillColor = SKColor.white.withAlphaComponent(0.10)
        base.strokeColor = SKColor.white.withAlphaComponent(0.28)
        base.lineWidth = 2
        addChild(base)

        knob.fillColor = SKColor.white.withAlphaComponent(0.32)
        knob.strokeColor = SKColor.white.withAlphaComponent(0.5)
        knob.lineWidth = 1
        addChild(knob)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show the joystick at a touch point and reset the knob to centre.
    func activate(at point: CGPoint) {
        position = point
        knob.position = .zero
        vector = .zero
        isHidden = false
    }

    /// Move the knob toward a touch point, clamped to the base radius.
    func update(to point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > radius {
            let angle = atan2(dy, dx)
            knob.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        } else {
            knob.position = CGPoint(x: dx, y: dy)
        }
        vector = CGVector(dx: knob.position.x / radius, dy: knob.position.y / radius)
    }

    /// Hide the joystick and zero the input.
    func deactivate() {
        knob.position = .zero
        vector = .zero
        isHidden = true
    }
}
