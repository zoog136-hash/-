extends SceneTree
const Cards=preload("res://scripts/card_draw_fusion.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const Unlock=preload("res://scripts/cards/native_doll_unlock_item.gd")
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func snapshot(world: Node) -> Dictionary:
	return {"con":world._effective_attribute("CON"),"mp":world._effective_max_mp(),"reduction":world._damage_reduction_stat(),"mr":world._effective_mr(),"er":world._effective_er(),"dg":world._effective_dg(),"melee":world._catalog_damage_bonus("melee"),"ranged":world._catalog_damage_bonus("ranged")}
func run() -> void:
	var private_root: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--private-ui-root="):private_root=arg.trim_prefix("--private-ui-root=")
	if private_root.is_empty():quit(2);return
	load("res://scripts/lineagem_pack_install.gd")._session_root=private_root
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);await process_frame;await process_frame
	check(QA.enter_game(world),"game entry")
	world.save_timer=-10000;world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	for node: Node in world.monsters_root.get_children():node.set_physics_process(false)
	world.level=95;world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1})
	world.option_awakening.progress[Unlock.FIELD]=Unlock.marker()
	var cards: Dictionary={}
	for record: Dictionary in world.catalog_db["마법인형"]:cards[Cards.card_id(record)]=record
	var main: String="source:m508:2:28";world.equipped_catalog["마법인형"]=cards[main];world.card_draw_fusion.owned["마법인형"][main]=true
	var cases: Dictionary={"source:m508:2:25002":{"melee":3,"ranged":3},"source:m508:2:24163":{"reduction":2,"mr":10},"source:m508:2:20531":{"mp":50},"source:m508:2:18978":{"con":1},"source:m508:2:20303":{"er":1},"source:m508:2:23258":{"dg":1}}
	for id: String in cases:world.card_draw_fusion.owned["마법인형"][id]=true
	var money: int=world.gold;var rng_before: String=str(world.rng.state)
	for id: String in cases:
		world.option_awakening.progress["native_subslot_identity"]="";world.option_awakening.progress.revision+=1;world._invalidate_equipment_static()
		var before: Dictionary=snapshot(world)
		world.option_awakening.progress["native_subslot_identity"]=id;world.option_awakening.progress.revision+=1;world._invalidate_equipment_static()
		check(world.option_awakening.subslot_view(false).active,"eligible additional summon "+id)
		var after: Dictionary=snapshot(world)
		for key: String in cases[id]:check(after[key]-before[key]==int(cases[id][key]),"actual World reader exact once "+id+":"+key)
		check(snapshot(world)==after,"repeat World stat reads never stack "+id)
		world.option_awakening.progress["native_subslot_identity"]="";world.option_awakening.progress.revision+=1;world._invalidate_equipment_static()
		check(snapshot(world)==before,"release restores previous stats "+id)
	check(world.gold==money and str(world.rng.state)==rng_before,"stat evaluation consumes no currency or RNG")
	world.queue_free();await process_frame;await process_frame
	print("NATIVE_SUBSLOT_BUFF_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"state":"isolated in-memory native ownership only; no save"}));quit(0 if errors.is_empty() else 1)
