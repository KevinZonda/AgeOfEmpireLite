class_name RtsFeedbackAudio
extends Node

# Short generated cues keep the prototype self contained and avoid loading a
# separate stream for every unit in a large battle.
const SAMPLE_RATE := 22050
const VOICE_COUNT := 5
const CUES := {
	"select": [580.0, 740.0, 0.075, 0.13],
	"move": [360.0, 480.0, 0.095, 0.15],
	"attack": [230.0, 115.0, 0.13, 0.21],
	"gather": [460.0, 310.0, 0.075, 0.13],
	"build": [210.0, 285.0, 0.13, 0.18],
	"impact": [140.0, 62.0, 0.14, 0.20],
	"complete": [490.0, 790.0, 0.23, 0.22],
	"alert": [650.0, 420.0, 0.25, 0.23],
	"invalid": [220.0, 165.0, 0.11, 0.17],
}

var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played: Dictionary = {}

func _ready() -> void:
	for cue in CUES:
		streams[cue] = _make_stream(CUES[cue])
	for _index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.volume_db = -11.0
		add_child(player)
		voices.append(player)

func play_cue(cue: String) -> void:
	if not streams.has(cue): return
	var now := Time.get_ticks_msec()
	var cooldown := 900 if cue == "alert" else 280 if cue in ["gather", "build", "impact"] else 110
	if now - int(last_played.get(cue, -10000)) < cooldown: return
	last_played[cue] = now
	var player := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	player.stream = streams[cue]
	player.play()

func _make_stream(spec: Array) -> AudioStreamWAV:
	var start_pitch: float = spec[0]
	var end_pitch: float = spec[1]
	var duration: float = spec[2]
	var amplitude: float = spec[3]
	var count := maxi(1, roundi(SAMPLE_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for index in count:
		var progress := float(index) / count
		phase += TAU * lerpf(start_pitch, end_pitch, progress) / SAMPLE_RATE
		var envelope := minf(1.0, progress * 25.0) * pow(1.0 - progress, 1.7)
		var tone := sin(phase) * 0.78 + sin(phase * 2.01) * 0.22
		var sample := clampi(roundi(tone * envelope * amplitude * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
