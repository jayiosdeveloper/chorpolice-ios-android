## Net (autoload) — LAN multiplayer over plain UDP + JSON, so it interoperates with
## the iOS build (which uses the same wire format) AND Android↔Android. The host is a
## relay hub: clients send to the host, the host fans out to everyone. Discovery is a
## UDP broadcast beacon → hosts appear automatically (no manual IP).
extends Node

signal peers_changed
signal hosts_changed
signal message(sender_id: int, msg: Dictionary)
signal match_started(cfg: Dictionary)
signal connected
signal disconnected

const GAME_PORT := 7711
const DISC_PORT := 7712
const MAGIC := "CHORPOLICE/2"
const TIMEOUT := 6.0

var active := false
var is_host := false
var local_name := "Player"
var color_index := 0
var jacket := Color(0.27, 0.55, 0.97)     # for lobby avatar colour

var players := {}                  # id -> {name, color, jr, jg, jb, seen}
var hosts := {}                    # ip -> {ip, name, players, map, seen}
var match_cfg := {}

var _sock: PacketPeerUDP
var _disc: PacketPeerUDP
var _my_id := 0
var _next_id := 2
var _clients := {}                 # "ip:port" -> {id, ip, port, seen}
var _host_ip := ""
var _adv_t := 0.0
var _join_t := 0.0
var _welcomed := false
var _host_seen := 0.0              # client: last time we heard from the host (loss detection)
var _started := false
var _seq := 0
var _seen := {}                    # sender_id -> { seq: true } dedupe for reliable
var _log_on := false

func _ready() -> void:
	_log_on = OS.has_environment("CP_NET_LOG")
	if OS.has_environment("CP_QUIT"):
		get_tree().create_timer(float(OS.get_environment("CP_QUIT"))).timeout.connect(
			func() -> void: get_tree().quit())

func my_id() -> int:
	return _my_id

func name_of(id: int) -> String:
	return players.get(id, {}).get("name", "P%d" % id)

func color_of(id: int) -> int:
	return int(players.get(id, {}).get("color", id % 6))

func jacket_of(id: int) -> Color:
	var p: Dictionary = players.get(id, {})
	return Color(float(p.get("jr", 0.3)), float(p.get("jg", 0.5)), float(p.get("jb", 0.9)))

# MARK: host / join / leave

func host() -> bool:
	_sock = PacketPeerUDP.new()
	if _sock.bind(GAME_PORT) != OK:
		return false
	is_host = true
	active = true
	_started = false
	_my_id = 1
	_next_id = 2
	_clients.clear()
	players = {1: {"name": local_name, "color": color_index, "jr": jacket.r, "jg": jacket.g, "jb": jacket.b, "seen": _now()}}
	_disc = PacketPeerUDP.new()
	_disc.bind(DISC_PORT)                 # also receive client probes (so iOS-as-host works)
	_disc.set_broadcast_enabled(true)     # and broadcast beacons
	peers_changed.emit()
	return true

func join(ip: String) -> bool:
	_sock = PacketPeerUDP.new()
	if _sock.bind(_pick_port()) != OK:
		return false
	_sock.set_dest_address(ip, GAME_PORT)
	is_host = false
	active = true
	_welcomed = false
	_started = false
	_host_ip = ip
	_join_t = 0.0
	_host_seen = _now()
	return true

func leave() -> void:
	if _sock:
		_sock.close()
		_sock = null
	if _disc:
		_disc.close()
		_disc = null
	active = false
	is_host = false
	_welcomed = false
	_started = false
	_my_id = 0
	players.clear()
	_clients.clear()
	match_cfg.clear()
	peers_changed.emit()

func _pick_port() -> int:
	return 7720 + (randi() % 200)     # ephemeral-ish; real devices differ, 2 local instances rarely clash

# MARK: discovery (client browses)

func start_browse() -> void:
	hosts.clear()
	_disc = PacketPeerUDP.new()
	_disc.bind(DISC_PORT)
	_disc.set_broadcast_enabled(true)     # to broadcast discovery probes
	hosts_changed.emit()

func stop_browse() -> void:
	if _disc and not is_host:
		_disc.close()
		_disc = null

# MARK: process loop

