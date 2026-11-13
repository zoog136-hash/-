extends SceneTree
## Real HUD polling, native view selection and slot ownership/patch paths.
## Only native scene construction/art is replaced with a counted fixture.
const HUD=preload("res://scripts/ui/original_ui/source_main_hud.gd")
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
	var category_filter: String="all"
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

class CountingView extends "res://scripts/ui/original_ui/source_main_inventory_view.gd":
	var stages: int=0
	func _stage(parent: Node, _initial_open: bool) -> Dictionary:
		stages+=1
		var model: Dictionary=_eligible_model()
		if not model.get("ok",false):return _stage_failed(model)
		var previous: Node2D=_scene
		_scene=Node2D.new()
		_inventory_scene=_scene
		_hits.clear()
		for entry: Dictionary in model.current_display_rows:
			var slot:=FakeSlot.new()
			_scene.add_child(slot)
			_hits[entry.reference]={"native_slot_scene":slot}
			_slots.refresh_slot(slot,entry.reference,model)
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
	_selection_work()
	_structure_changes()
	_external_and_capture()
	_rejected_selection()
	_icon_refresh()
	print("SOURCE_INVENTORY_SELECTION_ACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _selection_work() -> void:
	for acknowledge: bool in [false,true]:
		var fixture: Dictionary=_fixture(64,acknowledge)
		var bag: FakeBag=fixture.bag
		var view: CountingView=fixture.view
		var initial_scene: Node2D=view._scene
		var before_state: int=hash([bag.offered,bag.character_state])
		for index: int in range(6):
			var reference: String=bag.sorted_references[index]
			var result: Dictionary=fixture.controller.inventory_select(reference)
			check(result.get("ok",false) and not result.game_transaction_performed and not result.use_requested,"native select performs no transaction")
			fixture.controller._process_step(0.0)
			for hit_reference: String in view._hits:
				check(view._hits[hit_reference].native_slot_scene.shown[SLOTS.SELECTED]==(hit_reference==reference),"physical slot selection remains correct")
		var stages_before_same: int=view.stages
		fixture.controller.inventory_select(bag.selected_item)
		fixture.controller._process_step(0.0)
		check(view.stages==stages_before_same,"same selection never restages")
		check(view.stages==(1 if acknowledge else 7),"six native changes stage only once with acknowledgment")
		if acknowledge:check(view._scene==initial_scene,"native selection preserves scene and its playback/scroll ownership")
		check(bag.activations==0 and hash([bag.offered,bag.character_state])==before_state,"native selection preserves inventory, currency, equipment and use ownership")
		samples.append({"acknowledgment":acknowledge,"owned":64,"selection_changes":6,"full_stages_including_open":view.stages,"owner_reads":bag.entry_calls})
		fixture.host.free()

func _structure_changes() -> void:
	for field: String in ["inventory_list_rebuilds","category_filter","detail_active","search","columns","gold","current_weight","max_weight","carrying_capacity","equipped_items","equipped_ammo","item_locks"]:
		var fixture: Dictionary=_fixture()
		var bag: FakeBag=fixture.bag
		var before_signature: int=fixture.controller._inventory_signature
		match field:
			"inventory_list_rebuilds":bag.inventory_list_rebuilds+=1
			"category_filter":bag.category_filter="equipment"
			"detail_active":bag.detail_active=true
			"search":bag.search_line.text="same"
			"columns":bag.item_grid.columns=8
			"equipped_items":bag.character_state.equipped_items["weapon"]=bag.sorted_references[2]
			"equipped_ammo":bag.character_state.equipped_ammo=bag.sorted_references[3]
			"item_locks":bag.character_state.item_locks[bag.sorted_references[4]]=true
			_:bag.character_state[field]+=1
		check(fixture.controller.inventory_select(bag.sorted_references[1]).get("ok",false),field+": live selection still patches")
		check(fixture.controller._inventory_signature==before_signature,field+": structural change is not acknowledged")
		fixture.controller._process_step(0.0)
		check(fixture.view.stages==2,field+": structural change retains full stage")
		if field=="detail_active":
			check(not fixture.controller.inventory_is_open(),"unsupported detail still falls back through real eligibility guard")
		else:
			fixture.controller.inventory_select(bag.sorted_references[2])
			fixture.controller._process_step(0.0)
			check(fixture.view.stages==2,field+": successful full stage establishes new structural baseline")
		check(bag.activations==0,field+": refresh never uses item")
		fixture.host.free()

func _external_and_capture() -> void:
	var fixture: Dictionary=_fixture()
	var bag: FakeBag=fixture.bag
	bag.selected_item=bag.sorted_references[1]
	fixture.hud.pointer_transfer.pointer=4
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==1,"external selection waits during captured gesture")
	fixture.hud.pointer_transfer.pointer=-2
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==2,"external selection still triggers normal full stage")
	fixture.hud.pointer_transfer.pointer=4
	fixture.controller.inventory_select(bag.sorted_references[2])
	fixture.controller._process_step(0.0)
	fixture.hud.pointer_transfer.pointer=-2
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==2,"successful native patch during gesture needs no later duplicate stage")
	bag.character_state.gold+=1
	fixture.hud.pointer_transfer.pointer=4
	fixture.controller.inventory_select(bag.sorted_references[3])
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==2,"concurrent structural change still waits during gesture")
	fixture.hud.pointer_transfer.pointer=-2
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==3,"concurrent structural change refreshes after gesture")
	fixture.host.free()

