extends SceneTree
## The original card grid (Change_Card_Set placement in a Change_WinTotal
## page) is a virtual list: every card keeps its place in the scroll range,
## only the rows in view (plus CARD_GRID_MARGIN) are built, scrolling builds
## newly shown rows and frees the rows that left, and each built card is
## decorated (its picture) once. The card fusion window lists every eligible
## duplicate identity (no 150 cap), highest grade first, stable.
## Add -- --pack=<original UI directory> to exercise the native material
## checkboxes, the registration prompt and row geometry from the pack.
##   godot --headless --path <repo> --script res://tests/original_ui_card_grid_virtual_test.gd
const PAGE=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const FUSION=preload("res://scripts/ui/original_ui/source_main_card_fusion_window.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{},"externally_bound_texture_nodes":{}}
	func scene(_member: String) -> Dictionary:
		var slot: Callable=func(offset: int, x: float) -> Dictionary:return {"_offset":offset,"classname":"ProjectNode","options":{"nodeOptions":{"position":[x,75]}},"children":[]}
		return {"nodeTree":{"_offset":0,"children":[{"_offset":120,"classname":"Panel","options":{"widgetOptions":{"size":[360,150]}},"children":[slot.call(724,60.0),slot.call(444,180.0),slot.call(176,300.0)]}]}}

class Grid extends "res://scripts/ui/original_ui/source_main_change_page.gd":
	var content: Node2D
	var builds: int=0
	func _list(_root: Node2D, _out: Dictionary, _suffix: String) -> Dictionary:
		return {"ok":true,"content":content,"size":Vector2(360,450),"key":"/ListView"}
	func _scene_of(_member: String, spec: Dictionary, out: Dictionary, _list_key: String="") -> Dictionary:
		builds+=1
		var scene:=Node2D.new()
		scene.set_meta("card",int(spec.get("index",-1)))
		out["/Nd_Character/CardSample"]={"chain":[],"offset":1,"kind":"Sprite","member":""}
		return {"ok":true,"scene":scene}

class FakeHud extends Node:
	var catalog_data: Dictionary={}
	var card_collection_state: Dictionary={}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CARD_GRID_VIRTUAL_FAIL: "+label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_virtual_grid()
	_fusion_list()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):await _original_setup(arg.trim_prefix("--pack="))
	print("ORIGINAL_UI_CARD_GRID_VIRTUAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _built_indices(content: Node2D) -> Array:
	var shown: Array=[]
	for child: Node in content.get_children():
		if not child.is_queued_for_deletion():shown.append(int(child.get_meta("card")))
	shown.sort()
	return shown

func _virtual_grid() -> void:
	var grid:=Grid.new()
	grid._pack=FakePack.new()
	grid.content=Node2D.new()
	root.add_child(grid.content)
	var cards: Array=[]
	for index: int in range(600):cards.append({"member":"UI/Change/Change_Card_A_Rare.csb","spec":{"index":index},"record":{"id":index}})
	var decorated: Array=[]
	var decorate: Callable=func(_scene: Node2D,_out: Dictionary,card: Dictionary) -> bool:
		decorated.append(int(card.record.id))
		return true
	var filled: Dictionary=grid._fill_card_grid(null,{},"Nd_CardList/ListView",cards,decorate)
	var pitch: float=150.0+PAGE.CARD_SET_MARGIN
	var view_rows: int=ceili(450.0/pitch)+1
	check(filled.get("ok",false) and int(filled.cards)==600,"the grid keeps every card")
	check(int(filled.built)<=(view_rows+PAGE.CARD_GRID_MARGIN)*3 and int(filled.built)>=9,"only the rows in view are built at the top (%d)" % int(filled.built))
	check(grid.builds==int(filled.built) and decorated.size()==int(filled.built) and int(filled.pictures)==decorated.size(),"each built card is decorated once")
	var rows: int=ceili(600.0/3.0)
	var state: Dictionary=grid._scrolls["/ListView"]
	check(is_equal_approx(float(state.min),minf(0.0,450.0-(float(rows)*pitch-PAGE.CARD_SET_MARGIN))),"the scroll range covers every card row")
	# Position of a built card is the authored three-slot placement.
	var first: Node2D=filled.scenes[0]
	check(first.position==Vector2(60.0,-(450.0-150.0+75.0)),"the first card sits in the Change_Card_Set slot")
	grid._scroll_to("/ListView",-pitch*100.0)
	var shown: Array=_built_indices(grid.content)
	var range_rows: Vector2i=grid.card_grid_rows("/ListView")
	check(range_rows.x<=100 and range_rows.y>=100+2 and not shown.is_empty() and int(shown[0])==range_rows.x*3,"scrolling builds the rows that came into view")
	check(not shown.has(0) and shown.size()<=(view_rows+2*PAGE.CARD_GRID_MARGIN)*3,"rows that left the view are freed")
	var placed: Node2D=null
	for child: Node in grid.content.get_children():
		if not child.is_queued_for_deletion() and int(child.get_meta("card"))==301:placed=child
	check(placed!=null and placed.position==Vector2(180.0,-(450.0-100.0*pitch-150.0+75.0)),"a scrolled-in card keeps its own grid place")
	var before: int=grid.builds
	grid._scroll_to("/ListView",-pitch*100.0)
	check(grid.builds==before,"the same scroll builds nothing again")
	grid._scroll_to("/ListView",-1e9)
	shown=_built_indices(grid.content)
	check(shown.has(599) and grid._scrolls["/ListView"].value==state.min,"the last card is reachable at the end of the range")
	var small: Dictionary=grid._fill_card_grid(null,{},"Nd_CardMix/Nd_Card/ListView",cards.slice(0,4),Callable())
	check(int(small.built)==4,"a short grid builds all of its cards")
	grid.content.free()

func _fusion_list() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var records: Array=[]
	var grades: Array[String]=["일반","영웅","고급","희귀"]
	for index: int in range(400):records.append({"name":"카드 %d" % index,"grade":grades[index%4],"sourceId":"m523:1:%d" % (1000+index)})
	var owned: Dictionary={}
	var spare: Dictionary={}
	for record: Dictionary in records:
		owned[CARDS.card_id(record)]=true
		spare[CARDS.card_id(record)]=1
	var eligible: Dictionary=spare.duplicate()
	var excluded: Array[Dictionary]=[
		{"sourceId":"single","grade":"희귀"},
		{"sourceId":"pending","grade":"희귀","source_draw_pool_pending":true},
		{"sourceId":"restricted","grade":"희귀","source_merge_out_disabled":true},
		{"sourceId":"unique","grade":"유일"},
		{"sourceId":"unowned","grade":"희귀"}]
	for record: Dictionary in excluded:
		var id: String=CARDS.card_id(record)
		records.append(record)
		if record.sourceId!="unowned":owned[id]=true
		if record.sourceId!="single":spare[id]=1
	hud.catalog_data={"변신":records}
	hud.card_collection_state={"owned":{"변신":owned},"spare":{"변신":spare}}
	var window=FUSION.new()
	window._hud=weakref(hud)
	window.category="변신"
	window._collect()
	var listed: Dictionary={}
	for record: Dictionary in window._owned_records:listed[CARDS.card_id(record)]=1
	check(window._owned_records.size()==400 and listed==eligible,"all 400 eligible identities appear, excluding singles and unavailable duplicates (no 150 cap)")
	var ordered: bool=true
	for index: int in range(1,window._owned_records.size()):
		var a: Dictionary=window._owned_records[index-1]
		var b: Dictionary=window._owned_records[index]
		var ra: int=CARDS.GRADES.find(str(a.grade))
		var rb: int=CARDS.GRADES.find(str(b.grade))
		if ra<rb or (ra==rb and records.find(a)>records.find(b)):ordered=false
	check(ordered,"highest grade first, ties keep the catalog order")
	window.filter_grade="희귀"
	window._collect()
	check(window._owned_records.size()==100 and window._owned_records.all(func(r: Dictionary) -> bool:return r.grade=="희귀" and eligible.has(CARDS.card_id(r))),"the grade filter runs over the whole eligible list")
	hud.free()

func _original_setup(directory: String) -> void:
	var pack:=preload("res://scripts/ui/original_ui/source_pack.gd").new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("receipt.json")))
	if not pack.open(directory,str(receipt.manifest_sha256)).get("ok",false):
		check(false,"open the original UI pack")
		return
	var host:=Node2D.new()
	host.position=Vector2(0,675)
	var hud:=FakeHud.new()
	root.add_child(host)
	host.add_child(hud)
	var records: Array=[]
	var owned: Dictionary={}
	var spares: Dictionary={}
	for i: int in 9:
		var row: Dictionary={"sourceId":"material-%d" % i,"name":"재료 %d" % i,"grade":"고급" if i<4 else "일반"}
		if i==0:row["source_draw_pool_pending"]=true
		if i==3:row["source_merge_out_disabled"]=true
		records.append(row)
		var id: String=CARDS.card_id(row)
		owned[id]=true
		if i<4:spares[id]=1 if i==1 else 4
		if i in [4,5]:spares[id]=1
	records.append({"sourceId":"upper","name":"결과","grade":"희귀"})
	hud.catalog_data={"변신":records}
	hud.card_collection_state={"owned":{"변신":owned},"spare":{"변신":spares}}
	var saved: Dictionary=hud.card_collection_state.duplicate(true)
	var window:=FUSION.new()
	if not window.configure(pack,hud).get("ok",false) or not window.open(host,"변신").get("handled",false):
		check(false,"original Change_WinTotal normal fusion setup opens")
		host.free()
		return
	var path: String=FUSION.P+"Nd_CardList/ListView"
	var roster: Dictionary=window._list(window._scene,window._out,path)
	var grid: Dictionary=window._scrolls[roster.key].grid
	var pending: Dictionary=window._list(window._scene,window._out,FUSION.P+"Nd_CardMix/Nd_Card/ListView")
	var mix: Dictionary=window._locate(window._scene,window._out,path)
	var original_gap: float=float(PAGE.Scene._node_at_offset(mix.player.source_tree.nodeTree,mix.offset).options.itemMargin)
	var pitch: float=(grid.built[3].scene.position-grid.built[0].scene.position).y
	check(mix.member=="UI/Change/Change_DetailView_Mix.csb" and mix.offset==3256 and roster.size==Vector2(498,475) and pending.size==Vector2(480,270),"catalog and materials mount the original two ordinary-fusion lists")
	check(is_equal_approx(pitch,150.0+original_gap),"roster pitch follows its own authored margin")
	var tip: Dictionary=window._locate(window._scene,window._out,"Nd_Card/Label_Message")
	check(tip.player.source_nodes[tip.offset].is_visible_in_tree() and window.last_result.filled.registered==0 and not window.last_result.filled.can_fuse,"entry waits for registration even when enough duplicates are owned")
	check(window.last_result.filled.cards==4,"only eligible duplicate identities occupy the roster's grid slots")
	var first: Node2D=_roster_check(window,grid,0)
	check(first.current_state=="normal" and not first.selected,"an available original checkbox opens bright and unmarked")
	var router:=PAGE.Router.new()
	var point: Vector2=first._input_area.get_global_transform_with_canvas()*(first._input_area.size*0.5)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=9;event.position=point;event.pressed=down
		var tap: Dictionary=router.route(event,point,[first])
		check(tap.get("handled",false),"original material checkbox handles the finger")
	await process_frame
	check(window._registered==[CARDS.card_id(records[1])] and not window.last_result.filled.can_fuse,"one touch registers only the selected copy")
	window._auto_register()
	grid=window._scrolls[roster.key].grid
	var marked: Array[int]=[]
	for i: int in grid.built:
		if _roster_check(window,grid,i).selected:marked.append(i)
	marked.sort()
	var quantities: Dictionary={}
	for item: Dictionary in window._materials:
		var id: String=CARDS.card_id(item.record)
		quantities[id]=int(quantities.get(id,0))+1
	var plans: Array=[]
	for id: String in quantities:plans.append([id,quantities[id]])
	check(marked==[0,1] and plans==[[CARDS.card_id(records[1]),1],[CARDS.card_id(records[2]),3]] and window.last_result.filled.can_fuse,"only the exact spendable identities in the grade plan are marked")
	var model:=CARDS.new()
	model.configure(hud.catalog_data)
	model.owned["변신"]=owned.duplicate()
	model.spare["변신"]=spares.duplicate()
	model.rng.seed=4
	var outcome: Dictionary=model.fuse("변신","고급",false,window._registered)
	check(outcome.get("ok",false),"the original transaction accepts the shown grade")
	if outcome.get("ok",false):
		var consumed: Array=[]
		for id: String in spares:
			var returned: int=int(id==outcome.result.id and not outcome.result.new)
			var spent: int=int(spares[id])+returned-int(model.spare["변신"].get(id,0))
			if spent>0:consumed.append([id,spent])
		check(consumed==plans,"the preview agrees with the actual fuse debit including a returned duplicate")
	var material_grid: Dictionary=window._scrolls[pending.key].grid
	check(material_grid.built.size()==4 and is_equal_approx((material_grid.built[3].scene.position-material_grid.built[0].scene.position).y,150.0),"registered material list also uses its own original row pitch")
	check(hud.card_collection_state==saved,"registration never writes ownership")
	print("ORIGINAL_FUSION_SETUP_COMPARE ",JSON.stringify({"pitch":pitch,"source_margin":original_gap,"checked":marked,"plan":plans}))
	for i: int in 6:
		var extra: Dictionary={"sourceId":"extra-%d" % i,"name":"추가","grade":"일반"}
		records.append(extra)
		owned[CARDS.card_id(extra)]=true
		spares[CARDS.card_id(extra)]=1
	window.refresh()
	var state: Dictionary=window._scrolls[roster.key]
	first=_roster_check(window,state.grid,1)
	point=first._input_area.get_global_transform_with_canvas()*(first._input_area.size*0.5)
	var touch:=InputEventScreenTouch.new()
	touch.index=7;touch.position=point;touch.pressed=true
	router.route(touch,point,[first])
	var drag:=InputEventScreenDrag.new()
	drag.index=7;drag.relative=Vector2(0,-25);drag.position=point+drag.relative
	router.route(drag,drag.position,[first])
	touch.pressed=false;touch.position=drag.position
	router.route(touch,touch.position,[first])
	check(state.value<0 and window.last_result.filled.registered==4,"drag on a material checkbox scrolls the roster without changing the plan")
	window.close()
	window.open(host,"변신")
	check(window.last_result.filled.registered==0,"closing and reopening resets the unsaved preview")
	window._auto_register()
	check(window.last_result.filled.registered==4 and window.last_result.filled.can_fuse,"Auto still registers the existing eligible grade plan")
	window._select_filter("유일")
	check(window.grade=="유일" and window._materials.is_empty() and not window._can_fuse(),"the non-fusible grade never keeps a previous grade's materials")
	window.close()
	host.queue_free()
	await process_frame

func _roster_check(window: RefCounted, grid: Dictionary, index: int) -> Node2D:
	var cell: Dictionary=grid.built[index]
	var slot: Dictionary=window._locate(cell.scene,cell.out,"Panel_Root/CB_Check")
	return slot.player.source_nodes[slot.offset].get_meta("source_checkbox")
