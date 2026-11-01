extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	var failures := 0
	for kind in sound.clips:
		if "--just-guard" in OS.get_cmdline_user_args() and kind != "just_guard": continue
		var clip: AudioStreamWAV = sound.clips[kind]
		if kind == "just_guard":
			clip.save_to_wav("res://just_guard_preview.wav")
		var peak := 0
		for i in range(0, clip.data.size(), 2):
			peak = maxi(peak, absi(clip.data.decode_s16(i)))
		if clip.get_length() <= 0 or peak <= 0 or peak >= 32767:
			push_error("Invalid PCM: " + kind)
			failures += 1
		sound.play(kind, 60)
		var playing := false
		for voice in sound.voices:
			if voice.playing and voice.stream == clip: playing = true
		if not playing:
			push_error("Playback did not start: " + kind)
			failures += 1
		print("AUDIO: %s | %.2fs | peak %d | playing %s" % [kind, clip.get_length(), peak, playing])
		await create_timer(0.7).timeout
	print("AUDIO COMPLETE: %d failures" % failures)
	quit(failures)
