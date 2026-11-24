extends SceneTree
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const POLICY=preload("res://scripts/animation/source_presentation_policy.gd")
const STORE=preload("res://scripts/resources/cooked_actor_store.gd")
const COMP=preload("res://scripts/animation/source_sp2_compositor.gd")
const IDS:Dictionary={127971:17447,127981:17446,127991:17458,128001:17459}
const BANK_SHA:="587b419b38fd9e66639b315788011c986439a005b2525942162ff71febc81eeb"
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_FIREWORK_MAIN_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func reject(_path:String,data:Dictionary)->Error:
	rejected=data
	return ERR_CANT_CREATE
func run()->void:
	ck(STACK.DIRECT_FIREWORKS.size()==IDS.size() and not STACK.DIRECT_FIREWORKS.has(126543),"separate exact permanent IDs; dated visual duplicates not admitted")
	var definitions:String=OS.get_environment("TWILIGHT_NATIVE_FIREWORK_DEFINITIONS")
	if not definitions.is_empty():
		if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main profile"):
			await exact(definitions,OS.get_environment("TWILIGHT_NATIVE_FIREWORK_BANK"))
	print("NATIVE_FIREWORK_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exact(definitions:String,bank:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main inventory")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",definitions);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"pinned original definition archive")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var grants:Array=[]
	for id:int in IDS:
		var record:Dictionary=w.source_item_definition(id).get("native_record",{})
		w.catalog_db["아이템"].append(record)
		ck(STACK.profile(record).get("spec",{}).get("sprite_id")==IDS[id],"real original permanent use contract "+str(id))
		grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	var old:Dictionary=w.source_item_definition(126543).get("native_record",{})
	ck(not old.is_empty() and STACK.profile(old).get("kind")!="exact_firework","expired red firework cannot piggyback on the matching original sprite")
	var given:Dictionary=INV.stage(w,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(given.get("ok",false),"shared physical source supplier "+str(given.get("error",""))):
		w.queue_free();return
	w.inventory=given.overrides.inventory;w.item_instances=given.overrides.item_instances
	var uids:Dictionary={}
	for uid:String in w.item_instances:
		var id:int=int(w.item_instances[uid].get("record",{}).get("source_item_class_id",0))
		if IDS.has(id):uids[id]=uid
	if not ck(uids.size()==IDS.size() and w._save_game(true)==OK,"four exact physical receipts and baseline save"):
		w.queue_free();return
	var preview:Node2D=w.player.original_source_preview
	var original_context:Dictionary=preview._reference_request_context
	preview._reference_request_context={"current523_source_bank":{}}
	var old_nodes:int=preview._overlay_nodes.size()
	var before:PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	var red_uid:String=uids[127971]
	var red:String=str(w.item_instances[red_uid].name)+"@@@"+red_uid
	w.hud.inventory_item_activated.emit(red)
	ck(w.item_instances.has(red_uid) and preview._overlay_nodes.size()==old_nodes and FileAccess.get_file_as_bytes(w.save_path())==before,"missing packing never consumes, saves or starts an overlay")
	if bank.is_empty():
		w.queue_free();return
	var pinned:String=bank.path_join("manifest.json")
	if not ck(FileAccess.get_sha256(pinned)==BANK_SHA,"complete original released bank manifest is pinned"):
		w.queue_free();return
	var cooked:String=OS.get_environment("TWILIGHT_NATIVE_FIREWORK_COOKED")
	preview._reference_request_context={"current523_source_bank":{"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":definitions,"manifest_path":pinned,"manifest_sha256":BANK_SHA}}
	var prior_screen_copy:bool=COMP.screen_copy_available
	COMP.screen_copy_available=false # Production Android renderer request.
	if cooked.is_empty():
		STORE.root_override=bank.get_base_dir().path_join("cooked")
		STORE.reset_for_tests()
		ck(not STORE.effect_index(BANK_SHA).is_empty(),"only the original action index is mounted")
		w.hud.inventory_item_activated.emit(red)
		ck(w.item_instances.has(red_uid) and preview._overlay_nodes.size()==old_nodes and FileAccess.get_file_as_bytes(w.save_path())==before and preview.source_effect_status.get("reason")=="current523_item_effect_cooked_overlay_missing","even with raw assets and action index, missing fast overlay does not block decoding or spend")
		STORE.root_override="";STORE.reset_for_tests();COMP.screen_copy_available=prior_screen_copy
		w.queue_free();await process_frame;return
	STORE.root_override=cooked
	STORE.reset_for_tests()
	var index:Dictionary=STORE.effect_index(BANK_SHA)
	ck(not index.is_empty(),"ordinary published cooker action index exists")
	for sprite:int in IDS.values():
		ck(Array(index.get("domains",{}).get("sprite:"+str(sprite),[]))==[0] and Array(index.get("compiled",{}).get("sprite:"+str(sprite),[]))==[0],"sole original action and compiled input "+str(sprite))
	var rejected_started:int=Time.get_ticks_usec()
	w.equipment_collections.test_save_writer=reject;w.hud.inventory_item_activated.emit(red)
	var rejected_usec:int=Time.get_ticks_usec()-rejected_started
	ck(not rejected.is_empty() and not rejected.get("item_instances",{}).has(red_uid),"actual writer receives the debit only after detached exact art preparations succeed "+str(preview.source_effect_status.get("reason","")))
	ck(w.item_instances.has(red_uid) and preview._overlay_nodes.size()==old_nodes and FileAccess.get_file_as_bytes(w.save_path())==before,"failed writer does not display or debit")
	w.equipment_collections.test_save_writer=Callable()
	var state:Array=[w.hp,w.mp,w.gold,w.experience,w.rng.state,w.active_item_buffs.duplicate()]
	var observations:Dictionary={"first_asset_refused_writer_usec":rejected_usec}
	for id:int in IDS:
		var uid:String=uids[id];var ref:String=str(w.item_instances[uid].name)+"@@@"+uid
		var started:int=Time.get_ticks_usec()
		w.hud.inventory_item_activated.emit(ref)
		observations[str(id)]={"main_transaction_usec":Time.get_ticks_usec()-started}
		var last:Node2D=preview._overlay_nodes.back() if preview._overlay_nodes.size()>old_nodes else null
		var committed:bool=not w.item_instances.has(uid) and is_instance_valid(last)
		if ck(committed,"spent one actual bag receipt with true exact asset "+str(id)+" "+str(preview.source_effect_status.get("reason",""))):
			ck(not draws(last) and last.global_position==w.player.global_position,"original blank lead-in and actual world anchoring "+str(id))
			var frame:Dictionary=last._playback_tracks.idle.directions[last._overlay_facing][0]
			last.advance_reference_source(POLICY.duration(frame),"idle",last._overlay_facing)
			var shown:Dictionary=last.reference_source_frame_status()
			observations[str(id)]["authored_lead_in_msec"]=POLICY.duration(frame)*1000.0
			ck(last.cooked_actor() and draws(last) and shown.get("source_actor_id")==IDS[id] and shown.get("source_action_id")==0,"Main actually renders exact original pixels and source action "+str(id)+" "+str(shown))
			var count:int=preview._overlay_nodes.size()
			w.hud.inventory_item_activated.emit(ref)
			ck(preview._overlay_nodes.size()==count,"stale physical tap does not launch twice "+str(id))
	ck(state==[w.hp,w.mp,w.gold,w.experience,w.rng.state,w.active_item_buffs],"visual-only fireworks leave all gameplay states untouched")
	w._load_game(true)
	var gone:bool=true
	for uid:String in uids.values():gone=gone and not w.item_instances.has(uid)
	ck(gone,"four debits survive a disk reload")
	print("NATIVE_FIREWORK_EVIDENCE ",JSON.stringify(observations))
	preview._reference_request_context=original_context
	COMP.screen_copy_available=prior_screen_copy
	STORE.root_override=""
	STORE.reset_for_tests()
	w.queue_free();await process_frame


func draws(overlay:Node2D)->bool:
	for layer:Node in overlay.find_children("*","Sprite2D",true,false):
		if layer.texture!=null and layer.is_visible_in_tree():return true
	return false
