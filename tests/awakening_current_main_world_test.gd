extends SceneTree
## Actual Main, source supplier, quest producer and existing inventory touch path.
const QA=preload("res://tests/qa_class_selection.gd")
const S=preload("res://scripts/cards/native_awakening_supply.gd")
const G=preload("res://scripts/loot/patch523_item_inventory.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Relic=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
var world: Node
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,label: String) -> bool:
	checks+=1
	print("CURRENT_MAIN_CHECK ",checks," ",label," ",value)
	if not value:errors.append(label);push_error(label)
	return value
func freeze() -> void:
	world.set_process(false);world.field_population.set_process(false);world.save_timer=-100000
	world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
func settle() -> void:
	for frame: int in range(6):await process_frame
func fingerprint() -> int:return hash([world.inventory,world.item_instances,world.gold,world.hp,world.mp,world.skill_awakening.export_state(),world.option_awakening.export_state(),world.card_draw_fusion.export_state(),world.quest_service.export_state(),world.skill_awakening.selection_rng.state,world.card_draw_fusion.rng.state])
func physical(id: int) -> String:
	for uid: String in world.item_instances:
		if S.proof(world,uid,id).get("ok",false):return uid
	return ""
func touch_item(uid: String) -> void:
	var entry: Dictionary=world.item_instances.get(uid,{})
	if not check(not entry.is_empty(),"exact inventory physical selected"):return
	world._update_hud();world.hud.toggle_inventory();await settle()
	var bag: Control=world.hud.lineage_inventory_ui
	bag._select_item(str(entry.name)+"@@@"+uid);bag.open_detail();await settle()
	var button: Control=bag.detail_action
	check(button.is_visible_in_tree() and not button.disabled,"existing source inventory use button visible and enabled")
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=3;event.position=point;event.pressed=pressed;root.push_input(event,true);await process_frame
	await settle();world.hud._close_workspace();await settle()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_AWAKENING_CURRENT_MAIN_ISOLATED")!="1":push_error("Explicit isolated profile required");quit(2);return
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);freeze();await settle()
	if not check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main and pinned current map start"):finish();return
	freeze()
	var total: int=0
	for category: String in Cards.CATEGORIES:total+=world.catalog_db[category].size()
	check(total==720,"current720 registry is not expanded to736")
	check(world.quest_service.source.quests.size()==3621,"full original quest pack actually loaded")
	if not check(not S.record(3252).is_empty(),"actual full source item provider loaded"):finish();return
	world.inventory["마법인형 제작 코인"]=77
	if not check(G.commit(world,[{"item_class_id":3252,"amount":3000000,"bless_raw":1,"enchant":0}],{"kind":"focused_source_supplier","source_id":3252}),"real supplier commits exact source currency"):finish();return
	check(S.available(world,3252)==3000000 and world.option_awakening.nemesis_craft_view().available_coins==3000000,"real craft quote recognizes source3252 while generic77 is excluded")
	var native_coin_id: String=physical(3252)
	world.ui_preferences.item_locks["마법인형 제작 코인"]=true
	check(S.available(world,3252)==0 and not world._drop_inventory_reference("마법인형 제작 코인@@@"+native_coin_id,world.player.global_position),"existing global wallet-name lock also blocks newly supplied physical coin drop")
	world.ui_preferences.item_locks.erase("마법인형 제작 코인")
	var before: int=fingerprint();var disk: String=FileAccess.get_sha256(world.save_path())
	world.source_save_blocked=true
	var denied: Dictionary=world.option_awakening.craft_nemesis();world.source_save_blocked=false
	check(not denied.ok and denied.code=="save_failed" and fingerprint()==before and FileAccess.get_sha256(world.save_path())==disk,"failed craft preserves actual save, currency, items and both RNGs")
	var crafted: Dictionary=world.option_awakening.craft_nemesis()
	if not check(crafted.ok,"native source recipe258482 commits through actual writer"):print(crafted);finish();return
	check(world.inventory["마법인형 제작 코인"]==77 and S.available(world,3252)==0 and not physical(370562).is_empty(),"real craft consumes exactly3m typed coins and produces one typed ticket")
	var ticket_id: String=physical(370562)
	world.patch523_npc_spells.player_buffs["awakening_test_block"]={"values":{"CannotUseItem":1},"remaining":10}
	before=fingerprint();disk=FileAccess.get_sha256(world.save_path())
	denied=world.option_awakening.use_source_awakening_item(str(world.item_instances[ticket_id].name),ticket_id)
	check(denied.get("handled",false) and not denied.get("ok",false) and fingerprint()==before and FileAccess.get_sha256(world.save_path())==disk,"actual CannotUseItem state blocks native consumer before mutation")
	world.patch523_npc_spells.player_buffs.erase("awakening_test_block")
	await touch_item(physical(370562))
	check(world.card_draw_fusion.owned["마법인형"].get("source:m523:2:25152",false) and physical(370562).is_empty(),"existing inventory touch consumes source ticket and awards exact Nemesis")
	var target: String=""
	for identity: String in world.skill_awakening.core.cards:
		var row: Dictionary=world.skill_awakening.core.cards[identity]
		if row.category=="마법인형" and int(row.source_card.GradeID)==3 and not bool(row.source_card.IsNoMergeOut) and world.skill_awakening.core.eligibility(identity).ok:target=identity;break
	if not check(not target.is_empty(),"eligible source awakening target exists"):finish();return
	world.card_draw_fusion.owned["마법인형"][target]=true;world.card_draw_fusion.spare["마법인형"][target]=4
	var requirement: Dictionary=world.skill_awakening.core.book_requirement(target)
	if not check(G.commit(world,[{"item_class_id":int(requirement.item_class_id),"amount":2,"bless_raw":1,"enchant":0}],{"kind":"focused_source_supplier","source_id":int(requirement.item_class_id)}),"real source supplier commits source523 awakening books"):finish();return
	world.gold=10000000;world._save_game(true);before=fingerprint();disk=FileAccess.get_sha256(world.save_path())
	world.source_save_blocked=true;denied=world.skill_awakening.request_operation(target);world.source_save_blocked=false
	check(not denied.ok and denied.code=="save_failed" and fingerprint()==before and FileAccess.get_sha256(world.save_path())==disk,"failed source523 awakening preserves book, gold, skill, vitals, receipts and RNG")
	var awakened: Dictionary=world.skill_awakening.request_operation(target)
	if not check(awakened.ok and awakened.consumed_quantity==1 and S.available(world,int(requirement.item_class_id))==1,"source523 supplier book is actually consumed once by awakening"):print(awakened);finish();return
	for step: int in range(4):
		var fed: Dictionary=world.skill_awakening.request_experience_feed(target,target,int(world.skill_awakening.progress.revision))
		check(fed.ok,"actual card-owner feed save "+str(step))
	check(world.skill_awakening.progress.cards[target].level==2 and world.card_draw_fusion.spare["마법인형"].get(target,0)==0,"actual deterministic growth consumes four duplicates and reaches source level2")
	awakened=world.skill_awakening.request_operation(target)
	check(awakened.ok and S.available(world,int(requirement.item_class_id))==0 and world.skill_awakening.progress.cards[target].level==1 and world.skill_awakening.progress.cards[target].experience=="0","paid reawakening consumes final source book and resets Lv1/EXP0")
	var achievement_ids: Array[String]=["m523:quest:96201"]
	world.quest_service.claimed["m523:quest:92794"]=true;world.level=95
	check(not world.quest_auto.complete(world,achievement_ids) and not world.quest_service.claimed.get("m523:quest:96201",false),"existing original goal prevents96 achievement at95")
	world.level=96
	if not check(world.quest_auto.complete(world,achievement_ids),"existing quest owner grants96 achievement through actual atomic receipt producer"):print(world.quest_auto.failures);finish();return
	check(world.quest_service.claimed.get("m523:quest:96201",false) and not physical(346921).is_empty(),"source reward394871 is a verified held box");before=fingerprint()
	check(not world.quest_auto.complete(world,achievement_ids) and fingerprint()==before,"claimed achievement cannot grant a second box")
	var box_id: String=physical(346921);world._save_game(true);before=fingerprint();disk=FileAccess.get_sha256(world.save_path())
	world.source_save_blocked=true;denied=world.option_awakening.use_source_awakening_item(str(world.item_instances[box_id].name),box_id);world.source_save_blocked=false
	check(not denied.ok and fingerprint()==before and FileAccess.get_sha256(world.save_path())==disk,"failed held-box use preserves quest receipt and all owned outputs")
	await touch_item(box_id)
	check(physical(346921).is_empty() and not physical(365748).is_empty() and not physical(365758).is_empty() and not Unlock.unlocked(world.option_awakening.progress),"inventory touch opens exact source box into both outputs without automatic unlock")
	await touch_item(physical(365748))
	check(Unlock.unlocked(world.option_awakening.progress) and physical(365748).is_empty(),"source-native Eva item unlocks the slot through existing UI")
	var chosen: String=""
	for id: String in world.option_awakening.core.catalog["성물"]:
		world.card_draw_fusion.owned["성물"][id]=true
		if Relic.eligibility(world.option_awakening,id,world.level,world.active_skill_buffs).ok:chosen=id;break
	if not check(not chosen.is_empty() and world.option_awakening.select_relic_subslot(chosen).ok,"secondary selection obeys current owner transaction and source conditions"):finish();return
	var scroll_id: String=physical(365758);var scroll_before: Dictionary=world.item_instances[scroll_id].duplicate(true)
	await touch_item(scroll_id)
	check(world.option_awakening.progress.has("native_relic_summon_time") and world.option_awakening.relic_subslot_view().active,"existing inventory touch activates exact scroll on selected slot11")
	check(world.item_instances[scroll_id]==scroll_before and S.available(world,365758)==1,"original InfiniteAmount retains scroll and full supply receipt")
	var until: int=int(world.option_awakening.progress.native_relic_summon_time.expires_utc)
	check(until>int(Time.get_unix_time_from_system()) and until<=int(Time.get_unix_time_from_system())+1800,"source1800-second deadline is stored")
	world._load_game(true);freeze()
	check(world.option_awakening.progress.native_relic_summon_time.expires_utc==until and world.option_awakening.relic_subslot_view().active and S.available(world,365758)==1,"real reconnect preserves source summon deadline, slot and unlimited scroll")
	world.option_awakening.progress.native_relic_summon_time.expires_utc=int(Time.get_unix_time_from_system())-1
	world.option_awakening.refresh_timed_relic()
	check(not world.option_awakening.relic_subslot_view().active and world.hp<=world._effective_max_hp() and world.mp<=world._effective_max_mp(),"elapsed source timer removes effects and clamps live vitals without consuming scroll")
	world._save_game(true);world._load_game(true);freeze()
	check(not world.option_awakening.relic_subslot_view().active and S.available(world,365758)==1,"expired summon stays expired after real reconnect")
	check(world.inventory.get("마법인형 제작 코인",0)==77 and world.quest_service.claimed.get("m523:quest:96201",false),"unrelated coins and original quest completion survive full sequence")
	finish()
func finish() -> void:
	if world!=null:world.queue_free();await process_frame
	print("AWAKENING_CURRENT_MAIN_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_SOURCE_SUPPLIER_QUEST96201_INVENTORY_TOUCH_FAILURE_AND_RECONNECT; NOT_FULL_GAMEPLAY_OR_ORIGINAL_PIXELS"}));quit(0 if errors.is_empty() else 1)
