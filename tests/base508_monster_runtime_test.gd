extends SceneTree
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const VIEW = preload("res://scripts/monsters/base508_monster_view.gd")
var errors: Array[String] = []
class Host extends Node:
	var active_map_id: String = "aden_world"
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manifest: String = BINDINGS.pack_manifest()
	check(FileAccess.file_exists(manifest), "private monster manifest missing")
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var ready: Array = []
	var host := Host.new()
	root.add_child(host)
	var monster_scene: PackedScene = null
	if "--check-game-actors" in OS.get_cmdline_user_args():
		monster_scene = load("res://scenes/Monster.tscn")
		check(monster_scene != null, "actual game Monster scene failed to load")
	for binding: Dictionary in BINDINGS.data().get("bindings", []):
		var local: Dictionary = db["몬스터"][int(binding.legacy_game_db_index)]
		var mapped: Dictionary = BINDINGS.apply(local, "aden_world", manifest)
		check(int(mapped.get("source_m_npc_id", -1)) == int(binding.npc_id), "source context not applied to declared host slot")
		check(not BINDINGS.apply(local, "talking_island", manifest).has("source_m_npc_id"), "source variant leaked into another host map")
		var changed: Dictionary = local.duplicate(true)
		changed["hp"] = int(local.hp) + 1
		check(not BINDINGS.apply(changed, "aden_world", manifest).has("source_m_npc_id"), "same name with changed slot signature was matched")
		if not mapped.has("source_m_npc_id"): continue
		var view := VIEW.new()
		check(view.configure(mapped, manifest), "original pixel/8-direction track load failed")
		root.add_child(view)
		view.advance(0.3, "walk", 0, 0, false, false)
		view.advance(0.3, "attack", 7, 1, true, false)
		view.advance(0.3, "death", 2, 1, false, true)
		check(view.last_source_frame >= 0, "source action was not sampled")
		check(float(view.timing_status.walk.effective_fps) > 0.0, "host-compatible playback clock unavailable")
		check(str(view.timing_status.walk.origin).begins_with("compat_"), "unknown source FPS misreported as native")
		ready.append({"npc_id":mapped.source_m_npc_id,"sprite_id":mapped.source_m_sprite_id,"hp":mapped.hp,"level":mapped.lv,"roles":["idle","walk","attack","hit","death"],"directions":8})
		view.free()
		if monster_scene != null:
			var monster: Node = monster_scene.instantiate()
			root.add_child(monster)
			monster.setup(local, null, host, null)
			monster.set_physics_process(false)
			check(int(monster.source_m_npc_id) == int(binding.npc_id), "actual game actor source ID was not replaced")
			check(int(monster.max_hp) == int(mapped.hp) and int(monster.monster_level) == int(mapped.lv), "actual game actor native stats were not applied")
			check(is_instance_valid(monster.source_m_view) and not monster.sprite.visible, "actual game actor still draws legacy silhouette")
			check(monster.gold_reward == 0 and monster.drop_items.is_empty(), "source loot or currency invented")
			monster.free()
	host.free()
	check(ready.size() == 4, "expected four original-asset runtime bindings")
	if errors.is_empty():
		print("BASE508_MONSTER_RUNTIME_OK ", JSON.stringify(ready))
		quit(0)
	else:
		for message: String in errors: push_error(message)
		quit(1)
