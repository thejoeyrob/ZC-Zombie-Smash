class_name RomServer
extends Node
## Put game files on the headset without a cable: while it is switched on, the headset serves a small web page on the home Wi-Fi.
## Open the address shown on the JW EDS screen in the browser of a phone or computer on the same network, type the PIN shown on the screen,
## and drop game files onto the page. They are saved in this app's own folder (user://roms), where the JW EDS menu looks.
## Safety: only machines on the same private network may connect, every change needs the PIN, only game file types are accepted, file names are
## cleaned, and nothing is served until the player switches it on at the machine. It switches itself off when the player leaves.

signal uploaded(file_name: String)
signal changed

const PORT := 8080
const MAX_BYTES := 96 * 1024 * 1024
const DIR := "user://roms"
const EXTS := ["md", "gen", "smd", "bin", "nes", "sfc", "smc", "gb", "gbc", "gba", "sms", "gg", "pce", "zip"]

var running := false
var pin := ""
var received := 0                 # files received this time it was on
var last_name := ""
var _server: TCPServer
var _clients: Array = []          # {peer: StreamPeerTCP, buf: PackedByteArray, age: float}


func start() -> bool:
	if running:
		return true
	_server = TCPServer.new()
	if _server.listen(PORT, "0.0.0.0") != OK:
		_server = null
		return false
	pin = "%04d" % randi_range(1000, 9999)
	received = 0
	last_name = ""
	running = true
	DirAccess.make_dir_recursive_absolute(DIR)
	changed.emit()
	return true


