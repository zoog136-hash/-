extends SceneTree
## The verified pack's scene reader is represented by decoded Variant bytes.
## This fixture measures wiring/binding only, not original art or frame time.
const Named=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Routine=preload("res://scripts/ui/original_ui/source_main_routine_tree.gd")
const Menu=preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const Minimap=preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
const Cards=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const Shop=preload("res://scripts/ui/original_ui/source_main_shop_window.gd")
const SpriteScene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const WINDOW: String="UI/fixture/Window.csb"
const ROW: String="UI/fixture/Row.csb"
var checks: int=0
var failures: Array[String]=[]
var legacy: bool=false

class Pack extends RefCounted:
	var manifest_sha256: String=""
	var manifest: Dictionary={"scenes":{},"files":{}}
	var scenes: Dictionary={}
	var layouts: Dictionary={}
	var counts: Dictionary={}
	func scene(member: String) -> Dictionary:
		counts[member]=int(counts.get(member,0))+1
		return bytes_to_var(scenes[member]) if scenes.has(member) else {}
	func layout_source(member: String) -> Dictionary:
		return bytes_to_var(layouts[member]) if layouts.has(member) else {}

class Bag extends Control:
	var character_state: Dictionary={"current_weight":20,"max_weight":40}
	var weight_readout:=Label.new()
	var capacity_label:=Label.new()
	func _init() -> void:
		add_child(weight_readout);add_child(capacity_label)
	func _refresh_weight() -> void:
		capacity_label.text="50% · 12 / 100"
		weight_readout.text="20 / 40"

class Hud extends Node:
	signal inventory_pressed
	signal menu_pressed
	signal map_pressed
	var lineage_inventory_ui: Control
	var routed: Array[String]=[]
	func _navigate(target: String) -> void:routed.append(target)
	func open_skills() -> void:pass
	func open_shop() -> void:pass
	func open_quests() -> void:pass

class World extends Node:
	var inventory: Dictionary={}

func _initialize() -> void:run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ORIGINAL_UI_STAGE_SCENE_READS_FAIL ",label)

static func row_node(offset: int, kind: String, name: String, children: Array=[], extra: Dictionary={}) -> Dictionary:
	var options: Dictionary={"widgetOptions":{"name":name,"position":[0,0],"size":[100,32],"anchorPoint":[0.5,0.5],"rotationSkew":[0,0],"scale":[1,1],"visible":true,"zOrder":0,"color":[255,255,255,255],"alpha":255,"actionTag":offset,"flipX":false,"flipY":false}}
	options.merge(extra,true)
	return {"_offset":offset,"classname":kind,"options":options,"children":children}

func setup_nested(pack: Pack, projects: int, filler: int) -> void:
	var columns: Array=[]
	for index: int in range(projects):
		columns.append(row_node(100+index,"ProjectNode","Borrow%d"%index,[],{"fileName":ROW.trim_prefix("UI/"),"innerActionSpeed":1.0}))
	var rows: Array=[row_node(15,"Node","Marker")]
	for index: int in range(filler):
		rows.append(row_node(150+index,"Node","Unused%d"%index,[],{"padding":{"nested":range(16)}}))
	pack.scenes[WINDOW]=var_to_bytes({"nodeTree":row_node(1,"Node","Root",columns)})
	pack.scenes[ROW]=var_to_bytes({"nodeTree":row_node(2,"Node","Row",rows)})

func deferred_projects() -> void:
	var pack:=Pack.new()
	setup_nested(pack,2,0)
	var lazy: Dictionary={"role":"project","visible":false,"bindings":{},"defer_until_shown":true}
	var eager: Dictionary={"role":"project","bindings":{}}
	var scene:=SpriteScene.new()
	var configured: Dictionary=scene.configure(pack,WINDOW,false,{100:lazy,101:eager})
	check(configured.ok and pack.counts.get(ROW)==1,"the hidden project creates no child scene on open")
	if not configured.ok:
		scene.free()
		return
	root.add_child(scene)
	var slot: Node2D=scene.source_nodes[100]
	var unbuilt: bool=not scene.project_player([100]).ok
	check(not slot.visible and unbuilt,"the unopened project has no input or player")
	if not unbuilt:
		scene.free()
		return
	var before: int=slot.get_index()
	var home: Node=slot.get_parent()
	var sibling: Node=home.get_child(before+1)
	var row: PackedByteArray=pack.scenes[ROW]
	pack.scenes.erase(ROW)
	check(not scene.set_bound_visible(100,true).ok and scene.source_nodes[100]==slot and not slot.visible,
		"a failed popup leaves the hidden slot and eager sibling intact")
	pack.scenes[ROW]=row
	check(scene.set_bound_visible(100,true).ok,"retry builds the exact child after the source is available")
	var player: Dictionary=scene.project_player([100])
	check(player.ok and scene.source_nodes[100].visible and home.get_child(before)==player.get("player")
		and home.get_child(before+1)==sibling,"mount preserves same-z sibling order")
	var reads: int=pack.counts[ROW]
	check(scene.set_bound_visible(100,false).ok and scene.set_bound_visible(100,true).ok
		and pack.counts[ROW]==reads and scene.project_player([100])==player,"hide and reopen reuse the live popup")
	scene.free()

	# An outer timeline acts on the original child root, so this project must
	# still mount eagerly even if the owner asks to defer it.
	var animated: Dictionary=pack.scene(WINDOW)
	animated.action={"timeLines":[{"actionTag":100,"property":"VisibleForFrame","frames":[]}]}
	pack.scenes[WINDOW]=var_to_bytes(animated)
	scene=SpriteScene.new()
	check(scene.configure(pack,WINDOW,false,{100:lazy,101:eager}).ok and scene.project_player([100]).ok,
		"a parent timeline keeps its original target")
	scene.free()

