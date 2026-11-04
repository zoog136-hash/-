extends "res://tests/patch523_enhancement_main_test.gd"
const COMBAT=preload("res://scripts/crafting/patch523_equipment_combat.gd")
var ui_only: bool=false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--ui-only":ui_only=true
	super._initialize()

func equip_source(world: TwilightWorld,id: String,rank: int,bless: int) -> Dictionary:
	var source: Dictionary=world.patch523_equipment.record(id)
	var job: String=world.job_class
	if not world.PATCH523_ITEM_USE.reason(source,100,world.BASE508.source_class_id(job)).is_empty() or (source.get("slot")=="weapon" and not world._weapon_allowed_for_job(source,job)):
		for candidate: String in world.JOB_ALLOWED_WEAPONS:
			if not world.PATCH523_ITEM_USE.reason(source,100,world.BASE508.source_class_id(candidate)).is_empty():continue
			if source.get("slot")=="weapon" and not world._weapon_allowed_for_job(source,candidate):continue
			job=candidate;break
	check(QA.enter_game(world,job),"real class UI for source invoke equipment "+id)
	world.level=100
	var record: Dictionary=own(world,id,rank,bless)
	var slot: String=world._equipment_slot_base(record)
	if slot in ["earring","ring","seal"]:slot+="1"
	world._equip_reference_in_slot(str(record.name)+"@@@90001",slot)
	check(world.equipped_items.get(slot,{}).get("instance_id")=="90001","actual source physical item equips "+id)
	return record

func seed_integer(world: TwilightWorld,weight: int,success: bool) -> void:
	var probe:=RandomNumberGenerator.new()
	for seed: int in range(100000):
		probe.seed=seed
		var value: int=probe.randi_range(0,999999)
		if (value<weight)==success:world.rng.seed=seed;return
	check(false,"source invoke integer interval reachable")

