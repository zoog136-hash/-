extends SceneTree
## Reproduces the 2048×919 source-bag view with two neighbouring held items
## whose icon cannot resolve. Private original UI44 is optional for Core.
const QA=preload("res://tests/qa_class_selection.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const FIRST="[변신 카드] 원본 이미지가 설치되지 않은 검증용 긴 이름"
const OTHER="마법인형 제작 코인 상자 검증용 긴 이름"
var checks:int=0
var failures:Array[String]=[]

func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_INVENTORY_SLOT_NAMES_FAIL ",label)
	return ok

func _initialize()->void:run.call_deferred()

func run()->void:
	var selected:bool=not OS.get_environment("TWILIGHT_INVENTORY_855_ACTUAL_UI").is_empty()
	ck(SLOTS.ACTION==6500,"the original Common_Slot action label is unchanged")
	if selected and ck(not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"installed original UI44 required for live case") and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main save"):
		await live()
	print("NATIVE_INVENTORY_SLOT_NAMES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_ui":selected}))
	quit(0 if failures.is_empty() else 1)

func tap(control:Control)->void:
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=4;event.pressed=pressed
		event.position=control.get_global_transform_with_canvas()*(control.size*.5)
		root.push_input(event,true)

func live()->void:
	root.size=Vector2i(2048,919)
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	if not ck(QA.enter_game(w),"actual Main entered"):w.queue_free();return
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	# Real held bag rows deliberately lacking assets and with long titles.
	# They use genuine UI nodes, not generated replacement pictures.
	for title:String in [FIRST,OTHER]:
		w.catalog_db["아이템"].append({"name":title,"type":"소모품","slot":"consumable","grade":"일반","source":"qa_visual_fixture","weight":0})
		w.inventory[title]=1
	w._index_catalog_item_sources()
	var h:Node=w.hud
	w._update_hud();h.refresh_inventory(w.inventory)
	h.toggle_inventory()
	await process_frame;await process_frame
	var controller:Node=h.original_main_ui_controller
	if not ck(h.original_inventory_is_open() and is_instance_valid(controller),"original source bag actually mounted"):w.queue_free();return
	var view:RefCounted=controller._inventory_view
	var bag:Control=h.lineage_inventory_ui
	var hits:Dictionary=view._hits
	if not ck(hits.has(FIRST) and hits.has(OTHER),"both long held rows mounted in the bag"):w.queue_free();return
	for name:String in [FIRST,OTHER]:
		var hit:Dictionary=hits[name]
		var center:CanvasItem=hit.native_slot_scene.source_nodes.get(SLOTS.ACTION)
		ck(center!=null and not center.visible and hit.texture==null and hit.control.tooltip_text==name,"unresolved row is not drawn as long slot text; title retained for hover/detail")
	var before:Dictionary=w.inventory.duplicate()
	tap(hits[FIRST].control)
	await process_frame
	ck(bag.selected_item==FIRST and bag.item_name_hint.visible and bag.item_name_hint.text==FIRST,"one real touch shows the exact selected title")
	ck(view._hits[FIRST].native_slot_scene.source_nodes.get(SLOTS.ACTION).visible and not view._hits[OTHER].native_slot_scene.source_nodes.get(SLOTS.ACTION).visible,"only selected short Use is shown; it does not replace neighbours")
	bag.disarm_item_action()
	await process_frame
	ck(not bag.item_name_hint.visible and not view._hits[FIRST].native_slot_scene.source_nodes.get(SLOTS.ACTION).visible and w.inventory==before,"after disarm all name overlays stay off and stock is unchanged")
	w.queue_free();await process_frame
