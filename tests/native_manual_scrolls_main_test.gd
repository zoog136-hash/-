extends SceneTree
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const MANUAL=preload("res://scripts/loot/native_manual_scrolls523.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const EFFECTS=preload("res://scripts/loot/source523_item_effects.gd")
const RULES=preload("res://scripts/einasad/einasad523_rules.gd")
const DRAGON:=139581
const EXCLUDED_OLD:=227828
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
var exercised_main:bool=false
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("MANUAL_SCROLLS_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func reject(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func run()->void:
	ck(MANUAL.profile({},{}).is_empty() and not MANUAL.RULES.has(EXCLUDED_OLD),"manual profile never activates the expired similarly named event")
	var bad:Dictionary={MANUAL.ORACLE_KEY:{"source_manual_pve_amp_pct":2,"remaining":5.0}}
	ck(MANUAL.oracle_damage_percent(bad,false)==0,"PvE effect requires exact identity, not copied label")
	var definitions:String=OS.get_environment("TWILIGHT_NATIVE_MANUAL_SCROLL_DEFINITIONS")
	if not definitions.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main"):
		await exact(definitions)
		ck(exercised_main,"Main reached full save and lifecycle verification")
	print("NATIVE_MANUAL_SCROLLS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func tap_use(h:Node,ref:String)->void:
	var bag:Control=h.lineage_inventory_ui
	var native:bool=h.original_inventory_is_open()
	var control:Variant=h.original_main_ui_controller._inventory_view._hits.get(ref,{}).get("control") if native else bag.slot_buttons.get(ref)
	if not ck(control is Control and is_instance_valid(control),"actual bag contains visible selected slot "+ref):return
	var point:Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	bag.disarm_item_action()
	tap(point)
	ck(bag.item_action_label(ref)=="사용","first screen touch arms the physical action "+ref)
	tap(point)

func tap(point:Vector2)->void:
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=9;event.pressed=pressed;event.position=point
		root.push_input(event,true)

func attack(w:Node,target:TwilightMonster,is_player:bool)->int:
	target.hp=10000;target.set_meta("is_player_combatant",is_player)
	w.rng.seed=2065161
	w._deal_successful_player_hit(target,1000,false,"melee",true,false,{"final_blow":false})
	return 10000-target.hp

func incoming(w:Node,target:TwilightMonster,is_player:bool)->int:
	target.set_meta("is_player_combatant",is_player)
	w.player.global_position=target.global_position+Vector2(24,0)
	target.melee_accuracy=999999;target.melee_critical_rate=0;target.attack_element="physical"
	w.hp=w._effective_max_hp();var initial:int=w.hp
	w.rng.seed=424242
	w._on_player_hit(target,1000,"melee")
	var loss:int=initial-w.hp
	w.hp=initial
	return loss

func exact(definitions:String)->void:
	root.size=Vector2i(1280,720)
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",definitions);SRC.reset();RULES.reset_cache()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"pinned definition archive")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var real_ids:Array=MANUAL.RULES.keys()+[DRAGON]
	var requests:Array=[]
	for id:int in real_ids:
		var row:Dictionary=w.source_item_definition(id)
		var record:Dictionary=row.get("native_record",{})
		w.catalog_db["아이템"].append(record)
		requests.append({"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0})
		if id!=DRAGON:ck(STACK.profile(record).get("spec",{}).get("typed_effects")==MANUAL.RULES[id][6],"full exact guarded source profile "+str(id))
	ck(MANUAL.profile(w.source_item_definition(EXCLUDED_OLD).get("native_record",{}),{}).is_empty(),"the issue that ended 2022 is still not admitted")
	w._index_catalog_item_sources()
	var created:Dictionary=INV.stage(w,requests,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(created.get("ok",false),"actual supplier stages physical source stock "+str(created.get("error",""))):w.queue_free();return
	w.inventory=created.overrides.inventory;w.item_instances=created.overrides.item_instances
	var uids:Dictionary={};var refs:Dictionary={}
	for uid:String in w.item_instances:
		var item:Dictionary=w.item_instances[uid];var id:int=int(item.get("record",{}).get("source_item_class_id",0))
		if id in real_ids:uids[id]=uid;refs[id]=str(item.name)+"@@@"+uid
	if not ck(uids.size()==real_ids.size(),"actual physical scroll and dragon references"):w.queue_free();return
	if not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty() and not is_instance_valid(w.hud.original_main_ui_controller):w.hud._bind_selected_original_main_ui()
	var h:Node=w.hud
	ck(not w._quickslot_auto_allowed({"kind":"item","id":refs[MANUAL.WEIGHT].get_slice("@@@",0)}),"manual weight profile does not activate unverified automatic overlap policy")
	w._update_hud();h.refresh_inventory(w.inventory);h.toggle_inventory()
	await process_frame
	ck(h.original_inventory_is_open()==not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"actual selected inventory presentation")
	var weight_base:int=w._carrying_capacity();var xp_base:int=w._active_item_buff_total("xp")
	var reduction_base:float=w._pve_reduction_percent("melee")
	var target:TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	w.monsters_root.add_child(target);target.setup({"name":"원본 주문서 검증 대상","hp":10000,"lv":1,"atk":0},w.player,w,null);target.set_physics_process(false)
	var pve:int=attack(w,target,false);var pvp:int=attack(w,target,true)
	var safe:Vector2=w.player.global_position
	var combat_point:Vector2=safe
	var seeded:=RandomNumberGenerator.new();seeded.seed=802891
	if w.field_map!=null:
		for attempt:int in range(128):
			var candidate:Vector2=w.field_map.random_landing(seeded,safe,600,1800)
			if w.field_map.point_clear(candidate,4) and not w.field_map.is_safe(candidate+Vector2(24,0)):combat_point=candidate;break
	target.global_position=combat_point
	ck(w.field_map==null or combat_point!=safe,"incoming fixture is not prevented by the safe zone")
	var npc_damage:int=incoming(w,target,false);var pc_damage:int=incoming(w,target,true)
	w.player.global_position=safe
	w.level=50
	w.ain_service.blessing=150
	var dragon:Dictionary=w.item_instances[uids[DRAGON]].record
	var dragon_before:Dictionary=EFFECTS.prepare(w,dragon,"ain")
	ck(dragon_before.get("ok",false),"same actual dragon charge joins before applying the scroll "+str(dragon_before.get("reason","")))
	ck(w._save_game(true)==OK,"baseline writer")
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	w.equipment_collections.test_save_writer=reject
	tap_use(h,refs[MANUAL.WEIGHT])
	ck(rejected.get("item_instances",{}).get(uids[MANUAL.WEIGHT],{}).get(STACK.QUANTITY)==1 and not rejected.get("active_item_buffs",{}).is_empty(),"writer sees selected debit and exact buff together")
	ck(STACK.proof(w,uids[MANUAL.WEIGHT]).get("remaining")==2 and w._carrying_capacity()==weight_base and FileAccess.get_file_as_bytes(w.save_path())==bytes,"writer fault changes neither receipt nor carried capacity")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true)
	if not h.original_inventory_is_open() and h.active_section!="inventory":h.toggle_inventory()
	for id:int in MANUAL.RULES:
		tap_use(h,refs[id])
		ck(STACK.proof(w,uids[id]).get("remaining")==1 and w.item_use_cooldowns.get("m523:item:"+str(id))==0.5,"one exact scroll is consumed with authored time "+str(id))
		var active:Dictionary=w.active_item_buffs.get(MANUAL.ORACLE_KEY if id==MANUAL.ORACLE else refs[id].get_slice("@@@",0),{})
		ck(active.get("duration")==1800.0 and active.get("remaining")==1800.0,"actual buff uses original 30 minutes "+str(id))
	ck(w._carrying_capacity()==weight_base+180 and w._active_item_buff_total("xp")==xp_base+18 and is_equal_approx(w._pve_reduction_percent("melee"),reduction_base+2),"existing carry, progression and incoming PvE consumers read the new values")
	var boosted:int=attack(w,target,false);var not_boosted:int=attack(w,target,true)
	ck(boosted==int(round(float(pve)*1.02)) and pve>0 and not_boosted==pvp,"real outgoing PvE hit increases by 2%% without PvP projection: %s" % [[pve,boosted,pvp,not_boosted]])
	var guarded:int=incoming(w,target,false);var not_guarded:int=incoming(w,target,true)
	ck(guarded==int(round(float(npc_damage)*0.98)) and npc_damage>0 and not_guarded==pc_damage and pc_damage>0,"real incoming PvE falls by 2%% without PvP projection: %s" % [[npc_damage,guarded,pc_damage,not_guarded]])
	w.player.global_position=safe
	if dragon_before.get("ok",false):
		var charged:Dictionary=EFFECTS.prepare(w,dragon,"ain")
		var current:int=w.ain_service.blessing
		tap_use(h,refs[DRAGON])
		ck(charged.get("charged")==int(round(float(dragon_before.charged)*1.05)) and w.ain_service.blessing-current==charged.get("charged"),"actual native dragon charge uses original +5%")
	w._load_game(true)
	ck(w._carrying_capacity()==weight_base+180 and w._active_item_buff_total("xp")==xp_base+18,"reload retains all three timed effects and physical receipts")
	USE.clear_on_death(w)
	ck(w._carrying_capacity()==weight_base and w._active_item_buff_total("xp")==xp_base+18,"weight spell clears on death while the two source-immune buffs remain")
	w._tick_item_buffs(1800)
	ck(w._active_item_buff_total("xp")==xp_base and w._amount_with_ainhasad_charge_bonuses(100)==100,"the timed EXP and charge multipliers end together")
	exercised_main=true
	w.queue_free();await process_frame
