extends SceneTree
## The real view refresh and count adapter over a bounded synthetic HUD.
## Source CSB/pixels/GPU and authoritative use/save transactions are excluded.
const VIEW=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
const BINDINGS=preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
var checks: int=0
var failures: Array[String]=[]

class World extends Node:
	var pages: Array=[0,0]
	var quickslots: Array=[]
	var ammo: int=7
	var page_reads: int=0
	var ammo_reads: int=0
	var inventory: Dictionary={"synthetic-ammo":7}
	func _quickslot_pages() -> Array:page_reads+=1;return pages.duplicate()
	func _quickslot_ammo_source(entry: Dictionary) -> Dictionary:
		ammo_reads+=1
		return {"ammo_count":ammo,"can_use_without_ammo":false} if entry.get("kind")=="skill" else {}

class Hud extends Node:
	var quickslot_entries: Array=[]
	var quickslot_captions: Array=[]
	var quickslot_cooldown_labels: Array=[]
	var dispatched: Array=[]
	func quickslot_index(visible: int) -> int:
		var group: int=visible/5
		return group*25+get_parent().pages[group]*5+visible%5
	func _emit_quickslot(visible: int) -> void:dispatched.append(quickslot_index(visible))

class Pack extends RefCounted:
	var manifest: Dictionary={"files":{}}
	func scene(_member: String) -> Dictionary:return {}

class CountingBindings extends "res://scripts/ui/original_ui/source_main_quickslot_bindings.gd":
	var reads: int=0
	func snapshot() -> Dictionary:reads+=1;return super.snapshot()

class Slot extends Node2D:
	var source_member: String=BINDINGS.SLOT_MEMBER
	var texts: Dictionary={}
	var shown: Dictionary={}
	func set_bound_text(offset: int, value: String) -> Dictionary:texts[offset]=value;return {"ok":true}
	func set_bound_visible(offset: int, value: bool) -> Dictionary:shown[offset]=value;return {"ok":true}

class StagingView extends "res://scripts/ui/original_ui/source_main_quickslot_view.gd":
	var stages: int=0
	var staged_model: Dictionary={}
	func _stage(_host: Node, current_model: Dictionary={}) -> Dictionary:
		stages+=1
		staged_model=current_model if not current_model.is_empty() else _bindings.snapshot()
		return {"ok":true,"staged":true}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _fixture() -> Dictionary:
	var world:=World.new();var hud:=Hud.new();world.add_child(hud);root.add_child(world)
	for index: int in 50:world.quickslots.append({"kind":"skill","id":"synthetic-"+str(index),"auto":false})
	hud.quickslot_entries=world.quickslots.duplicate(true)
	for visible: int in 10:
		var caption:=Label.new();var cooldown:=Label.new();cooldown.text="0.5"
		hud.add_child(caption);hud.add_child(cooldown)
		hud.quickslot_captions.append(caption);hud.quickslot_cooldown_labels.append(cooldown)
	var pack:=Pack.new()
	pack.manifest.files={BINDINGS.SET_MEMBER:{"sha256":BINDINGS.SET_SHA256},BINDINGS.SLOT_MEMBER:{"sha256":BINDINGS.SLOT_SHA256}}
	var bindings:=CountingBindings.new()
	check(bindings.configure(pack,hud,Callable()).get("ok",false),"actual bindings accept the existing identity contract")
	var view=VIEW.new();view._pack=pack;view._bindings=bindings;view._parent=weakref(root);view._hud=weakref(hud)
	var shell:=Node2D.new();root.add_child(shell);view._scene=shell
	var model: Dictionary=bindings.snapshot();view._identity=VIEW._model_identity(model)
	for visible: int in 10:
		var slot:=Slot.new();shell.add_child(slot)
		view._hits[visible]={"native_slot_scene":slot}
	bindings.reads=0;world.page_reads=0;world.ammo_reads=0
	return {"world":world,"hud":hud,"bindings":bindings,"view":view,"shell":shell,"pack":pack,"model":model}

func _release(f: Dictionary) -> void:
	f.view.close()
	if is_instance_valid(f.shell):f.shell.free()
	f.world.free()

