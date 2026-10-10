extends RefCounted
class_name TwilightSkillStatusService

var rules: Dictionary = {}
var debuffs: Dictionary = {}

func _init() -> void:
	rules = preload("res://scripts/skills/skill_catalog.gd").read_json("status_rules.json")

func clear() -> void:
	debuffs.clear()

static func same_life(entry: Dictionary, target: Node) -> bool:
	return is_instance_valid(target) and int(entry.get("life_id", -1)) == int(target.get("life_id"))

func tick(delta: float) -> void:
	for key: int in debuffs.keys():
		var entry: Dictionary = debuffs[key]
		var target: Node = entry.target.get_ref()
		entry.remaining -= delta
		if not same_life(entry, target) or target.dead or float(entry.remaining) <= 0: debuffs.erase(key)

func modifier(target: Node, key: String) -> float:
	if not is_instance_valid(target): return 0.0
	var id := target.get_instance_id()
	var entry: Dictionary = debuffs.get(id, {})
	if not same_life(entry, target) or target.dead or float(entry.get("remaining", 0)) <= 0:
		debuffs.erase(id)
		return 0.0
	return float(entry.get("values", {}).get(key, 0))

func can_affect(skill: Dictionary, target: TwilightMonster) -> bool:
	if not is_instance_valid(target) or target.dead: return false
	var kind := str(skill.get("status", ""))
	if kind not in ["stun", "hold", "fear", "silence", "slow", "poison", "bleed"] or target.status_immunities.has(kind): return false
	if kind != "slow" and float(target.get(kind + "_resistance")) >= 100: return false
	return float(skill.get("status_chance", .6)) > 0

func apply(skill: Dictionary, target: TwilightMonster, world: Node) -> bool:
	if not can_affect(skill, target): return false
	var kind := str(skill.get("status", ""))
	var resistance: float = 0.0
	if kind in ["stun","hold","fear","silence","poison","bleed"]:
		resistance = float(target.get(kind + "_resistance"))
	var chance := float(skill.get("status_chance", .6)) * (1.0 - clampf(resistance / 100.0, 0, 1))
	if target.is_boss: chance *= float(rules.get("boss_chance_factor", .35))
	if world.rng.randf() >= chance: return false
	var duration := float(skill.get("duration", 3))
	var bounds: Array = skill.get("duration_bounds", [])
	if bounds.size() == 2: duration = world.rng.randf_range(float(bounds[0]), float(bounds[1]))
	if target.is_boss: duration *= float(rules.get("boss_duration_factor", .35))
	match kind:
		"stun": target.apply_stun(duration)
		"hold": target.apply_hold(duration)
		"fear": target.apply_fear(duration, world.player.global_position)
		"silence": target.apply_silence(duration)
		"slow": target.apply_slow(duration, float(skill.get("slow", .6)))
		"poison": target.apply_poison(duration, int(skill.get("tick_damage", 8)), float(skill.get("tick_interval", 1)))
		"bleed": target.apply_bleed(duration, int(skill.get("tick_damage", 8)), float(skill.get("tick_interval", 1)))
		_: return false
	var key := target.get_instance_id()
	var previous: Dictionary = debuffs.get(key, {})
	if not same_life(previous, target): previous = {}
	debuffs[key] = {"target":weakref(target),"life_id":target.life_id,"remaining":maxf(duration, float(previous.get("remaining", 0))),"values":skill.get("debuff", {}).duplicate(true)}
	return true

static func cleanse(player: TwilightPlayer, kinds: Array) -> void:
	for kind: String in kinds:
		if kind in ["stun","hold","fear","silence","poison","bleed"]:
			player.set(kind + "_remaining", 0.0)
