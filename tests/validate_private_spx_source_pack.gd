extends SceneTree

## Explicit private-input audit, separate from public synthetic CI fixtures.
const SOURCE = preload("res://scripts/animation/source_spx_player.gd")
var checks := 0
var failures: Array[String] = []
var markers := 0
var raw_markers := 0
var sound_ids: Dictionary = {}
var tracks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manifest := SOURCE.read_manifest()
	check(manifest.get("actors", {}).size() == 2, "two source bodies")
	check(manifest.get("effects", {}).size() == 36, "36 physical effect groups")
	if not failures.is_empty(): finish(); return
	for section: String in ["actors", "effects"]:
		for id: String in manifest[section]:
			var entry: Dictionary = manifest[section][id]
			for aid: String in entry.actions:
				var action: Dictionary = entry.actions[aid]
				for direction in range(8 if action.directional else 1):
					var player := SOURCE.new()
					player.free_on_finish = false
					player.set_process(false)
					root.add_child(player)
					check(not player.configure(id,aid,direction),"unreviewed production activation rejected")
					var configured := player.configure(id,aid,direction,true)
					check(configured,"configure "+id+"/"+aid+"/"+str(direction))
					if not configured: player.free(); continue
					if section == "actors":
						check(player._layers[1].z_index < player._layers[0].z_index,"source shadow behind body")
					tracks += 1
					var at := 0.0
					var index := 0
					for record: Dictionary in action.frames:
						if int(record.ticks) <= 0: continue
						player._sample(at+float(record.ticks)*.5)
						for layer in player._layers:
							var frames: SpriteFrames = layer.get_meta("frames")
							check(frames.get_frame_duration(player._track_name,index) == float(record.ticks),"relative source duration")
							check(layer.texture == frames.get_frame_texture(player._track_name,index),"same-clock layer sample")
						at += float(record.ticks)
						index += 1
					check(at == float(action.total_ticks),"all positive ticks retained")
					var before := markers
					var raw_before := raw_markers
					player.source_marker.connect(func(_id: String,_frame: int): markers += 1)
					player.raw_source_marker.connect(func(_id: String,_frame: int): raw_markers += 1)
					player.sound_requested.connect(func(sound_id: String): sound_ids[sound_id] = true)
					player.play_source_audio = section == "effects"
					player.play()
					player.advance(at/float(manifest.tick_rate)+1.0)
					check(not player._running,"finite playback terminates")
					check(markers-before <= 1,"multiple source marks never multiply attacks")
					check(raw_markers-raw_before == action.frames.filter(func(record: Dictionary): return record.hit_marker).size(),"all original visual markers retained")
					player.free()
	for id: String in ["10827","10828","10829","10830"]:
		check(sound_ids.has(id),"actual source audio event "+id)
		check(ResourceLoader.exists("res://assets/external_spx/source_sounds/"+id+".ogg"),"available OGG "+id)
		check(SOURCE._resources.has("sound:"+id) and SOURCE._resources["sound:"+id] is AudioStream,"source OGG actually loaded by its event "+id)
	for id: String in ["10831","10832"]:
		check(not ResourceLoader.exists("res://assets/external_spx/source_sounds/"+id+".ogg"),"missing OGG stays missing "+id)
	for id: String in ["11549","11558","11560"]:
		var path: String = "res://assets/external_spx/csb_effects/FX_"+id+".tscn"
		var scene := load(path) as PackedScene
		check(scene != null,"CSB scene loads "+id)
		if scene == null: continue
		var node := scene.instantiate()
		root.add_child(node)
		var animation := node.get_node("AnimationPlayer") as AnimationPlayer
		animation.pause()
		var data := animation.get_animation("source")
		for key in range(data.track_get_key_count(0)):
			animation.seek(data.track_get_key_time(0,key),true,true)
			check(data.track_get_key_value(0,key) is AtlasTexture,"CSB original texture key "+id)
		node.free()
	finish()

func finish() -> void:
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,
		"logical_tracks":tracks,"source_markers":markers,"raw_visual_markers":raw_markers,"sound_ids":sound_ids.keys(),
		"source_body_candidates":2,"effect_group_candidates":36,"CSB_candidates":3,
		"production_skill_bindings":0,"visual_blend_approval":"HOLD","Main":"NOT_RUN"}
	var path := OS.get_environment("TWILIGHT_SPX_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PRIVATE_SPX_SOURCE_AUDIT "+JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
