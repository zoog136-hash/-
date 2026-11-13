extends SceneTree
## Production routing/deferred refresh/retirement contracts, without private
## CSBs. Stage counters exclude original rendering and quest data costs.
var checks: int=0
var failures: Array[String]=[]

class WindowProbe extends "res://scripts/ui/original_ui/source_main_quest_window.gd":
	var stages: Array=[]
	func _stage() -> Dictionary:
		stages.append([_category,_selected_id,_scroll])
		if not is_open():
			_scene=Node2D.new()
			var host: Node=_parent.get_ref() if _parent!=null else null
			if host!=null:host.add_child(_scene)
		return {"ok":true,"handled":true,"selected_id":_selected_id}

class NativeController extends Node:
	var handled: bool=true
	var succeeded: bool=true
	var attempts: int=0
	var refreshes: int=0
	var claim: Callable
	var target_window: RefCounted
	func try_open_quest_window(_world: Node,callback: Callable) -> Dictionary:
		attempts+=1
		claim=callback
		return {"ok":succeeded,"handled":handled}
	func quest_window_is_open() -> bool:return handled
	func refresh_quest_window() -> Dictionary:
		refreshes+=1
		return target_window.refresh() if target_window!=null else {"ok":true,"handled":true}

class HudProbe extends "res://scripts/ui/renewal_hud.gd":
	var browser_opens: int=0
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String,_title: String,_description: String) -> void:
		active_section=section
		workspace.show()
	func _open_quest_browser() -> void:
		browser_opens+=1
		workspace.show()

class OldEntries extends RefCounted:
	var rows: Array[Dictionary]=[]
	var calls: int=0
	func entries(_level: int,_inventory: Dictionary) -> Array[Dictionary]:
		calls+=1
		return rows

class CategoryEntries extends OldEntries:
	var category_calls: int=0
	func entries_for_category(_level: int,_inventory: Dictionary,category: String) -> Array[Dictionary]:
		category_calls+=1
		var result: Array[Dictionary]=[]
		for row: Dictionary in rows:
			if row.get("category")==category:result.append(row)
		return result

class QuestWorld extends Node:
	var level: int=80
	var inventory: Dictionary={}
	var quest_auto: RefCounted
	var quest_service: RefCounted

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _hud() -> HudProbe:
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(HudProbe)
	var hud: HudProbe=instance as HudProbe
	hud.workspace=preload("res://scripts/ui/renewal_window.gd").new()
	hud.get_node("Root").add_child(hud.workspace)
	root.add_child(hud)
	return hud

