## MatchCfg (autoload) — the chosen map + match settings, shared across scenes.
## Grows over the milestones (mode/teams/timer/etc.); for G2 it just holds the map.
extends Node

var map_index := 0
var mode := 0          # 0 = deathmatch, 1 = team deathmatch, 2 = capture the flag
var target := 10
var minutes := 5
var unlimited_ammo := false
var bot_level := 1
var is_multiplayer := false

# Multiplayer (G4) — filled by the lobby / startGame message.
var local_team := -1               # -1 = FFA, 0 = Team A, 1 = Team B
var assignments := {}              # str(peer_id) -> team (0/1), team modes only

func apply_start(cfg: Dictionary) -> void:
	map_index = int(cfg.get("map", 0))
	mode = int(cfg.get("mode", 0))
	target = int(cfg.get("target", 10))
	minutes = int(cfg.get("minutes", 5))
	unlimited_ammo = bool(cfg.get("unlimited", false))
	assignments = cfg.get("assign", {})
