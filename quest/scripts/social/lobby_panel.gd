class_name LobbyPanel
extends VBoxContainer
var session: ShackSession
var heading: Label
var content: VBoxContainer
var name_value := "PLAYER"
var code_value := ""
var editing_name := false

func setup(value: ShackSession) -> void:
	session = value
	add_theme_constant_override("separation", 9)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 27)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(heading)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	session.changed.connect(refresh)
	refresh()

func button(parent: Control, text: String, callback: Callable, height := 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 25)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func text(parent: Control, value: String) -> void:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", 23)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	heading.text = session.status
	if session.online:
		text(content, "Share this room code: " + session.code)
		for member in session.members:
			var row := HBoxContainer.new()
			content.add_child(row)
			text(row, str(member.name) + ("  (HOST)" if member.id == session.host_id else ""))
			if session.self_id == session.host_id and member.id != session.self_id:
				var id: String = member.id
				button(row, "REMOVE", func(): session.send({"type": "kick", "id": id}), 36)
		if session.self_id == session.host_id:
			button(content, "UNLOCK ROOM" if session.locked else "LOCK ROOM", func(): session.send({"type": "lock", "locked": not session.locked}))
		button(content, "VOICE: ON  (TAP TO MUTE)" if session.voice.enabled else "VOICE: OFF  (TAP TO TALK)", func(): session.voice.enabled = not session.voice.enabled; refresh())
		button(content, "LEAVE ROOM", session.leave)
		text(content, "Point at a free machine or stool to claim it.\nVoice: you hear people from where they stand. Your microphone is only used while you are in a room.")
		return
	button(content, "NAME: " + name_value + ("  ✓ DONE" if editing_name else "  EDIT"), func(): editing_name = not editing_name; refresh())
	if editing_name:
		var keys := GridContainer.new()
		keys.columns = 10
		content.add_child(keys)
		for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -":
			var ch: String = letter
			button(keys, ch, func(): name_value = (name_value + ch).left(20); refresh(), 42)
		button(content, "DELETE LETTER", func(): name_value = name_value.left(maxi(0, name_value.length() - 1)); refresh())
	else:
		text(content, "JOIN CODE: " + (code_value if not code_value.is_empty() else "8 digits"))
		var keys := GridContainer.new()
		keys.columns = 6
		content.add_child(keys)
		for letter in "1234567890":
			var digit: String = letter
			button(keys, digit, func(): code_value = (code_value + digit).left(8); refresh(), 48)
		button(keys, "⌫", func(): code_value = code_value.left(maxi(0, code_value.length() - 1)); refresh())
		button(keys, "CLEAR", func(): code_value = ""; refresh())
		var row := HBoxContainer.new()
		content.add_child(row)
		button(row, "HOST ROOM", func(): session.connect_room("", name_value)).disabled = session.connecting
		button(row, "JOIN ROOM", func(): session.connect_room(code_value, name_value)).disabled = session.connecting or code_value.length() != 8
	text(content, "Up to six players. Nobody can join a locked or full room.\nTake turns on shared machines; each player has their own tracked avatar.")
