extends SceneTree
## Synthetic ownership/admission regression, not original catalog delivery.
const COMBAT = preload("res://scripts/monsters/base508_boss_combat.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
class Pose extends RefCounted:
	func begin_attack() -> void: pass
class Actor extends Node2D:
	var life_id: int = 1
	var dead: bool = false
	var is_boss: bool = false
	var attack_interval: float = 1.0
	var attack_cooldown: float = 0.0
	var enraged: bool = false
	var motion = Pose.new()
	func is_stunned() -> bool: return false
	func is_feared() -> bool: return false
	func is_silenced() -> bool: return false
	func _target_attackable() -> bool: return true
	func current_attack_range() -> float: return 10.0
	func current_attack_type() -> String: return "melee"
class Player extends Node2D:
	var original_source_manifest: String = ""
	func apply_stun() -> void: pass
class World extends Node:
	var hp: int = 10
	var combat_generation: int = 1
	var rng = RandomNumberGenerator.new()
	var player = Player.new()
	var active_map_id: String = "test"
	func _has_line_of_sight_world() -> bool: return true
	func _on_player_hit() -> void: pass
	func _roll_monster_hit() -> bool: return true
	func _status_effect_chance() -> float: return 0.0
	func _stun_resistance_stat() -> int: return 0
var errors: Array[String] = []
var checks: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
func _initialize() -> void:
	var actor := Actor.new()
	var world := World.new()
	var combat := COMBAT.new()
	var saved: Dictionary = COMBAT._catalog
	COMBAT._catalog = {"source_npcs":{"123":{"sprite_id":456}}}
	var record := {"source_m_npc_id":123,"source_m_original":{"ID":123,"Sprite":456},"source_m_boss_combat_options":{"explicit_attack_id":1}}
	HITCH._counters.clear()
	check(not combat.configure(actor,world,record),"ordinary actor without reviewed action contract remains rejected")
	check(not HITCH._counters.has("boss.catalog_request"),"ineligible ordinary actor never requests catalog")
	for path_field: String in ["source_m_combat_pack_root","source_m_asset_manifest_path"]:
		var rooted: Dictionary = record.duplicate(true)
		rooted[path_field] = "user://explicit_combat_pack" if path_field.ends_with("root") else "user://explicit_visual_pack/manifest.json"
		HITCH._counters.clear()
		check(not combat.configure(actor,world,rooted),"rooted ordinary actor remains rejected")
		check(int(HITCH._counters.get("boss.catalog_request",0)) == 1,"explicit root retains existing shared catalog priming order")
	for contract: String in COMBAT.ORDINARY_CONTRACTS:
		var adopted: Dictionary = record.duplicate(true)
		adopted["source_m_host_action_contract"] = {"contract":contract}
		HITCH._counters.clear()
		check(not combat.configure(actor,world,adopted),"unproven ordinary contract still rejected: "+contract)
		check(int(HITCH._counters.get("boss.catalog_request",0)) > 0,"eligible contract reaches original catalog/adoption verification: "+contract)
	actor.is_boss = true
	check(combat.configure(actor,world,record) and combat.source_npc_id == 123,"boss retains original configure path")
	var changed: Dictionary = record.duplicate(true)
	changed.source_m_original.Sprite = 789
	check(not combat.configure(actor,world,changed) and combat.source_npc_id == -1,"changed sprite rejected and pooled life cleared")
	for invalid: Dictionary in [{},{"source_m_npc_id":123,"source_m_original":{"ID":124}},{"source_m_npc_id":123,"source_m_original":{"ID":123,"TestNPC":true}}]:
		HITCH._counters.clear()
		check(not combat.configure(actor,world,invalid) and not HITCH._counters.has("boss.catalog_request"),"invalid identity rejected before catalog")
	COMBAT._catalog = saved
	combat.clear()
	world.player.free()
	world.free()
	actor.free()
	print("BOSS_CATALOG_ADMISSION_RESULT ",JSON.stringify({"checks":checks,"failures":errors}))
	quit(0 if errors.is_empty() else 1)