func _process(delta: float) -> void:
	if _disc:
		if is_host:
			_adv_t -= delta
			if _adv_t <= 0.0:
				_adv_t = 1.0
				_send_beacon("255.255.255.255", DISC_PORT)
			_host_read_probes()           # reply unicast so clients find an iOS host too
		else:
			_adv_t -= delta
			if _adv_t <= 0.0:
				_adv_t = 1.0
				_send_probe()             # ask hosts to reply (covers hosts that can't broadcast)
			_read_discovery()
	if not active:
		return
	if not is_host:
		_join_t -= delta
		if _join_t <= 0.0:
			_join_t = 1.0                  # also a keep-alive so the host doesn't time us out
			_send_to_host({"t": "join", "name": local_name, "color": color_index,
				"jr": jacket.r, "jg": jacket.g, "jb": jacket.b}, 1)
	_read_game()
	_timeouts()

func _beacon_dict() -> Dictionary:
	return {"magic": MAGIC, "name": local_name, "players": players.size(), "map": int(match_cfg.get("map", 0))}

func _send_beacon(ip: String, port: int) -> void:
	_disc.set_dest_address(ip, port)
	_disc.put_packet(JSON.stringify(_beacon_dict()).to_utf8_buffer())

func _send_probe() -> void:
	_disc.set_dest_address("255.255.255.255", DISC_PORT)
	_disc.put_packet(JSON.stringify({"magic": MAGIC, "probe": true}).to_utf8_buffer())

# Host listens on the discovery port for client probes and replies UNICAST — this is
# what lets an iOS host (which cannot send to a broadcast address without the multicast
# entitlement) still be discovered: the client broadcasts the probe, the host unicasts back.
func _host_read_probes() -> void:
	while _disc.get_available_packet_count() > 0:
		var raw := _disc.get_packet()
		var ip := _disc.get_packet_ip()
		var port := _disc.get_packet_port()
		var d = JSON.parse_string(raw.get_string_from_utf8())
		if d is Dictionary and d.get("magic") == MAGIC and bool(d.get("probe", false)):
			_send_beacon(ip, port)

func _read_discovery() -> void:
	while _disc.get_available_packet_count() > 0:
		var raw := _disc.get_packet()
		var ip := _disc.get_packet_ip()
		var d = JSON.parse_string(raw.get_string_from_utf8())
		if d is Dictionary and d.get("magic") == MAGIC and not bool(d.get("probe", false)):
			hosts[ip] = {"ip": ip, "name": d.get("name", "Host"),
				"players": int(d.get("players", 1)), "map": int(d.get("map", 0)), "seen": _now()}
			hosts_changed.emit()
	var now := _now()
	var dropped := false
	for ip in hosts.keys():
		if now - float(hosts[ip]["seen"]) > 3.0:
			hosts.erase(ip); dropped = true
	if dropped:
		hosts_changed.emit()

func _read_game() -> void:
	while _sock and _sock.get_available_packet_count() > 0:
		var raw := _sock.get_packet()
		var ip := _sock.get_packet_ip()
		var port := _sock.get_packet_port()
		var d = JSON.parse_string(raw.get_string_from_utf8())
		if d is Dictionary:
			if is_host:
				_host_recv(d, ip, port)
			else:
				_client_recv(d)

# MARK: host receive

func _host_recv(d: Dictionary, ip: String, port: int) -> void:
	var key := "%s:%d" % [ip, port]
	match d.get("t", ""):
		"join":
			var is_new := not _clients.has(key)
			if is_new:
				var id := _next_id
				_next_id += 1
				_clients[key] = {"id": id, "ip": ip, "port": port, "seen": _now()}
				players[id] = {"name": d.get("name", "Player"), "color": int(d.get("color", 0)),
					"jr": float(d.get("jr", 0.3)), "jg": float(d.get("jg", 0.5)), "jb": float(d.get("jb", 0.9)), "seen": _now()}
				if _log_on: print("[net] +client ", id, " @", key)
				peers_changed.emit()
			_clients[key]["seen"] = _now()
			var cid: int = _clients[key]["id"]
			_send_addr(ip, port, {"t": "welcome", "id": cid, "peers": _roster()}, 2)   # re-welcome covers lost packets
			if is_new:
				_broadcast_raw({"t": "roster", "peers": _roster()}, 3)
		"m":
			if not _clients.has(key):
				return
			_clients[key]["seen"] = _now()
			var from: int = _clients[key]["id"]
			var gm: Dictionary = d.get("d", {})
			var rel := int(d.get("r", 0))
			if rel == 1 and _dup(from, int(d.get("s", 0))):
				return
			message.emit(from, gm)                       # host processes it
			# relay to all OTHER clients
			for k in _clients:
				if k == key:
					continue
				var c: Dictionary = _clients[k]
				_send_addr(c["ip"], c["port"], {"t": "m", "from": from, "d": gm, "r": rel, "s": d.get("s", 0)}, rel + 1)

