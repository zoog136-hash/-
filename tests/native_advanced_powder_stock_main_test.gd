extends SceneTree
## A hosted title-era exact aggregate and the actual native supplier's stack
## share source #117544. In a private original fixture check real Main load,
## inventory touch, durable receipt conservation and title debit/rollback.
const QA=preload("res://tests/qa_class_selection.gd")
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const SUPPLY=preload("res://scripts/loot/patch523_item_inventory.gd")
const REFINE=preload("res://scripts/refine523/bless_refine523_service.gd")
const TOP=preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const ITEM: int=117544
const KEY: String="상급 축복의 가루 · 원본#117544"
const OTHER: String="상급 축복의 가루"
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void:run.call_deferred()

func ck(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_ADVANCED_POWDER_STOCK_FAIL: "+label)
	return ok

func frames() -> void:
	await process_frame
	await process_frame

func tap(control: Control) -> bool:
	if not ck(is_instance_valid(control) and control.is_visible_in_tree(),"the actual bag input target is visible"):return false
	var p: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var ev:=InputEventScreenTouch.new();ev.index=8;ev.pressed=down;ev.position=p
		root.push_input(ev,true)
		await process_frame
	return true

func actual(archive: String) -> void:
	if not ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated save"):return
	root.size=Vector2i(2048,919)
	var w: Node=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000;w.deferred_save_enabled=true
	ck(QA.enter_game(w),"the actual Main enters")
	await frames()
	w.player.set_physics_process(false);w.field_population.set_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive);SRC.reset()
	# The original table fixture is selected after startup so this focused
	# UI/gameplay test doesn't imply that a full original map pack is present.
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var t: RefCounted=w.titles
	t.source.problem=t.source.load_zip(archive)
	if not ck(t.source.problem.is_empty() and SRC.identity().get("source_sha256")==t.source.SHA,"pinned title and original definitions"):w.queue_free();return
	var canonical: Dictionary=w.source_item_definition(ITEM).get("native_record",{})
	if not ck(canonical.get("name")==KEY and canonical.get("source_bless_raw")==1,"the game's exact normal #117544 definition"):w.queue_free();return
	ck(STACK.supply_profile(t.source.powder_record).is_empty(),"historical title supplier was plain despite matching ID and key")
	w.catalog_db["아이템"].append(canonical);w._index_catalog_item_sources();t.bind_material()
	w.level=85
	var grant: Dictionary=SUPPLY.stage(w,[{"item_class_id":ITEM,"amount":2201,"bless_raw":1,"enchant":0}],
		{"kind":"source523_advanced_dissolution","table":"AdvancedBlessPowderAmount","fixture":true})
	if not ck(grant.get("ok",false),"the production supplier makes a real native 2201-unit receipt"):w.queue_free();return
	w.inventory=grant.overrides.inventory;w.item_instances=grant.overrides.item_instances
	w.inventory[KEY]+=2;w.inventory[OTHER]=5
	var original: Dictionary=REFINE.powder_owned(w)
	if not ck(original.total==2201 and original.stacks.size()==1 and t.powder_count()==2203,"reproduced legacy and native source quantities living in different owner views"):w.queue_free();return
	var original_id: String=original.stacks[0].uid
	var original_receipt: Dictionary=original.stacks[0].owned.receipt
	w.ui_preferences["item_locks"]={KEY:true}
	ck(not t.reconcile_powder_stock() and w.inventory[KEY]==2203 and w.item_instances[original_id][STACK.QUANTITY]==2201,"a name lock prevents any promotion")
	w.ui_preferences["item_locks"]={}
	# This reproduces a current save whose versioned pre-523 name migration
	# already completed. This fix must not change what that older migration does.
	w.legacy_item_marker={"schema":preload("res://scripts/loot/legacy_item_migration523.gd").SCHEMA}
	var initial_save: Error=w._save_game(false)
	if initial_save!=OK:
		print("NATIVE_ADVANCED_POWDER_SAVE_DIAG ",error_string(initial_save)," dungeon=",w.dungeon_play.save_blocked,"/",w.dungeon_play.valid(w.dungeon_play.state),
			" source_dungeon=",w.source_dungeon_runs.save_blocked,"/",w.source_dungeon_runs.validate(w.source_dungeon_runs.state),
			" title=",t.blocked,"/",t.validate(t.state)," owner=",w.patch523_owner_state_problem,
			" skill=",w.skill_awakening.blocks_save()," source_save=",w.source_save_blocked,
			" source_item=",w.source_item_save_blocked," notice=",w.hud.message_label.text)
	if not ck(initial_save==OK,"save actual mixed before state"):w.queue_free();return
	var before_load: String=FileAccess.get_sha256(w.save_path())
	w._load_game(true);await frames()
	var after: Dictionary=REFINE.powder_owned(w)
	if after.total!=2203 or after.stacks.size()!=1:
		print("NATIVE_ADVANCED_POWDER_LOAD_DIAG total=",after.total," stacks=",after.stacks.size(),
			" title=",t._powder_stock()," source_save=",w.source_save_blocked," source_item=",w.source_item_save_blocked,
			" owner=",w.patch523_owner_state_problem," notice=",w.hud.message_label.text,
			" source_proven=",t.source.powder_record.get("source_item_row")==SRC.row("ItemClass",ITEM))
	if not ck(after.total==2203 and after.stacks.size()==1 and t.powder_count()==2203 and w.inventory[KEY]==2203 and w.inventory[OTHER]==5,"load produces one real 2203 stack, both consumers agree, other name unchanged"):w.queue_free();return
	var unique: Dictionary=after.stacks[0]
	var journal: Dictionary=w.consumable_service.export_state().get(STACK.MERGES,{})
	var parts: Array=journal.get(str(unique.owned.receipt.origin.get("merge_id","")),{}).get("components",[])
	ck(parts.size()==2 and parts.any(func(part: Dictionary) -> bool:return part.physical_id==original_id and part.receipt==original_receipt),"the original 2201-unit physical receipt is still the exact journal component")
	ck(parts.any(func(part: Dictionary) -> bool:return part.remaining_quantity==2 and part.receipt.origin.get("kind")=="TWILIGHT_title523_existing_exact_key_reconciliation"),"the two migrated units are attributed to existing stock, not a new purchase")
	ck(FileAccess.get_sha256(w.save_path())==before_load and not t.reconcile_powder_stock(),"validation and second application do not rewrite disk or duplicate units")
	var h: Node=w.hud
	var controller: Node=h.original_main_ui_controller
	if is_instance_valid(controller):
		var hotspot: Node=controller._menu_scene.source_nodes.get(TOP.INVENTORY)
		var button: Node=hotspot.get_meta("source_button") if is_instance_valid(hotspot) and hotspot.has_meta("source_button") else null
		if await tap(button.get("_input_area") if is_instance_valid(button) else null):
			var view: RefCounted=controller._inventory_view
			var reference: String=KEY+"@@@"+unique.uid
			var slot: Dictionary=view._hits.get(reference,{})
			ck(h.original_inventory_is_open() and not slot.is_empty(),"one physical powder row is drawn in the original bag")
			if await tap(slot.get("control")):
				ck(h.lineage_inventory_ui.selected_item==reference and h.lineage_inventory_ui._bag_display_amount(reference)==2203,"actual selection keeps exact ID and visible 2203")
			h.toggle_inventory();await frames()
	else:ck(false,"actual original UI fixture is required for the real bag test")
	if not ck(w._save_game(true)==OK,"normal save writes the combined receipt and contents"):w.queue_free();return
	w.ui_preferences["item_locks"]={KEY+"@@@"+unique.uid:true}
	ck(t.powder_count()==0 and REFINE.powder_owned(w).total==0 and not t.attempt("donation",int(t.state.revision)).ok,"a locked physical stack cannot be used by either consumer")
	w.ui_preferences["item_locks"]={}
	var disk: String=FileAccess.get_sha256(w.save_path())
	var prev_title: Dictionary=t.state.duplicate(true)
	var denied: Array[int]=[0]
	w.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary) -> Error:denied[0]+=1;return ERR_CANT_CREATE
	ck(not t.attempt("donation",int(t.state.revision)).ok and denied[0]==1 and t.state==prev_title and w.inventory[KEY]==2203 and FileAccess.get_sha256(w.save_path())==disk,"failed donation write preserves live counts, RNG, revision and exact saved bytes")
	w.equipment_collections.test_save_writer=Callable()
	if ck(t.attempt("donation",int(t.state.revision)).ok,"the original title donation debits the actual physical stock"):
		ck(w.inventory[KEY]==203 and w.inventory[OTHER]==5 and REFINE.powder_owned(w).total==203,"only the 2000 paid units disappear")
		w._load_game(true);await frames()
		ck(t.powder_count()==203 and REFINE.powder_owned(w).total==203 and w.inventory[OTHER]==5,"reload preserves the remaining 203, same-name unknown and journal")
		var npc_id: int=int(t.source.powder_npcs.keys()[0])
		var authored_drop: Dictionary=t.powder_drop(npc_id,t.source.powder_npcs[npc_id],0.0)
		if ck(authored_drop.get("item_name")==KEY and authored_drop.get("quantity")==1,"authored title supplier produces the exact item"):
			# No full original field pack is mounted: only the walkable geometry
			# is synthetic. The Main drop, interact button and save are real.
			if w.field_map==null:
				w.astar=AStarGrid2D.new()
				w.astar.region=Rect2i(0,0,8,8)
				w.astar.update()
				w.player.global_position=w._cell_to_world(Vector2i(4,4))
			var ground: Button=w._spawn_ground_drop(KEY,w.player.global_position,1,w.ground_loot.begin_hunt_batch())
			if ck(is_instance_valid(ground),"the actual world spawns the title drop"):
				ground.set("visible_since",Time.get_ticks_msec()-900)
				ground.pressed.emit()
				w.loot_pickup.pickup_button.pressed.emit()
				ck(not w.ground_loot.valid_view(ground) and w.inventory[KEY]==204 and REFINE.powder_owned(w).total==204
					and REFINE.powder_owned(w).stacks.size()==1 and t.powder_count()==204,
					"real ground pickup joins the same native slot without adding or losing units")
				ck(w._save_game(true)==OK,"the picked-up exact unit and folded receipt save")
				w._load_game(true);await frames()
				ck(t.powder_count()==204 and REFINE.powder_owned(w).total==204 and w.inventory[OTHER]==5,
					"reload keeps the acquired unit and the separate name")
	w.queue_free();await frames()

func run() -> void:
	ck(ITEM==REFINE.RULES.ADVANCED_BLESS_POWDER_ITEM,"refine and title fixtures refer to the same source class")
	var archive: String=OS.get_environment("TWILIGHT_ADVANCED_POWDER_DEFINITIONS")
	if not archive.is_empty():await actual(archive)
	print("NATIVE_ADVANCED_POWDER_STOCK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"exact_pack":not archive.is_empty()}))
	quit(0 if failures.is_empty() else 1)
