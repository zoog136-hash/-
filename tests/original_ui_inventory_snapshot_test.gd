extends SceneTree
## Exercises the real native slot producer with synthetic ownership only.
## No private art, Main scene, save, or elapsed-time threshold is required.
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const VIEW=preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={}

class FakeBag extends Control:
	var offered: Array[Dictionary]=[]
	var legacy_rows: Array=[]
	var sorted_references: Variant=[] as Array[String]
	var inventory_grid_dirty: bool=false
	var selected_item: String=""
	var character_state: Dictionary={"item_locks":{}}
	var equipped: String=""
	var prepare_calls: int=0
	var entry_calls: int=0
	var activations: int=0
	var icons: Array[String]=[]
	var texture: Texture2D=PlaceholderTexture2D.new()
	var mutate_icon_input: bool=false
	var missing_icon: bool=false
	var armed_action: String=""
	func prepare_source_inventory_model() -> void:prepare_calls+=1
	func _inventory_entries() -> Array[Dictionary]:
		entry_calls+=1
		return offered.duplicate(true)
	func _select_item(reference: String) -> void:selected_item=reference
	func _activate_selected() -> void:activations+=1
	func item_action_label(_reference: String) -> String:return armed_action
	func _is_item_equipped(reference: String) -> bool:return reference==equipped
	func image(entry: Dictionary, _context: Dictionary) -> Dictionary:
		icons.append(entry.reference)
		if missing_icon:return {"ok":false,"code":"fixture_original_image_absent"}
		if mutate_icon_input:entry.amount=9999
		return {"ok":true,"texture":texture}

class FakeHud extends Node:
	var lineage_inventory_ui: Control

class FakeSlot extends Node2D:
	var source_member: String="UI/CommonUi/Common_Slot.csb"
	var source_nodes: Dictionary={8328:true,7304:true,SLOTS.ACTION:true}
	var texts: Dictionary={}
	var shown: Dictionary={}
	func set_bound_text(offset: int, text: String) -> Dictionary:
		texts[offset]=text
		return {"ok":true}
	func set_bound_visible(offset: int, visible_value: bool) -> Dictionary:
		shown[offset]=visible_value
		return {"ok":true}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _fixture(count: int) -> Dictionary:
	var bag:=FakeBag.new()
	for index: int in range(count):
		var reference: String="같은 검@@@physical-%d"%index
		bag.offered.append({"name":"같은 검","reference":reference,"amount":index+1})
		bag.sorted_references.push_front(reference)
	var hud:=FakeHud.new()
	hud.lineage_inventory_ui=bag
	hud.add_child(bag)
	var pack:=FakePack.new()
	pack.manifest={"files":{SLOTS.PARENT:{"sha256":SLOTS.PARENT_SHA},SLOTS.SET_MEMBER:{"sha256":SLOTS.SET_SHA},SLOTS.SLOT_MEMBER:{"sha256":SLOTS.SLOT_SHA}}}
	var slots=SLOTS.new()
	check(slots.configure(pack,hud,Callable(bag,"image")).get("ok",false),"synthetic owner configures")
	return {"bag":bag,"hud":hud,"slots":slots}

