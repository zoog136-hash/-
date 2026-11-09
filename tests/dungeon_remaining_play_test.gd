extends SceneTree
## Actual Main, own wave actors/death callbacks/UI/atomic writer. Wave and pool
## clocks are explicitly accelerated; no original map or manual-play assertion.
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("DUNGEON_REMAINING_FAIL: ",label)

func _initialize() -> void:call_deferred("run")

func capture(name: String) -> void:
	var directory:=OS.get_environment("TWILIGHT_DUNGEON_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(directory);await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK,"actual viewport capture")

func pinned(world: Node, item: Dictionary, suffix: String, valid_id: bool = true) -> String:
	var id: int=int(item.row.ID);var name: String=str(item.name)
	world.inventory[name]=int(world.inventory.get(name,0))+1
	world.item_instances[suffix]={"name":name,"level":0,"element":"","element_level":0,"record":{"name":name,"slot":"consumable","source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:"+str(id if valid_id else id+1),"source_item_class_id":id if valid_id else id+1}}
	return name

func run() -> void:
	var world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.set_physics_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual class selection")
	world.player.set_physics_process(false)
	for i in range(6):world.field_population._drain_initial_spawns();await process_frame
	world.field_population.set_process(false)
	for child: Node in world.monsters_root.get_children():child.set_physics_process(false)
	world.level=80;world.gold=5000000;world.inventory["다이아"]=1000;world.ain_service.blessing=500
	var service: RefCounted=world.dungeon_play
	check(world.source_dungeons.orim_actor_types.size()==244 and world.source_dungeons.orim_item_effects.has(231162),"real verified typed execution sidecar loaded")
	check(world._save_game(true)==OK,"initial fixture balances saved")
	world.hud.open_source_dungeons()
	var view: Node=world.hud.workspace.find_child("SourceDungeonView",true,false)
	var previous:=OS.get_environment("TWILIGHT_DUNGEON523_PREVIOUS_PACK")
	if not previous.is_empty():view._install_pack(previous)
	view._install_pack(OS.get_environment("TWILIGHT_DUNGEON523_PACK"))
	var restored=world.SOURCE_DUNGEONS.new()
	check(restored.load_pack().ok and restored.orim_actor_types.size()==244 and restored.orim_item_effects.has(231162) and not restored.orim_actor_defs.is_empty(),"latest Drive consumer pack actually installs and loads NPC definitions from persistent default path")
	if not previous.is_empty():check(FileAccess.get_sha256(restored.DEFAULT_MANIFEST.get_base_dir()+"/orim_execution.json.backup."+restored.PREVIOUS_EXECUTION_SHA)==restored.PREVIOUS_EXECUTION_SHA,"previous execution sidecar preserved before latest activation")
	var bad_directory: String="user://invalid-orim-pack";DirAccess.make_dir_recursive_absolute(bad_directory)
	for name: String in ["manifest.json","dungeons.json"]:
		var file:=FileAccess.open(bad_directory.path_join(name),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(OS.get_environment("TWILIGHT_DUNGEON523_PACK").get_base_dir().path_join(name)));file.close()
	var bad:=FileAccess.open(bad_directory.path_join("orim_execution.json"),FileAccess.WRITE);bad.store_string("{}");bad.close()
	check(not restored.load_pack(bad_directory.path_join("manifest.json")).ok and not restored.orim_actor_defs.is_empty(),"corrupt sidecar cannot replace the verified installed definitions")
	view.family.select(2);view.family.item_selected.emit(2)
	check(service.state.settings.enabled==true,"own execution on by default")
	view._play_action("settings")
	var cfg: Dictionary=service.state.settings.duplicate(true);cfg.enabled=true;cfg.live_limit=2;cfg.attempts=2;cfg.token_chance=0
	view.play_settings_text.text=JSON.stringify(cfg);view.play_settings_dialog.confirmed.emit();view.play_settings_dialog.hide()
	if not service.state.settings.enabled:printerr("DUNGEON_REMAINING_DIAGNOSTIC ",view.notice.text)
	check(service.state.settings.enabled and not view.play_buttons.begin.disabled,"own settings saved through actual dialog")
	var ain: int=world.ain_service.blessing;view.play_buttons.begin.pressed.emit()
	check(service.state.active.get("kind","")=="orim" and world.ain_service.blessing==ain-10,"actual Orim UI start and own single Ain cost")
	if service.state.active.is_empty():world.queue_free();await process_frame;quit(1);return
	var run_id: String=service.state.active.id;var started: int=int(service.state.active.started)
	check(not world.source_dungeon_runs.begin(4).ok,"Tower cannot overlap Orim")
	var gold: int=world.gold
	check(service.buy_buff(71672).ok and world.gold==gold-200000 and service.modifier("move_speed")==25.0,"source preparation cost and own actual speed modifier")
	check(not service.buy_buff(71672).ok and world.gold==gold-200000,"duplicate preparation purchase rejected")
	var gems: int=int(world.inventory["다이아"])
	check(service.reroll().ok and world.inventory["다이아"]==gems-10 and service.state.active.rerolls==1,"source reroll cost with own configured currency/effect")
	service.tick(1.0,started+10)
	check(service.actors.size()>0 and service.actors.size()<=2,"actual bounded source-scheduled own actors")
	var target: TwilightMonster=service.actors.values()[0]
	check(target.global_position.is_finite() and world._is_walkable_world(target.global_position),"own actor uses finite validated current-field placement")
	var survivor: TwilightMonster=service.actors.values()[1] if service.actors.size()>1 else null
	var survivor_token: String="";var survivor_hp: int=0
	if survivor!=null:
		survivor.set_physics_process(false);survivor.take_damage(7,false,"melee");survivor_token=str(survivor.get_meta("dungeon_play_token"));survivor_hp=survivor.hp
	var raw: Dictionary=world.source_dungeons.orim_actor_defs[int(target.get_meta("declared_npc"))].row
	check(target.max_hp==int(raw.HP) and target.armor_class==int(raw.AC) and target.magic_resistance==int(raw.MR),"confirmed source HP AC MR override the borrowed visual template")
	var dice_ok:=true;var dice_rng:=RandomNumberGenerator.new();dice_rng.seed=17
	for definition: Dictionary in world.source_dungeons.orim_actor_defs.values():
		for attack: Dictionary in definition.attacks:
			var damage: int=world.DUNGEON_PLAY.roll_attack(attack,dice_rng)
			dice_ok=dice_ok and damage>=int(attack.DiceBonus)+int(attack.DiceCount) and damage<=int(attack.DiceBonus)+int(attack.DiceCount)*int(attack.DiceSpots)
	check(dice_ok,"actual source basic attack dice stay within all243 declared ranges")
	target.set_physics_process(false)
	var events: int=service.state.active.events.size()
	world.source_save_blocked=true;target.take_damage(target.hp+1,false,"melee")
	check(not service.pending.is_empty() and service.state.active.events.size()==events,"real actor death save failure remains retryable")
	world.source_save_blocked=false;service.tick(1.0,started+11)
	check(service.pending.is_empty() and service.state.active.events.size()==events+1,"death retry commits once")
	check(world._save_game(true)==OK,"active wave cursor/issued actors persisted")
	world._load_game(true)
	check(service.state.active.id==run_id and service.state.active.events.size()==events+1,"active Orim progress survives real reload without entry charge")
	for i in range(3):world.field_population._drain_initial_spawns();await process_frame
	world.field_population.set_process(false)
	service.tick(1.0,started+400)
	check(survivor_token.is_empty() or (service.actors.has(survivor_token) and service.actors[survivor_token].hp==survivor_hp),"issued live actor HP survives actual save/reload")
	var boss: TwilightMonster=null
	for actor: TwilightMonster in service.actors.values():
		actor.set_physics_process(false)
		if actor.get_meta("dungeon_play_role","")=="Boss":boss=actor
	check(boss!=null,"typed final boss priority survives a full local actor cap")
	var badge:=Label.new();badge.text="자체 대체형 · 가속 시계/피해 자동 검증 · 원본 맵 이동 없음";badge.position=Vector2(230,690);badge.z_index=999;world.hud.get_node("Root").add_child(badge)
	await capture("orim-waves-own")
	if boss!=null:
		boss.died.disconnect(world._on_monster_died)
		boss.died.connect(func(dead: TwilightMonster)->void:service.monster_died(dead,started+400);world._on_monster_died(dead))
		boss.take_damage(boss.hp+1,false,"melee")
	check(service.state.active.status=="cleared" and service.state.active.rewards.size()>=5,"actual boss death freezes base plus weighted lucky plan")
	if service.state.active.rewards.is_empty():
		printerr("DUNGEON_REMAINING_DIAGNOSTIC ",service.problem)
		print("DUNGEON_REMAINING_PLAY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
		service.cleanup();world.queue_free();await process_frame;quit(1);return
	var damaged: Dictionary=service.state.duplicate(true);damaged.active.rewards[0].row.Amount=999999
	check(not service.valid(damaged).is_empty(),"altered source reward amount rejected")
	var token_name: String="TWILIGHT · 오림의 증표";var before_tokens: int=int(world.inventory.get(token_name,0))
	world.source_save_blocked=true;var before_sha:=FileAccess.get_sha256(world.save_path())
	check(not service.claim().ok and int(world.inventory.get(token_name,0))==before_tokens and FileAccess.get_sha256(world.save_path())==before_sha,"failed payout preserves balance and bytes")
	world.source_save_blocked=false;view._update_play();view.play_buttons.claim.pressed.emit()
	check(int(world.inventory.get(token_name,0))==before_tokens+350 and service.state.receipts.has(run_id),"actual UI payout uses base350 with separate lucky rows")
	check(not service.claim().ok,"claimed run cannot replay")
	await capture("orim-claimed-own")
	world._load_game(true)
	check(service.state.receipts.has(run_id) and not service.claim().ok,"receipt survives actual reload")
	for i in range(3):world.field_population._drain_initial_spawns();await process_frame
	check(service.begin("orim",2).ok,"second own normal attempt")
	var timeout_start: int=int(service.state.active.started)
	service.tick(1.0,timeout_start+420)
	check(service.state.active.status=="cleared" and service.state.active.rewards.size()==1 and int(service.state.active.rewards[0].row.Amount)==10,"own timeout-only Care rule does not sum successful rewards")
	check(service.claim().ok,"Care settlement committed")
	check(not service.begin("orim",2).ok,"normal daily quota persisted")
	var hard: int=int(world.source_dungeon_entries("orim",true)[0].stage.ID)
	check(service.begin("orim",hard).ok,"separate hard stage and daily budget")
	check(service.stop().ok,"explicit own forfeit")
	view.family.select(4);view.family.item_selected.emit(4)
	gold=world.gold;view.play_buttons.begin.pressed.emit()
	check(service.state.active.get("kind","")=="special" and world.gold==gold-10000,"actual special session consumes exact declaration cost")
	var special_start: int=int(service.state.active.started)
	var group: int=int(service.state.active.groups[0]);var base: int=int(service.state.pools[str(group)].base)
	check(service.account_special(special_start+30).ok and int(service.state.pools[str(group)].base)==base-30,"actual time pool debit persisted")
	world._load_game(true)
	check(int(service.state.pools[str(group)].base)==base-30 and service.state.active.kind=="special","special session and clock survive reload")
	check(service.account_special(special_start+130).ok and int(service.state.pools[str(group)].base)==base-130,"configured offline elapsed consumption")
	check(service.stop(special_start+130).ok,"special stop preserves unspent pool")
	view.family.select(5);view.family.item_selected.emit(5)
	var charger: Dictionary={};var charger_index: int=-1
	for i in range(view.rows.size()):
		if int(view.rows[i].group_id)==group and not view.rows[i].item.row.TestItem and int(view.rows[i].item.row.LevelLimitMin)<=world.level:
			charger=view.rows[i];charger_index=i;break
	check(not charger.is_empty(),"source linked recharger available")
	if not charger.is_empty():
		var name:=pinned(world,charger.item,"valid-charge");pinned(world,charger.item,"lookalike-charge",false)
		check(world._save_game(true)==OK,"explicit source physical-item fixtures saved")
		view.listing.select(charger_index);view._select(charger_index)
		world.source_save_blocked=true;view.play_buttons.recharge.pressed.emit()
		check(world.item_instances.has("valid-charge") and int(service.pool(group,special_start).bonus)==0,"failed charger transaction preserves physical item")
		world.source_save_blocked=false;view.play_buttons.recharge.pressed.emit()
		check(not world.item_instances.has("valid-charge") and world.item_instances.has("lookalike-charge") and int(service.pool(group,special_start).bonus)==3600,"actual UI consumes exact ID only and adds3600 seconds")
		pinned(world,charger.item,"cap-charge")
		var original_pool: Dictionary=service.state.pools[str(group)].duplicate(true)
		service.state.pools[str(group)].bonus=int(world.source_dungeons.time_by_id[group].row.MaxRechargeTime)-1800
		check(not service.recharge(int(charger.item.row.ID)).ok and world.item_instances.has("cap-charge"),"independent recharge cap rejects without consumption")
		service.state.pools[str(group)]=original_pool
		world.item_instances.erase("cap-charge");world.inventory[name]=int(world.inventory[name])-1 # remove only the explicit cap fixture.
		gold=world.gold;view.play_buttons.buy_charge.pressed.emit()
		var own_name: String="TWILIGHT · "+str(charger.item.name);var own_id: String=service.own_physical(own_name,int(charger.item.row.ID))
		check(not own_id.is_empty() and world.gold==gold-int(service.state.settings.recharger_price),"actual own-shop UI supplies a distinct playable recharger")
		view.play_buttons.recharge.pressed.emit()
		check(not world.item_instances.has(own_id) and int(service.pool(group,special_start).bonus)==7200,"own recharger uses same verified group effect without impersonating original item")
	await capture("special-time-recharge-own")
	var next_pool: Dictionary=service.pool(group,special_start+86400)
	check(int(next_pool.base)==int(world.source_dungeons.time_by_id[group].row.TimeLimit) and int(next_pool.bonus)==7200,"own reset replenishes base and carries separate bonus")
	var rewards: Array=[]
	for r: Dictionary in world.source_dungeons.stage("orim",2).lucky_rewards:
		if int(r.row.RewardClassID) in [231162,232352]:rewards.append(r)
	var plan: Dictionary=service.reward_plan(rewards);plan.erase("ok")
	check(service.commit(service.state.duplicate(true),plan).ok,"explicit source lucky-item inventory fixtures, not another cleared-run fixture")
	var holy: String="TWILIGHT · 드래곤의 성수 (이벤트)";var holy_id: String=service.own_physical(holy,231162)
	var exp_before: int=world.experience
	world._on_inventory_item_activated(holy+"@@@"+holy_id)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(not holy_id.is_empty() and not world.item_instances.has(holy_id) and int(saved.experience)==exp_before+30400000,"actual inventory activation uses source EXP with own blessing conversion atomically")
	var holy_count: int=int(world.inventory.get(holy,0));var receipt_count: int=service.state.receipts.size()
	world._on_inventory_item_activated(holy+"@@@"+holy_id)
	check(int(world.inventory.get(holy,0))==holy_count and service.state.receipts.size()==receipt_count,"consumed physical holy ID cannot replay or consume a different legitimate copy")
	var accessory: Dictionary={"name":"검증용 자체 장신구","type":"장비","slot":"ring","grade":"일반","weight":0}
	world.item_db.append(accessory);world.inventory[accessory.name]=1
	world.item_instances["qa-accessory"]={"name":accessory.name,"level":0,"element":"","element_level":0,"record":accessory}
	var normal_scroll: String="TWILIGHT · 오림의 장신구 마법 주문서 (이벤트)";var blessed_scroll: String=normal_scroll+" (축복)"
	check(world._scroll_mode(blessed_scroll)=="blessed_orim","blessed and normal source variants remain distinct in enhancement UI")
	var physical_scroll: String=service.own_physical(normal_scroll,232352)
	world.source_save_blocked=true;world._attempt_enhancement(normal_scroll,accessory.name+"@@@qa-accessory")
	check(world.item_instances.has(physical_scroll) and not service.pending.is_empty(),"own scroll failed save preserves physical scroll and frozen result")
	var potions: int=int(world.inventory.get("HP 물약",0));world.inventory["HP 물약"]=potions+3
	world.source_save_blocked=false;service.tick(1.0)
	check(not world.item_instances.has(physical_scroll) and service.pending.is_empty(),"own scroll retry consumes one physical ID with persisted equipment result")
	check(int(world.inventory.get("HP 물약",0))==potions+3,"retry preserves unrelated inventory gained after failed save")
	var weekly: Dictionary=world.source_dungeons.time_by_id[72]
	var tuesday: int=Time.get_unix_time_from_datetime_string("2026-11-03T19:59:59")
	var clock_service=world.DUNGEON_PLAY.new();clock_service.configure(world,world.source_dungeons)
	check(clock_service.period(weekly,tuesday+1)==clock_service.period(weekly,tuesday)+1,"existing05 KST Wednesday reset boundary in fresh clock fixture")
	check(service.day(1)==int(service.state.day),"saved daily high-water protects against device clock rollback")
	check(world.active_map_id=="aden_world","all execution excludes map transport/collision changes")
	var corrupt: Dictionary=service.state.duplicate(true);corrupt.settings.duration=-1
	check(not service.valid(corrupt).is_empty(),"malformed own settings rejected")
	print("DUNGEON_REMAINING_PLAY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_OWN_WAVE_ACTORS_DEATH_UI_ATOMIC_PAYOUT_AND_PHYSICAL_RECHARGE; ACCELERATED_CLOCK_DAMAGE_AND_EXPLICIT_INVENTORY_CAP_FIXTURES; NO_ORIGINAL_MAP_MANUAL_PLAY"}))
	service.cleanup();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
