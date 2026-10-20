extends SceneTree
## Tests actual World combat/stat hook deltas without fabricating source catalog data.
const Stats = preload("res://scripts/collections/equipment_collection_stats.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);print("COLLECTION_STAT_FAIL: "+message)
func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.hud.complete_class_selection()
	world.equipped_items = {}
	world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
	var rt = world.equipment_collections
	var scalar: Dictionary = {"max_hp:flat":["_effective_max_hp",20],"max_mp:flat":["_effective_max_mp",10],"ac:flat":["_effective_ac",-1],"mr:flat":["_effective_mr",2],"er:flat":["_effective_er",2],"weight_bonus:flat":["_carrying_capacity",30],"damage_reduction:flat":["_damage_reduction_stat",2],"sp:flat":["_spell_power_stat",1],"melee_damage:flat":["_melee_damage_stat",1],"ranged_damage:flat":["_ranged_damage_stat",1],"magic_damage:flat":["_magic_damage_stat",1],"melee_hit:flat":["_melee_accuracy_stat",1],"ranged_hit:flat":["_ranged_accuracy_stat",1],"magic_hit:flat":["_magic_accuracy_stat",1]}
	for code: String in scalar:
		rt.totals={};rt.bonus_record={}
		var method: String = str(scalar[code][0])
		check(world.has_method(method),"existing actual stat hook "+method)
		if not world.has_method(method): continue
		var before: float = float(world.call(method))
		rt.totals={code:scalar[code][1]};rt.bonus_record=Stats.record(rt.totals)
		check(is_equal_approx(float(world.call(method))-before,float(scalar[code][1])),"actual stat delta "+code)
	for attr: String in ["str","dex","con","int","wis","cha"]:
		rt.totals={};rt.bonus_record={}
		var before: int = world._effective_attribute(attr.to_upper())
		rt.totals={attr+":flat":1};rt.bonus_record=Stats.record(rt.totals)
		check(world._effective_attribute(attr.to_upper())==before+1,"actual attribute delta "+attr)
	for style: String in ["melee","ranged","magic"]:
		rt.totals={};rt.bonus_record={}
		var before: int=world._player_critical_damage(100,style)
		rt.totals={style+"_critical_damage:flat":2};rt.bonus_record=Stats.record(rt.totals)
		check(world._player_critical_damage(100,style)==before+2,"critical damage applied after multiplier "+style)
		rt.totals={};rt.bonus_record={}
		var damage_before: int = world._equipment_additional_damage(style)
		var hit_before: int = world._equipment_accuracy_bonus(style)
		rt.totals={"pve_"+style+"_damage:flat":1,"pve_"+style+"_hit:flat":1};rt.bonus_record=Stats.record(rt.totals)
		check(world._equipment_additional_damage(style)==damage_before+1 and world._equipment_accuracy_bonus(style)==hit_before+1,"explicit PvE style hooks "+style)
	rt.totals={};rt.bonus_record={}
	var xp_before: float=world._experience_multiplier()
	var attack_before: float=world._effective_attack_speed_bonus_percent()
	var move_before: float=world._effective_move_speed_multiplier()
	var reduction_before: int=world._pve_damage_after_item_buffs(100)
	rt.totals={"experience_bonus:percent":0.1,"attack_speed:percent":0.5,"movement_speed:percent":0.5,"pve_damage_reduction:flat":2};rt.bonus_record=Stats.record(rt.totals)
	check(is_equal_approx(world._experience_multiplier(),xp_before+0.001),"XP percent /100 conversion")
	check(is_equal_approx(world._effective_attack_speed_bonus_percent(),attack_before+0.5),"fractional attack speed preserved")
	check(is_equal_approx(world._effective_move_speed_multiplier(),clampf(move_before*1.005,0.5,2.5)),"movement respects existing multipliers/cap")
	check(world._pve_damage_after_item_buffs(100)==reduction_before-2,"PvE reduction actual hook")
	for code: String in Stats.SUPPORTED: check(not code.begins_with("pvp_"),"no unauthorized PvP conversion "+code)
	world.queue_free();await process_frame
	print("COLLECTION_STATS_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty():print("EQUIPMENT_COLLECTION_STATS_OK")
	quit(0 if failures.is_empty() else 1)