func _run() -> void:
	for count: int in [64,256]:_staged_rows(count)
	_selection_refresh()
	_filter_and_action_guards()
	_duplicate_guards()
	_legacy_rows()
	_ordered_snapshot_alias_boundary()
	_missing_icon_keeps_name()
	print("ORIGINAL_UI_INVENTORY_SNAPSHOT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _missing_icon_keeps_name() -> void:
	var f: Dictionary=_fixture(1)
	var bag: FakeBag=f.bag
	var slots: RefCounted=f.slots
	bag.offered[0].name="용기의 물약 (각인) · 원본#335"
	bag.missing_icon=true
	var reference: String=bag.offered[0].reference
	var offset: int=SLOTS.VARIANTS.Nd_Slot.slots[0]
	var built: Dictionary=slots.build(56036,{offset:reference})
	var title: String="용기의 물약 (각인)"
	check(built.get("ok",false) and built.missing_icon_titles.get(offset)==title and not built.owner_results.has(offset),"source label fallback uses exact displayed name and does not stage a substitute texture")
	var view = VIEW.new()
	var control := Control.new()
	var authored:=FakeSlot.new()
	view._keep_missing_icon_title(authored,control,title)
	check(slots.refresh_action(authored,reference).ok and authored.shown[SLOTS.ACTION] and authored.texts[SLOTS.ACTION]==title and control.tooltip_text==title and control.get_child_count()==0,"authored slot shows fallback name without intercepting taps")
	bag.armed_action="사용"
	check(slots.refresh_action(authored,reference).ok and authored.texts[SLOTS.ACTION]=="사용","actual action supersedes name while selected")
	bag.armed_action=""
	check(slots.refresh_action(authored,reference).ok and authored.texts[SLOTS.ACTION]==title,"unarmed slot shows name again")
	authored.free();control.free();f.hud.free()

func _staged_rows(count: int) -> void:
	var fixture: Dictionary=_fixture(count)
	var bag: FakeBag=fixture.bag
	var slots: RefCounted=fixture.slots
	var started: int=Time.get_ticks_usec()
	var model: Dictionary=slots.entries()
	check(model.get("ok",false),"owner snapshot "+str(count))
	check(model.current_display_rows[0].reference==bag.sorted_references[0],"owner order retained "+str(count))
	for variant: String in ["Nd_Slot","Nd_Slot_Extension"]:
		var offsets: Array=SLOTS.VARIANTS[variant].slots
		var parent: int=56036 if offsets.size()==4 else 44156
		for first: int in range(0,count,offsets.size()):
			var assignments: Dictionary={}
			for column: int in range(mini(offsets.size(),count-first)):
				assignments[offsets[column]]=model.current_display_rows[first+column].reference
			var built: Dictionary=slots.build(parent,assignments,{},variant,model)
			check(built.get("ok",false),"build physical row "+str(first)+" "+variant)
			if built.get("ok",false):
				for offset: int in assignments:
					var reference: String=assignments[offset]
					var bound: Dictionary=built.bindings[parent].bindings[offset].bindings
					check(bound[SLOTS.AMOUNT].text==str(model.owned_by_reference[reference].amount),"count follows exact physical ID")
	check(bag.entry_calls==1 and bag.prepare_calls==1,"all 4/8-column rows share one owner read "+str(count))
	check(bag.icons.size()==count*2,"one image request per displayed slot in each variant")
	check(bag.selected_item.is_empty() and bag.activations==0,"staging performs no action")
	samples.append({"owned":count,"staged_slots":count*2,"owner_reads":bag.entry_calls,"usec":Time.get_ticks_usec()-started})
	fixture.hud.free()

func _selection_refresh() -> void:
	var fixture: Dictionary=_fixture(64)
	var bag: FakeBag=fixture.bag
	bag.selected_item=bag.sorted_references[7]
	bag.equipped=bag.sorted_references[9]
	bag.character_state.item_locks[bag.sorted_references[11]]=true
	var view=VIEW.new()
	view._slots=fixture.slots
	view._on_selection_changed(bag.selected_item)
	check(bag.entry_calls==0 and bag.prepare_calls==0,"closed presentation selection remains a no-op")
	for reference: String in bag.sorted_references:view._hits[reference]={"native_slot_scene":FakeSlot.new()}
	view._on_selection_changed(bag.selected_item)
	check(bag.entry_calls==1 and bag.prepare_calls==1,"selection patches every slot from one snapshot")
	for reference: String in view._hits:
		var slot: FakeSlot=view._hits[reference].native_slot_scene
		check(slot.shown.get(SLOTS.SELECTED)==(reference==bag.selected_item),"selection stays on exact physical ID")
		check(slot.shown.get(8328)==(reference==bag.equipped),"equipped marker remains independent")
		check(slot.shown.get(7304)==bool(bag.character_state.item_locks.get(reference,false)),"lock marker remains independent")
		slot.free()
	fixture.hud.free()

func _filter_and_action_guards() -> void:
	var fixture: Dictionary=_fixture(4)
	var bag: FakeBag=fixture.bag
	var slots: RefCounted=fixture.slots
	var hidden: String=bag.sorted_references.pop_back()
	var model: Dictionary=slots.entries()
	check(slots._resolve_reference(hidden,model).get("code")=="source_inventory_slots_reference_not_in_current_bag_filter","owned but filtered reference rejected")
	var reference: String=bag.sorted_references[0]
	check(slots.select_reference(reference).get("ok",false) and bag.selected_item==reference,"select emits exact owner reference")
	check(slots.activate_existing_selection(reference).get("ok",false) and bag.activations==1,"activation retains existing selected action")
	bag.sorted_references.erase(reference)
	check(not slots.activate_existing_selection(reference).get("ok",false) and bag.activations==1,"action rereads live filter after presentation snapshot")
	check(not slots.select_reference(reference).get("ok",false) and bag.selected_item==reference,"stale hit cannot change selection")
	check(bag.entry_calls==5,"each explicit action rechecks live ownership")
	bag.inventory_grid_dirty=true
	check(slots.entries().get("code")=="source_inventory_slots_current_owner_model_dirty","dirty owner still rejected")
	fixture.hud.free()

func _duplicate_guards() -> void:
	var fixture: Dictionary=_fixture(4)
	var bag: FakeBag=fixture.bag
	var slots: RefCounted=fixture.slots
	bag.offered.append(bag.offered[0].duplicate(true))
	check(slots.entries().get("code")=="source_inventory_slots_current_order_reference_not_unique","duplicate physical reference still rejected")
	bag.offered.pop_back()
	bag.sorted_references.append("같은 검@@@missing")
	check(slots.entries().get("code")=="source_inventory_slots_current_order_reference_not_unique","missing ordered reference still rejected")
	bag.sorted_references.pop_back()
	bag.sorted_references.append(bag.sorted_references[0])
	var model: Dictionary=slots.entries()
	check(slots._resolve_reference(bag.sorted_references[0],model).get("code")=="source_inventory_slots_reference_not_in_current_bag_filter","duplicate display reference still rejected")
	fixture.hud.free()

func _legacy_rows() -> void:
	var fixture: Dictionary=_fixture(3)
	var bag: FakeBag=fixture.bag
	bag.sorted_references=null
	bag.legacy_rows=[bag.offered[2].duplicate(true),bag.offered[0].duplicate(true)]
	bag.legacy_rows[0]["record"]={"native_identity":"preserved"}
	var model: Dictionary=fixture.slots.entries()
	check(model.current_display_rows.size()==2 and model.current_display_rows[0].record.native_identity=="preserved","legacy displayed record and order retained")
	check(fixture.slots._resolve_reference(bag.offered[1].reference,model).get("code")=="source_inventory_slots_reference_not_in_current_bag_filter","legacy filter retained")
	model.owned_entries[0].amount=999
	check(bag.offered[0].amount==1,"snapshot cannot mutate owner rows")
	fixture.hud.free()


func _ordered_snapshot_alias_boundary() -> void:
	var fixture: Dictionary=_fixture(8)
	var bag: FakeBag=fixture.bag
	var slots: RefCounted=fixture.slots
	var model: Dictionary=slots.entries()
	var row: Dictionary=model.current_display_rows[0]
	var reference: String=row.reference
	check(is_same(row,model.owned_by_reference[reference]),"ordered and owned lookup borrow one detached snapshot row")
	check(not is_same(row,bag.offered[-1]),"ordered snapshot detached from original bag")
	bag.mutate_icon_input=true
	var slot: Dictionary=slots.build(56036,{5464:reference},{},"Nd_Slot",model)
	check(slot.ok and row.amount==8 and bag.offered[-1].amount==8,
		"external icon callback cannot mutate a selected snapshot or live inventory")
	fixture.hud.free()
