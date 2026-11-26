extends SceneTree
## Only true standalone abilities in material slots arm direct use. The
## native/Common_Slot and fallback bag share the real ItemClass action owner.
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const BAG=preload("res://scripts/ui/renewal_inventory.gd")
const ACTIVE=[19372,122424]
const EXACT_MATERIAL_IDS=[9212,19372,19382,33161,33171,33181,55463,65261,111173,122364,122404,122424,122434,122444,122454,122464,122474,122484,122494,130491,130521,141873,159021,182401,182521,198124,198164,232434,232454,259621,259631,283164,283184,328898]
const CRAFT_ONLY=200742
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("ITEM_VISIBLE_ACTION_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	var source:String=OS.get_environment("TWILIGHT_VISIBLE_ACTION_DEFINITIONS")
	if not source.is_empty():await main(source)
	else:
		ck(not BAG.material_direct_use({"slot":"material","source_category_name":"TeleportAmulet"}),"category text alone cannot prove a direct-use action")
	print("ITEM_VISIBLE_ACTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func main(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"pinned source definitions")
	var category: Dictionary={}
	for row: Dictionary in SRC.rows("ItemCategory"):
		if row.get("Name")=="TeleportAmulet":category[int(row.ID)]=true
	var resolved:Array[int]=[]
	for row: Dictionary in SRC.rows_matching("ItemClass","CategoryID",category):
		if row.get("TestItem")!=false:continue
		var id:int=int(row.ID)
		var projected:Dictionary=DROPS.variant_item(DROPS.definition_id(str(id)).get("native_record",{}),1)
		if projected.get("slot")=="material" and BAG.material_direct_use(projected):resolved.append(id)
	resolved.sort()
	ck(resolved==EXACT_MATERIAL_IDS,"resolved all and only the exact 34 originals with admitted standalone effect: "+str(resolved))

	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	w.inventory={};w.item_instances={}
	var requests:Array=[]
	for id:int in ACTIVE+[CRAFT_ONLY]:
		var raw:Dictionary=DROPS.variant_item(DROPS.definition_id(str(id)).get("native_record",{}),1)
		ck(raw.get("slot")=="material","actual original material-slot record "+str(id))
		w.catalog_db["아이템"].append(raw)
		requests.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	if not ck(INV.commit(w,requests,{"kind":"qa_verified_action"}),"real Main supplier publishes receipts"):
		w.queue_free();await process_frame;return
	var keys:Dictionary={}
	for uid:String in w.item_instances:
		var owned:Dictionary=STACK.proof(w,uid)
		if not owned.is_empty():keys[int(owned.receipt.item_class_id)]=str(owned.record.name)+"@@@"+uid
	if not ck(keys.size()==3,"real Main has three exact physical references"):
		w.queue_free();await process_frame;return
	var h:Node=w.hud
	h.refresh_inventory(w.inventory);w._update_hud();h.toggle_inventory()
	await process_frame
	var bag:Control=h.lineage_inventory_ui
	var native:bool=h.original_inventory_is_open()
	ck(native==not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"test reached requested actual inventory surface")
	for id:int in ACTIVE+[CRAFT_ONLY]:
		var ref:String=keys[id]
		var using:bool=id in ACTIVE
		if native:
			var chosen:Dictionary=h.original_inventory_select(ref)
			ck(chosen.get("ok",false),"native surface selects exact physical slot "+str(id))
			var view:RefCounted=h.original_main_ui_controller._inventory_view
			var slot:Node2D=view._hits.get(ref,{}).get("native_slot_scene")
			ck(is_instance_valid(slot) and view._slots.action_text(ref)==("사용" if using else ""),"native Common_Slot action role "+str(id))
			if using and is_instance_valid(slot):
				ck(slot.source_nodes[SLOTS.ACTION].is_visible_in_tree(),"native 사용 shown "+str(id))
		else:
			bag._select_item(ref)
			ck(bag.slot_buttons.has(ref) and bag.item_action_armed(ref)==using,"fallback bag selects and arms only real effect "+str(id))
		ck(bag.item_action_label(ref)==("사용" if using else ""),"shared exact marker "+str(id))
		if using:
			var before:String=FileAccess.get_sha256(w.save_path())
			w.level=60
			if native:h.original_inventory_activate_selected(ref)
			else:bag._activate_selected()
			ck(h.message_label.text.contains("레벨 조건"),"real used button applies original level gate "+str(id)+" / "+h.message_label.text)
			w.level=90
			if native:h.original_inventory_activate_selected(ref)
			else:bag._activate_selected()
			ck(h.message_label.text.contains("원본 523 지도에서만") and STACK.proof(w,ref.get_slice("@@@",1)).get("remaining")==1 and FileAccess.get_sha256(w.save_path())==before,"real dispatched use applies current map rule and preserves source receipt "+str(id)+" / "+h.message_label.text)
	w.queue_free();await process_frame