func _refresh_snapshot() -> void:
	var f: Dictionary=_fixture()
	var state: PackedByteArray=var_to_bytes([f.world.inventory,f.world.quickslots,f.hud.quickslot_entries])
	check(f.view.refresh().get("ok",false),"actual view refresh succeeds")
	check(f.bindings.reads==1 and f.world.page_reads==1 and f.world.ammo_reads==10,"one view refresh reads one ten-slot snapshot")
	for visible: int in 10:
		var slot: Slot=f.view._hits[visible].native_slot_scene
		check(slot.texts=={BINDINGS.AMOUNT:"7",BINDINGS.COOLDOWN:"0.5"} and slot.shown[BINDINGS.AMOUNT] and slot.shown[BINDINGS.COOLDOWN] and not slot.shown[BINDINGS.AUTO_ICON],"original count/cooldown/AUTO projection is preserved for slot "+str(visible))
	check(var_to_bytes(f.view._rows)==var_to_bytes(f.model.rows),"every displayed detached row retains exact values and order")
	f.world.ammo=0
	f.hud.quickslot_cooldown_labels[3].text=""
	check(f.view.refresh().get("ok",false) and f.bindings.reads==2,"next refresh takes a fresh snapshot rather than retaining the old one")
	check(f.view._hits[0].native_slot_scene.texts[BINDINGS.AMOUNT]=="0" and f.view._hits[0].native_slot_scene.shown[BINDINGS.AMOUNT],"zero original ammo remains visible")
	check(f.view._hits[3].native_slot_scene.texts[BINDINGS.COOLDOWN]=="" and not f.view._hits[3].native_slot_scene.shown[BINDINGS.COOLDOWN],"live cooldown completion updates its existing source node")
	f.view._rows[0].entry.id="caller-only"
	check(f.hud.quickslot_entries[0].id=="synthetic-0","retained display rows do not alias authoritative entries")
	check(var_to_bytes([f.world.inventory,f.world.quickslots,f.hud.quickslot_entries])==state and f.hud.dispatched.is_empty(),"read-only refresh does not use an item, modify inventory or change bindings")
	_release(f)

func _standalone_and_actions() -> void:
	var f: Dictionary=_fixture()
	var row: Dictionary=f.model.rows[0]
	var slot: Slot=f.view._hits[0].native_slot_scene
	f.world.ammo=2
	var updated: Dictionary=f.bindings.refresh_slot(slot,row)
	check(updated.get("ok",false) and f.bindings.reads==1 and slot.texts[BINDINGS.AMOUNT]=="2","two-argument standalone slot refresh still reads current host values")
	var presented: Dictionary=BINDINGS._presented_identity(row)
	f.hud.quickslot_entries[0].auto=true
	check(f.bindings.activate_presented(0,presented).get("dispatched",false) and f.hud.dispatched==[0],"AUTO changes preserve existing action identity and fresh dispatch")
	f.hud.quickslot_entries[0]={"kind":"item","id":"replacement"}
	check(f.bindings.activate_presented(0,presented).get("code")=="source_quickslot_presented_entry_changed" and f.hud.dispatched==[0],"a stale presented entry never dispatches its replacement")
	check(f.bindings.refresh_slot(slot,row).get("code")=="source_quickslot_row_identity_changed","standalone refresh still rejects a stale row")
	f.hud.quickslot_entries=f.world.quickslots.duplicate(true)
	f.world.pages[0]=1
	check(f.bindings.activate_presented(0,presented).get("code")=="source_quickslot_presented_entry_changed" and f.hud.dispatched==[0],"a page change is checked fresh before dispatch")
	var changed: Dictionary=f.bindings.snapshot()
	check(changed.rows[0].absolute_index==5 and changed.rows[5].absolute_index==25,"existing independent group page/index policy remains authoritative")
	_release(f)

func _staging_snapshot() -> void:
	var f: Dictionary=_fixture()
	var owner_reads: Array=[]
	var texture:=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	f.bindings._image_provider=func(row: Dictionary, context: Dictionary) -> Dictionary:
		owner_reads.append([row.visible_index,row.absolute_index,context.group,context.slot_project_offset])
		return {"ok":true,"texture":texture}
	var first: Dictionary=f.bindings.build_group(0,f.model)
	var second: Dictionary=f.bindings.build_group(1,f.model)
	check(first.get("ok",false) and second.get("ok",false) and f.bindings.reads==0,"both groups consume the same detached stage model")
	check(owner_reads.size()==10 and first.rows.size()==5 and second.rows.size()==5,"all ten original slots and owner lookups remain present")
	check(first.slot_project_offsets==BINDINGS.SLOT_PROJECT_OFFSETS and first.rows[0].entry==f.model.rows[0].entry and second.rows[0].entry==f.model.rows[5].entry,"authored project offsets and both group record identities are unchanged")
	f.bindings.build_group(0)
	check(f.bindings.reads==1,"standalone group construction still snapshots current state")
	var staged:=StagingView.new();staged._bindings=f.bindings;staged._parent=weakref(root)
	staged._scene=f.shell;staged._identity=f.view._identity.duplicate(true)
	f.hud.quickslot_entries[0].id="new-current-entry"
	f.bindings.reads=0
	check(staged.refresh().get("staged",false) and staged.stages==1 and f.bindings.reads==1,"an identity-changing refresh forwards its one fresh snapshot to staging")
	check(staged.staged_model.rows[0].entry.id=="new-current-entry","staging receives the actual current entry, not the previous identity")
	# Production staging declines a missing original root after preparing both
	# groups. Its failure keeps the legacy presentation available as before.
	f.bindings.reads=0
	var failed: Dictionary=f.view._stage(root)
	check(not failed.get("ok",true) and not failed.get("handled",true) and f.bindings.reads==1,"production staging reads once and still declines unavailable original scenes")
	check(not f.view.is_open(),"failed original staging closes its partial native view")
	staged._scene=null
	_release(f)

func _run() -> void:
	_refresh_snapshot()
	_standalone_and_actions()
	_staging_snapshot()
	print("ORIGINAL_UI_QUICKSLOT_SNAPSHOT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"private_pack_used":false}))
	quit(0 if failures.is_empty() else 1)
