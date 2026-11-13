extends SceneTree
## Real HUD polling, chrome snapshot, scene setters, slot ownership and view.
## Full native CSB construction and text drawing are counted synthetic fixtures.
const HUD=preload("res://scripts/ui/original_ui/source_main_hud.gd")
const CHROME=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakePointer extends RefCounted:
	var pointer: int=-2

class FakeBag extends Control:
	var offered: Array[Dictionary]=[]
	var legacy_rows: Array=[]
	var sorted_references: Array[String]=[]
	var inventory_grid_dirty: bool=false
	var inventory_list_rebuilds: int=0
	var category_filter: String="전체"
	var inventory: Dictionary={}
	var capacity_label: Label
	func hide_inventory() -> void:pass
	func _set_category(value: String) -> void:category_filter=value
	func _format_number(value: int) -> String:return "formatted-%d"%value
	var selected_item: String=""
	var detail_active: bool=false
	var search_line: LineEdit
	var item_grid: GridContainer
	var character_state: Dictionary={"gold":9,"current_weight":3,"max_weight":100,"carrying_capacity":100,"equipped_items":{},"equipped_ammo":"","item_locks":{}}
	var entry_calls: int=0
	var activations: int=0
	var on_select: Callable
	func prepare_source_inventory_model() -> void:pass
	func _inventory_entries() -> Array[Dictionary]:
		entry_calls+=1
		return offered.duplicate(true)
	func _select_item(reference: String) -> void:
		selected_item=reference
		if on_select.is_valid():on_select.call()
	func _activate_selected() -> void:activations+=1
	func _is_item_equipped(reference: String) -> bool:return character_state.equipped_items.values().has(reference)

class FakeHud extends Node:
	var lineage_inventory_ui: Control
	var pointer_transfer: RefCounted=FakePointer.new()

class FakeSlot extends Node2D:
	var source_member: String="UI/CommonUi/Common_Slot.csb"
	var source_nodes: Dictionary={8328:true,7304:true}
	var texts: Dictionary={}
	var shown: Dictionary={}
	var reject: bool=false
	var patches: int=0
	func set_bound_text(offset: int, text: String) -> Dictionary:
		patches+=1
		if reject:return {"ok":false,"code":"synthetic_slot_reject"}
		texts[offset]=text
		return {"ok":true}
	func set_bound_visible(offset: int, visible_value: bool) -> Dictionary:
		shown[offset]=visible_value
		return {"ok":true}

class TextSink extends Node2D:
	var text: String=""
	var reject: bool=false
	func set_source_text(value: String) -> Dictionary:
		if reject:return {"ok":false,"code":"synthetic_font_reject"}
		text=value
		return {"ok":true}

class HeaderScene extends "res://scripts/ui/original_ui/sprite_scene.gd":
	func build_header(model: Dictionary) -> void:
		source_member=CHROME.MEMBER
		for category: String in CHROME.TABS:
			for offset: int in CHROME.TABS[category]:
				var node:=Node2D.new()
				add_child(node)
				source_nodes[offset]=node
				_bindings[offset]={"visible":true}
		for entry: Array in [[CHROME.GOLD_TEXT,"gold_text"],[CHROME.CAPACITY_TEXT,"capacity_text"]]:
			if not model.has(entry[1]):continue
			var node:=Node2D.new()
			var text:=TextSink.new()
			node.add_child(text)
			node.set_meta("source_text",text)
			add_child(node)
			source_nodes[entry[0]]=node
			_bindings[entry[0]]={"role":"source_text"}
	func values() -> Dictionary:
		var result: Dictionary={}
		for offset: int in source_nodes:
			var node: Node2D=source_nodes[offset]
			result[offset]=node.get_meta("source_text").text if node.has_meta("source_text") else node.visible
		return result

