extends SceneTree
## TWILIGHT-made combat/light presentation under the 523 original-only rule
## (user report 2026-11-17: hazy glow around the character, a floating white
## "sword" beside a 유카). PlayerActionFX swing crescents/dust, CombatVFX
## impact halos/crescents/rings and the critical-heading glow, and the
## generated Source523PassiveLight have no original sprite: none of them is
## drawn while current523_source_only_presentation() is true. Damage numbers
## stay. The original SkipDamageMotionSprite hit effect is the only hit effect
## selected, and only for a body the original declares.
##   godot --headless --path <repo> --script res://tests/source_only_host_fx_test.gd
## With TWILIGHT_PATCH523_CONTENT and --bank-manifest=/--bank-manifest-sha256=
## the selection is also checked against the original table.
const SOURCE_ONLY = preload("res://scripts/animation/source_only_host_fx.gd")
const COMBAT_VFX = preload("res://scripts/animation/combat_vfx.gd")
const ACTION_FX = preload("res://scripts/animation/player_action_fx.gd")
const PROGRESSION = preload("res://scripts/skills/progression_runtime523.gd")
const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
var checks: int = 0
var failures: Array[String] = []

class FakePreview extends Node:
	var on: bool = true
	func current523_source_only_presentation() -> bool: return on

class FakeWorld extends Node2D:
	var player: Node = null
	var hp: int = 100

class FakeCatalog extends RefCounted:
	func stat(name: String) -> float: return 160.0 if name == "lightRadius" else 0.0

class FakeService extends RefCounted:
	var catalog: FakeCatalog = FakeCatalog.new()
	var world: FakeWorld = null

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_ONLY_HOST_FX_FAIL: " + label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: _run.call_deferred()

func _player(source_only: bool) -> TwilightPlayer:
	var player: TwilightPlayer = preload("res://scripts/player.gd").new()
	var preview := FakePreview.new()
	preview.on = source_only
	var old: Variant = player.original_source_preview
	if old is Node and is_instance_valid(old): (old as Node).free()
	player.original_source_preview = preview
	return player

func _run() -> void:
	var evidence: Dictionary = {}
	for source_only: bool in [true, false]:
		var label: String = "source_only" if source_only else "host"
		var world := FakeWorld.new()
		var player: TwilightPlayer = _player(source_only)
		world.player = player
		root.add_child(world)
		await process_frame
		check(SOURCE_ONLY.active(player) == source_only, "%s: policy follows the player's original-only presentation" % label)
		check(SOURCE_ONLY.active_for_world(world) == source_only, "%s: world policy uses its player" % label)
		check(not SOURCE_ONLY.active(null), "%s: no player, no suppression" % label)
		# CombatVFX: impacts and rings are TWILIGHT art; numbers are text.
		var vfx = COMBAT_VFX.new()
		world.add_child(vfx)
		vfx.impact(Vector2(10, 10), Vector2.RIGHT, "slash", true)
		vfx.ring(Vector2(10, 10), 40.0, Color.WHITE)
		vfx.number(Vector2(10, 10), "123", Color.WHITE, true)
		var kinds: Array = vfx.active.map(func(entry: Dictionary) -> String: return str(entry.kind))
		evidence[label + "_combat_vfx"] = kinds
		check(kinds.has("number"), "%s: damage numbers are kept" % label)
		check(kinds.has("impact") != source_only and kinds.has("ring") != source_only, "%s: impact halos/crescents and rings %s" % [label, "are not recorded" if source_only else "remain for the host presentation"])
		var number: Dictionary = vfx.active.filter(func(entry: Dictionary) -> bool: return str(entry.kind) == "number")[0]
		check(bool(number.get("host_art_suppressed", false)) == source_only, "%s: the critical heading glow follows the rule" % label)
		# PlayerActionFX: swing crescents, glints and movement dust.
		var fx = ACTION_FX.new()
		fx.actor = player
		world.add_child(fx)
		player.motion.active = true
		fx._process(1.0 / 60.0)
		check(fx.visible != source_only, "%s: player swing crescent %s" % [label, "is hidden" if source_only else "stays for the host presentation"])
		player.motion.active = false
		# Source523PassiveLight: a generated gradient PointLight2D.
		var service := FakeService.new()
		service.world = world
		var runtime = PROGRESSION.new()
		runtime.configure(service)
		runtime.update_light()
		var light: Node = player.get_node_or_null("Source523PassiveLight")
		var shown: bool = light != null and (light as CanvasItem).visible
		evidence[label + "_light"] = shown
		check(shown != source_only, "%s: generated passive light %s" % [label, "is not drawn" if source_only else "stays for the host presentation"])
		world.queue_free()
		await process_frame
		player.free()
	# Original hit effect selection: only a declared SkipDamageMotionSprite row.
	check(not EFFECT.select_damage_effect(0).get("ok", false), "no body sprite, no hit effect")
	check(SOURCE.OPTIONAL_TABLES.has("SkipDamageMotionSprite"), "the original table is an admitted optional source table")
	var tables: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	var manifest: String = arg("--bank-manifest=")
	var manifest_sha: String = arg("--bank-manifest-sha256=")
	if tables != "" and FileAccess.file_exists(tables) and manifest != "" and FileAccess.file_exists(manifest):
		var context: Dictionary = {"current523_source_bank":{"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":tables,"manifest_path":manifest,"manifest_sha256":manifest_sha}}
		var boss: Dictionary = EFFECT.select_damage_effect(2389, context)
		var yuka: Dictionary = EFFECT.select_damage_effect(7097, context)
		evidence["original"] = {"doppelganger_boss_2389":{"ok":boss.get("ok"),"sprite":boss.get("sprite_id"),"reason":boss.get("reason", boss.get("error", ""))},"yuka_7097":yuka.get("reason", yuka.get("error", ""))}
		check(int(boss.get("sprite_id", 0)) == 1248 and boss.get("consumer") == "damage_effect" or str(boss.get("reason", "")).begins_with("current523_effect_"), "도펠겡어 보스 (2389): the original DamageEffectSpriteID 1248 or an honest bank miss")
		check(not yuka.get("ok", false) and str(yuka.get("reason", "")) == "current523_damage_effect_not_declared", "유카 (7097): the original declares no hit effect, none is invented")
	else:
		evidence["original"] = "not_installed"
	print("SOURCE_ONLY_HOST_FX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
