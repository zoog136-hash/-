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
		if not same_life(entry, target) or target.dead:
			debuffs.erase(key)
			continue
		for effect: Dictionary in entry.sources.values():
			effect.remaining -= delta
		refresh_entry(key)

func refresh_entry(key: int) -> void:
	var entry: Dictionary = debuffs[key]
	var sources: Dictionary = entry.sources
	var values: Dictionary = {}
	var remaining := 0.0
	for source: String in sources.keys():
		var effect: Dictionary = sources[source]
		if float(effect.remaining) <= 0:
			sources.erase(source)
			continue
		remaining = maxf(remaining, float(effect.remaining))
		# CUSTOM_BALANCE: keep the latest live value for an overlapping field,
		# without adding sources together or erasing unrelated modifier fields.
		values.merge(effect.values, true)
	if sources.is_empty():
		debuffs.erase(key)
	else:
		entry.remaining = remaining
		entry.values = values

func set_modifiers(target: Node, source: String, duration: float, values: Dictionary) -> void:
	if not is_instance_valid(target) or target.dead: return
	var key := target.get_instance_id()
	var entry: Dictionary = debuffs.get(key, {})
	if not same_life(entry, target):
		entry = {"target":weakref(target),"life_id":target.life_id,"sources":{}}
	var sources: Dictionary = entry.sources
	var remaining := maxf(duration, float(sources.get(source, {}).get("remaining", 0)))
	# Reinsert the refreshed source last so collisions retain latest-value
	# precedence. Refresh only this source's timer, never another skill's timer.
	sources.erase(source)
	if duration > 0 and not values.is_empty():
		sources[source] = {"remaining":remaining,"values":values.duplicate(true)}
	debuffs[key] = entry
	refresh_entry(key)

func remove_modifiers(target: Node, source: String) -> void:
	if not is_instance_valid(target): return
	var key := target.get_instance_id()
	var entry: Dictionary = debuffs.get(key, {})
	if not same_life(entry, target):
		debuffs.erase(key)
		return
	entry.sources.erase(source)
	refresh_entry(key)

func modifier(target: Node, key: String) -> float:
	if not is_instance_valid(target): return 0.0
	var id := target.get_instance_id()
	var entry: Dictionary = debuffs.get(id, {})
	if not same_life(entry, target) or target.dead or float(entry.get("remaining", 0)) <= 0:
		debuffs.erase(id)
		return 0.0
	return float(entry.get("values", {}).get(key, 0))

func damage_after_reduction(amount: int, target: Node) -> int:
	# CUSTOM_BALANCE: the stored -3 reduction is a flat +3 received-damage
	# modifier after scaling, not an asserted original NPC defense formula.
	return maxi(1, amount - int(modifier(target, "reduction")))

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
	set_modifiers(target, "status:" + str(skill.get("id", kind)), duration, skill.get("debuff", {}))
	return true

static func cleanse(player: TwilightPlayer, kinds: Array) -> void:
	for kind: String in kinds:
		if kind in ["stun","hold","fear","silence","poison","bleed"]:
			player.set(kind + "_remaining", 0.0)
