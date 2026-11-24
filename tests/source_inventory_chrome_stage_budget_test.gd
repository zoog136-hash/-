extends SceneTree
## Exercises chrome's real binding producer; a serialized synthetic scene
## stands in for the private CSB tree. No generated/redistributed visual art.
const CHROME := preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const VIEW := preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
const SLOTS := preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const HEADER := preload("res://tests/source_inventory_header_refresh_test.gd")
const QA := preload("res://tests/qa_class_selection.gd")
const KEYPAD := "UI/FloatingUi/Inventory_Popup_Keypad.csb"
var checks: int=0
var failures: Array[String]=[]
var legacy: bool=false

class Pack extends RefCounted:
	var manifest: Dictionary
	var scene_bytes: PackedByteArray=PackedByteArray()
	var layout_bytes: PackedByteArray=PackedByteArray()
	var scene_reads: int=0
	var layout_reads: int=0
	var manifest_sha256: String=""
	func scene(member: String) -> Dictionary:
		if member!=CHROME.MEMBER or scene_bytes.is_empty():return {}
		scene_reads+=1
		return bytes_to_var(scene_bytes)
	func layout_source(member: String) -> Dictionary:
		if member!=CHROME.MEMBER:return {}
		layout_reads+=1
		return bytes_to_var(layout_bytes) if not layout_bytes.is_empty() else {}

class Bag extends HEADER.FakeBag:
	func _toggle_expanded() -> void:pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_INVENTORY_CHROME_STAGE_FAIL ",label)

static func node(offset: int, children: Array=[], padded: bool=false) -> Dictionary:
	var value: Dictionary={"_offset":offset,"children":children}
	if padded:value["options"]={"comment":"fixture","offsets":range(20),"nested":{"fixture":range(12)}}
	return value

static func original_tree(filler: int, controls: bool=true) -> Dictionary:
	var children: Array=[node(CHROME.CLOSE,[node(146005)]),node(CHROME.GOLD_TEXT),node(13052),node(CHROME.CAPACITY_TEXT)]
	for group: Array in CHROME.TABS.values():
		for offset: int in group:children.append(node(offset))
	for branch: Dictionary in CHROME.FRAMES.values():
		children.append(node(branch.parent))
		for offset: int in branch.offsets:children.append(node(offset))
	for i: int in range(filler):
		children.append(node(220000+i,[node(440000+i,[],true)],true))
	if controls:
		var extension: Dictionary=node(CHROME.EXTENSION_BUTTON)
		extension["_offset"]=float(CHROME.EXTENSION_BUTTON) # numeric source JSON
		children.append(extension)
		children.append(node(CHROME.SEARCH_BUTTON,[node(46132)]))
	return {"nodeTree":{"_offset":0,"options":{"fixture":"source root"},"children":children}}

func fixture(count: int,filler: int) -> Dictionary:
	var hud := HEADER.FakeHud.new()
	var bag := Bag.new()
	hud.lineage_inventory_ui=bag
	hud.add_child(bag)
	bag.capacity_label=Label.new()
	bag.capacity_label.text="%d / 1000"%count
	bag.add_child(bag.capacity_label)
	for i: int in range(count):
		var name: String="fixture:%d"%i
		bag.inventory[name]=i+1
		bag.legacy_rows.append({"name":name,"amount":i+1,"reference":name,"record":{"nested":range(16)}})
	var pack := Pack.new()
	pack.manifest={"files":{SLOTS.PARENT:{"sha256":SLOTS.PARENT_SHA},SLOTS.SET_MEMBER:{"sha256":SLOTS.SET_SHA},SLOTS.SLOT_MEMBER:{"sha256":SLOTS.SLOT_SHA}},
		"scenes":{KEYPAD:{}}}
	pack.scene_bytes=var_to_bytes(original_tree(filler))
	var chrome := CHROME.new()
	check(chrome.configure(pack,hud).ok,"existing fixture bag configures")
	return {"bag":bag,"hud":hud,"pack":pack,"chrome":chrome}