func _frames() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	_routing()
	_hud_retirement()
	_row_models()
	await _selection_batches()
	await _hud_refresh_sessions()
	print("ORIGINAL_UI_QUEST_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"private_pack_used":false}))
	quit(0 if failures.is_empty() else 1)

func _routing() -> void:
	var hud: HudProbe=_hud()
	var controller:=NativeController.new()
	hud.add_child(controller)
	hud.original_main_ui_controller=controller
	var claimed: Array=[]
	hud.quest_complete_requested.connect(func(id: String) -> void:claimed.append(id))
	hud.open_quests()
	check(controller.attempts==1 and hud.browser_opens==0 and not hud.workspace.visible,"native quest entry creates no hidden legacy browser")
	check(hud.active_section=="quests" and hud.quest_view==null,"native quest section remains active without a legacy view")
	controller.claim.call("existing-quest")
	check(claimed==["existing-quest"],"native claims retain the existing HUD signal")
	controller.succeeded=false
	hud.open_quests()
	check(hud.browser_opens==1 and hud.workspace.visible,"a failed native result cannot hide the current browser")
	controller.succeeded=true
	controller.handled=false
	hud.open_quests()
	check(hud.browser_opens==2 and hud.workspace.visible,"unsupported native input retains the current browser fallback")
	hud.original_main_ui_controller=null
	hud.open_quests()
	check(hud.browser_opens==3,"a missing native controller retains the current browser")
	hud.free()

func _row_models() -> void:
	var rows: Array[Dictionary]=[
		{"id":"done","source_id":1,"category":"main","completed":true},
		{"id":"waiting","source_id":2,"category":"main","available":true,"progress":0,"objective":{"count":1}},
		{"id":"ready","source_id":3,"category":"main","available":true,"progress":1,"objective":{"count":1}},
		{"id":"other","source_id":4,"category":"achievement","available":true,"progress":1},
		{"id":"legacy","category":"main","available":true,"progress":1}]
	var before: Array=rows.duplicate(true)
	var old:=OldEntries.new();old.rows=rows
	var category:=CategoryEntries.new();category.rows=rows
	var world:=QuestWorld.new()
	var window=preload("res://scripts/ui/original_ui/source_main_quest_window.gd").new()
	window._world=weakref(world)
	world.quest_service=old
	var old_rows: Array[Dictionary]=window._rows()
	world.quest_service=category
	var new_rows: Array[Dictionary]=window._rows()
	check(old.calls==1 and category.calls==0 and category.category_calls==1,"native rows use the category API while two-argument providers still work")
	check(new_rows==old_rows and new_rows.map(func(row: Dictionary) -> String:return row.id)==["ready","waiting","done"],"receivable/waiting/completed order and source-only filtering are preserved")
	check(rows==before,"native list projection leaves source quest data unchanged")
	world.free()

func _hud_retirement() -> void:
	var hud: HudProbe=_hud()
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	var texture: Texture2D=ImageTexture.create_from_image(image)
	var witness: WeakRef=weakref(texture)
	for section: String in ["inventory","character_equipment","character_stats","quest_window","shop_window","change_window","npc_dialogue","enhance_action","quest_controls","emblem_window","domination_window","status_board","acquisition_popup"]:
		hud.original_main_ui_status[section]={"ok":true,"code":"preserved-status","texture":texture,"nested":{"texture":texture}}
	texture=null
	hud._close_workspace()
	check(witness.get_ref()==null,"closing the workspace releases every transient diagnostic texture")
	for status: Dictionary in hud.original_main_ui_status.values():
		check(status.get("closed",false) and status.get("code")=="preserved-status" and not status.has("texture") and not status.has("nested"),"closed diagnostics preserve plain reasons only")
	texture=ImageTexture.create_from_image(image)
	witness=weakref(texture)
	hud.original_main_ui_status["inventory"]={"texture":texture}
	texture=null
	hud._original_inventory_closed()
	check(witness.get_ref()==null and hud.original_main_ui_status.inventory.closed,"direct authored inventory close also retires its snapshot")
	texture=ImageTexture.create_from_image(image)
	witness=weakref(texture)
	hud._restore_current_inventory_view({"ok":false,"code":"unsupported-source","owner":{"texture":texture}})
	texture=null
	check(witness.get_ref()==null and hud.original_main_ui_status.inventory.code=="unsupported-source","fallback diagnostics retain their reason without failed owner textures")
	hud.free()

func _selection_batches() -> void:
	var host:=Node2D.new();root.add_child(host)
	var world:=Node.new();root.add_child(world)
	var received: Array=[]
	var window:=WindowProbe.new()
	window.open(host,world,func(id: String) -> void:received.append(id))
	window._selected_id="first"
	window._scroll=-240.0
	window._select_quest("first")
	check(window.stages.size()==1,"tapping the current quest creates no replacement scene")
	for index: int in 50:window._select_quest("quest-"+str(index))
	window.refresh()
	check(window.stages.size()==1 and window._refresh_pending,"selection input and world refresh share the pending rebuild")
	await _frames()
	check(window.stages.size()==2 and window.stages[-1][1]=="quest-49" and window.stages[-1][2]==-240.0,"one rebuild keeps the final selected ID and scroll")
	window._receive("quest-49")
	window.refresh()
	check(received==["quest-49"] and window.stages.size()==2,"the existing claim executes once before the deferred visual update")
	await _frames()
	check(window.stages.size()==3,"claim plus world refresh create one replacement")
	var claim_hud: HudProbe=_hud()
	var claim_controller:=NativeController.new();claim_hud.add_child(claim_controller)
	claim_controller.target_window=window
	claim_hud.original_main_ui_controller=claim_controller
	var hud_ref: WeakRef=weakref(claim_hud)
	window._claim=func(id: String) -> void:
		received.append(id)
		var current: Node=hud_ref.get_ref()
		if current!=null:current.refresh_quests()
	window._select_quest("same-frame-selection")
	window._receive("same-frame-claim")
	await _frames()
	check(window.stages.size()==4 and claim_controller.refreshes==1 and received[-1]=="same-frame-claim","selection then claim then actual deferred HUD refresh share one replacement")
	claim_hud.free()
	window._select_quest("cancel-on-close")
	var pending_callback: Callable=window._refresh_callback
	window.close()
	check(not process_frame.is_connected(pending_callback),"close disconnects its one-shot frame callback immediately")
	await _frames()
	check(window.stages.size()==4 and not window.is_open(),"closing cancels pending selection work")
	window.open(host,world,func(_id: String) -> void:pass)
	window._select_quest("old-session")
	window.close()
	window.open(host,world,func(_id: String) -> void:pass)
	var opened_stages: int=window.stages.size()
	await _frames()
	check(window.stages.size()==opened_stages,"a stale selection callback cannot rebuild a reopened window")
	window._select_quest("old-category")
	window._select_category("achievement")
	var category_stages: int=window.stages.size()
	await _frames()
	check(window.stages.size()==category_stages+1 and window.stages[-1]==["achievement","",0.0],"category switch shares the pending selection rebuild")
	category_stages=window.stages.size()
	var window_ref: WeakRef=weakref(window)
	window._claim=func(_id: String) -> void:
		var current: RefCounted=window_ref.get_ref()
		if current!=null:current.close()
	window._receive("close-during-claim")
	await _frames()
	check(not window.is_open() and window.stages.size()==category_stages,"a claim callback that closes the window cannot reopen it")
	host.queue_free();world.queue_free()
	await _frames()

func _hud_refresh_sessions() -> void:
	var hud: HudProbe=_hud()
	var controller:=NativeController.new();hud.add_child(controller)
	hud.original_main_ui_controller=controller
	hud.refresh_quests()
	var old_generation: int=hud.quest_refresh_generation
	hud.original_main_ui_controller=null
	hud.workspace.hide()
	hud._close_workspace()
	hud.original_main_ui_controller=controller
	hud.active_section="quests"
	hud._refresh_quests_deferred(old_generation)
	await _frames()
	check(controller.refreshes==0,"a deferred HUD refresh from a closed session cannot rebuild a new quest window")
	hud.refresh_quests()
	hud.refresh_quests()
	await _frames()
	check(controller.refreshes==1,"current-session HUD events still coalesce and refresh")
	hud.free()
