extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const SCALE=preload("res://scripts/crafting/patch523_equipment_combat.gd")
const ITEM_OPTIONS=preload("res://scripts/item_options.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const ELEMENT=preload("res://scripts/elemental_rules.gd")
const SOURCE_AMMO=preload("res://scripts/shop/source523_ammo.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("NORMAL_HIT_SCOPE_FAIL ",msg)
func _initialize()->void:run.call_deferred()
func reference(w:Node,target:TwilightMonster,kind:String,native:int)->Dictionary:
	var base:int=w._ranged_normal_damage_stat() if kind=="ranged" else w._melee_damage_stat()
	var max_roll:int=ITEM_OPTIONS.weapon_size_damage(w._equipped_weapon_record(),str(target.get_meta("size_class","small")).to_lower()=="large")
	var roll:int=w.rng.randi_range(1,max_roll) if max_roll>0 else 0
	if max_roll>0:
		var weapon:Dictionary=w._equipped_weapon_record()
		var extra:int=ITEM_OPTIONS.additional_damage(weapon,"melee")+w._enhancement_weapon_stat("damage")
		var policy:String=str(w.ui_preferences.get("patch523_weapon_double_scope","base_flat_enchant"))
		if policy not in ["base_flat_enchant","base_only","disabled"]:policy="base_flat_enchant"
		var outcome:Dictionary=DROPS.weapon_invoke_roll(weapon,roll,max_roll,extra,policy,w.rng)
		for message:String in outcome.fired:w.hud.append_log(message)
		roll=int(outcome.damage)
	roll=SCALE.weapon_scale(w,roll,kind,target)
	var damage:int=maxi(1,base+roll+(native if native>=0 else w._roll_source_ammo_damage(target))+SOURCE_AMMO.roll({},target,w.rng))
	var chance:float=w._critical_chance(w._player_critical_rate(kind),target.critical_resistance)
	var critical:bool=w.rng.randf()<chance
	if critical:damage=w._player_critical_damage(damage,kind)
	var element:String="holy"
	if w._active_skill_buff_total("element_bonus_holy")<=0:
		var enchanted:String=str(w.consumable_service.call("weapon_element",w._equipped_weapon_record()))
		element=ELEMENT.channel(enchanted if enchanted!="" else str(w._equipped_weapon_record().get("element","physical")))
	damage=w._elemental_damage_to_monster(damage,element,target)
	damage+=int(w.consumable_service.call("weapon_element_bonus",w._equipped_weapon_record(),target))
	return {"damage":damage,"critical":critical,"chance":chance}
func samples(times:Array)->Array:
	times.sort()
	return [times[times.size()/2],times[ceili(.95*times.size())-1],times.back(),times.filter(func(t:int)->bool:return t>16000 and t<=50000).size(),times.filter(func(t:int)->bool:return t>50000).size()]
func run()->void:
	Engine.max_fps=0
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w,"기사"),"actual Main confirmed original knight")
	w.player.set_physics_process(false);w.field_population.set_process(false)
	var target:TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	w.monsters_root.add_child(target)
	target.setup({"name":"combat_roll_scope_fixture","hp":1000000000,"lv":1,"atk":0},w.player,w,null)
	target.set_physics_process(false);target.hp=1000000000
	w.level=89;w.str_stat=47;w.dex_stat=44
	for slot:String in w.EQUIPMENT_SLOT_ORDER:
		w.equipped_items[slot]={"name":"test gear "+slot,"atk":5,"hit":3,"stat_str":2,"stat_dex":3,"crit":2,"element":"fire"}
	for _i:int in range(4):await process_frame
	var cpu_old:Array=[];var cpu_new:Array=[];var frame_old:Array=[];var frame_new:Array=[]
	var saw_critical:bool=false;var saw_plain:bool=false
	for i:int in range(81):
		var ranged:bool=i%2!=0;var kind:String="ranged" if ranged else "melee"
		var wet:Dictionary={"name":"test bow" if ranged else "test sword","type":"활" if ranged else "한손검","atk":15 if ranged else 19,"hit":18,"smallDmg":17,"largeDmg":11,"element":"water" if ranged else "fire","crit":12}
		w.equipped_items["weapon"]=wet;w._invalidate_equipment_static()
		target.critical_resistance=i%6
		target.set_meta("size_class","large" if i%4>=2 else "small")
		w.str_stat=47+i%4;w.dex_stat=44+i%7
		var initial:int=i+873
		var outcome:Dictionary={};var rng_after:int=0
		for phase:int in range(2):
			var old:bool=(i+phase)%2==0
			w.rng.seed=initial
			var started:int=Time.get_ticks_usec()
			var actual:Dictionary=reference(w,target,kind,9 if ranged else -1) if old else w._normal_hit_damage_roll(target,kind,{},9 if ranged else -1)
			var elapsed:int=Time.get_ticks_usec()-started
			if phase==0:outcome=actual;rng_after=w.rng.state
			else:ck(actual==outcome and w.rng.state==rng_after,"same exact roll, crit and RNG with those mutable stats/weapon "+str(i))
			saw_critical=saw_critical or actual.critical
			saw_plain=saw_plain or not actual.critical
			await process_frame
			var interval:int=Time.get_ticks_usec()-started
			if i==0:continue
			if old:cpu_old.append(elapsed);frame_old.append(interval)
			else:cpu_new.append(elapsed);frame_new.append(interval)
	ck(saw_critical and saw_plain and w._stat_memo_depth==0 and w._stat_memo.is_empty(),"critical and noncritical tested; no memo survives the roll")
	print("NORMAL_HIT_SCOPE_CPU_US old=",samples(cpu_old)," new=",samples(cpu_new))
	print("NORMAL_HIT_SCOPE_NEXT_PROCESS_US old=",samples(frame_old)," new=",samples(frame_new))
	for kind:String in ["melee","ranged"]:
		var chance:float=w._normal_attack_hit_chance(target,kind)
		var prior:int=target.hp
		var probe:=RandomNumberGenerator.new()
		for want_hit:bool in [false,true]:
			var trial:int=1
			while trial<=500:
				probe.seed=trial
				if (probe.randf()<chance)==want_hit:break
				trial+=1
			ck(trial<=500,"seeded exact "+kind+" "+("hit" if want_hit else "miss"))
			w.rng.seed=trial
			w._resolve_normal_attack(target,kind)
			ck(target.hp<prior if want_hit else target.hp==prior,"actual Main "+kind+" "+("hit damages" if want_hit else "miss preserves HP"))
			ck(w._stat_memo_depth==0,"scoped memo cannot leak to passives/target HUD")
			prior=target.hp
	# Test the existing mastery branch without claiming a pinned mastery pack
	# was provided. The ordinary points owner is activated on a fresh ledger.
	var mastery = w.weapon_mastery
	mastery.enabled=true
	mastery.balance_config=mastery.balance_config.duplicate(true)
	mastery.balance_config.normal_hit_points=3
	# Only the exact MasteryWeaponType row needed by the point owner; no
	# simulation of sealed claims, levels or native gear outside this fixture.
	mastery.core.tables["MasteryWeaponType"]=[{"ID":21,"ActualType":1,"BaseType":1,"AssetID":197791}]
	var weapon_type:int=w._mastery_actual_weapon_type()
	ck(weapon_type==1 and mastery.core.normalize_weapon(weapon_type)==1,"exact sword source row maps to normal mastery type")
	if weapon_type==1:
		var mastery_record:Dictionary=mastery.core.record(mastery.state,weapon_type)
		var points:int=int(mastery_record.points)
		var hit_proof:=RandomNumberGenerator.new()
		var chance:float=w._normal_attack_hit_chance(target,"melee")
		var seed_hit:int=1
		while seed_hit<500:
			hit_proof.seed=seed_hit
			if hit_proof.randf()<chance:break
			seed_hit+=1
		w.rng.seed=seed_hit
		w._resolve_normal_attack(target,"melee",weapon_type+1000)
		ck(int(mastery.core.record(mastery.state,weapon_type).points)==points,"queued weapon mismatch does not award mastery")
		w.rng.seed=seed_hit
		w._resolve_normal_attack(target,"melee",weapon_type)
		ck(int(mastery.core.record(mastery.state,weapon_type).points)==points+3 and w._stat_memo_depth==0,"valid hit applies mastery before immutable roll (save_protected=%s owner=%s)" % [str(w.source_save_blocked),str(mastery.balance_error)])
	w.queue_free();await process_frame
	print("NORMAL_HIT_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