func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	legacy="--legacy-mode" in args
	var f: Dictionary=fixture(32,12)
	var chrome: RefCounted=f.chrome
	var pack: Pack=f.pack
	var bag: Bag=f.bag
	var old_like: Dictionary=chrome.build({},true)
	check(old_like.ok and old_like.model.inventory==bag.inventory and old_like.model.rows==bag.legacy_rows,"public build retains detached full owner snapshot")
	var no_rows: Dictionary={}
	if not legacy:
		pack.scene_reads=0
		no_rows=chrome.call("build",{},true,false)
		check(pack.scene_reads==1,"active scene decoded exactly once when it also owns layout")
		var expected: Dictionary=old_like.model.duplicate(true)
		expected.erase("inventory");expected.erase("rows")
		check(no_rows.model==expected,"native header-only projection still uses exact owner values")
		check(no_rows.source_node_offsets==old_like.source_node_offsets and no_rows.bindings==old_like.bindings and no_rows.original_root_options==old_like.original_root_options,"both paths have exact authored offsets, visibility, action bindings and root options")
		check(no_rows.bindings.has(CHROME.EXTENSION_BUTTON) and no_rows.bindings.has(CHROME.SEARCH_BUTTON),"permitted expansion and search controls retained")
		var scene := HEADER.HeaderScene.new()
		scene.build_header(expected)
		var refreshed: Dictionary=chrome.call("refresh",scene,false)
		check(refreshed.ok and refreshed.model==expected and scene.values()[CHROME.CAPACITY_TEXT]=="32 / 1000","pose rebind updates same header texts without row copy")
		scene.free()
	old_like.model.rows[0].record.nested[0]=999
	check(bag.legacy_rows[0].record.nested[0]==0,"public snapshot cannot mutate owner rows")
	# Exact active scope is authoritative even when separate layout contains
	# extra controls: otherwise a native tap can escape the permitted scene.
	pack.layout_bytes=pack.scene_bytes
	pack.scene_bytes=var_to_bytes(original_tree(8,false))
	pack.scene_reads=0
	var split: Dictionary=chrome.build({},true)
	check(split.ok and not split.bindings.has(CHROME.EXTENSION_BUTTON) and not split.bindings.has(CHROME.SEARCH_BUTTON) and pack.scene_reads==1,"separate layout does not authorize absent active controls")
	var duplicate: Dictionary=original_tree(0,false)
	duplicate.nodeTree.children.append(node(CHROME.CLOSE))
	pack.layout_bytes=var_to_bytes(duplicate)
	check(chrome.build({},false).get("code")=="source_main_inventory_core_node_not_unique","duplicate required offset fails closed")
	pack.layout_bytes=PackedByteArray()
	pack.scene_bytes=var_to_bytes({"other":{}})
	check(chrome.build({},false).get("code")=="source_main_inventory_original_layout_missing","invalid layout fails closed")
	pack.manifest.files[CHROME.MEMBER].sha256="not-pinned"
	check(chrome.build({},false).get("code")=="source_main_inventory_identity_mismatch","missing matching pin fails closed")
	f.hud.free()
	var evidence: Dictionary={}
	if "--benchmark" in args:evidence=measure()
	if "--main" in args:await main_stage()
	print("SOURCE_INVENTORY_CHROME_STAGE_BUDGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"sample":evidence}))
	quit(0 if failures.is_empty() else 1)

func measure() -> Dictionary:
	return {"moderate":measure_size(450,180),"stress":measure_size(450,1200)}

func measure_size(rows: int,filler: int) -> Dictionary:
	var f: Dictionary=fixture(rows,filler)
	var chrome: RefCounted=f.chrome
	var pack: Pack=f.pack
	var samples: Array[float]=[]
	pack.scene_reads=0
	var signature: String=""
	for _i: int in range(13):
		var started: int=Time.get_ticks_usec()
		var made: Dictionary=chrome.build({},true) if legacy else chrome.call("build",{},true,false)
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
		check(made.ok,"benchmark produces expected chrome")
		if _i==0:
			var stable: Dictionary={}
			for offset: int in made.bindings:
				var binding: Dictionary=made.bindings[offset].duplicate(false)
				binding.erase("activate")
				stable[offset]=binding
			signature=JSON.stringify([made.source_node_offsets,stable,made.original_root_options]).sha256_text()
	samples.sort()
	var reads: int=pack.scene_reads
	f.hud.free()
	return {"median_ms":samples[6],"samples_ms":samples,"reads":reads,"binding_signature":signature}

func main_stage() -> void:
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main reaches entered HUD")
	var hud: Node=world.hud
	var bag: Control=hud.lineage_inventory_ui
	var count: int=bag.inventory_list_rebuilds
	var view := VIEW.new()
	var pack := Pack.new()
	pack.manifest={"files":{SLOTS.PARENT:{"sha256":SLOTS.PARENT_SHA},SLOTS.SET_MEMBER:{"sha256":SLOTS.SET_SHA},SLOTS.SLOT_MEMBER:{"sha256":SLOTS.SLOT_SHA}}}
	pack.scene_bytes=var_to_bytes(original_tree(18,false))
	check(view.configure(pack,hud).ok,"actual native view configures with Main's existing owner")
	var stage: Dictionary=view.open(hud)
	# Only chrome is provided; missing original parent must be rejected rather
	# than manufacturing a source UI/hit area. Stage still runs from Main.
	check(not stage.ok and not view.is_open() and pack.scene_reads==1,"Main's real stage uses one chrome read and refuses the missing parent")
	check(bag.inventory_list_rebuilds in [count,count+1] and not bag.inventory_panel.is_visible_in_tree(),"Main owner semantics and fallback visibility unchanged")
	world.queue_free()
	await process_frame