func menu_nodes(weight: bool) -> Dictionary:
	var nodes: Array=[]
	for offset: int in Menu.CORE_ROOT_OFFSETS+[Menu.QUEST,27336]:
		nodes.append(row_node(offset,"Node","Core%d"%offset))
	if weight:
		nodes.append(row_node(Menu.WEIGHT_TEXT,"Text","Weight"))
		nodes.append(row_node(Menu.WEIGHT_BACKGROUND,"Sprite","Bg"))
	return {"nodeTree":row_node(1,"Node","Root",nodes)}

func hud_contracts(owner: Node, pack: Pack) -> void:
	pack.manifest.files[Menu.MEMBER]={"sha256":Menu.SHA256}
	pack.manifest.files[Minimap.MINIMAP_MEMBER]={"sha256":Minimap.MINIMAP_SHA256}
	pack.manifest.scenes[Minimap.CHANGE_CARD_MEMBER]={}
	pack.scenes[Menu.MEMBER]=var_to_bytes(menu_nodes(true))
	pack.scenes[Minimap.MINIMAP_MEMBER]=var_to_bytes({"nodeTree":row_node(1,"Node","Map",[
		row_node(Minimap.MAP_NAME_TEXT,"Text","Name"),row_node(Minimap.ZONE_TEXT,"Text","Zone"),
		row_node(Minimap.SIDE_GROUP,"Node","Side",[row_node(Minimap.CHANGE_CARD_PROJECT,"ProjectNode","Card")])])})
	var menu:=Menu.new()
	check(menu.configure(pack,owner).ok,"existing HUD top-menu owner admits pinned member")
	var menu_result: Dictionary=menu.build_core()
	check(menu_result.ok and menu_result.source_node_offsets.has(Menu.WEIGHT_TEXT) and menu_result.source_node_offsets.has(Menu.WEIGHT_BACKGROUND),"native top menu preserves both weight offsets and original owner")
	if not legacy:check(pack.counts[Menu.MEMBER]==1,"layout fallback and two weight nodes share one original menu read")
	pack.layouts[Menu.MEMBER]=pack.scenes[Menu.MEMBER]
	pack.scenes[Menu.MEMBER]=var_to_bytes(menu_nodes(false))
	var reduced: Dictionary=menu.build_core()
	check(reduced.ok and not reduced.weight_connected and not reduced.source_node_offsets.has(Menu.WEIGHT_TEXT),"layout alone cannot admit missing active weight text")
	var mini:=Minimap.new()
	check(mini.configure(pack,owner).ok,"existing HUD minimap admits pinned member")
	var both: Dictionary=mini.build_name("지역"+Minimap.EXISTING_SAFE_SUFFIX)
	check(both.ok and both.safe_label_connected and both.change_card_connected and both.bindings.has(Minimap.CHANGE_CARD_PROJECT),"minimap retains exactly the zone and card contract")
	if not legacy:check(pack.counts[Minimap.MINIMAP_MEMBER]==1,"zone + card presence share one active read")
	var before: int=pack.counts[Minimap.MINIMAP_MEMBER]
	var plain: Dictionary=mini.build_name("지역",false,false)
	check(plain.source_node_offsets==[Minimap.MAP_NAME_TEXT] and pack.counts[Minimap.MINIMAP_MEMBER]==before,"name-only request performs no unused minimap read")
	pack.manifest.scenes.erase(Minimap.CHANGE_CARD_MEMBER)
	check(not mini.build_name("지역",true,true).change_card_connected,"filtered-out side project never becomes an active button")

