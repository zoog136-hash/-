extends SceneTree
## Source-sized synthetic records, real text UI and existing atomic acceptance.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const VIEW=preload("res://scripts/ui/renewal_quests.gd")
const RUNNER=preload("res://scripts/quests/quest_auto_runner.gd")
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={"synthetic":true,"android_verified":false}
var bake_name: String
var source: RefCounted

class TracedSource extends "res://scripts/quests/source_quest523.gd":
	var reads: int=0
	var plans: int=0
	var gates: int=0
	func _read_record(id: String) -> Dictionary:reads+=1;return super._read_record(id)
	func reward_plan(row: Dictionary,context: Dictionary) -> Dictionary:plans+=1;return super.reward_plan(row,context)
	func gate(row: Dictionary,context: Dictionary,claimed: Dictionary,now: int) -> String:gates+=1;return super.gate(row,context,claimed,now)

class Runner extends "res://scripts/quests/quest_auto_runner.gd":
	var contexts: int=0
	func refresh_context(world: Node) -> void:
		contexts+=1
		context={"level":world.level,"max_level":world.level,"class_id":1,"source_items":{},"currency_items":{}}
		world.quest_service.source_context=context

class Hud extends Node:
	var logs: Array=[]
	func append_log(value: String) -> void:logs.append(value)
	func show_message(value: String) -> void:logs.append(value)
	func refresh_quests() -> void:pass

class Collections extends RefCounted:
	var save_blocked: bool=false
	func accept_load(_value: Dictionary) -> bool:return true

class Deferred extends RefCounted:
	func cancel() -> void:pass

class World extends Node:
	var quest_service: RefCounted
	var quest_auto: RefCounted=Runner.new()
	var level: int=80
	var job_class: String="기사"
	var inventory: Dictionary={"preserved":3}
	var item_instances: Dictionary={}
	var next_item_instance_id: int=1
	var gold: int=100
	var experience: int=0
	var exp_need: int=1000000
	var max_hp: int=100
	var max_mp: int=100
	var hp: int=100
	var mp: int=100
	var attack_power: int=10
	var defense: int=10
	var stat_points: int=0
	var equipment_collections: RefCounted=Collections.new()
	var deferred_save: RefCounted=Deferred.new()
	var source_save_blocked: bool=false
	var pending_map_save_record: Dictionary={}
	var hud: Node=Hud.new()
	var writes: int=0
	var write_mode: String="ok"
	var path: String
	func save_path() -> String:return path
	func _check_level_up(_quiet: bool) -> void:pass
	func _update_hud() -> void:pass
	func _refresh_inventory_hud() -> void:pass
	func _refresh_combat_hud() -> void:pass
	func _save_game(_quiet: bool,staged: Dictionary) -> Error:
		writes+=1
		if write_mode=="before_error":return ERR_FILE_CANT_WRITE
		var error: Error=preload("res://scripts/skills/save_writer.gd").write(path,staged)
		return ERR_FILE_CANT_WRITE if write_mode=="after_error" and error==OK else error
	func accept(id: String) -> void:quest_auto.claim(self,id)

class NativeSpy extends Node:
	var opens: int=0
	var closes: int=0
	func try_open_quest_window(_world: Node,_claim: Callable) -> Dictionary:opens+=1;return {"ok":true,"handled":true}
	func close_quest_window() -> void:closes+=1

class HudRoute extends "res://scripts/ui/renewal_hud.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String,_title: String,_description: String) -> void:
		active_section=section
		workspace.show()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:_run.call_deferred()
func frames() -> void:
	await process_frame
	await process_frame

