extends RefCounted
## Source proc chance/duration/dice with explicitly local missing mechanics.
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")

static func on_normal_hit(world: Node, target: Node) -> bool:
	if not is_instance_valid(target) or target.dead: return false
	var rule: String = str(world.ui_preferences.get("patch523_bleed_max_hp_rule","total_damage_cap"))
	if rule == "disabled": return false
	if rule not in ["total_damage_cap","no_cap"]: rule = "total_damage_cap"
	var definition: Dictionary = DROPS.item_definition(world._equipped_weapon_record())
	if definition.get("original_item", {}).get("TestItem", true): return false
	for effect: Dictionary in definition.get("source_invoke_options", []):
		if effect.get("kind") != "normal_attack_source_bleed" or effect.get("activation_status") != "unrestricted": continue
		if world.rng.randi_range(0,999999) >= int(effect.get("probability_raw",0)): continue
		var interval: float = clampf(float(world.ui_preferences.get("patch523_bleed_tick_interval_seconds",0.75)),0.1,3.0)
		target.apply_patch523_weapon_bleed(effect,interval,rule)
		# Exact source identity goes through the existing private compositor.
		# Missing pixels stay unavailable; no replacement is called original art.
		world.option_awakening.combat.emit_spell(effect.source_spell_class,target)
		world.hud.append_log("523 총 출혈 발동 · 원본 확률·지속·주사위 · 틱 간격·HP 상한은 TWILIGHT 추정 설정")
		return true
	return false

static func apply(monster: Node, effect: Dictionary, interval: float, rule: String) -> void:
	if monster.dead or float(effect.get("duration_seconds",0)) <= 0: return
	var cap: int = -1
	if rule == "total_damage_cap": cap = maxi(0,int(float(monster.max_hp)*float(effect.get("source_max_hp_percent",50))/100.0))
	monster.patch523_weapon_bleed = {"remaining":float(effect.duration_seconds),"clock":interval,"interval":interval,"dice_number":int(effect.get("damage_dice_number",0)),"dice_spot_count":int(effect.get("damage_dice_spot_count",0)),"remaining_cap":cap,"source_spell_class_id":int(effect.get("spell_class_id",0)),"source_buff_class_id":int(effect.get("buff_class_id",0)),"rule_origin":"local_estimate_after_source_and_public_research"}
	monster.show_status_text("BLEED*")

static func tick(monster: Node, delta: float) -> void:
	var state: Dictionary = monster.patch523_weapon_bleed
	if state.is_empty(): return
	if monster.dead:
		state.clear(); return
	var duration: float = float(state.remaining)
	state.remaining = maxf(0.0,duration-maxf(0.0,delta))
	state.clock -= minf(maxf(0.0,delta),duration)
	var count: int = int(state.dice_number)
	var sides: int = int(state.dice_spot_count)
	if count < 1 or count > 1000 or sides < 1 or sides > 1000000:
		state.clear(); return
	while float(state.clock) <= 0.0 and not monster.dead:
		var damage: int = 0
		for die: int in range(count): damage += monster.world_controller.rng.randi_range(1,sides)
		if int(state.remaining_cap) >= 0:
			damage = mini(damage,int(state.remaining_cap))
			state.remaining_cap = maxi(0,int(state.remaining_cap)-damage)
		state.clock += maxf(0.1,float(state.interval))
		if damage > 0: monster.take_damage(damage,false,"bleed")
		if state.is_empty(): return # A death callback may retire this pooled actor.
		if int(state.remaining_cap) == 0: break
	if float(state.remaining) <= 0.0 or monster.dead or int(state.remaining_cap) == 0: state.clear()
