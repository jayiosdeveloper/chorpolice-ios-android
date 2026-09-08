# Chor Police 3D — Handoff / Continuity Doc

> Aa file biji chat / biji session ma kaam continue karva maate che. Badhi jaruri details
> ahi che. (Reply in **Gujlish**; big scope pahela confirm karvu.)

**Project:** `ChorPolice3D/` — Godot **4.6** (Mobile renderer), single codebase for **Android + iOS**.
3D rebuild of the older 2D Chor Police. Third-person (TPS) arena shooter, twin-stick touch controls.
Git repo root: `/Users/jayprajapati/Documents/JAY/GAME1` · remote `github.com/jayiosdeveloper/chorpolice-ios-android` · branch `main`.

---

## 1. Toolchain / how to run (Godot NOT installed on this Mac)

- Godot editor is a **downloaded binary in the session scratchpad** (re-download each fresh session if wiped):
  - Download: `curl -L -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.6-stable/Godot_v4.6-stable_macos.universal.zip && unzip -q godot.zip` → `Godot.app`.
  - Export templates 4.6.stable persist in `~/Library/Application Support/Godot/export_templates/4.6.stable/`.
- **Import** (build the `.godot` cache) before rendering: `Godot.app/Contents/MacOS/Godot --headless --path . --import`
- The harmless compile warning `Identifier not found: MatchCfg` in standalone `--script` runs is expected (autoload not injected there).

## 2. Headless testing workflow (how we "check" without a device)

iOS **Simulator canNOT run Godot** (simulator slice of `libgodot.a` has no `_main`) → test via headless PNG renders, deploy to the physical iPhone only for live feel.

- **Lobby/menu/settings screenshot** — `scratchpad/shot.gd`:
  `CP_SCENE="res://scenes/Lobby.tscn" CP_WAIT=5 CP_OUT=out.png Godot --path . --script shot.gd --resolution 1480x720`
- **In-game screenshot** — `scratchpad/shot_game.gd` (sets MatchCfg via `/root/MatchCfg`, boots Game.tscn; after 1s forces `player.model.fire_pose()`+ADS so the gun raises for an aiming view).
- **Gun tuning envs** (read live in `human_model.gd`): `CP_GUNROT="x,y,z"`, `CP_GUNPOS="x,y,z"` override the squad gun mount for quick render iteration.

## 3. Deploy to iPhone (works from terminal)

`scratchpad/deploy.sh <path-to-Godot-binary>` does: export iOS Xcode project → patch Info.plist to **landscape both ways** → codesign → zip → `xcrun devicectl install/launch`.
- Device UDID: `70EAA891-0325-5A31-BAF6-3CC00D6D2697` (iPhone 17), bundle `com.jay.chorpolice`.
- Signing cert hash: `1B5865D4ABBAB1400E816B0FD980DA1B3CEE7568`.
- Result IPA ~865MB (all real assets bundled).

## 4. Player character (MOST-TOUCHED area)

- Local player = **`black_squad`** rigged Meshy/Mixamo FBX at `assets/real/chars/black_squad/black_squad.fbx` (+ `anims/*.fbx` merged clips). Bots still use the old procedural soldier.
- Driven by **`scripts/human_model.gd`** `use_squad` path:
  - Gun mount: `BoneAttachment3D` on RightHand → a `top_level` `gun_hold` follows the bone; child `_gun_mount` holds the GunModel.
  - **Current gun transform:** `SQUAD_GUN_ROT = (90, 0, 180)`, `SQUAD_GUN_POS = (0, 0, 0.14)` — *user's latest pick; verify on device.* (History: user rejected -90/180 flips; "keep hands as the animation poses them, only move the GUN". NO IK on hands.)
  - Gun local space (see `gun_model.gd` line 5): **barrel/muzzle = −Z, up = +Y, right = +X**.
  - Anims merged + made in-place (hips x/z stripped) in `_merge_squad_anims()`/`_make_in_place()`. States: idle/walk/run/jump/fall/land/death/fire. Reload = procedural gun-dip stub (needs a real Mixamo "Reloading" FBX).
  - Materials brightened (metallic 0, roughness ≥0.6) to fix a black look.
- **Design rule (user):** keep all movement/anim/gun logic **generic** so any future rigged character works. Facing: body turns toward move direction unless firing/ADS; backpedal keeps camera facing.

## 5. Lobby (Free Fire / BGMI style) — `scripts/lobby.gd` + `scripts/menu_bg.gd` + `scripts/logo3d.gd`

- **Logo3D** (`scripts/logo3d.gd`): real 3D extruded metal wordmark ("CHOR" orange / "POLICE" steel-blue) in a SubViewport, with a sweeping specular spotlight + float/tilt animation. Used top-left on MAIN.
- **Drag-to-rotate hero:** `MenuBg.set_drag(true/false)`. The hero lives in the MenuBg **CanvasLayer (-5) behind** the UI. CRITICAL: lobby scene-root and `root` Control are set `MOUSE_FILTER_IGNORE` so drags reach the hero; buttons (STOP) still work. Momentum + idle auto-spin in `MenuBg._process`.
- Layout: big centered hero on a glow disc, bottom **HOST / JOIN / ONLINE** tiles + big green **START** (Practice). Top-right premium profile chip + gear (cyan accent). Corner Logo widget hidden on MAIN (Logo3D replaces it).
- **Safe-area insets:** `_compute_safe()` converts `DisplayServer.get_display_safe_area()` to canvas units → `_safe_l/_safe_r` so nothing sits under the notch. UI sizes were enlarged (phone looked "small").
- Disc-clipping fixed by lowering the MenuBg camera aim (`look_at y ≈ 0.82`).