func _roster() -> Dictionary:
	var r := {}
	for id in players:
		var p: Dictionary = players[id]
		r[str(id)] = {"name": p["name"], "color": p["color"], "jr": p["jr"], "jg": p["jg"], "jb": p["jb"]}
	return r

# MARK: client receive

func _client_recv(d: Dictionary) -> void:
	_host_seen = _now()
	match d.get("t", ""):
		"welcome":
			if not _welcomed:
				_my_id = int(d["id"])
				_apply_roster(d.get("peers", {}))
				_welcomed = true
				if _log_on: print("[net] welcomed as id ", _my_id)
				connected.emit()
				peers_changed.emit()
		"roster":
			_apply_roster(d.get("peers", {}))
			peers_changed.emit()
		"start":
			if not _started:
				_started = true
				match_cfg = d.get("cfg", {})
				match_started.emit(match_cfg)
		"m":
			var from := int(d.get("from", 0))
			var rel := int(d.get("r", 0))
			if rel == 1 and _dup(from, int(d.get("s", 0))):
				return
			message.emit(from, d.get("d", {}))

func _apply_roster(r: Dictionary) -> void:
	for sid in r:
		var id := int(sid)
		var p: Dictionary = r[sid]
		players[id] = {"name": p.get("name", "P%d" % id), "color": int(p.get("color", 0)),
			"jr": float(p.get("jr", 0.3)), "jg": float(p.get("jg", 0.5)), "jb": float(p.get("jb", 0.9)), "seen": _now()}

# MARK: send

func send(msg: Dictionary, reliable := false) -> void:
	if not active:
		return
	var rel := 1 if reliable else 0
	_seq += 1
	if is_host:
		# host fans out to all clients (its own message)
		for k in _clients:
			var c: Dictionary = _clients[k]
			_send_addr(c["ip"], c["port"], {"t": "m", "from": 1, "d": msg, "r": rel, "s": _seq}, rel + 1)
	else:
		_send_to_host({"t": "m", "d": msg, "r": rel, "s": _seq}, rel + 1)

func start_match(cfg: Dictionary) -> void:
	if _log_on: print("[net] START ", cfg)
	match_cfg = cfg
	_broadcast_raw({"t": "start", "cfg": cfg}, 6)
	match_started.emit(cfg)

func _send_to_host(d: Dictionary, times: int) -> void:
	for i in times:
		_sock.put_packet(JSON.stringify(d).to_utf8_buffer())

func _send_addr(ip: String, port: int, d: Dictionary, times: int) -> void:
	if not _sock:
		return
	_sock.set_dest_address(ip, port)
	for i in times:
		_sock.put_packet(JSON.stringify(d).to_utf8_buffer())

func _broadcast_raw(d: Dictionary, times: int) -> void:
	for k in _clients:
		var c: Dictionary = _clients[k]
		_send_addr(c["ip"], c["port"], d, times)

# MARK: helpers

func _dup(from: int, seq: int) -> bool:
	if not _seen.has(from):
		_seen[from] = {}
	if _seen[from].has(seq):
		return true
	_seen[from][seq] = true
	if _seen[from].size() > 128:
		_seen[from].clear()
	return false

func _timeouts() -> void:
	var now := _now()
	if is_host:
		var gone := []
		for k in _clients:
			if now - float(_clients[k]["seen"]) > TIMEOUT:
				gone.append(k)
		for k in gone:
			players.erase(_clients[k]["id"])
			_clients.erase(k)
			peers_changed.emit()
	elif active and _welcomed and now - _host_seen > TIMEOUT:
		# Host went silent — don't hang on the lobby/game; reset and notify.
		if _log_on: print("[net] host lost — disconnecting")
		leave()
		disconnected.emit()

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
