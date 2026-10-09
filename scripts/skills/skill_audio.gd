extends Node
class_name TwilightOriginalSkillAudio

var players: Array[AudioStreamPlayer2D] = []
var cache: Dictionary = {}
var next_voice: int = 0

func _ready() -> void:
	for _index: int in range(6):
		var player := AudioStreamPlayer2D.new()
		player.volume_db = -10
		player.max_distance = 700
		add_child(player)
		players.append(player)

func play_skill(id: String, point: Vector2) -> void:
	if players.is_empty(): return
	if not cache.has(id):
		var path := "res://assets/skills/audio/" + id + ".wav"
		if not ResourceLoader.exists(path): return
		cache[id] = load(path)
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stop()
	player.global_position = point
	player.stream = cache[id]
	player.play()

func clear() -> void:
	for player: AudioStreamPlayer2D in players: player.stop()