func _row(i: int) -> Dictionary:
	var metadata: Dictionary={}
	for j: int in 48:metadata["synthetic_"+str(j)]={"n":i+j,"text":"record scale fixture ".repeat(4)}
	return {"id":"m523:quest:"+str(i+1),"source_id":i+1,"title":"Synthetic quest "+str(i+1),"category":"main","definition":{"ID":i+1,"Name":"Synthetic","TypeID":0},"prerequisites":[],"goals":[],"source_rewards":[{"ID":i+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":7,"RewardClassID":0,"type_name":"Exp","source_item":metadata}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800,"description":"synthetic","objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func _run() -> void:
	bake_name="quest-text-window-"+str(OS.get_process_id())
	var writer=BAKE.record_writer(bake_name,"text-window-synthetic")
	check(writer!=null,"synthetic record writer opens")
	if writer==null:_finish();return
	var service=SERVICE.new()
	source=TracedSource.new();source.class_ids={"기사":1};service.source=source
	for i: int in 3621:
		var row: Dictionary=_row(i)
		writer.add(row.id,row)
		var resident: Dictionary=SOURCE._compact(row)
		service.quests.append(resident);service.index[resident.id]=resident;source.quests.append(resident)
	check(BAKE.finish_records(writer),"source-sized synthetic bake commits")
	source._records=BAKE.open_records(bake_name,"text-window-synthetic")
	check(source._records!=null,"verified source record reader opens")
	if source._records==null:_finish();return
	evidence.record_bytes=source._records.file.get_length()
	check(evidence.record_bytes>20*1024*1024,"3621-row bake exceeds 20 MiB")
	var record_sha: String=FileAccess.get_sha256(BAKE.data_path(bake_name))
	var world:=World.new();world.quest_service=service;world.add_child(world.hud);root.add_child(world)
	world.path="user://quest-text-save-"+str(OS.get_process_id())+".json"
	var sentinel:=FileAccess.open(world.path,FileAccess.WRITE);sentinel.store_string("{\"preserve\":true}\n");sentinel.close()
	service.day_key=SERVICE.korean_daily_key(int(Time.get_unix_time_from_system()))
	service.claimed={"m523:quest:1":true,"twilight:historic":true}
	service.progress={"m523:quest:2":0}
	var before: Dictionary=service.export_state()
	var save_sha: String=FileAccess.get_sha256(world.path)
	var baseline: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var model: Dictionary=service.text_page(80,"main",0,30,"","all",-1,1)
	evidence.data_usec=Time.get_ticks_usec()-started
	evidence.data_static_growth=OS.get_static_memory_usage()-baseline
	check(model.rows.size()==30 and model.matches==3621 and model.rows[0].completed and model.rows[1].can_accept,"resident text page preserves completed state and individual acceptance")
	check(source.reads==0 and source.plans==0 and source.gates==29,"listing checks only visible uncompleted gates, no record decode or reward plan")
	check(service.text_page(80,"main",999999,30).rows.size()==21,"last page clamps to 21 rows")
	check(service.text_page(80,"main",0,30,"3621").rows[0].id=="m523:quest:3621","last original ID remains searchable")
	check(service.text_page(80,"main",0,30,"","done").matches==1,"completed filter uses saved claims")
	check(service.text_page(80,"main",0,30,"","waiting").matches==3620,"uncompleted filter does not mark every quest done")
	var legacy: Dictionary={"id":"twilight:daily:1","title":"Saved history","category":"daily"}
	service.quests.append(legacy);service.claimed[legacy.id]=true
	check(service.text_page(80,"common",0,30,"","history").rows[0].completed,"retired daily completion remains visible as saved history")
	service.quests.pop_back();service.claimed.erase(legacy.id)
	model.rows[0].title="caller only"
	check(service.quests[0].title=="Synthetic quest 1","text output cannot mutate original resident metadata")
	for i: int in 50:world.quest_auto.tick(world)
	check(source.reads==0 and source.plans==0 and world.quest_auto.contexts==0,"normal gameplay no longer scans every quest or prepares all rewards")
	var view=VIEW.new();root.add_child(view)
	baseline=OS.get_static_memory_usage();started=Time.get_ticks_usec()
	view.configure(world);view.claim_requested.connect(world.accept)
	evidence.ui_usec=Time.get_ticks_usec()-started
	evidence.ui_static_growth=OS.get_static_memory_usage()-baseline
	check(view.listing.get_child_count()==30 and view.listing.find_children("","TextureRect",true,false).is_empty() and view.listing.find_children("","Sprite2D",true,false).is_empty(),"real UI mounts only 30 text rows without image nodes: "+str([view.listing.get_child_count(),view.find_children("","TextureRect",true,false).size(),view.find_children("","Sprite2D",true,false).size()]))
	check(view.find_children("","Button",true,false).all(func(button: Button) -> bool:return button.text!="모두 받기"),"no bulk completion button")
	var first_row: WeakRef=weakref(view.listing.get_child(0))
	for i: int in 50:view._select("main" if i%2 else "common")
	check(view.listing.get_child(0)==first_row.get_ref() and view._refresh_pending,"rapid tab input coalesces before constructing new rows")
	await frames()
	check(first_row.get_ref()==null and view.listing.get_child_count()==30,"one redraw retires the previous page")
	check(service.export_state()==before and world.writes==0 and FileAccess.get_sha256(world.path)==save_sha,"opening and browsing never complete, reward or save any quest")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var capture: Image=root.get_texture().get_image()
		check(not capture.is_empty() and capture.save_png("user://quest-text-window.png")==OK,"real OpenGL text list renders and captures")
		root.size=Vector2i(854,480)
		await frames()
		await RenderingServer.frame_post_draw
		check(view.size.x<=854 and view.listing.get_parent().size.y>=100,"text list stays within an Android-sized 854x480 viewport")
	view.listing.get_child(1).get_child(2).pressed.emit()
	for i: int in 49:view._accept("m523:quest:2")
	check(service.claimed.get("m523:quest:2",false) and world.experience==7 and world.writes==1,"accept immediately completes exactly one quest and grants once")
	check(service.claimed.size()==before.claimed.size()+1 and service.progress["m523:quest:2"]==0,"acceptance needs no objective farming and does not complete the catalog: "+str([service.claimed.size(),before.claimed.size(),service.progress]))
	await frames()
	check(service.text_page(80,"main",0,30,"2").rows[0].completed,"completion appears in the text list")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.path))
	check(service.import_state(saved.quest_state),"completion reloads through existing save validator")
	view._accept("m523:quest:2")
	check(world.writes==1 and world.experience==7,"reloaded completion rejects duplicate acceptance")
	world.write_mode="before_error"
	view._accept("m523:quest:3");await frames()
	check(not service.claimed.has("m523:quest:3") and world.experience==7,"failed save leaves quest and rewards uncompleted")
	world.write_mode="after_error"
	view._accept("m523:quest:3");await frames()
	check(service.claimed.get("m523:quest:3",false) and world.experience==14,"post-write error adopts the confirmed durable transaction once")
	var writes: int=world.writes
	view._accept("m523:quest:3")
	check(world.writes==writes and world.experience==14,"post-write retry cannot award twice")
	view.refresh()
	var callback: Callable=Callable(view,"_flush_refresh")
	view.free()
	check(not process_frame.is_connected(callback),"closing disconnects pending redraw")
	await frames()
	view=VIEW.new();root.add_child(view);view.configure(world)
	check(view.listing.get_child_count()==30,"text list reopens with saved completion")
	view.free()
	await _routing(world)
	check(FileAccess.get_sha256(BAKE.data_path(bake_name))==record_sha,"original record bake bytes are unchanged")
	DirAccess.remove_absolute(world.path)
	world.free()
	_finish()

func _routing(world: Node) -> void:
	var hud: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	hud.set_script(HudRoute)
	hud.workspace=preload("res://scripts/ui/renewal_window.gd").new()
	hud.get_node("Root").add_child(hud.workspace)
	world.add_child(hud)
	var native:=NativeSpy.new();hud.add_child(native);hud.original_main_ui_controller=native
	hud.open_quests()
	var view: Node=hud.quest_view
	for i: int in 50:hud.open_quests()
	check(hud.quest_view==view and native.opens==0 and native.closes==1,"actual HUD repeated opens reuse one text view and never open native quest art")
	hud.free();await frames()

func _finish() -> void:
	if source!=null:source._records=null
	if not bake_name.is_empty():BAKE.clear(bake_name)
	print("QUEST_TEXT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
