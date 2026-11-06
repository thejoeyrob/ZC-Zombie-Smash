class_name ShackSession
extends Node
signal changed
var main: Node3D
var socket: WebSocketPeer
var online := false
var connecting := false
var self_id := ""
var host_id := ""
var code := ""
var status := "Solo — host or join a room"
var locked := false
var members: Array = []
var owners := {}
var guests := {}
var awaiting_spawn := false
var granted := false
var pending_station := ""
var pending_seat := -1
var request_data := {}
var elapsed := 0.0
var send_elapsed := 0.0
var last_rx := 0.0
var nudge_prev := [false, false]
var endpoint := ""

func setup(owner_node: Node3D) -> void:
	main = owner_node
	var config_path := "res://config/shack.json"
	if FileAccess.file_exists(config_path):
		var config = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if config is Dictionary:
			endpoint = str(config.get("endpoint", ""))

func connect_room(room_code: String, player_name: String) -> void:
	if online or connecting:
		return
	if not endpoint.begins_with("wss://") and not (OS.is_debug_build() and endpoint.begins_with("ws://127.0.0.1:")):
		status = "Online server not configured. See Claude setup instructions."
		changed.emit()
		return
	request_data = {"type": "create" if room_code.is_empty() else "join", "protocol": 1,
		"name": player_name.left(20), "skin": main.avatar.skin_id, "code": room_code}
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 65536
	socket.outbound_buffer_size = 65536
	var err := socket.connect_to_url(endpoint)
	if err != OK:
		status = "Connection failed (%d)" % err
		changed.emit()
		return
	connecting = true
	elapsed = 0
	last_rx = 0
	status = "Connecting…"
	changed.emit()

