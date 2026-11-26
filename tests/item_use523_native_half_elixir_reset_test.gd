extends SceneTree
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const ACCOUNT=preload("res://scripts/characters/account_store.gd")
const IDS: Array[int]=[186024,190754]
var failures: Array[String]=[]
var checks: int=0
var writes: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("NATIVE_HALF_ELIXIR_RESET_FAIL ",label)
	return ok

func dialog(world: TwilightWorld) -> Control:
	return world.hud.find_child("TwilightConfirmation",true,false)

func exercise(world: TwilightWorld) -> void:
	var targeted: String=OS.get_environment("TWILIGHT_TEST_HALF_ELIXIR_RESET_SOURCE")
	if not check(not targeted.is_empty() and world.skill_awakening.definitions_not_installed() and not world.skill_awakening.blocks_save(),"clean isolated Main before targeted original input"):return
	# Installing after this unrelated owner booted in untouched no-source mode
	# only isolates the harness from that owner's missing tables.
	world.skill_awakening.problem=""
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",targeted)
	SOURCE.reset()
	if not check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"pinned original ZIP verified"):return
	var owner: Variant=world.half_elixir
	var grants: Array=[]
	for id: int in IDS:
		var native: Dictionary=DROPS.definition_id(str(id)).get("native_record",{})
		if not check(STACK.profile(native).get("kind")=="half_elixir_reset","exact original initializer "+str(id)):return
		world.catalog_db["아이템"].append(native)
		grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	world._index_catalog_item_sources()
	var staged: Dictionary=INV.stage(world,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false),"actual physical originals granted"):return
	world.inventory=staged.overrides.inventory;world.item_instances=staged.overrides.item_instances
	if not check(owner.link_bundled().get("ok",false),"actual half-elixir source connects"):return
	var context: String=""
	for pair: String in owner.source.pairs:
		if owner.source.enabled("HalfElixirInitialize",pair):context=pair;break
	if not check(not context.is_empty() and owner.execute(owner.request("context",context)).get("ok",false),"select original context supporting reset"):return
	var can_invest: Dictionary=owner.source.profile(context)
	var allocation: String=""
	var cost: int=0
	for id: String in can_invest:
		var price: int=int(can_invest[id].raw.Cost)
		if price>0 and price<=owner.capacity(owner.state,owner.source) and price<=owner.source.cap(id,0):allocation=id;cost=price;break
	if not check(not allocation.is_empty(),"pick an exact investment/cost row"):return
	var funded: Dictionary=owner.state.duplicate(true); funded.points=cost
	owner.accept(funded)
	if not check(owner.execute(owner.request("invest",allocation)).get("ok",false),"existing owner creates actual investment"):return
	var refs: Dictionary={}
	for uid: String in world.item_instances:
		var entry: Dictionary=world.item_instances[uid]
		var id: int=int(entry.get("record",{}).get("source_item_class_id",0))
		if id in IDS:refs[id]={"uid":uid,"name":entry.name,"text":entry.name+"@@@"+uid}
	if not check(refs.size()==2,"both exact receipt IDs available"):return
	var first: Dictionary=refs[IDS[0]]
	var other: Dictionary=refs[IDS[1]]
	var baseline: String=FileAccess.get_sha256(world.save_path())
	var before: Dictionary=owner.state.duplicate(true)
	world.hud.inventory_item_activated.emit(first.text)
	if not check(dialog(world)!=null and FileAccess.get_sha256(world.save_path())==baseline,"real inventory opens confirmation without spending"):return
	dialog(world).dismiss()
	await process_frame
	check(owner.state==before and int(STACK.proof(world,first.uid).remaining)==1,"cancel preserves investment and candle")
	world.equipment_collections.test_save_writer=func(_path: String,data: Dictionary)->Error:
		if data.get("half_elixir523",{}).get("allocations",{})=={} and not data.get("item_instances",{}).has(first.uid):writes+=1
		return ERR_CANT_CREATE
	world.hud.inventory_item_activated.emit(first.text)
	if not check(dialog(world)!=null,"repeat opens real confirmation"):return
	dialog(world).find_child("ConfirmTransaction",true,false).pressed.emit()
	check(writes==1 and owner.state==before and STACK.proof(world,first.uid).get("remaining")==1 and FileAccess.get_sha256(world.save_path())==baseline,"failed writer keeps both owners and disk unchanged")
	world.equipment_collections.test_save_writer=Callable()
	world.hud.inventory_item_activated.emit(first.text)
	if not check(dialog(world)!=null,"retry confirms source reset"):return
	dialog(world).find_child("ConfirmTransaction",true,false).pressed.emit()
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	ACCOUNT.expand(disk)
	check(owner.state.allocations.is_empty() and owner.state.points==before.points and owner.state.extension==before.extension and owner.state.context==before.context,"only investments reset")
	check(not world.item_instances.has(first.uid) and STACK.proof(world,other.uid).get("remaining")==1 and not disk.get("item_instances",{}).has(first.uid),"selected candle only consumed durably")
	var hash_before: String=FileAccess.get_sha256(world.save_path())
	world.hud.inventory_item_activated.emit(other.text)
	check(dialog(world)==null and FileAccess.get_sha256(world.save_path())==hash_before,"empty allocations preserve other candle")
	if not check(owner.execute(owner.request("invest",allocation)).get("ok",false),"reuse refunded points to invest"):return
	world.hud.inventory_item_activated.emit(other.text)
	if not check(dialog(world)!=null,"event candle opens confirmation from exact physical receipt"):return
	dialog(world).find_child("ConfirmTransaction",true,false).pressed.emit()
	check(not world.item_instances.has(other.uid) and owner.state.allocations.is_empty() and owner.state.points==before.points,"event candle also resets one investment, once")

func run() -> void:
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):
			printerr("Isolated user data required");quit(2);return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	if check(QA.enter_game(world),"actual Main character starts"):
		world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
		await exercise(world)
	world.queue_free();await process_frame
	print("NATIVE_HALF_ELIXIR_RESET_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
