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
signal rooms_changed                       # online: public room list updated
signal server_ready                        # online: connected to the relay server
signal online_error(code: String)          # online: room_full / bad_password / no_room
signal presence_changed(count: int)        # social: number of players online
signal players_received(data: Dictionary)  # social: a paginated online-players page
signal friends_received(items: Array)       # social: friends list
signal requests_received(items: Array)      # social: incoming friend requests
signal friend_req_in(from: Dictionary)      # social: a new request arrived
signal friend_accepted(who: Dictionary)     # social: someone accepted your request
signal profile_received(data: Dictionary)   # social: a player's details

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

# online (WebSocket relay server) — a second transport; LAN above is untouched
var SERVER_URL := "wss://chorpolice-relay.onrender.com"
var online := false
var is_owner := false
var room_code := ""
var rooms := {}                    # code -> {code, name, players, max, mode, map}
var _ws: WebSocketPeer
var _outbox := []
var _ws_hello_sent := false

# social (presence + friends)
var pid := ""                      # this player's persistent account id
var online_count := 0
var players_data := {}             # last paginated online-players page
var friends := []                  # [{pid, name, skin, online}]
var requests := []                 # incoming friend requests [{pid, name, skin}]

func _ready() -> void:
	_log_on = OS.has_environment("CP_NET_LOG")
	if OS.has_environment("CP_SERVER"):
		SERVER_URL = OS.get_environment("CP_SERVER")
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
	_leave_ws()                          # LAN match → leave the social server, use UDP
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
	_leave_ws()                          # LAN match → leave the social server, use UDP
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
	if _ws:
		_ws.close()
		_ws = null
	online = false
	is_owner = false
	room_code = ""
	rooms.clear()
	_outbox.clear()
	_ws_hello_sent = false
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
	_leave_ws()                          # LAN join → leave the social server, use UDP
	hosts.clear()
	_disc = PacketPeerUDP.new()
	_disc.bind(DISC_PORT)
	_disc.set_broadcast_enabled(true)     # to broadcast discovery probes
	hosts_changed.emit()

func stop_browse() -> void:
	if _disc and not is_host:
		_disc.close()
		_disc = null

# MARK: online (WebSocket relay) — same public API (players/send/start_match/signals)

func online_connect() -> void:
	if online and _ws:
		return                       # already connected/connecting — reuse the social session
	leave()
	online = true
	_started = false
	_ws_hello_sent = false
	_outbox.clear()
	players.clear()
	rooms.clear()
	_ws = WebSocketPeer.new()
	_ws.connect_to_url(SERVER_URL)
	if _log_on: print("[net] online connecting to ", SERVER_URL)

# Drop the social/online WebSocket and switch back to LAN (UDP) mode.
func _leave_ws() -> void:
	if _ws:
		_ws.close()
		_ws = null
	online = false
	is_owner = false
	room_code = ""
	rooms.clear()
	friends.clear()
	requests.clear()
	online_count = 0
	_outbox.clear()
	_ws_hello_sent = false

func create_room(is_public: bool, password: String, max_players: int, settings: Dictionary) -> void:
	_ws_send({"t": "create", "public": is_public, "password": password, "max": max_players, "settings": settings})

func list_rooms() -> void:
	_ws_send({"t": "list"})

func join_room(code: String, password := "") -> void:
	_ws_send({"t": "join", "code": code.strip_edges().to_upper(), "password": password})

# Leave the current room but stay connected to the server (so you can browse/join another).
func leave_room() -> void:
	_ws_send({"t": "leave"})
	active = false
	is_owner = false
	room_code = ""
	_started = false
	players.clear()
	peers_changed.emit()

# social
func req_players(page := 0) -> void: _ws_send({"t": "players", "page": page})
func friend_request(to: String) -> void: _ws_send({"t": "friend_req", "to": to})
func friend_accept(from: String) -> void: _ws_send({"t": "friend_accept", "from": from})
func friend_decline(from: String) -> void: _ws_send({"t": "friend_decline", "from": from})
func unfriend_player(p: String) -> void: _ws_send({"t": "unfriend", "pid": p})
func req_friends() -> void: _ws_send({"t": "friends"})
func req_requests() -> void: _ws_send({"t": "requests"})
func req_profile(p: String) -> void: _ws_send({"t": "profile", "pid": p})