func stop() -> void:
	if not running:
		return
	for c in _clients:
		(c.peer as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	_server.stop()
	_server = null
	running = false
	changed.emit()


## The address to type into a browser: the headset's private IPv4 address, or "" when it is not on a network.
func address() -> String:
	for a in IP.get_local_addresses():
		if _private_v4(a):
			return "http://%s:%d" % [a, PORT]
	return ""


static func _private_v4(a: String) -> bool:
	if a.contains(":"):
		return false
	var p := a.split(".")
	if p.size() != 4:
		return false
	var o1 := int(p[0])
	var o2 := int(p[1])
	return o1 == 10 or (o1 == 192 and o2 == 168) or (o1 == 172 and o2 >= 16 and o2 <= 31)


func _process(delta: float) -> void:
	if not running:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		var who := peer.get_connected_host().trim_prefix("::ffff:")
		if not _private_v4(who) and who != "127.0.0.1" and who != "::1":
			peer.disconnect_from_host()
			continue
		_clients.append({"peer": peer, "buf": PackedByteArray(), "age": 0.0})
	var keep: Array = []
	for c in _clients:
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		c.age += delta
		var st := peer.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED or c.age > 120.0:
			if st == StreamPeerTCP.STATUS_CONNECTED:
				peer.disconnect_from_host()
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			var r := peer.get_data(n)
			if r[0] == OK:
				var got: PackedByteArray = c.buf      # packed arrays are copied when read out of a dictionary, so put it back after adding
				got.append_array(r[1])
				c.buf = got
		if (c.buf as PackedByteArray).size() > MAX_BYTES + 65536:
			_reply(peer, 413, "text/plain", "Too large".to_utf8_buffer())
			continue
		if _try_handle(c):
			continue
		keep.append(c)
	_clients = keep


## Returns true when the request was complete and has been answered (the connection is then closed).
func _try_handle(c: Dictionary) -> bool:
	var buf: PackedByteArray = c.buf
	var head_end := _find_header_end(buf)
	if head_end < 0:
		return false
	var head := buf.slice(0, head_end).get_string_from_utf8()
	var lines := head.split("\r\n")
	var req := lines[0].split(" ")
	if req.size() < 2:
		_reply(c.peer, 400, "text/plain", "Bad request".to_utf8_buffer())
		return true
	var length := 0
	for i in range(1, lines.size()):
		var kv := lines[i].split(":", true, 1)
		if kv.size() == 2 and kv[0].strip_edges().to_lower() == "content-length":
			length = int(kv[1].strip_edges())
	if length > MAX_BYTES:
		_reply(c.peer, 413, "text/plain", "Too large".to_utf8_buffer())
		return true
	if buf.size() < head_end + 4 + length:
		return false
	var body := buf.slice(head_end + 4, head_end + 4 + length)
	var method := req[0]
	var target := req[1]
	var path := target.split("?")[0]
	var query := _parse_query(target.split("?", true, 1)[1] if target.contains("?") else "")
	_route(c.peer, method, path, query, body)
	return true


static func _find_header_end(buf: PackedByteArray) -> int:
	var n := buf.size()
	for i in range(0, mini(n - 3, 16384)):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1


static func _parse_query(q: String) -> Dictionary:
	var out := {}
	for part in q.split("&"):
		var kv := part.split("=", true, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1].uri_decode()
	return out


func _route(peer: StreamPeerTCP, method: String, path: String, q: Dictionary, body: PackedByteArray) -> void:
	if method == "GET" and (path == "/" or path == "/index.html"):
		_reply(peer, 200, "text/html; charset=utf-8", _page().to_utf8_buffer())
		return
	if str(q.get("pin", "")) != pin:
		_reply(peer, 403, "application/json", JSON.stringify({"ok": false, "error": "Wrong PIN. It is shown on the arcade machine's screen."}).to_utf8_buffer())
		return
	match [method, path]:
		["GET", "/api/list"]:
			_reply(peer, 200, "application/json", JSON.stringify({"ok": true, "files": list_files()}).to_utf8_buffer())
		["POST", "/api/upload"]:
			var fname := clean_name(str(q.get("name", "")))
			if fname == "":
				_reply(peer, 400, "application/json", JSON.stringify({"ok": false, "error": "Not a game file type I know."}).to_utf8_buffer())
				return
			if body.size() < 16:
				_reply(peer, 400, "application/json", JSON.stringify({"ok": false, "error": "That file is empty."}).to_utf8_buffer())
				return
			var f := FileAccess.open("%s/%s" % [DIR, fname], FileAccess.WRITE)
			if f == null:
				_reply(peer, 500, "application/json", JSON.stringify({"ok": false, "error": "Could not save the file."}).to_utf8_buffer())
				return
			f.store_buffer(body)
			f.close()
			received += 1
			last_name = fname
			_reply(peer, 200, "application/json", JSON.stringify({"ok": true, "name": fname}).to_utf8_buffer())
			uploaded.emit(fname)
			changed.emit()
		["POST", "/api/delete"]:
			var dn := clean_name(str(q.get("name", "")))
			if dn != "" and FileAccess.file_exists("%s/%s" % [DIR, dn]):
				DirAccess.remove_absolute("%s/%s" % [DIR, dn])
				changed.emit()
				_reply(peer, 200, "application/json", JSON.stringify({"ok": true}).to_utf8_buffer())
			else:
				_reply(peer, 404, "application/json", JSON.stringify({"ok": false, "error": "No such file."}).to_utf8_buffer())
		_:
			_reply(peer, 404, "text/plain", "Not found".to_utf8_buffer())


## A safe file name: no folders, no odd characters, and a game file extension. "" when it is not acceptable.
static func clean_name(raw: String) -> String:
	var n := raw.get_file().strip_edges()
	var out := ""
	for ch in n:
		out += ch if (ch.unicode_at(0) >= 48 and ch.unicode_at(0) <= 57) or (ch.unicode_at(0) >= 65 and ch.unicode_at(0) <= 90) or (ch.unicode_at(0) >= 97 and ch.unicode_at(0) <= 122) or ch in " ._-()[]!&'," else "_"
	out = out.lstrip(".")
	var ext := out.get_extension().to_lower()
	if out.length() < 3 or out.length() > 120 or not EXTS.has(ext):
		return ""
	return out


func list_files() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			var fa := FileAccess.open("%s/%s" % [DIR, f], FileAccess.READ)
			out.append({"name": f, "size": fa.get_length() if fa != null else 0})
	return out


func _reply(peer: StreamPeerTCP, code: int, mime: String, body: PackedByteArray) -> void:
	var text: String = {200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 413: "Payload Too Large", 500: "Server Error"}.get(code, "OK")
	var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [code, text, mime, body.size()]
	peer.put_data(head.to_utf8_buffer())
	if body.size() > 0:
		peer.put_data(body)
	peer.disconnect_from_host()


func _page() -> String:
	return """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>JW EDS Arcade: add games</title><style>
body{margin:0;background:#04070a;color:#8dffa6;font:16px/1.4 ui-monospace,Menlo,Consolas,monospace;padding:20px;max-width:640px;margin:auto}
h1{color:#fff;font-size:20px;margin:0 0 4px}small,.dim{color:#7a9}input,button{font:inherit}
#pin{width:90px;font-size:22px;letter-spacing:4px;text-align:center;background:#000;color:#fff;border:2px solid #2a6;border-radius:8px;padding:6px}
#drop{margin:16px 0;border:2px dashed #2a6;border-radius:14px;padding:34px 12px;text-align:center;cursor:pointer}
#drop.over{background:#0a2a14}.row{display:flex;justify-content:space-between;gap:8px;padding:6px 0;border-bottom:1px solid #123}
.bar{height:6px;background:#123;border-radius:3px;margin-top:4px}.bar i{display:block;height:6px;background:#3f6;border-radius:3px;width:0}
button{background:#122;color:#8dffa6;border:1px solid #2a6;border-radius:6px;padding:2px 8px;cursor:pointer}.err{color:#ffbf33}
</style></head><body>
<h1>JW EDS ARCADE OS</h1><div class="dim">Add your own game files to this headset. They stay on the headset.</div>
<p>PIN shown on the arcade screen: <input id="pin" inputmode="numeric" maxlength="4" placeholder="----"></p>
<div id="drop">Drop game files here, or tap to choose<br><small>md gen smd bin nes sfc smc gb gbc gba sms gg pce zip</small>
<input id="file" type="file" multiple hidden></div>
<div id="log"></div><h1>On the headset</h1><div id="list" class="dim">Enter the PIN to see the list.</div>
<script>
const $=id=>document.getElementById(id);let pin=localStorage.getItem('pin')||'';$('pin').value=pin;
$('pin').oninput=e=>{pin=e.target.value;localStorage.setItem('pin',pin);refresh()};
const fmt=n=>n>1048576?(n/1048576).toFixed(1)+' MB':Math.max(1,Math.round(n/1024))+' KB';
async function refresh(){if(pin.length<4)return;try{const r=await fetch('/api/list?pin='+pin);const j=await r.json();
if(!j.ok){$('list').innerHTML='<span class=err>'+j.error+'</span>';return}
$('list').innerHTML=j.files.length?j.files.map(f=>'<div class=row><span>'+f.name+'</span><span>'+fmt(f.size)+' <button onclick="del(\\''+encodeURIComponent(f.name)+'\\')">remove</button></span></div>').join(''):'Nothing yet.'}catch(e){}}
async function del(n){await fetch('/api/delete?pin='+pin+'&name='+n,{method:'POST'});refresh()}
function send(file){const row=document.createElement('div');row.className='row';row.innerHTML='<span>'+file.name+'<div class=bar><i></i></div></span><span class=st>0%</span>';$('log').prepend(row);
const x=new XMLHttpRequest();x.open('POST','/api/upload?pin='+pin+'&name='+encodeURIComponent(file.name));
x.upload.onprogress=e=>{const p=Math.round(e.loaded/e.total*100);row.querySelector('i').style.width=p+'%';row.querySelector('.st').textContent=p+'%'};
x.onload=()=>{let j={};try{j=JSON.parse(x.responseText)}catch(e){}row.querySelector('.st').innerHTML=j.ok?'saved':'<span class=err>'+(j.error||'failed')+'</span>';refresh()};
x.onerror=()=>{row.querySelector('.st').innerHTML='<span class=err>failed</span>'};x.send(file)}
function take(fs){for(const f of fs)send(f)}
$('drop').onclick=()=>$('file').click();$('file').onchange=e=>take(e.target.files);
$('drop').ondragover=e=>{e.preventDefault();$('drop').classList.add('over')};$('drop').ondragleave=()=>$('drop').classList.remove('over');
$('drop').ondrop=e=>{e.preventDefault();$('drop').classList.remove('over');take(e.dataTransfer.files)};refresh();
</script></body></html>"""
