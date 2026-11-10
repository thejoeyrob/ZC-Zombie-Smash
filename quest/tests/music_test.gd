extends SceneTree
## The owner's two tracks: Lost Inside the Game plays first when the arcade has nobody in a game, Everything I Used to Be follows, then round again.
var failed := 0
var seen: Array = []
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	var a := ZSAudio.new()
	root.add_child(a)
	a.setup(holder)
	a.track_changed.connect(func(id): seen.append(id))
	check(a.ambient_track == "lostinside", "The arcade should start with Lost Inside the Game")
	var s1 := a.music_stream("lostinside")
	var s2 := a.music_stream("everything")
	check(s1 != null and s2 != null, "Both tracks should load")
	check(s1 is AudioStreamMP3 and not (s1 as AudioStreamMP3).loop, "A track plays through once")
	check(absf(s1.get_length() - 201.0) < 2.0 and absf(s2.get_length() - 256.2) < 2.0, "Lengths %f %f" % [s1.get_length(), s2.get_length()])
	a.play_music("ambient", 0.01)
	check(a.current == "lostinside", "Ambient music is Lost Inside the Game (got %s)" % a.current)
	a._deck_finished(a._decks[a._deck])
	check(a.ambient_track == "everything" and a.current == "everything" and seen == ["everything"], "Everything I Used to Be follows (ambient %s current %s)" % [a.ambient_track, a.current])
	a._deck_finished(a._decks[a._deck])
	check(a.current == "lostinside" and seen == ["everything", "lostinside"], "...and then round again")
	# a game's own music is not disturbed when a track ends in the background
	a.play_music("main", 0.01)
	var before := a.current
	a._deck_finished(a._decks[a._deck])
	check(a.current == before, "A game's music keeps playing")
	var jb := Jukebox.new()
	check(Jukebox.TRACKS[0][0] == "lostinside" and Jukebox.TRACKS[1][0] == "everything", "The jukebox lists them first")
	print("MUSIC PASS" if failed == 0 else "MUSIC FAILED")
	quit(failed)
