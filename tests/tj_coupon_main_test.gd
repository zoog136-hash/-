extends SceneTree
## Actual Main, menu, failure callback and whole-save writer in an isolated profile.
const Service=preload("res://scripts/tj/coupon_service.gd")
const Source=preload("res://scripts/tj/source523.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
class HistoricalService extends Service:
	# A test fixture clock does not modify the operating-system/user clock.
	func clock() -> int:return int(Time.get_unix_time_from_datetime_string("2026-09-10T00:00:00"))
var world
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var isolated: String=OS.get_environment("TWILIGHT_TJ_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):push_error("isolated profile required");quit(1);return
	var args: PackedStringArray=OS.get_cmdline_user_args()
	check(args.size()==1,"private source argument")
	var scene: PackedScene=load("res://Main.tscn")
	check(scene!=null,"real Main loads")
	world=scene.instantiate();root.add_child(world)
	await process_frame;await process_frame
	world.set_process(false);world.player.set_physics_process(false);world.hud.complete_class_selection()
	for monster: Node in world.monsters_root.get_children():monster.set_process(false);monster.set_physics_process(false)
	check(world.tj_coupons.core.definitions.is_empty(),"missing TJ source does not fabricate catalog or own coupons")
	world.hud._on_lineage_side_action("tj_coupons")
	check(world.hud.active_section=="tj_coupons","actual Main menu opens TJ page without source")
	check(await world.tj_coupons.install_async(args[0]),"private source installs asynchronously with SHA and full-table checks")
	var service=HistoricalService.new();service.definitions=world.tj_coupons.core.definitions
	world.tj_coupons.core=service
	check(world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}),"explicit test server context")
	world.gold=987654321
	check(world.tj_coupons.set_context("KR","1").ok,"normal TJ context action commits declared server")
	var compatible_count:=0
	var gated_count:=0
	for category: String in world.option_awakening.core.definitions:
		for row: Dictionary in world.option_awakening.core.definitions[category].values():
			var error: String=world.tj_coupons.awakening_compatibility(row)
			if error.is_empty():compatible_count+=1
			else:
				gated_count+=1
				check(error.contains("최신 523"),"changed engine inputs are explicitly gated")
	check(compatible_count>0 and compatible_count+gated_count==289,"every existing option awakening definition checked against523")
	var old_quest: Dictionary=world.quest_service.export_state()
	check(world._save_game(true)==OK,"real baseline save")
	var item: String=""
	for id: String in service.definitions.coupons:
		var row: Dictionary=service.definitions.coupons[id]
		if int(row.profile.BuffCardDeckID)!=1 or int(row.profile.TJCouponHistoryType)!=1:continue
		var view: Dictionary=service.resolve(id,world.tj_coupons.context(),service.clock())
		if view.get("ok",false) and not view.window.is_empty() and service.date_value(int(view.window.StartDateTimeID))<=service.wall(service.clock()) and service.date_value(int(view.window.EndDateTimeID))>service.wall(service.clock()):item=id;break
	check(not item.is_empty(),"actual source coupon for historical fixture")
	if item.is_empty():finish();return
	var identities: Array=world.card_draw_fusion.pools["변신"]["희귀"]
	check(identities.size()>0,"actual source material pool")
	var identity: String=str(identities[0].id)
	world.card_draw_fusion.owned["변신"][identity]=true
	world.card_draw_fusion.spare["변신"][identity]=4
	world._invalidate_equipment_static()
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,1000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)>=Cards.FUSION_WEIGHTS["희귀"]:world.card_draw_fusion.rng.seed=seed_value;break
	world._on_card_fusion_requested("변신","희귀",1)
	await process_frame
	if is_instance_valid(world.hud.card_reveal_stage):world.hud.card_reveal_stage.close_reveal()
	await process_frame
	check(service.state.history.size()==1,"real failed fusion callback records one event")
	if service.state.history.is_empty():finish();return
	check(world.tj_coupons.grant_for_test(item).ok,"explicit test coupon grant persisted")
	var event: Dictionary=service.state.history[0]
	var policy: Dictionary=service.definitions.coupons[item].profile
	var good: Array=[];var bad: Array=[]
	for pair: Array in [[event.success_candidates,good,1],[event.fail_candidates,bad,maxi(1,int(policy.ChoiceFailCardCount))]]:
		for id: String in pair[0]:
			var card: Dictionary=service.definitions.cards.get(id,{})
			if card.is_empty() or int(card.get("ServerLimitSetID",0))!=0 or int(card.get("StartDateTimeID",0))!=0 or int(card.get("EndDateTimeID",0))!=0:continue
			pair[1].append(id)
			if pair[1].size()>=int(pair[2]):break
	check(good.size()==1 and bad.size()==maxi(1,int(policy.ChoiceFailCardCount)),"real eligible candidate selection")
	var old: Dictionary=service.export_state()
	var disk_sha: String=FileAccess.get_sha256(world.save_path())
	world.hud.open_tj_coupons()
	await process_frame
	var page: Node=find_page()
	check(page!=null,"real TJ view mounted in workspace")
	select_choices(page,item,good,bad)
	page.confirm()
	var dialogs: Array=page.find_children("TJSpendConfirmation","ConfirmationDialog",true,false)
	check(dialogs.size()==1,"real confirmation dialog opens")
	if not dialogs.is_empty():dialogs[0].canceled.emit()
	await process_frame
	check(service.export_state()==old and FileAccess.get_sha256(world.save_path())==disk_sha,"opening Main UI does not spend")
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_FILE_CANT_WRITE
	var before_cards: Dictionary=world.card_draw_fusion.export_state()
	select_choices(page,item,good,bad)
	page.confirm()
	dialogs=page.find_children("TJSpendConfirmation","ConfirmationDialog",true,false)
	if not dialogs.is_empty():dialogs[0].confirmed.emit()
	await process_frame
	check(service.export_state()==old and world.card_draw_fusion.export_state()==before_cards,"Main UI write failure rolls back coupon and award")
	check(FileAccess.get_sha256(world.save_path())==disk_sha,"Main failed transaction preserves save bytes")
	world.equipment_collections.test_save_writer=Callable()
	select_choices(page,item,good,bad)
	page.confirm()
	dialogs=page.find_children("TJSpendConfirmation","ConfirmationDialog",true,false)
	if not dialogs.is_empty():dialogs[0].confirmed.emit()
	await process_frame
	check(service.state.receipts.size()==1,"Main UI confirm commits")
	check(int(service.state.coupons[item])==0 and service.state.used.has(str(event.id)),"Main coupon and record consumed together")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(disk.tj_coupons523.receipts.size()==1,"Main result receipt persisted")
	check(world.quest_service.export_state()==old_quest,"existing temporary quests preserved")
	world._load_game(true)
	check(not service.blocked and int(service.state.coupons[item])==0 and service.state.receipts.size()==1,"actual reload restores coupon and reward receipt")
	var result: Dictionary=world.tj_coupons.redeem(item,str(event.id),int(old.revision),good,bad)
	check(not result.ok,"duplicate Main confirm refused after reload")
	var valid_text: String=FileAccess.get_file_as_string(world.save_path())
	var damaged: Dictionary=JSON.parse_string(valid_text)
	damaged.tj_coupons523.coupons[item]=-1
	var writer=preload("res://scripts/skills/save_writer.gd")
	check(writer.write(world.save_path(),damaged)==OK,"controlled damaged save written only in isolated profile")
	var damaged_sha: String=FileAccess.get_sha256(world.save_path())
	var wallet_before: int=int(world.gold)
	world._load_game(true)
	check(service.blocked and int(world.gold)==wallet_before,"damaged TJ save blocks before live state mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==damaged_sha,"damaged file is not overwritten by autosave")
	check(writer.write_text(world.save_path(),valid_text)==OK,"verified test baseline restored through same atomic writer")
	world._load_game(true)
	check(not service.blocked and service.state.receipts.size()==1,"valid reload clears protection and preserves committed receipt")

	finish()
func finish() -> void:
	print("TJ523_MAIN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_Main":true,"source_snapshot":523,"fixture_clock":"historical only, operating-system clock unchanged"}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)

func find_page() -> Node:
	for node: Node in world.hud.workspace.find_children("*","VBoxContainer",true,false):
		if node.get_script()==preload("res://scripts/tj/view.gd"):return node
	return null
func select_choices(page: Node,item: String,good: Array,bad: Array) -> void:
	for i: int in range(page.coupons.item_count):
		if str(page.coupons.get_item_metadata(i))==item:page.coupons.select(i);break
	page.refresh_events()
	for pair: Array in [[page.success,good],[page.failure,bad]]:
		for i: int in range(pair[0].item_count):
			if pair[1].has(str(pair[0].get_item_metadata(i))):pair[0].select(i,false)