func run() -> void:
	var managed_install: bool=OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES").is_empty()
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main/class confirmation")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	var book: Object=world.patch523_equipment
	var initial_digest: String=book.digest
	check(book.problem.is_empty() and book.data.source_files.size()==37,"all37 pinned source tables loaded")
	check(book.data.enchantment.InvokeOption.size()==2216 and book.data.enchantment.InvokeOptionType.size()==71,"whole source invoke and type tables retained")
	var target: TwilightMonster=world.MONSTER_SCENE.instantiate()
	# A harness-owned actor uses the production NPC scene while remaining out
	# of the field population pool, which legitimately recycles unregistered mobs.
	world.add_child(target);target.global_position=world.player.global_position+Vector2(32,0)
	check(not world.monster_db.is_empty(),"existing game NPC definition exists")
	var npc_record: Dictionary=world.monster_db[0].duplicate(true)
	target.setup(npc_record,world.player,world,world._monster_texture(npc_record))
	target.set_physics_process(false);target.set_process(false);target.social_alert_cooldown=1000000
	# Only this test target's HP is enlarged to observe all source hits without
	# killing it or generating loot. This is not an original-NPC-stat claim.
	target.max_hp=1000000;target.hp=target.max_hp;target.hp_bar.max_value=target.max_hp
	var cases: Dictionary={}
	for id: String in book.data.equipment_runtime:
		var runtime: Dictionary=book.data.equipment_runtime[id]
		for bless: String in runtime.invokes:
			for rank: String in runtime.invokes[bless]:
				for row: Dictionary in runtime.invokes[bless][rank]:
					if not cases.has(int(row.row_id)):cases[int(row.row_id)]={"id":id,"bless":int(bless),"rank":int(rank),"row":row}
	check(cases.size()==130,"all130 connected source invoke rows, not a few samples")
	var seen: int=0
	for case: Dictionary in ([] if ui_only else cases.values()):
		var record: Dictionary=equip_source(world,case.id,case.rank,case.bless)
		var row: Dictionary=case.row
		check(COMBAT.valid(row),"source numeric invoke remains typed "+str(row.row_id))
		var kind: String="ranged" if int(row.option.AttackTypeID)==2 else "melee"
		var before_rng: int=world.rng.state
		var active: Array=COMBAT.active(world,row.kind)
		check(active.size()==1 and int(active[0].row_id)==int(row.row_id),"actual worn source row selected "+str(row.row_id))
		check(world.rng.state==before_rng,"source preview never rolls "+str(row.row_id))
		var probability: int=int(row.probability)
		if probability>0:seed_integer(world,probability,true)
		target.hp=target.max_hp
		var result: int=777
		if row.kind=="attack_fixed_damage":COMBAT.on_hit(world,target,kind,true,false)
		else:result=COMBAT.incoming(world,target,kind,777)
		check(COMBAT.fired.size()==(1 if probability>0 else 0),"actual source proc/zero branch "+str(row.row_id))
		var amount: int=int(row.option.Param1) if probability>0 else 0
		check(target.hp==target.max_hp-amount if row.kind=="attack_fixed_damage" else result==777-amount,"actual fixed source amount "+str(row.row_id))
		if probability<1000000 and probability>0:
			seed_integer(world,probability,false);target.hp=target.max_hp
			if row.kind=="attack_fixed_damage":COMBAT.on_hit(world,target,kind,true,false)
			else:result=COMBAT.incoming(world,target,kind,777)
			check(COMBAT.fired.is_empty() and (target.hp==target.max_hp if row.kind=="attack_fixed_damage" else result==777),"actual original failure interval "+str(row.row_id))
		check(world._save_game(true)==OK,"every connected source row saves through actual Main "+str(row.row_id))
		world._load_game(true)
		var restored: Array=COMBAT.active(world,row.kind)
		check(restored.size()==1 and int(restored[0].row_id)==int(row.row_id) and int(restored[0].probability)==probability and int(restored[0].option.Param1)==int(row.option.Param1),"every connected source row restores original chance/amount/identity "+str(row.row_id))
		check(world.patch523_equipment.bless_code(world.item_instances["90001"])==int(case.bless) and int(world.item_instances["90001"].level)==int(case.rank),"every source physical blessing/level survives "+str(row.row_id))
		check(book._state_matches(world.item_instances["90001"],{"source_id":str(case.id),"level":int(case.rank),"bless_code":int(case.bless)},false),"derived source invokes remain exact valid crafting material state "+str(row.row_id))
		seen+=1
	print("PATCH523_EQUIPMENT_INVOKE_ALL_ROWS ",JSON.stringify({"source_rows":cases.size(),"actual_rows_executed":seen,"matrix_skipped":ui_only}))
	# Real weapon/passive event dispatch, then exact non-spell qualification.
	var record: Dictionary=equip_source(world,"632",5,1)
	seed_integer(world,20000,true);target.hp=target.max_hp
	world._try_trigger_passives("on_hit",target,"melee",true,false)
	check(not COMBAT.fired.is_empty() and target.hp<=target.max_hp-20,"actual successful-hit world event fires source equipment effect")
	var snapshot: int=world.rng.state;target.hp=target.max_hp
	COMBAT.on_hit(world,target,"magic",true,true)
	check(COMBAT.fired.is_empty() and target.hp==target.max_hp and world.rng.state==snapshot,"normal-hit source invoke never leaks to spells")
	# Two real copies equip through the existing UI/API. Same option rolls once
	# at its strongest probability under the explicitly named game setting.
	world.inventory[str(record.name)]=2;world._sync_item_instances()
	var second: String=""
	for id: String in world.item_instances:
		if id!="90001" and world.item_instances[id].name==record.name:second=id;break
	check(not second.is_empty(),"second physical source earring exists")
	if not second.is_empty():
		world.item_instances[second].level=8
		world._equip_reference_in_slot(str(record.name)+"@@@"+second,"earring2")
		check(world.equipped_items.get("earring2",{}).get("instance_id")==second,"second source copy equips in real second slot")
		var active: Array=COMBAT.active(world,"attack_fixed_damage")
		check(active.size()==1 and str(active[0].instance_id)==second,"configured duplicate policy selects strongest physical source hook once")
		check(world._save_game(true)==OK,"source invoke physical records save durably")
		world._load_game(true)
		check(COMBAT.active(world,"attack_fixed_damage").size()==1,"source invoke/duplicate policy survives actual reload")
		var candidates: Array=world._enhancement_candidates("accessory","normal","장신구 마법 주문서 (각인)")
		# Roomtis uses its own original scroll group, so its existing numeric
		# effect information is also available in the original equipment view.
		check(COMBAT.summary(world.item_instances[second].record,8).contains("발동"),"source invoke UI description is connected to actual saved record")
		world.hud.open_patch523_equipment_info();await process_frame
		var information: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
		check(information!=null,"actual source equipment information UI opens")
		if information!=null:
			var matching_scroll: bool=false
			for index: int in range(information.scroll_ids.size()):
				var evidence: Dictionary=book.enhancement_evidence(632,int(information.scroll_ids[index]),5,1,1)
				if not evidence.groups.is_empty() and not evidence.probabilities.is_empty():
					information.scroll.select(index);information.scroll.item_selected.emit(index);matching_scroll=true;break
			check(matching_scroll,"actual original compatible scroll is selectable in source information")
			check(information.pack_sha.text==book.digest,"source UI displays actually loaded pack hash")
			check(information.detail.text.contains("적중 추가 피해"),"source invoke amount/chance appears in actual detail")
			check(information.detail.text.contains("발동 확률 +2.00% · 적용 연결"),"raw source evidence correctly identifies the active invoke row")
			var scroll: ScrollContainer=information.find_child("Patch523EquipmentScroll",true,false)
			scroll.scroll_vertical=100000
			await capture("source-equipment-invoke-information")
	# Real NPC player_hit signal reaches the defensive hook. Use a traversable
	# non-safe point; ordinary hit/crit rolls remain enabled in this integration.
	record=equip_source(world,"629",5,1)
	var outside: Vector2=world.player.global_position
	for i: int in range(128):
		var point: Vector2=world.field_map.random_landing(world.rng,world.player.global_position,500,1800)
		if world.field_map.point_clear(point,4) and not world.field_map.is_safe(point):outside=point;break
	check(world.field_map.point_clear(outside,4) and not world.field_map.is_safe(outside),"actual traversable combat position outside safe area")
	world.player.global_position=outside;target.global_position=outside+Vector2(24,0)
	target.melee_accuracy=100000;target.ranged_accuracy=100000;target.magic_accuracy=100000
	target.melee_critical_rate=0;target.ranged_critical_rate=0;target.magic_critical_rate=0
	target.player_hit.connect(world._on_player_hit)
	var defensive_event: bool=false
	for seed: int in range(1000):
		world.hp=world._effective_max_hp();world.rng.seed=seed;COMBAT.fired.clear()
		target.player_hit.emit(target,80,"melee")
		if not COMBAT.fired.is_empty():defensive_event=true;break
	check(defensive_event,"actual NPC hit signal executes source defensive equipment invoke")
	check(COMBAT.summary(record,5).contains("피격 리덕션"),"source defensive effect text reflects its type")
	world._update_hud();await capture("source-equipment-defensive-proc")
	check(world._save_game(true)==OK,"defensive source invoke save")
	# Portable saved rules still work when the optional private pack is absent.
	OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES");OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
	target.queue_free();world.queue_free();await process_frame
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world,world.job_class),"actual saved class reload without equipment pack")
	if managed_install:
		check(world.patch523_equipment.digest==initial_digest and not world.patch523_equipment.data.is_empty(),"installed private pack restores without environment arguments")
	else:
		check(world.patch523_equipment.data.is_empty(),"private equipment pack genuinely absent in new Main")
	check(not COMBAT.active(world,"defence_flat_reduction").is_empty(),"saved source invoke remains effective after relaunch")
	world.queue_free();await process_frame
	print("PATCH523_EQUIPMENT_INVOKE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":seen}))
	quit(0 if failures.is_empty() else 1)