func _ws_send(obj: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))
	else:
		_outbox.append(obj)

func _poll_ws() -> void:
	if not _ws:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_hello_sent:
			_ws_hello_sent = true
			_ws.send_text(JSON.stringify({"t": "hello", "pid": pid, "name": local_name,
				"skin": {"jr": jacket.r, "jg": jacket.g, "jb": jacket.b}}))
			for o in _outbox:
				_ws.send_text(JSON.stringify(o))
			_outbox.clear()
		while _ws.get_available_packet_count() > 0:
			var d = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if d is Dictionary:
				_handle_ws(d)
	elif st == WebSocketPeer.STATE_CLOSED:
		online = false
		active = false
		_ws = null
		if _log_on: print("[net] online connection closed")
		disconnected.emit()

func _handle_ws(d: Dictionary) -> void:
	match d.get("t", ""):
		"welcome":
			if _log_on: print("[net] online: server welcome")
			server_ready.emit()
		"rooms":
			rooms.clear()
			for r in d.get("rooms", []):
				rooms[str(r.get("code", ""))] = r
			rooms_changed.emit()
		"joined":
			_my_id = int(d.get("you", 1))
			room_code = str(d.get("code", ""))
			is_owner = _my_id == int(d.get("owner", 1))
			active = true
			_started = false
			_apply_online_roster(d.get("roster", {}))
			match_cfg = d.get("settings", {})
			if _log_on: print("[net] online: joined room ", room_code, " as id ", _my_id, " owner=", is_owner)
			connected.emit()
			peers_changed.emit()
		"roster":
			is_owner = _my_id == int(d.get("owner", _my_id))
			_apply_online_roster(d.get("roster", {}))
			peers_changed.emit()
		"settings":
			match_cfg = d.get("settings", {})
			peers_changed.emit()
		"start":
			if not _started:
				_started = true
				match_cfg = d.get("settings", match_cfg)
				match_started.emit(match_cfg)
		"m":
			message.emit(int(d.get("from", 0)), d.get("d", {}))
		"error":
			online_error.emit(str(d.get("code", "error")))
		"presence":
			online_count = int(d.get("count", 0))
			presence_changed.emit(online_count)
		"players":
			players_data = d
			players_received.emit(d)
		"friends":
			friends = d.get("items", [])
			friends_received.emit(friends)
		"requests":
			requests = d.get("items", [])
			requests_received.emit(requests)
		"friend_req":
			var f: Dictionary = d.get("from", {})
			var dup := false
			for r in requests:
				if str(r.get("pid", "")) == str(f.get("pid", "")):
					dup = true
			if not dup:
				requests.append(f)
			friend_req_in.emit(f)
			requests_received.emit(requests)
		"friend_ok":
			friend_accepted.emit(d.get("with", {}))
			req_friends()
		"profile":
			profile_received.emit(d)

func _apply_online_roster(r: Dictionary) -> void:
	players.clear()
	for sid in r:
		var id := int(sid)
		var p: Dictionary = r[sid]
		var sk: Dictionary = p.get("skin", {})
		players[id] = {"name": p.get("name", "P%d" % id), "color": 0,
			"jr": float(sk.get("jr", 0.3)), "jg": float(sk.get("jg", 0.5)), "jb": float(sk.get("jb", 0.9)),
			"team": int(p.get("team", -1)), "seen": _now()}

# MARK: process loop

func _process(delta: float) -> void:
	if online:
		_poll_ws()
		return
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
	if online:
		_ws_send({"t": "m", "d": msg})       # server relays to the other room members
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
	if online:
		match_cfg = cfg
		_ws_send({"t": "settings", "settings": cfg})
		_ws_send({"t": "start"})
		if not _started:
			_started = true
			match_started.emit(cfg)
		return
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
