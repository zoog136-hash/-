extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const ENGINE=preload("res://scripts/crafting/patch523_enhancement.gd")
const STATS=preload("res://scripts/original_enhancement.gd")
const BLESS=preload("res://scripts/equipment_blessing.gd")
var checks: int=0
var failures: Array[String]=[]
var captures: String=""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("PATCH523_ENHANCE_FAIL: ",label)
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):captures=arg.trim_prefix("--capture-dir=")
	call_deferred("run")
func capture(label: String) -> void:
	if captures.is_empty(): return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	check(root.get_texture().get_image().save_png(captures.path_join(label+".png"))==OK,"actual UI capture "+label)
func finish_reveal(world: TwilightWorld) -> void:
	if is_instance_valid(world.hud.enhancement_reveal):
		world.hud.enhancement_reveal.skip_to_result()
		world.hud.enhancement_reveal.close_reveal()
func own(world: TwilightWorld,id: String,rank: int,bless: int=1) -> Dictionary:
	var record: Dictionary=world.patch523_equipment.record(id).duplicate(true)
	check(not record.is_empty(),"actual source catalog record "+id)
	record["bless_state"]="blessed" if bless==2 else "normal"
	if record.get("source_m_native_item",false):record["source_bless_raw"]=bless
	world.inventory={str(record.name):1}
	world.item_instances={"90001":{"name":record.name,"record":record,"level":rank,"element":"","element_level":0,"bless_state":record.bless_state,"source_bless_code":bless}}
	world.equipped_items.clear();world.next_item_instance_id=90002;world.gold=1000000
	world._sync_item_instances()
	return world.item_instances["90001"].record
func seed_roll(world: TwilightWorld,low: float,high: float) -> void:
	var probe:=RandomNumberGenerator.new()
	for seed: int in range(100000):
		probe.seed=seed
		var value: float=probe.randf_range(0,100)
		if value>=low and value<high: world.rng.seed=seed;return
	check(false,"reachable requested result interval")

func probability_matrix(book: Object) -> void:
	var tables: Dictionary=book.data.enchantment
	var targets: Dictionary={}
	var scrolls: Dictionary={}
	for id: String in book.data.items:
		var entry: Dictionary=book.data.items[id]
		if entry.item_class.get("TestItem",false) or not str(entry.item_class.get("ServiceRegionCode","")).is_empty():continue
		var equip: Array=[]
		var scroll_groups: Dictionary={}
		for link: Dictionary in entry.item_bonuses:
			var b: Dictionary=book.data.bonuses[str(int(link.BonusID))]
			if int(b.BonusTypeID)==2032: equip.append(int(b.Value))
			if int(b.BonusTypeID)==2022: scroll_groups[int(b.Value)]=1
			if int(b.BonusTypeID)==8352 and int(b.BonusApplicationTypeID)==202 and int(b.BonusApplicationTargetID) in [1,2]:scroll_groups[int(b.Value)]=int(b.BonusApplicationTargetID)
		for row: Dictionary in tables.ItemEnchantEquipGroupMapping:
			if int(row.ItemEnchantEquipGroupID) in equip and book.data.equipment_runtime.has(id): targets[int(row.ItemEnchantProbabilityGroupID)]=id
		for row: Dictionary in tables.ItemEnchantScrollGroupMapping:
			if scroll_groups.has(int(row.ItemEnchantScrollGroupID)):scrolls[int(row.ItemEnchantProbabilityGroupID)]={"id":id,"bless":scroll_groups[int(row.ItemEnchantScrollGroupID)]}
	var executable: int=0
	var no_catalog: Array=[]
	for row: Dictionary in tables.BmItemEnchantProView:
		var group: int=int(row.ItemEnchantProbabilityGroupID)
		check(int(row.Success)+int(row.Remain)+int(row.Vaporize)+int(row.SideEffect)==1000000,"all source probability sums group "+str(group))
		if not targets.has(group) or not scrolls.has(group):no_catalog.append(row);continue
		var target: Dictionary=book.record(targets[group])
		var scroll: Dictionary=scrolls[group]
		var bless: int=maxi(1,int(row.TargetItemBlessCode))
		var quote: Dictionary=ENGINE.rule(book,target,scroll.id,int(row.EnchantLevel),bless,int(scroll.bless))
		check(quote.get("source_rule",false) and int(quote.get("group",-1))==group,"all registered source probability joins group "+str(group)+" level "+str(row.EnchantLevel))
		if int(quote.get("group",-1))!=group:continue
		for pair: Array in [["success","Success"],["no_change","Remain"],["destroy","Vaporize"],["decrease","SideEffect"]]:
			check(is_equal_approx(float(quote[pair[0]])*10000,float(row[pair[1]])),"actual dispatcher preserves original branch "+str(group)+" / "+str(pair[0]))
		executable+=1
	print("PATCH523_ENHANCEMENT_PROBABILITY_MATRIX ",JSON.stringify({"total":tables.BmItemEnchantProView.size(),"registered_target_source_scroll_definition_rows":executable,"no_registered_target_or_scroll_definition_rows":no_catalog.size()}))
