extends SceneTree
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
class Host extends Node:
	var active_map_id: String = "aden_world"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var archive: String = ""
	var invalid: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--monster-install="): archive = arg.trim_prefix("--monster-install=")
		if arg.begins_with("--invalid-context="): invalid = arg.trim_prefix("--invalid-context=")
	assert(not archive.is_empty() and not invalid.is_empty())
	var installer := INSTALL.new()
	root.add_child(installer)
	var cards_before: String = INSTALL.active_root()
	var monsters_before: String = INSTALL.monster_root()
	var sentinel := FileAccess.open("user://monster-install-save-sentinel", FileAccess.WRITE)
	sentinel.store_string("keep"); sentinel.close()
	var installed: Dictionary = await installer.install_zip(archive)
	assert(installed.ok, str(installed))
	assert(INSTALL.active_root() == cards_before and INSTALL.monster_root() == monsters_before)
	INSTALL._monster_session_root = ""
	var selected: String = INSTALL.monster_root()
	assert(selected == installed.root)
	assert(BINDINGS.pack_manifest() == selected.path_join("manifest.json"))
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS.pack_manifest()))
	var header: Dictionary = {"npc_ids":[248,249,281,286]}
	assert(INSTALL.validate_monster_payload(selected, original, header).is_empty())
	var changed_pixels: Dictionary = original.duplicate(true)
	changed_pixels.records["248"].tracks.idle.directions[0][0].layers[0].path = "pixels/missing.png"
	assert(not INSTALL.validate_monster_payload(selected, changed_pixels, header).is_empty())
	var changed_offset: Dictionary = original.duplicate(true)
	changed_offset.records["248"].tracks.idle.directions[0][0].layers[0].offset = ["invalid",0]
	assert(not INSTALL.validate_monster_payload(selected, changed_offset, header).is_empty())
	var rejected: Dictionary = await installer.install_zip(invalid)
	assert(not rejected.ok)
	INSTALL._monster_session_root = ""
	assert(INSTALL.monster_root() == selected and INSTALL.active_root() == cards_before)
	assert(FileAccess.get_file_as_string("user://monster-install-save-sentinel") == "keep")
	var host := Host.new()
	root.add_child(host)
	var monster = load("res://scenes/Monster.tscn").instantiate()
	host.add_child(monster)
	monster.set_physics_process(false)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var live_records: Array = preload("res://scripts/monsters/monster_catalog.gd").expand(db["몬스터"])
	var checked: int = 0
	for binding: Dictionary in BINDINGS.data().bindings:
		var legacy: Dictionary = live_records[int(binding.legacy_game_db_index)]
		monster.setup(legacy, null, host, null)
		monster.set_physics_process(false)
		assert(monster.source_m_npc_id == int(binding.npc_id))
		assert(is_instance_valid(monster.source_m_view) and not monster.sprite.visible)
		var mapped: Dictionary = BINDINGS.apply(legacy, "aden_world")
		assert(monster.max_hp == mapped.hp and monster.monster_level == mapped.lv)
		for role: String in ["idle", "walk", "attack", "hit", "death"]:
			assert(monster.source_m_view._tracks[role].directions.size() == 8)
		monster.source_m_view.advance(0.2, "walk", 0, 0, false, false)
		monster.source_m_view.advance(0.2, "attack", 7, 1, true, false)
		monster.source_m_view.advance(0.2, "death", 2, 1, false, true)
		assert(monster.source_m_view.last_source_frame >= 0)
		print("INSTALLED_MONSTER_CONTEXT npc=", binding.npc_id, " sprite=", binding.sprite_id, " HP=", monster.max_hp, " level=", monster.monster_level)
		monster.retire_for_pool()
		assert(not is_instance_valid(monster.source_m_view))
		checked += 1
	var changed: Dictionary = db["몬스터"][1].duplicate(true)
	changed.hp += 1
	monster.setup(changed, null, host, null)
	monster.set_physics_process(false)
	assert(monster.source_m_npc_id == -1 and not is_instance_valid(monster.source_m_view))
	assert(monster.max_hp == int(changed.hp))
	assert(checked == 4)
	print("BASE508_MONSTER_INSTALL_OK four_actual_actors=true pool_reuse=true wrong_context_preserves_old_pack=true saves_and_card_pack_preserved=true native_geographic_spawns=0 android=false")
	host.free()
	quit()
