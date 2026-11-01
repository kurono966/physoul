extends Node
## Original synthesized mono PCM effects; no external audio assets required.
const RATE := 22050
const VOICES := 12
@export_range(-40, 0) var volume_db := -8.0
var clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 71281
	for kind in ["swing", "heavy", "flesh", "metal", "stone", "wood", "break", "roll", "kick", "death", "just_guard", "heal"]:
		clips[kind] = synthesize(kind)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play(kind: String, strength := 40.0) -> void:
	if not clips.has(kind): return
	var voice := voices[next_voice]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	next_voice = (next_voice + 1) % VOICES
	voice.stream = clips[kind]
	voice.volume_db = volume_db + linear_to_db(lerpf(0.45, 1.0, clampf(strength / 75, 0, 1)))
	voice.pitch_scale = rng.randf_range(0.94, 1.06) * (0.9 if strength > 60 else 1.0)
	if kind == "just_guard":
		# Keep the success chord tuned and consistent across different attacks.
		voice.pitch_scale = 1.0
		voice.volume_db = volume_db - 1.0
	voice.play()

func synthesize(kind: String) -> AudioStreamWAV:
	var duration := 0.25
	if kind in ["metal", "break", "death"]: duration = 0.65
	if kind == "heavy": duration = 0.38
	if kind == "just_guard": duration = 0.72
	if kind == "heal": duration = 0.65
	var count := int(duration * RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var filtered := 0.0
	for i in count:
		var t := float(i) / RATE
		var u := t / duration
		var noise := rng.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, 0.18)
		var value := 0.0
		match kind:
			"heal":
				value = (sin(TAU*392*t)*0.3+sin(TAU*493.88*t)*0.18)*sin(PI*u)*exp(-t*3)
				if t > 0.12: value += sin(TAU*659.25*(t-0.12))*0.2*sin(PI*clampf((t-0.12)/0.53,0,1))
			"just_guard":
				# Soft strike, tuned D/A/D chime and a delayed upper shimmer.
				var attack := 1-exp(-t*350)
				value = sin(TAU*587.33*t)*0.43*exp(-t*7)*attack
				value += sin(TAU*880*t)*0.24*exp(-t*8)*attack
				value += sin(TAU*1174.66*t)*0.13*exp(-t*10)*attack
				value += sin(TAU*293.665*t)*0.2*exp(-t*24)*attack
				value += (sin(TAU*(1500*t-6500*t*t))*0.12+noise*0.06)*exp(-t*110)
				if t > 0.035:
					var delayed := t-0.035
					value += sin(TAU*1760*delayed)*0.1*(1-exp(-delayed*120))*exp(-delayed*10)
			"swing", "heavy":
				value = (noise * 0.3 + filtered * 1.7) * pow(sin(PI * u), 2) * 0.65
				if kind == "heavy": value += sin(TAU * (95*t-65*t*t)) * sin(PI*u) * 0.22
			"metal":
				value = (sin(TAU*713*t)*0.35 + sin(TAU*1171*t)*0.24 + sin(TAU*1927*t)*0.15) * exp(-t*9) + noise*exp(-t*70)*0.5
			"stone":
				value = (noise*0.65 + sin(TAU*163*t)*0.4) * exp(-t*25)
			"wood":
				value = (sin(TAU*185*t)*0.6 + sin(TAU*327*t)*0.2 + noise*0.35)*exp(-t*21)
			"flesh", "kick":
				value = (sin(TAU*(100*t-95*t*t))*0.8 + filtered*1.3)*exp(-t*23)
			"break":
				value = (sin(TAU*(240*t-130*t*t))*0.45 + sin(TAU*827*t)*0.2 + noise*0.4)*exp(-t*7)
			"roll":
				value = filtered * 2 * sin(PI*u) * 0.7 + noise*exp(-t*45)*0.15
			"death":
				value = (sin(TAU*(80*t-40*t*t))*0.7+filtered)*exp(-t*6)
		# Short fades prevent clicks at stream boundaries; headroom for overlap.
		value *= minf(1, t*500) * minf(1, (duration-t)*100) * 0.65
		pcm.encode_s16(i*2, int(clampf(value, -0.95, 0.95)*32767))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.data = pcm
	return clip