func nested_contracts(pack: Pack, hud: Node) -> void:
	setup_nested(pack,3,5)
	var named:=Named.new(pack)
	var slot_out: Dictionary={}
	var root_bound: Dictionary=named.bind(WINDOW,"",[],{"Borrow1/Marker":{"visible":false}},slot_out)
	check(root_bound.scope==[100,101,102] and root_bound.bindings[101].bindings[15].visible==false and not root_bound.bindings[100].bindings.has(15),"same source row instances keep independent path bindings")
	check(slot_out["/Borrow0/Marker"].chain==[100] and slot_out["/Borrow2/Marker"].chain==[102],"named source uses distinct original project chains")
	if not legacy:check(pack.counts[ROW]==1 and pack.counts[WINDOW]==1,"one read for three nested references to same member")
	setup_nested(pack,2,0)
	var replacement: Dictionary={}
	named.bind(WINDOW,"",[],{},replacement)
	check(not replacement.has("/Borrow2/Marker") and pack.counts[WINDOW]==2,"next operation observes replaced source; no persistent binding cache")
	var routine:=Routine.new(pack,hud)
	pack.counts.clear()
	var out: Dictionary={}
	var bound: Dictionary=routine.bind(WINDOW,"",[],{"Borrow0/Marker":{"visible":false}},out)
	check(bound.bindings[100].bindings[15].visible==false and out["/Borrow1/Marker"].chain==[101],"routine instance identity and suffix semantics are unchanged")
	if not legacy:check(pack.counts[ROW]==1,"routine nested binding reuses one decoded row")
	var mounted: Dictionary=named.scene_of(WINDOW,{}, {})
	check(mounted.get("ok",false),"actual SpriteScene validator/renderer still mounts the independently decoded source scopes: "+str(mounted))
	if mounted.get("ok",false):
		var left: Dictionary=mounted.scene.project_player([100])
		var right: Dictionary=mounted.scene.project_player([101])
		check(left.get("ok",false) and right.get("ok",false) and left.player!=right.player,"separate mounted projects retain their own live nodes")
		mounted.scene.free()

func card_contracts(pack: Pack) -> void:
	var window:=Cards.new()
	window._pack=pack
	pack.counts.clear()
	var controls: Array=[]
	for offset: int in [Cards.COLLECTION_BUTTON,Cards.AWAKEN,Cards.RESET,Cards.ORDER_BUTTON]:
		controls.append(row_node(offset,"Node","Control%d"%offset,[row_node(offset+100000,"Text","Label")]))
	pack.scenes[Cards.DETAIL]=var_to_bytes({"nodeTree":row_node(4,"Node","Detail",controls)})
	pack.scenes[Cards.INFO]=var_to_bytes({"nodeTree":row_node(5,"Node","Info",[])})
	var contract: Dictionary=window._detail_bindings("")
	check(contract.scope.has(Cards.COLLECTION_BUTTON+100000) and contract.bindings[Cards.COLLECTION_BUTTON].activate.is_valid(),"real card detail binder retains original descendant and owner callback")
	if not legacy:check(pack.counts[Cards.DETAIL]==1,"four mandatory details and touch tree read once")

func benchmark(pack: Pack) -> Dictionary:
	setup_nested(pack,12,140)
	var named:=Named.new(pack)
	pack.counts.clear()
	var samples: Array[float]=[]
	var digest: String=""
	for index: int in range(9):
		var out: Dictionary={}
		var start: int=Time.get_ticks_usec()
		var bound: Dictionary=named.bind(WINDOW,"",[],{},out)
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		if index==0:digest=JSON.stringify([out,bound.scope]).sha256_text()
	samples.sort()
	return {"median_ms":samples[4],"samples_ms":samples,"signature":digest,"row_reads":pack.counts[ROW],"root_reads":pack.counts[WINDOW]}

func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	legacy="--legacy-mode" in args
	var pack:=Pack.new()
	var hud:=Hud.new()
	root.add_child(hud)
	hud.lineage_inventory_ui=Bag.new()
	hud.add_child(hud.lineage_inventory_ui)
	hud_contracts(hud,pack)
	nested_contracts(pack,hud)
	card_contracts(pack)
	deferred_projects()
	var evidence: Dictionary=benchmark(pack) if "--benchmark" in args else {}
	hud.free()
	if "--main" in args:
		var world: Node=load("res://Main.tscn").instantiate()
		root.add_child(world)
		world.set_process(false)
		world.player.set_physics_process(false)
		world.save_timer=-100000.0
		check(QA.enter_game(world),"real Main loads and enters the existing HUD")
		hud_contracts(world.hud,Pack.new())
		world.queue_free()
		await process_frame
	print("ORIGINAL_UI_STAGE_SCENE_READS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"sample":evidence}))
	quit(0 if failures.is_empty() else 1)