func _rejected_selection() -> void:
	for failure: String in ["slot","owner_dirty","identity"]:
		var fixture: Dictionary=_fixture()
		var bag: FakeBag=fixture.bag
		var counts: Array[int]=[0,0]
		fixture.view.selection_refreshed.connect(func() -> void:counts[0]+=1)
		fixture.view.return_to_current_requested.connect(func(_reason: Dictionary) -> void:counts[1]+=1)
		var before_signature: int=fixture.controller._inventory_signature
		match failure:
			"slot":fixture.view._hits[bag.sorted_references[3]].native_slot_scene.reject=true
			"owner_dirty":bag.on_select=func() -> void:bag.inventory_grid_dirty=true
			"identity":fixture.pack.manifest.files[SLOTS.SLOT_MEMBER].sha256="changed"
		fixture.controller.inventory_select(bag.sorted_references[1])
		check(counts==[0,1] and not fixture.controller.inventory_is_open(),failure+": failed in-place patch falls back without successful acknowledgment")
		check(fixture.controller._inventory_signature==before_signature,failure+": failure does not acknowledge model")
		check(bag.activations==0,failure+": no use on failure")
		fixture.host.free()
	var fixture: Dictionary=_fixture()
	var before_signature: int=fixture.controller._inventory_signature
	check(not fixture.controller.inventory_select("missing@@@physical").get("ok",false),"unowned physical reference remains rejected")
	check(fixture.controller._inventory_signature==before_signature and fixture.view.stages==1,"rejected reference never changes acknowledgment")
	fixture.host.free()

func _icon_refresh() -> void:
	var fixture: Dictionary=_fixture()
	fixture.bag.character_state.gold+=1
	fixture.hud.pointer_transfer.pointer=4
	var pending: Dictionary=fixture.controller.refresh_source_icons()
	check(pending.get("refresh_pending",false) and fixture.view.stages==1,"provider icon invalidation waits for active gesture")
	fixture.controller.inventory_select(fixture.bag.sorted_references[1])
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==1,"native selection does not bypass icon invalidation gesture gate")
	fixture.hud.pointer_transfer.pointer=-2
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==2,"pending icon replacement retains one full refresh and captures its structural baseline")
	fixture.controller.inventory_select(fixture.bag.sorted_references[2])
	fixture.controller._process_step(0.0)
	check(fixture.view.stages==2,"selection after icon full refresh reuses new baseline")
	fixture.host.free()
