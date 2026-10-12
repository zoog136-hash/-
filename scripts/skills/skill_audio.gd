extends Node
class_name TwilightOriginalSkillAudio

var players: Array[AudioStreamPlayer2D] = []
var cache: Dictionary = {}
var next_voice: int = 0
var played: int = 0
var last_skill: String = ""
var last_phase: String = ""
const PHASE_PITCH := {"cast":.78, "impact":1.0, "status":1.08, "resist":.62}

func _ready() -> void:
	for _index: int in range(6):
		var player := AudioStreamPlayer2D.new()
		player.volume_db = -10
		player.max_distance = 700
		add_child(player)
		players.append(player)

func play_skill(id: String, point: Vector2, phase: String = "impact") -> bool:
	if players.is_empty() or not PHASE_PITCH.has(phase): return false
	if not cache.has(id):
		var path := "res://assets/skills/audio/" + id + ".wav"
		if not ResourceLoader.exists(path): return false
		cache[id] = load(path)
	if not cache[id] is AudioStream: return false
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stop()
	player.global_position = point
	player.stream = cache[id]
	player.pitch_scale = float(PHASE_PITCH[phase])
	player.volume_db = -16 if phase == "resist" else -14 if phase == "cast" else -10
	player.play()
	played += 1
	last_skill = id
	last_phase = phase
	return true

func clear() -> void:
	for player: AudioStreamPlayer2D in players: player.stop()
	next_voice = 0
