extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const ROOT_PATH = "res://assets/actors/eight_direction/monster_boss_repair/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var measurements: Dictionary = {}
	for relative_path: String in ["albino_unicorn/published-v02/SpriteFrames.tres", "zombie_lord/published-v01/SpriteFrames.tres"]:
		var path: String = ROOT_PATH + relative_path
		var begun: int = Time.get_ticks_usec()
		var frames: SpriteFrames = CATALOG.frames(path,"native8")
		var first_load_usec: int = Time.get_ticks_usec() - begun
		var total_attack_frames: int = 0
		for direction: int in range(8):
			var name_value: String = "attack_%d" % direction
			if not frames.has_animation(name_value):
				failures.append(relative_path + " missing " + name_value)
				continue
			if frames.get_animation_speed(name_value) <= 0.0:
				failures.append(relative_path + " invalid attack speed " + name_value)
			for index: int in range(frames.get_frame_count(name_value)):
				var texture: Texture2D = frames.get_frame_texture(name_value,index)
				if texture == null or texture.get_size().x <= 0.0 or frames.get_frame_duration(name_value,index) <= 0.0:
					failures.append(relative_path + " invalid attack frame " + name_value)
				total_attack_frames += 1
		if total_attack_frames == 0:failures.append(relative_path + " attack unavailable")
		CATALOG.release_region_frames()
		if not is_same(CATALOG.frames(path,"native8"),frames):failures.append(relative_path + " live frames reloaded on region return")
		measurements[relative_path.get_slice("/",0)] = {"attack_frames":total_attack_frames,"first_load_usec":first_load_usec}
	print("BOSS_FIRST_ATTACK_FRAMES_RESULT ",JSON.stringify({"failures":failures,"resources":measurements}))
	quit(0 if failures.is_empty() else 1)
