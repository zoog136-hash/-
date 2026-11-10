extends SceneTree

const SOURCE = preload("res://scripts/maps/source_map_runtime.gd")
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
const RENDERER = preload("res://scripts/maps/source_map_runtime_renderer.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CORE_SAVE_FAIL: ", label)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func run() -> void:
	check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(), "explicit verified source pack")
	var scene = load("res://Main.tscn") as PackedScene
	check(scene != null, "actual Main scene loads")
	if scene == null:
		quit(1)
		return
	var world: TwilightWorld = scene.instantiate() as TwilightWorld
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual class confirmation and Main startup")
	# Regression guard for PR219 (cards), PR220 (option awakening), and PR221 (skill awakening).
	check(world.option_awakening != null and world.option_awakening.problem.is_empty(), "merged option awakening configure")
	if DEFINITIONS.not_installed():
		# CI never has the user's owned current523 definition ZIP. Verify the
		# absent-install path instead: features report it, substitute nothing,
		# refuse their own actions, and do not block the rest of the save.
		print("VALIDATION_SCOPE current523 definitions not installed: card/skill-awakening definition checks verify the absent-install path")
		check(world.card_collections != null and not world.card_collections.problem.is_empty(), "absent definitions are reported by card collections")
		check(world.skill_awakening != null and world.skill_awakening.definitions_not_installed(), "absent definitions are reported by skill awakening")
		check(world.skill_awakening.core.cards.is_empty(), "no substitute skill awakening definitions are invented")
		check(not world.skill_awakening.blocks_save(), "untouched awakening state does not block saving")
		check(not bool(world.skill_awakening.request_operation("missing").get("ok", true)), "awakening actions stay refused")
		check(world.skill_awakening.bonus_records().is_empty(), "no awakening bonuses apply without definitions")
	else:
		check(world.card_collections != null and world.card_collections.problem.is_empty(), "merged source card collections configure")
		check(world.skill_awakening != null and world.skill_awakening.problem.is_empty(), "merged skill awakening configure")
		check(world.skill_awakening.core.cards.size() > 0, "source card skill awakening definitions loaded")
	check(world.hud != null and world.hud.has_method("open_card_skill_awakening"), "skill awakening UI entry available")
	world.player.set_physics_process(false)
	# Pre-November art was removed (user decision 2026-11-10): without the
	# original 523 pack the player shows nothing, never an old sheet.
	var frames: SpriteFrames = world.player.class_sprite.sprite_frames
	var old_art: bool = false
	if frames != null:
		for animation: StringName in frames.get_animation_names():
			for index: int in frames.get_frame_count(animation):
				var texture: Texture2D = frames.get_frame_texture(animation, index)
				while texture is AtlasTexture: texture = (texture as AtlasTexture).atlas
				if texture != null and texture.resource_path.begins_with("res://assets/") and not texture.resource_path.begins_with("res://assets/boot/"): old_art = true
	check(not old_art, "no removed pre-November player art is loaded")
	check(world.active_map_id == "aden_world", "ordinary current starting map")
	# The pre-November source84 map pack was removed; only the installed
	# original 523 pack draws a map. An obsolete picture field never returns.
	check(world.field_map == null or not str(world.field_map.get_script().resource_path).contains("native_png"), "no obsolete NativePngField")
	# Without the installed 523 pack there is no map to walk; saving and
	# migration below do not depend on one.
	if world.field_map != null:
		check(world.field_map.point_clear(world.player.global_position, 4), "actual current entry is traversable")
	else:
		print("VALIDATION_SCOPE no map without the installed 523 pack: traversal check skipped")
	world.gold = 7654321
	check(world._save_game(true) == OK, "real atomic initial save")
	var original_path: String = world.save_path()
	var before_aden_registry: String = FileAccess.get_sha256(original_path)
	check(not world.open_current523_aden_sources(ProjectSettings.globalize_path("user://absent-current523-aden")), "missing current523 Aden source registry rejects")
	check(world.current523_aden_source_members().is_empty(), "missing current523 Aden registry stays empty")
	check(FileAccess.get_sha256(original_path) == before_aden_registry and world.active_map_id == "aden_world", "rejected current523 source registration preserves save and current map")
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(original_path))
	check(baseline.has("card_option_awakening"), "option awakening save namespace present")
	check(baseline.has("card_skill_awakening"), "skill awakening save namespace present")
	check(world.skill_awakening.check_load(baseline).is_empty(), "new skill awakening save validates")
	var invalid_skill_save: Dictionary = baseline.duplicate(true)
	invalid_skill_save["card_skill_awakening"] = {"version": -1}
	check(not world.skill_awakening.check_load(invalid_skill_save).is_empty(), "corrupt skill awakening state rejected before mutation")
	# A new character's items are original 523 items staged from the installed
	# pack (current523_starter_kit.gd); without the pack it starts empty and
	# no pre-November item is given.
	check(not baseline.is_empty() and baseline.get("inventory") is Dictionary and baseline.get("item_instances") is Dictionary, "real save with inventory and instances")
	var legacy_names: Array = []
	for name: Variant in baseline.inventory:
		if not str(name).contains("· 원본#"): legacy_names.append(name)
	check(legacy_names.is_empty(), "no pre-November item in a new character: " + str(legacy_names))
	# Historical native-PNG/source84 save migration was removed with those
	# maps (user decision 2026-11-10). The current save reloads unchanged.
	world.gold = 1
	world._load_game(true)
	check(not world.source_save_blocked and world.gold == 7654321, "current save reloads through actual Main")
	for key: String in ["inventory","item_instances","equipped_items","equipped_catalog","enhancement_levels"]:
		check(normalized(world.get(key)) == normalized(baseline[key]), "preserve " + key)
	check(normalized(world.equipment_collections.export_state()) == normalized(baseline.equipment_collections), "collection progress survives reload")
	check(normalized(world.option_awakening.export_state()) == normalized(baseline.card_option_awakening), "option awakening state survives reload")
	check(world._save_game(true) == OK, "reloaded save commits again")
	print("CORE_RUNTIME_SAVE_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_SAVE_RELOAD; MAP_FROM_523_PACK_ONLY"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