func run() -> void:
	print("PATCH523_ENHANCE_STAGE Main load")
	var scene: PackedScene=load("res://Main.tscn")
	var world: TwilightWorld=scene.instantiate()
	print("PATCH523_ENHANCE_STAGE Main ready")
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	print("PATCH523_ENHANCE_STAGE Main class selection")
	check(QA.enter_game(world),"actual Main startup")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	var book: Object=world.patch523_equipment
	check(book.problem.is_empty() and book.recipes.size()==732,"full actual732 source pack loaded")
	check(book.data.source_files.size()==(37 if book.data.enchantment.has("InvokeOption") else 33),"all pinned original tables included; explicit v8/v9 compatibility")
	var effect_items: int=0
	var ranks: int=0
	var extra_consumers: int=0
	for id: String in book.data.get("equipment_runtime",{}):
		if effect_items%200==0:print("PATCH523_ENHANCE_STAGE all-item matrix ",effect_items)
		var base: Dictionary=book.record(id)
		for bless: int in [1,2]:
			var prepared: Dictionary=ENGINE.prepare(book,base,bless)
			check(prepared.has("enhancement_options") and prepared.enhancement_options.size()==22,"complete exact source rank registry "+id+" state"+str(bless))
			for level: int in range(22):
				var actual: Dictionary=STATS.stats(world._enhancement_kind_for_record(base),level,prepared)
				check(actual==prepared.enhancement_options[str(level)],"actual stat reader uses exact rank/state "+id+" / "+str(level))
				ranks+=1
			# Actual Main option resolution must also work for newly registered
			# namespace items which do not appear in the old Inven-only index.
			var rank: int=0
			for candidate: int in range(21):
				if not prepared.enhancement_extra_options.get(str(candidate),{}).is_empty():rank=candidate
			var extras: Dictionary=prepared.enhancement_extra_options.get(str(rank),{})
			if not extras.is_empty():
				var pinned: Dictionary=prepared.duplicate(true)
				pinned["bless_state"]="blessed" if bless==2 else "normal"
				if pinned.get("source_m_native_item",false):pinned["source_bless_raw"]=bless
				world.item_instances={"80001":{"name":base.name,"record":pinned,"level":rank,"bless_state":pinned.bless_state,"source_bless_code":bless}}
				var worn: Dictionary=base.duplicate(true);worn["instance_id"]="80001"
				var actual: Dictionary=world._source_catalog_record("아이템",worn)
				var baseline: Dictionary=world.INVEN_OPTIONS.annotate(base)
				for key: String in extras:
					check(is_equal_approx(float(actual.get(key,0))-float(baseline.get(key,0)),float(extras[key])),"actual Main typed extra consumer "+id+" / "+key)
					extra_consumers+=1
		effect_items+=1
	check(effect_items==1534,"all1534 currently registered original equipment covered, no sample count")
	check(extra_consumers>0,"actual Main typed-extra consumers were exercised")
	print("PATCH523_ENHANCEMENT_ALL_ITEMS ",JSON.stringify({"items":effect_items,"rank_state_reads":ranks,"main_extra_consumers":extra_consumers}))
	probability_matrix(book)
	check(float(ENGINE.rule(book,book.record("252"),"138",0,-1,1).get("success",0))==0,"inconsistent physical blessing cannot select default-zero rule")
	check(float(ENGINE.rule(book,book.record("252"),"138",0,1,3).get("success",0))==0,"unrepresented cursed scroll cannot enter ordinary branch")
	check(float(world._source_enhancement_rule(book.record("252"),0,"normal","갑옷 마법 주문서 (각인)",{"sourceId":"332"}).get("success",0))==0,"conflicting physical source ID is blocked")
	check(float(ENGINE.rule(book,book.record("30671"),"320802",3,2,1).get("success",0))==0,"generic source selector preserves verified normal-only seal qualification")
	# Material is descriptive; exact equipment/scroll relation controls safety.
	for test: Array in [["252",4,25.0],["332",6,100.0],["3192",0,33.3]]:
		var record: Dictionary=book.record(test[0])
		var rule: Dictionary=world._source_enhancement_rule(record,4 if test[0]!="3192" else 0,"normal")
		check(int(rule.get("safe_level",-1))==test[1] and is_equal_approx(float(rule.get("success",-1)),test[2]),"source material/group safety "+test[0])
	check(BLESS.bonus_for("신화","weapon")=={"damage":3} and BLESS.bonus_for("유일","weapon")=={"damage":6},"active source mythic/unique weapon blessing")
	check(BLESS.bonus_for("신화","armor")=={"defense":3} and BLESS.bonus_for("유일","armor").is_empty(),"active mythic armor; IsTest unique row excluded")
	check(BLESS.bonus_for("희귀","accessory")=={"hp":20} and BLESS.bonus_for("영웅","accessory")=={"potion_heal_pct":1},"source accessory blessing HP and potion tiers")
	# Actual UI execution from source equipment, including safety differences.
	var record: Dictionary=own(world,"332",4)
	var scroll: String="갑옷 마법 주문서 (각인)"
	world.inventory[scroll]=3;world._update_hud()
	var candidates: Array=world._enhancement_candidates("armor","normal",scroll)
	check(candidates.size()==1 and candidates[0].safe_level==6 and candidates[0].cost==1000,"actual forge receives exact safety and source fee")
	world.hud.open_enhancement(scroll,candidates)
	await process_frame
	check(world.hud.enhancement_forge.detail.text.contains("1000 아데나") and world.hud.enhancement_forge.detail.text.contains("원본523 그룹 6"),"actual forge displays source cost/group policy")
	await capture("elven-safe-six")
	world.hud.enhancement_requested.emit(scroll,str(record.name)+"@@@90001")
	check(world.item_instances["90001"].level==5 and world.gold==999000 and world.inventory[scroll]==2,"actual UI signal consumes exact fee/scroll and succeeds")
	finish_reveal(world);await process_frame
	check(world._save_game(true)==OK,"enhancement durable save")
	world._load_game(true)
	check(world.item_instances["90001"].level==5 and world.gold==999000,"enhancement level/cost survive actual reload")
	# Save failure must roll back the source fee and RNG as one transaction.
	world.source_save_blocked=true
	var before: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.rng.state])
	world._attempt_enhancement(scroll,str(record.name)+"@@@90001")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.rng.state])==before,"source save rejection preserves equipment/cost/scroll/RNG")
	world.source_save_blocked=false
	# Source blessed leap weights drive actual integer RNG, including +3.
	record=own(world,"332",0);scroll="축복받은 갑옷 마법 주문서 (각인)";world.inventory[scroll]=1
	var probe:=RandomNumberGenerator.new()
	for seed: int in range(10000):
		probe.seed=seed;probe.randf_range(0,100)
		if probe.randi_range(0,999999)>=666667:world.rng.seed=seed;break
	world._attempt_enhancement(scroll,str(record.name)+"@@@90001")
	check(world.item_instances["90001"].level==3 and world.gold==999000,"actual source blessed scroll uses original +3 leap branch")
	finish_reveal(world);await process_frame
	# Bone group has no safety, even at +0; force the actual destroy interval.
	record=own(world,"3192",0);scroll="무기 마법 주문서 (각인)";world.inventory[scroll]=1
	seed_roll(world,40,90);world._attempt_enhancement(scroll,str(record.name)+"@@@90001")
	check(not world.item_instances.has("90001") and not world.inventory.has(str(record.name)) and world.gold==999000,"actual bone +0 failure destroys only selected physical item and consumes cost")
	finish_reveal(world);await process_frame
	# Rare source accessory accepts blessing on exactly one physical ID.
	var accessory_id: String=""
	for id: String in book.data.equipment_runtime:
		var row: Dictionary=book.data.equipment_runtime[id]
		if int(row.category_id)==43 and int(row.grade_id)==3 and world._enhancement_kind_for_record(book.record(id))=="accessory": accessory_id=id;break
	check(not accessory_id.is_empty(),"actual rare accessory identity exists")
	if not accessory_id.is_empty():
		record=own(world,accessory_id,0)
		var bless_scroll: String="축복 부여 주문서 (각인)"
		world.inventory[bless_scroll]=2;world._update_hud()
		world.consumable_service._use_bless_scroll(bless_scroll);await process_frame
		check(world.hud.enhancement_forge.mode=="blessing" and world.hud.enhancement_forge.values.size()==1,"actual blessing chooser includes source accessory")
		await capture("accessory-blessing")
		world.source_save_blocked=true
		before=JSON.stringify([world.inventory,world.item_instances,world.rng.state])
		check(not world.consumable_service.apply_bless_scroll(bless_scroll,str(record.name)+"@@@90001",0),"blocked blessing reports failure")
		check(before==JSON.stringify([world.inventory,world.item_instances,world.rng.state]),"blessing save rejection preserves scroll/item/RNG")
		world.source_save_blocked=false
		check(world.consumable_service.apply_bless_scroll(bless_scroll,str(record.name)+"@@@90001",0),"source accessory blesses through actual durable service")
		check(world.inventory[bless_scroll]==1 and book.bless_code(world.item_instances["90001"])==2,"source accessory blessing consumes once, state agrees")
		world._load_game(true)
		check(book.bless_code(world.item_instances["90001"])==2,"accessory blessing survives reload")
	# Potion blessing has a separate live consumer from HP/weapon blessing.
	var potion_id: String=""
	world.level=100
	for id: String in book.data.equipment_runtime:
		var row: Dictionary=book.data.equipment_runtime[id]
		var source: Dictionary=book.record(id)
		if int(row.category_id)==43 and int(row.grade_id)==4 and source.get("slot")=="necklace" and world.PATCH523_ITEM_USE.reason(source,100,world.BASE508.source_class_id(world.job_class)).is_empty():potion_id=id;break
	check(not potion_id.is_empty(),"actual equippable hero necklace source identity")
	if not potion_id.is_empty():
		record=own(world,potion_id,0)
		world.inventory["축복 부여 주문서 (각인)"]=1
		world._equip_reference_in_slot(str(record.name)+"@@@90001","necklace")
		check(world.equipped_items.get("necklace",{}).get("instance_id")=="90001","actual source necklace equips")
		world.inventory["빨간 물약"]=2;world.hp=1;world.item_use_cooldowns.clear()
		world._use_healing_item("빨간 물약",100)
		var before_heal: int=world.hp
		check(world.consumable_service.apply_bless_scroll("축복 부여 주문서 (각인)",str(record.name)+"@@@90001",0),"source hero necklace blessing succeeds")
		check(world._equipped_bless_bonus("potion_heal_pct")==1,"actual equipped source potion blessing contributes1%")
		world.hp=1;world.item_use_cooldowns.clear();world._use_healing_item("빨간 물약",100)
		check(world.hp==before_heal+1,"actual potion heals one extra HP from source1% blessing")
		check(world._save_game(true)==OK,"source potion blessing save")
		world._load_game(true)
		check(world._equipped_bless_bonus("potion_heal_pct")==1,"source potion blessing consumer survives save/reconnect")
	var regen_id: String=""
	var regen_rank: int=0
	var regen_delta: int=0
	for id: String in book.data.equipment_runtime:
		var prepared: Dictionary=ENGINE.prepare(book,book.record(id),1)
		for rank: int in range(1,21):
			var extra: Dictionary=prepared.enhancement_extra_options.get(str(rank),{})
			if int(extra.get("mpRecoveryTick",0))>0:
				regen_id=id;regen_rank=rank;regen_delta=int(extra.mpRecoveryTick);break
		if not regen_id.is_empty():break
	check(not regen_id.is_empty(),"source MP regeneration enhancement exists")
	if not regen_id.is_empty():
		record=own(world,regen_id,0)
		var worn: Dictionary=record.duplicate(true);worn["instance_id"]="90001"
		world.equipped_items["necklace"]=worn
		world._invalidate_equipment_static();world._refresh_equipment_effects()
		var base_regen: int=int(world.equipment_effects.mp_tick_amount)
		var base_delta: int=int(record.enhancement_extra_options.get("0",{}).get("mpRecoveryTick",0))
		world.item_instances["90001"].level=regen_rank
		world._invalidate_equipment_static();world._refresh_equipment_effects()
		check(int(world.equipment_effects.mp_tick_amount)==base_regen+regen_delta-base_delta,"actual source MP regeneration uses exact numeric delta, not legacy boolean quantum")
	world.queue_free();await process_frame
	print("PATCH523_ENHANCEMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
