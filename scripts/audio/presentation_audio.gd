extends Node
class_name TwilightPresentationAudio

## Presentation-only event sink. Call after an action has actually succeeded.
## Reuses shipped authored WAVs; these are not recordings of Lineage M audio.
## Four spatial voices and two UI voices keep bursts bounded without allowing
## menu clicks to steal confirmed world feedback. No timers or gameplay calls.
const WORLD_VOICES: int = 4
const UI_VOICES: int = 2
const CONTACT = preload("res://assets/skills/audio/lm_00d9f77d3ff9315a.wav")
const ACCENT = preload("res://assets/skills/audio/lm_024a0e845c280295.wav")
const SOFT = preload("res://assets/skills/audio/lm_01141f56509e111e.wav")
const WORLD_EVENTS: Dictionary = {
	"attack": {"stream": SOFT, "gain": -24.0, "pitch": 0.82},
	"impact": {"stream": CONTACT, "gain": -20.0, "pitch": 1.0},
	"hurt": {"stream": CONTACT, "gain": -23.0, "pitch": 0.68},
	"drop": {"stream": ACCENT, "gain": -22.0, "pitch": 1.10},
	"pickup": {"stream": ACCENT, "gain": -19.0, "pitch": 1.38},
}
const UI_EVENTS: Dictionary = {
	"button": {"stream": SOFT, "gain": -28.0, "pitch": 1.45},
	"transition": {"stream": SOFT, "gain": -25.0, "pitch": 0.90},
	"confirm": {"stream": ACCENT, "gain": -23.0, "pitch": 1.18},
}
# Local mixing choices, not source-game timing measurements. Coalesce only
# presentation bursts; each confirmed event still performs its original action.
const BURST_USEC: int = 45000
var world_voices: Array[AudioStreamPlayer2D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var recent: Dictionary = {}
var world_cursor: int = 0
var ui_cursor: int = 0
var played: int = 0
var suppressed: int = 0
var muted: bool = false
var last_event: String = ""

func _ready() -> void:
	name = "PresentationAudio"
	add_to_group("presentation_audio")
	for _index: int in range(WORLD_VOICES):
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 700.0
		add_child(voice)
		world_voices.append(voice)
	for _index: int in range(UI_VOICES):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		ui_voices.append(voice)

func _accept(event: String) -> bool:
	if muted: return false
	var now := Time.get_ticks_usec()
	if recent.has(event) and now - int(recent[event]) < BURST_USEC:
		suppressed += 1
		return false
	recent[event] = now
	last_event = event
	played += 1
	return true

func play_world(event: String, point: Vector2, critical: bool = false) -> bool:
	if not WORLD_EVENTS.has(event) or world_voices.is_empty() or not point.is_finite(): return false
	if not _accept(event): return false
	var profile: Dictionary = WORLD_EVENTS[event]
	var voice := world_voices[world_cursor]
	world_cursor = (world_cursor + 1) % world_voices.size()
	voice.stop()
	voice.global_position = point
	voice.stream = profile.stream
	voice.pitch_scale = float(profile.pitch)
	voice.volume_db = float(profile.gain) + (2.0 if critical and event == "impact" else 0.0)
	voice.play()
	return true

func play_ui(event: String) -> bool:
	if not UI_EVENTS.has(event) or ui_voices.is_empty(): return false
	if not _accept(event): return false
	var profile: Dictionary = UI_EVENTS[event]
	var voice := ui_voices[ui_cursor]
	ui_cursor = (ui_cursor + 1) % ui_voices.size()
	voice.stop()
	voice.stream = profile.stream
	voice.pitch_scale = float(profile.pitch)
	voice.volume_db = float(profile.gain)
	voice.play()
	return true

func clear() -> void:
	for voice: AudioStreamPlayer2D in world_voices: voice.stop()
	for voice: AudioStreamPlayer in ui_voices: voice.stop()
	recent.clear()
	world_cursor = 0
	ui_cursor = 0
