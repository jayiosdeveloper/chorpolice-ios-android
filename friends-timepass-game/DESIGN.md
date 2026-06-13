# Desi Militia — Technical Design Doc

A 2D arena shooter (Mini Militia–inspired) for a friends group. Jetpack movement,
dual-stick controls, guns, deathmatch/team modes. Local multiplayer over
WiFi/Bluetooth — no internet, no server.

---

## 1. Platforms & compatibility
- **Targets:** iPhone + iPad + Mac, one portable codebase. Cross-play wanted
  (iPhone vs iPad vs Mac in the same match).
- **Minimum deployment: iOS 15.0** — REQUIRED. Test devices include iPhone 7 / 7 Plus,
  which max out at iOS 15 (they cannot run iOS 16). macOS 12+ when the Mac target is added.
- **Orientation:** landscape only (gameplay).
- **Build order:** iOS-first (run on the iPhones), code kept Mac-ready, macOS target added later.

## 2. Tech stack
| Layer | Responsibility | Framework |
|---|---|---|
| App shell / menus / lobby | navigation, UI | SwiftUI |
| Gameplay (render + physics, 60fps) | the actual game | SpriteKit via SwiftUI `SpriteView` |
| Local multiplayer | discovery + transport, ~8 peers | MultipeerConnectivity |
| Controllers (optional) | Bluetooth gamepads | GameController |

## 3. Module layout
```
DesiMilitia/
├── DesiMilitiaApp.swift        @main entry
├── ContentView.swift           root screen router (menu ⇄ game)
├── Menu/        MainMenuView · LobbyView
├── Game/
│   ├── GameView.swift          SwiftUI → SpriteView wrapper
│   ├── GameScene.swift         SpriteKit scene, game loop, physics
│   ├── Player.swift            player node + state
│   ├── Bullet.swift · Weapon.swift · PowerUp.swift
│   └── HUD/ HUDNode.swift
├── Input/
│   ├── GameInput.swift         protocol: moveVector, aimVector, isFiring, isJetpacking
│   ├── TouchInput.swift        #if os(iOS)   joysticks
│   ├── KeyboardMouseInput.swift#if os(macOS) WASD + mouse
│   └── ControllerInput.swift   GameController (both)
├── Networking/
│   ├── MultipeerManager.swift  advertise / browse / connect
│   ├── GameMessage.swift       Codable: input, snapshot, spawn, hit, score
│   └── NetworkSync.swift       host simulation + client interpolation
└── Models/  GameState · PlayerState
```

## 4. Input abstraction
A `GameInput` protocol feeds the game core normalized values
(`moveVector`, `aimVector`, `isFiring`, `isJetpacking`). The core never knows the
source. Implementations: touch joysticks (iOS), keyboard+mouse (Mac), gamepad (both).

| Platform | Controls |
|---|---|
| iPhone / iPad | on-screen move joystick + aim joystick + fire button |
| Mac | WASD / arrows = move, W or Space = jetpack, mouse = aim, click = fire |
| both (bonus) | Bluetooth controller (PS5 / Xbox) via GameController |

## 5. Gameplay entities & physics
- **Player:** position, velocity, health, facing, jetpack fuel, current weapon.
- **Bullet, Weapon** (fire rate / damage / ammo), **PowerUp**, **Platform**.
- **Physics (SpriteKit):** gravity pulls down; jetpack applies upward thrust while held;
  players collide with platforms and ground; bullets are kinematic, detect hits via
  contact bitmasks.

## 6. Networking model (Phase 3–4)
- **Topology:** one device is Host (authoritative simulation); others are clients.
- **Messages (Codable → Data):** `playerInput`, `stateSnapshot`, `spawn`, `hit`, `score`.
- **Sync:** host simulates and broadcasts snapshots ~15–20/sec; clients interpolate
  between snapshots and run client-side prediction for their own player.
- **Discovery:** `MCNearbyServiceAdvertiser` (host) + `MCNearbyServiceBrowser` (join),
  serviceType `"desi-militia"`.
- **Info.plist:** `NSLocalNetworkUsageDescription` + `NSBonjourServices`
  (`_desi-militia._tcp`, `_desi-militia._udp`).

## 7. Roadmap (each phase = a runnable milestone)
- **P0 — Setup:** Xcode project, settings, blank app runs on device.
- **P1 — Solo playable:** SpriteKit scene, one player, joystick, jetpack, gravity, platforms.
- **P2 — Combat:** shooting, bullets, weapon, health, hit detection, respawn, HUD.
- **P3 — Connect 2 devices:** MultipeerConnectivity host/join, peer list, position sync.
- **P4 — Full multiplayer:** sync shoot/hit/health/respawn + lag handling.
- **P5 — Bigger app:** maps, modes, skins, weapon unlocks, sound, chat, polish, macOS target.

## 8. Open decisions
- Art: start with placeholder shapes/colors, swap in sprites later.
- Max players per match: start at 2, scale to 4–8.
- When to enable the macOS target: after the game is solid on iPhone.
