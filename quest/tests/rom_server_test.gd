extends SceneTree
## Starts the Wi-Fi ROM installer and talks to it from inside the same program (a small HTTP client), checking PIN, file types and saving.
func _request(method: String, path: String, body := PackedByteArray()) -> String:
	var c := StreamPeerTCP.new()
	if c.connect_to_host("127.0.0.1", RomServer.PORT) != OK:
		return "CONNECT FAILED"
	var t := 0.0
	while c.get_status() == StreamPeerTCP.STATUS_CONNECTING and t < 3.0:
		c.poll()
		await process_frame
		t += 0.016
	var head := "%s %s HTTP/1.1\r\nHost: x\r\nContent-Length: %d\r\n\r\n" % [method, path, body.size()]
	c.put_data(head.to_utf8_buffer())
	var sent := 0
	while sent < body.size():                           # in pieces, with a frame between, so the server (in this same program) can keep reading
		var piece := body.slice(sent, mini(sent + 262144, body.size()))
		var r := c.put_partial_data(piece)
		sent += int(r[1])
		await process_frame
	var out := PackedByteArray()
	t = 0.0
	while t < 12.0:
		c.poll()
		var n := c.get_available_bytes()
		if n > 0:
			out.append_array(c.get_data(n)[1])
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
		t += 0.016
	var text := out.get_string_from_utf8()
	return text.split("\r\n\r\n", true, 1)[1] if text.contains("\r\n\r\n") else text


func _initialize() -> void:
	var srv := RomServer.new()
	get_root().add_child(srv)
	DirAccess.make_dir_recursive_absolute("user://roms")
	for f in DirAccess.open("user://roms").get_files():
		DirAccess.remove_absolute("user://roms/" + f)
	var ok := srv.start()
	await process_frame
	var bad := 0
	var rom := PackedByteArray()
	rom.resize(4096)
	for i in range(rom.size()):
		rom[i] = (i * 31) % 251
	var page := await _request("GET", "/")
	print("page has upload form: ", page.contains("JW EDS ARCADE OS"))
	if not page.contains("JW EDS ARCADE OS"): bad += 1
	var r1 := await _request("POST", "/api/upload?pin=0000&name=x.nes", rom)
	print("wrong PIN -> ", r1)
	if not r1.contains("Wrong PIN"): bad += 1
	var r2 := await _request("POST", "/api/upload?pin=%s&name=Test%%20Game.nes" % srv.pin, rom)
	print("good upload -> ", r2)
	if not r2.contains('"ok":true'): bad += 1
	var r3 := await _request("POST", "/api/upload?pin=%s&name=evil.exe" % srv.pin, rom)
	print("bad type -> ", r3)
	if not r3.contains("Not a game file"): bad += 1
	var r4 := await _request("POST", "/api/upload?pin=%s&name=..%%2F..%%2Fetc%%2Fpasswd.nes" % srv.pin, rom)
	print("path trick -> ", r4)
	var r5 := await _request("GET", "/api/list?pin=%s" % srv.pin)
	print("list -> ", r5)
	if not r5.contains("Test Game.nes"): bad += 1
	var saved := FileAccess.open("user://roms/Test Game.nes", FileAccess.READ)
	var same := saved != null and saved.get_buffer(4096) == rom
	print("saved file identical: ", same)
	if not same: bad += 1
	var big := PackedByteArray()
	big.resize(12 * 1024 * 1024)
	var r6 := await _request("POST", "/api/upload?pin=%s&name=Big.sfc" % srv.pin, big)
	print("12 MB upload -> ", r6)
	if not r6.contains('"ok":true'): bad += 1
	var r7 := await _request("POST", "/api/delete?pin=%s&name=Big.sfc" % srv.pin)
	print("delete -> ", r7)
	srv.stop()
	for f in DirAccess.open("user://roms").get_files():
		DirAccess.remove_absolute("user://roms/" + f)
	print("ROM SERVER TEST OK" if ok and bad == 0 else "ROM SERVER TEST FAILED (%d)" % bad)
	quit()