func send(data: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func leave() -> void:
	send({"type": "leave"})
	_disconnect("Left room. Playing solo.")

func _disconnect(message: String) -> void:
	if socket != null:
		socket.close(1000, "Leaving")
	socket = null
	online = false
	connecting = false
	status = message
	self_id = ""
	members.clear()
	owners.clear()
	pending_station = ""
	pending_seat = -1
	for g in guests.values():
		g.queue_free()
	guests.clear()
	var board: BoardGame = main.room.board_game
	for p in board.players:
		board.leave_seat(p.occupant)
	board.authority = true
	board.local_id = "local"
	board.phase = "wait"
	board.remaining = 1.6
	main.room.pinball.table.network_remote = false
	main.room.pinball2.table.network_remote = false
	main._stand_up()
	main._set_locked(false)
	changed.emit()

func _process(delta: float) -> void:
	if socket == null:
		return
	elapsed += delta
	last_rx += delta
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED or (connecting and elapsed > 10) or (online and last_rx > 15):
		_disconnect("Connection lost. Playing solo; host again to reconnect.")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not request_data.is_empty():
		send(request_data)
		request_data.clear()
	while socket != null and socket.get_available_packet_count() > 0:
		var raw := socket.get_packet()
		if raw.size() > 16384:
			continue
		var data = JSON.parse_string(raw.get_string_from_utf8())
		if data is Dictionary:
			last_rx = 0
			_receive(data)

func _receive(d: Dictionary) -> void:
	match d.get("type", ""):
		"welcome":
			self_id = str(d.id)
			online = true
			connecting = false
			main._set_locked(false)
			main._stand_up()
			main.room.board_game.authority = false
			main.room.board_game.local_id = self_id
			awaiting_spawn = true
		"room":
			code = str(d.code)
			host_id = str(d.host)
			locked = bool(d.locked)
			members = d.members
			owners = d.owners
			status = "ROOM %s  •  %d / 6" % [code, members.size()]
			if awaiting_spawn:
				for i in range(members.size()):
					if members[i].id == self_id:
						main._place_player(Vector3((i % 3 - 1) * 0.6, 0, 0.45 + int(i / 3) * 0.65), ArcadeRoom.ARC_CENTRE)
				awaiting_spawn = false
			_sync_guests()
			for i in range(main.machines.size()):
				main.machines[i].set_lock_light(owners.has("m%d" % i))
			for pair in [["pinball", main.room.pinball], ["pinball2", main.room.pinball2]]:
				pair[1].table.network_remote = owners.get(pair[0], "") != self_id
			changed.emit()
		"board":
			main.room.board_game.apply_snapshot(d.state)
		"pose":
			if guests.has(d.id):
				guests[d.id].receive_pose(d.pose)
		"pin":
			if d.station in ["pinball", "pinball2"] and owners.get(d.station, "") != self_id:
				var pb: Pinball = main.room.pinball if d.station == "pinball" else main.room.pinball2
				pb.table.apply_snapshot(d.state)
		"granted":
			if str(d.station) != pending_station:
				return
			pending_station = ""
			granted = true
			if d.station in ["pinball", "pinball2"]:
				var pb: Pinball = main.room.pinball if d.station == "pinball" else main.room.pinball2
				pb.table.reset_game()
			main._set_locked(false)
			main._choose(str(d.station))
			granted = false
		"seated":
			if int(d.seat) != pending_seat:
				return
			pending_seat = -1
			granted = true
			main._sit(main.room.seats[int(d.seat)])
			granted = false
		"error":
			pending_station = ""
			pending_seat = -1
			status = str(d.get("message", "Unable to complete action"))
			if not online:
				_disconnect(status)
			else:
				changed.emit()
		"ended":
			_disconnect(str(d.get("message", "Room ended")))

func _sync_guests() -> void:
	var ids: Array = []
	for member in members:
		if member.id == self_id:
			continue
		ids.append(member.id)
		if not guests.has(member.id):
			var guest := RemoteGuest.new()
			main.add_child(guest)
			guest.build(str(member.name), str(member.skin), main.font)
			guests[member.id] = guest
		elif guests[member.id].avatar.skin_id != str(member.skin):
			guests[member.id].avatar.apply_skin(str(member.skin))
	for id in guests.keys():
		if not id in ids:
			guests[id].queue_free()
			guests.erase(id)

func owns(station: String) -> bool:
	return not online or owners.get(station, "") == self_id

func claim(station: String) -> void:
	if pending_station == station:
		return
	pending_station = station
	status = "Requesting station…"
	send({"type": "claim", "station": station})
	changed.emit()

func sit(seat: int) -> void:
	pending_seat = seat
	send({"type": "sit", "seat": seat})

func tick(hands: Array, delta: float) -> void:
	# Controller B / X nudges only the pinball owned by the player, on a rising edge.
	for side in range(2):
		var down: bool = hands[side].active and hands[side].b
		if down and not nudge_prev[side] and not main.menu.open:
			for pair in [["pinball", main.room.pinball], ["pinball2", main.room.pinball2]]:
				if owns(pair[0]) and main._head_floor().distance_to(pair[1].stand_world()) < 1.5:
					pair[1].table.nudge(-1 if side == 0 else 1)
		nudge_prev[side] = down
	if not online:
		return
	send_elapsed += delta
	if send_elapsed < 0.1:
		return
	send_elapsed = 0
	var curls: Array = []
	for h in hands:
		curls.append_array([float(h.trig_val), float(h.grip_val), clampf(float(h.thumb), 0, 1)])
	send({"type": "pose", "pose": {"head": pack(main.cam.global_transform), "left": pack(hands[0].vis_xf), "right": pack(hands[1].vis_xf),
		"wrists": [[main.avatar.wrists[0].x, main.avatar.wrists[0].y, main.avatar.wrists[0].z], [main.avatar.wrists[1].x, main.avatar.wrists[1].y, main.avatar.wrists[1].z]],
		"curls": curls, "active": [bool(hands[0].active), bool(hands[1].active)], "seated": bool(main.seated), "scale": float(main.avatar.scale_k)}})
	for pair in [["pinball", main.room.pinball], ["pinball2", main.room.pinball2]]:
		if owns(pair[0]):
			if main._head_floor().distance_to(pair[1].stand_world()) > 2.0:
				send({"type": "release"})
			else:
				send({"type": "pin", "station": pair[0], "state": pair[1].table.snapshot()})

static func pack(xf: Transform3D) -> Array:
	var q := xf.basis.orthonormalized().get_rotation_quaternion()
	return [xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w]
