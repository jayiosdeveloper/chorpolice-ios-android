# Chor Police 3D (Godot 4.6) — one project for Android + iOS

The 3D rebuild of Chor Police: a real rigged + animated human soldier character, third-person
camera, 3D arenas with lighting / shadows / fog / weather, and the same lobby, friends,
LAN + online multiplayer, weapons, bots and settings as the 2D game.

`ChorPolice-Godot/` (2D) is untouched; this folder is a separate project.

## Open / run

1. Install **Godot 4.6** (standard build) from https://godotengine.org/download.
2. Open `ChorPolice3D/project.godot`. First open imports the soldier model (~10 s).
3. Press **F5**. Desktop controls: WASD move, click to capture the mouse, mouse = look,
   hold left button = fire, Space = jump / hold = jetpack, R = reload, G = grenade,
   1–9 = weapons, Esc = release the mouse.
4. Phone controls (Free Fire / CoD-Mobile style): left half = floating move stick,
   right half = **drag to look** (camera only, never fires), **FIRE** buttons (big one
   bottom-right, small one on the left edge so either thumb can shoot), **JUMP** (tap =
   jump, hold in the air = jetpack), **R** = reload, grenade button (tap = quick throw,
   hold + drag = aim, release = throw). An aim magnet eases the camera onto an enemy
   near the crosshair, and **Auto-fire** (Settings, on by default) shoots by itself while
   an enemy is in the crosshair. **Aim sensitivity** Low / Normal / High is in Settings.
   Left-handed mode mirrors everything. **Settings → Controls → Customize buttons** opens
   the HUD layout editor: drag FIRE / FIRE-left / JUMP / RELOAD / GRENADE anywhere, pick
   S / M / L size, RESET restores the defaults (stored in `user://chorpolice.cfg`, `[hud]`).

## Export

* **Android** — preset "Android" (same as the 2D game). Uses the Vulkan Mobile renderer;
  needs Android 8+ devices. Install the Android export template in the editor.
* **iOS** — preset "iOS". Fill in your Apple *Team ID* in the preset, export, then open the
  generated Xcode project and run on a device. The iOS SwiftUI app
  (`friends-timepass-game/`) is no longer needed once this ships.

## What is where

| File | Role |
| --- | --- |
| `scripts/game.gd` | The match: camera, twin-stick controls, weapons, grenades, pickups, bots, DM/TDM/CTF, net sync |
| `scripts/fighter.gd` | `Fighter` — CharacterBody3D for the local player, bots and remote avatars (acceleration movement, jetpack, footsteps, HP bar) |
| `scripts/human_model.gd` | `HumanModel` — the Mixamo soldier: Idle/Walk/Run clips, two-arm IK holding the gun, reload + recoil + shell ejection, death fall, team tint |
| `scripts/gun_model.gd` | `GunModel` — the nine guns built from primitives with muzzle / grip / foregrip / magazine markers |
| `scripts/aim_rig.gd` | `AimRig` — SkeletonModifier3D layering aim pitch, air pose, lean and flinch on the animation |
| `scripts/arena.gd` | Builds a map: sky, sun, ground, walls, crates, platforms, ramps, bunkers / towers / houses, trees, weather |
| `scripts/maps3d.gd` | The six arena layouts (metres). Names + themes come from `maps.gd` |
| `scripts/bullet3d.gd`, `rocket3d.gd`, `grenade3d.gd`, `pickup3d.gd` | Projectiles and supply crates |
| `scripts/ui.gd`, `logo.gd`, `menu_bg.gd` | Design system (colours, glass panels, buttons, glyphs), the procedural shield logo, the animated menu backdrop with the live 3D hero |
| `scripts/hud_kit.gd`, `hud_editor.gd` | The on-screen game buttons (shared art) and the drag-to-place HUD layout editor |
| `scripts/player.gd` | `Player` — the 2D **menu preview widget** that renders the 3D soldier (keeps lobby / settings / splash code unchanged) |
| `scripts/lobby.gd`, `settings*.gd`, `net.gd`, `audio*.gd`, `match_cfg.gd`, `weapons.gd`, `maps.gd`, `shapes.gd`, `menu_bg.gd`, `splash.gd` | Reused from the 2D game as-is |

## Multiplayer protocol

Same transports (LAN UDP relay, online WebSocket relay — `chorpolice-server`) and the same
message types (`state`, `fire`, `nade`, `hit`, `pickup`, `flag`). Positions are now
`x, y, z`, aim is `yaw, pit`, fire carries a direction `dx, dy, dz`. The server relays
opaque messages, so **no server change is needed**. Old 2D clients can't play against 3D
clients (different coordinates) — ship both platforms from this project.

## Credits

The soldier is the Mixamo "Vanguard" character (via the three.js examples) — see
`CREDITS.md`. Guns, maps and effects are procedural.

## Tuning knobs

* `HumanModel._hold_home` (per weapon) — where the gun sits in front of the chest; `AimRig` factors — torso pitch.
* `Fighter.SPEED / JUMP / THRUST / GRAVITY` — movement feel.
* `game.gd` `CAM_DIST / CAM_SIDE / CAM_UP`, `LOOK_SENS`, `MAGNET_RATE`, `AIM_ASSIST_DEG`, `MAG_SIZE / RELOAD_TIME`, `BOT_PROFILES`.
* `Arena.DEATH_Y` — pit death height. Map geometry lives in `maps3d.gd`.

## Deploying to the iPhone from the terminal

```bash
Godot --headless --path ChorPolice3D --export-debug "iOS" ChorPolice3D/build/ios/chorpolice.xcodeproj
xcrun devicectl device install app --device <device-id> ChorPolice3D/build/ios/chorpolice.ipa
xcrun devicectl device process launch --device <device-id> com.jay.chorpolice
```
The iOS preset carries the team id `5X7D9JA3UA` (Pratigya Gulani); Godot archives and
signs with Xcode automatically. `build/` is git-ignored.
