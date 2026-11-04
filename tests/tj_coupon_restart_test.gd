extends SceneTree
## Run as a second process against the Main test's isolated profile only.
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var isolated: String=OS.get_environment("TWILIGHT_TJ_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):push_error("isolated profile required");quit(1);return
	var world=load("res://Main.tscn").instantiate();root.add_child(world)
	await process_frame;await process_frame
	world.set_process(false);world.player.set_physics_process(false);world.hud.complete_class_selection()
	for monster: Node in world.monsters_root.get_children():monster.set_process(false);monster.set_physics_process(false)
	var service=world.tj_coupons.core
	check(not service.blocked,"cold Main accepts persisted TJ namespace")
	check(service.state.receipts.size()==1 and service.state.used.size()==1,"cold process restores committed receipt and used failure")
	if not service.state.receipts.is_empty():
		var receipt: Dictionary=service.state.receipts[0]
		check(int(service.state.coupons.get(str(receipt.coupon),-1))==0,"spent coupon remains spent")
		var found:=false
		for owned: Dictionary in world.card_draw_fusion.owned.values():
			for identity: String in owned:
				if identity.ends_with(":"+str(receipt.card)) and owned[identity]:found=true
		check(found,"actual awarded source card survives process restart")
	check(world.tj_coupons.context()==service.state.get("server_context",{}),"declared server context restored without guessing")
	var before_source_load: String=FileAccess.get_sha256(world.save_path())
	world.hud._on_lineage_side_action("tj_coupons")
	while world.tj_coupons.loading:await process_frame
	check(world.hud.active_section=="tj_coupons" and service.definitions.get("coupons",{}).size()==139,"normal reopened UI consumes installed common523 ZIP")
	check(FileAccess.get_sha256(preload("res://scripts/tj/source523.gd").CACHE)==preload("res://scripts/tj/source523.gd").SHA,"installed input keeps exact common ZIP hash")
	check(FileAccess.get_sha256(world.save_path())==before_source_load and service.state.receipts.size()==1,"source reload does not rewrite player state")
	print("TJ523_RESTART_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"new_process":true,"actual_Main":true}))
	world.queue_free();quit(0 if failures.is_empty() else 1)