class CountingView extends "res://scripts/ui/original_ui/source_main_inventory_view.gd":
	var stages: int=0
	var allocated_slots: int=0
	func _stage(parent: Node, _initial_open: bool) -> Dictionary:
		stages+=1
		if not _slots._identities().get("ok",false):return _stage_failed({"ok":false})
		var model: Dictionary=_eligible_model()
		if not model.get("ok",false):return _stage_failed(model)
		var chrome: Dictionary=_chrome.snapshot()
		if not chrome.get("ok",false):return _stage_failed(chrome)
		var previous: Node2D=_scene
		var next:=HeaderScene.new()
		next.build_header(chrome)
		_chrome.refresh(next)
		_scene=next
		_inventory_scene=next
		_hits.clear()
		for entry: Dictionary in model.current_display_rows:
			var slot:=FakeSlot.new()
			allocated_slots+=1
			_scene.add_child(slot)
			_hits[entry.reference]={"native_slot_scene":slot}
			_slots.refresh_slot(slot,entry.reference,model)
		_scroll_content=Node2D.new()
		_scene.add_child(_scroll_content)
		parent.add_child(_scene)
		if is_instance_valid(previous):previous.free()
		return {"ok":true,"handled":true}

func _initialize() -> void:_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _fixture(count: int=8, acknowledge: bool=true) -> Dictionary:
	var host:=Node.new()
	root.add_child(host)
	var bag:=FakeBag.new()
	bag.capacity_label=Label.new()
	bag.capacity_label.text="33%% · %d / 100"%count
	bag.add_child(bag.capacity_label)
	bag.search_line=LineEdit.new()
	bag.add_child(bag.search_line)
	bag.item_grid=GridContainer.new()
	bag.item_grid.columns=4
	bag.add_child(bag.item_grid)
	for index: int in range(count):
		var reference: String="same-item@@@physical-%d"%index
		bag.offered.append({"name":"same-item","reference":reference,"amount":index+1})
		bag.sorted_references.append(reference)
	var hud:=FakeHud.new()
	hud.lineage_inventory_ui=bag
	hud.add_child(bag)
	host.add_child(hud)
	var pack:=FakePack.new()
	pack.manifest["files"]={SLOTS.PARENT:{"sha256":SLOTS.PARENT_SHA},SLOTS.SET_MEMBER:{"sha256":SLOTS.SET_SHA},SLOTS.SLOT_MEMBER:{"sha256":SLOTS.SLOT_SHA}}
	var slots=SLOTS.new()
	check(slots.configure(pack,hud).get("ok",false),"physical owner fixture configures")
	var view:=CountingView.new()
	view._slots=slots
	view._chrome=CHROME.new()
	check(view._chrome.configure(pack,hud).get("ok",false),"chrome configures")
	view._bag=weakref(bag)
	slots.selection_changed.connect(view._on_selection_changed)
	var controller=HUD.new()
	host.add_child(controller)
	controller.set_process(false)
	controller._pack=pack
	controller._hud=weakref(hud)
	controller._coordinates=Node2D.new()
	host.add_child(controller._coordinates)
	controller._inventory_view=view
	view.return_to_current_requested.connect(controller._inventory_view_fallback)
	view.closed.connect(controller._inventory_view_closed)
	if acknowledge:view.selection_refreshed.connect(controller._inventory_selection_refreshed)
	check(controller.try_open_inventory().get("handled",false),"real HUD open captures model")
	return {"host":host,"bag":bag,"hud":hud,"pack":pack,"slots":slots,"view":view,"controller":controller}

