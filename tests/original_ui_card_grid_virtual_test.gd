extends SceneTree
## The original card grid (Change_Card_Set placement in a Change_WinTotal
## page) is a virtual list: every card keeps its place in the scroll range,
## only the rows in view (plus CARD_GRID_MARGIN) are built, scrolling builds
## newly shown rows and frees the rows that left, and each built card is
## decorated (its picture) once. The card fusion window lists every owned
## card of the filter (no 150 cap), highest grade first, stable.
## Synthetic only (no original files).
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
	hud.catalog_data={"변신":records}
	var spare: Dictionary={}
	for record: Dictionary in records:spare[CARDS.card_id(record)]=1
	hud.card_collection_state={"owned":{"변신":{}},"spare":{"변신":spare}}
	var window=FUSION.new()
	window._hud=weakref(hud)
	window.category="변신"
	window._collect()
	check(window._owned_records.size()==400,"every owned card is listed (no 150 cap)")
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
	check(window._owned_records.size()==100 and window._owned_records.all(func(r: Dictionary) -> bool:return r.grade=="희귀"),"the grade filter runs over the whole list")
	hud.free()