## 6. Locker (Settings → CHARACTER) — `scripts/settings_screen.gd` + `scripts/settings.gd`

- Old colour/army/custom grids **removed**. CHARACTER tab = **character selection grid**.
- `Settings.CHARACTERS` registry: `{id,name,tag,tier,col,owned}`. Only **Bravo owned** (real black_squad); Ghost/Vector/Blaze/Nova/Raptor are **locked slots** (fill as rigged models are added). Selected id saved as `Settings.char_id`.
- Cards = finished portrait tiles: tier gradient + monogram watermark + tier ribbon (EPIC/RARE/LEGENDARY) + name/role scrim footer + **✓ EQUIPPED** badge / 🔒 dim overlay. Owned count "N/6". Bottom fade over the scroll.
- Center: drag-rotate 3D preview + glass name/role plate ("Name · ROLE · TIER"). Left tab rail with active cyan stripe. Header "LOCKER / EQUIP YOUR OPERATOR".
- Same drag mechanism as lobby (scene-root `MOUSE_FILTER_IGNORE`, `bg.set_drag(true)`).

## 7. Key files map

| File | What |
|---|---|
| `scripts/human_model.gd` | squad/soldier/meshy character model, gun mount, anims |
| `scripts/fighter.gd` | CharacterBody3D player/bot/remote |
| `scripts/game.gd` | match loop, muzzle flash, bullets, facing, map place |
| `scripts/lobby.gd` | main menu + host/join/online + map-pick + social |
| `scripts/menu_bg.gd` | animated 3D hero backdrop + drag-rotate |
| `scripts/logo3d.gd` | 3D animated metal wordmark |
| `scripts/settings_screen.gd` | Locker (character/controls/audio/match tabs) |
| `scripts/settings.gd` | persisted prefs + CHARACTERS registry + char_id |
| `scripts/arena.gd` / `maps3d.gd` / `realtex.gd` | 6 real maps, PBR textures, HDRI, props |
| `scripts/gun_model.gd` | procedural guns (muzzle/grip/foregrip markers) |
| `scripts/bullet3d.gd` | tracer/flame projectile |
| `scenes/*.tscn` | Splash, Lobby, Settings, Game, HudEditor, IconGen |

## 8. Assets — `assets/real/`

`tex/` (ambientCG + Poly Haven PBR), `sky/*.hdr` (HDRIs), `models/*` (props/trees/houses, downscaled to 1K to fix a 2.6GB OOM crash), `chars/black_squad/`. Rule: **use only downloaded real/CC0 assets** (no procedural "block" look); user downloads assets themselves — provide `curl`/`gltf-transform` (`npx @gltf-transform/cli resize`) commands, then integrate.

## 9. Pending / next ideas

- [ ] Verify gun `(90,0,180)/(0,0,0.14)` on device; fine-tune GUN only (never body/hands).
- [ ] Real **Reload** animation (Mixamo "Reloading" FBX) — replace procedural stub.
- [ ] More **rigged characters** for the locker (Mixamo/Meshy) → flip `owned:true` + map id→model in `human_model.gd`.
- [ ] **FPS-template assets** (see below) — VFX/SFX are the biggest win.
- [ ] "9 GUNS / 6 MAPS" lobby pills are hardcoded.
- [ ] Android APK export for the 3D project (only iOS deployed so far).

## 10. External asset opportunity — GodotFPS-Template (MIT)

`github.com/bukkbeek/GodotFPS-Template` (Godot 4.6, **MIT**, ~17MB). It's **FPS** (we're TPS) so FP arms/systems don't port, but these assets do:
- ⭐ **VFX**: muzzle flash (GPUParticles3D+light), bullet-hole **Decal**, blood splash, explosions (5 particle systems) — fixes the "fake bullet/fire" complaint. Note: our renderer is **Mobile** (template is Forward+) — verify Decal/particles on Mobile.
- ⭐ **SFX**: gun fire/reload/switch/empty, explosion, footstep, door, zombie sounds.
- ✅ **Undead zombie** (rigged+animated glb) → possible enemy type.
- ✅ **Props glb** (barrel/crate/door), exploding barrel + auto-door systems → map detail.
- ⚠️ Drivable **jeep** vehicle (optional, needs integration).

## 11. User prefs (important)

- Reply in **Gujlish**; confirm before big scope changes.
- Provide terminal **download commands** rather than downloading assets (saves the user's limits); user runs them.
- Git: commit co-author `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`; PR footer `🤖 Generated with [Claude Code]`.
- Don't edit the old 2D project; work only in `ChorPolice3D/`.