func _run() -> void:
	HITCH.reset_for_test("user://inventory_header_test")
	_real_owner_headers()
	_header_work()
	_structure_and_capture()
	_fallbacks()
	check(HITCH._details.has("ui.inventory_chrome"),"header path has separate inclusive diagnostic")
	print("SOURCE_INVENTORY_HEADER_REFRESH_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _header_work() -> void:
	for columns: int in [4,8]:
		var old: Dictionary=_fixture(64)
		var fresh: Dictionary=_fixture(64)
		for f: Dictionary in [old,fresh]:
			f.bag.item_grid.columns=columns
			f.controller._process_step(0.0)
		var first: Node2D=fresh.view._scene
		var slot: Node2D=fresh.view._hits[fresh.bag.sorted_references[0]].native_slot_scene
		fresh.view._scroll_content.position.y=-240
		first.z_index=150
		var reads: int=fresh.bag.entry_calls
		var stages: int=fresh.view.stages
		var allocations: int=fresh.view.allocated_slots
		for index: int in range(12):
			for f: Dictionary in [old,fresh]:
				f.bag.character_state.gold+=7
				f.bag.character_state.current_weight+=1
				f.bag.character_state.max_weight+=2
				f.bag.character_state.carrying_capacity+=3
			old.controller._inventory_rows_signature=-1 # Previous full-stage routing.
			old.controller._process_step(0.0)
			fresh.controller._process_step(0.0)
			check(old.view._scene.values()==fresh.view._scene.values(),"header/tab values equal previous full-stage route")
			check(fresh.view._scene==first and fresh.view._hits[fresh.bag.sorted_references[0]].native_slot_scene==slot,"live scene and slot identity retained")
			check(first.z_index==150 and fresh.view._scroll_content.position.y==-240,"z order and scroll retained")
			check(fresh.controller._inventory_result.get("chrome_only",false),"header-only route acknowledged")
		check(fresh.view.stages==stages and fresh.view.allocated_slots==allocations,"no additional full stage or slot allocations")
		check(fresh.bag.entry_calls==reads,"header refresh never rebuilds owner entries")
		check(fresh.bag.activations==0 and fresh.bag.offered==old.bag.offered,"no transaction or item mutation")
		check(old.view.stages==stages+12,"old route rebuilds all rows on twelve header changes")
		samples.append({"columns":columns,"items":64,"updates":12,"old_additional_stages":12,"new_additional_stages":fresh.view.stages-stages,"old_fixture_slot_allocations":12*64,"new_fixture_slot_allocations":fresh.view.allocated_slots-allocations})
		# Selection acknowledgement updates the row baseline before a later header change.
		fresh.controller.inventory_select(fresh.bag.sorted_references[3])
		fresh.bag.character_state.gold+=1
		fresh.controller._process_step(0.0)
		check(fresh.view.stages==stages,"native selection then header change reuses updated row baseline")
		for reference: String in fresh.view._hits:
			check(fresh.view._hits[reference].native_slot_scene.shown[SLOTS.SELECTED]==(reference==fresh.bag.selected_item),"header refresh preserves each physical selection marker")
		old.host.free()
		fresh.host.free()

func _structure_and_capture() -> void:
	for field: String in ["inventory_grid_dirty","inventory_list_rebuilds","category_filter","selected_item","detail_active","search","columns","equipped_items","equipped_ammo","item_locks"]:
		var f: Dictionary=_fixture()
		f.bag.character_state.gold+=1
		match field:
			"inventory_grid_dirty":f.bag.inventory_grid_dirty=true
			"inventory_list_rebuilds":f.bag.inventory_list_rebuilds+=1
			"category_filter":f.bag.category_filter="장비"
			"selected_item":f.bag.selected_item=f.bag.sorted_references[1]
			"detail_active":f.bag.detail_active=true
			"search":f.bag.search_line.text="same"
			"columns":f.bag.item_grid.columns=8
			"equipped_items":f.bag.character_state.equipped_items.weapon=f.bag.sorted_references[2]
			"equipped_ammo":f.bag.character_state.equipped_ammo=f.bag.sorted_references[3]
			"item_locks":f.bag.character_state.item_locks[f.bag.sorted_references[4]]=true
		f.controller._process_step(0.0)
		check(f.view.stages==2,field+": simultaneous header change cannot hide full refresh")
		f.host.free()
	var f: Dictionary=_fixture()
	var scene: Node2D=f.view._scene
	var values: Dictionary=scene.values()
	f.hud.pointer_transfer.pointer=4
	f.bag.character_state.gold+=1
	f.controller._process_step(0.0)
	check(scene.values()==values,"captured gesture defers header text updates")
	f.hud.pointer_transfer.pointer=-2
	f.controller._process_step(0.0)
	check(f.view.stages==1 and scene.values()!=values,"release updates chrome without stage")
	f.view._refreshing=true
	f.bag.character_state.gold+=1
	var before_signature: int=f.controller._inventory_signature
	f.controller._process_step(0.0)
	check(f.controller._inventory_signature==before_signature,"pending work never acknowledges unpainted model")
	f.view._refreshing=false
	f.controller._process_step(0.0)
	check(f.controller._inventory_signature!=before_signature and f.view.stages==1,"pending header update retries next uncaptured frame")
	f.controller._icons_refresh_pending=true
	f.bag.character_state.gold+=1
	f.controller._process_step(0.0)
	check(f.view.stages==2,"icon descriptor replacement still rebuilds every slot")
	f.bag.character_state.gold+=1
	f.controller._process_step(0.0)
	check(f.view.stages==2,"icon refresh establishes current header baseline")
	f.controller.close_inventory()
	check(not f.view.refresh_chrome().get("ok",false),"closed view rejects header refresh")
	f.controller.try_open_inventory()
	f.bag.character_state.gold+=1
	f.controller._process_step(0.0)
	check(f.view.stages==3,"reopen establishes header baseline")
	f.host.free()

func _fallbacks() -> void:
	for kind: String in ["missing_gold","removed_gold","added_gold","missing_capacity","removed_capacity","text_failure","slot_identity","chrome_identity","busy"]:
		var f: Dictionary=_fixture()
		var scene: Node2D=f.view._scene
		match kind:
			"missing_gold":scene.source_nodes.erase(CHROME.GOLD_TEXT)
			"added_gold":
				f.bag.character_state.gold="invalid"
				f.view.refresh()
				f.bag.character_state.gold=99
			"removed_gold":f.bag.character_state.gold="invalid"
			"missing_capacity":scene.source_nodes.erase(CHROME.CAPACITY_TEXT)
			"removed_capacity":f.bag.capacity_label.text="unknown"
			"text_failure":scene.source_nodes[CHROME.GOLD_TEXT].get_meta("source_text").reject=true
			"slot_identity":f.pack.manifest.files[SLOTS.SLOT_MEMBER].sha256="changed"
			"chrome_identity":f.pack.manifest.files[CHROME.MEMBER].sha256="changed"
			"busy":f.view._refreshing=true
		var result: Dictionary=f.view.refresh_chrome()
		if kind=="busy":check(result.get("refresh_pending",false) and f.view.stages==1,"busy view defers chrome work")
		else:check(f.view.stages==(3 if kind=="added_gold" else 2),kind+": invalid header/identity returns to full-stage validation")
		f.host.free()

func _real_owner_headers() -> void:
	# Exercise the production owner setter without mounting its legacy controls.
	var bag=preload("res://scripts/ui/renewal_inventory.gd").new()
	bag.gold_label=Label.new()
	bag.add_child(bag.gold_label)
	bag.weight_readout=Label.new()
	bag.add_child(bag.weight_readout)
	bag.weight_gauge=ProgressBar.new()
	bag.add_child(bag.weight_gauge)
	bag.capacity_label=Label.new()
	bag.capacity_label.text="64 / 100"
	bag.add_child(bag.capacity_label)
	var state: Dictionary={"gold":9,"current_weight":3,"max_weight":100,"carrying_capacity":100,"equipped_items":{},"equipped_ammo":"","item_locks":{}}
	bag.set_character_state(state.duplicate(true))
	bag.inventory_grid_dirty=false
	for field: String in ["gold","current_weight","max_weight","carrying_capacity"]:
		state[field]+=1
		bag.set_character_state(state.duplicate(true))
		check(not bag.inventory_grid_dirty and bag.inventory_list_rebuilds==0,field+": production owner leaves row model intact")
	check(bag.capacity_label.text.ends_with("64 / 100"),"production weight prefix preserves owner count text")
	check(bag.gold_label.text=="아데나  "+bag._format_number(10),"production gold formatter owns displayed currency")
	state.equipped_ammo="physical-id"
	bag.set_character_state(state)
	check(bag.inventory_grid_dirty,"production equipment change still dirties row model")
	bag.free()
