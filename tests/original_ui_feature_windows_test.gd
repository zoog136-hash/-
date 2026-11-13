extends SceneTree
## The original 523 feature windows built on source_main_window_kit.gd
## (card collection, card fusion, 작위, 토템, 몬스터 도감, 하프 엘릭서).
## Synthetic only (no original files): every registered window names its
## original members and fails closed without them; the kit binds a synthetic
## original tree (texts static, buttons and touch nodes connected, lists
## declared, excluded subtrees out of scope, spec merged by name path);
## rows are placed from their root panel and lists scroll within bounds; the
## HUD opens each original window first, hides the workspace when it is
## handled, and keeps the TWILIGHT view otherwise.
const KIT=preload("res://scripts/ui/original_ui/source_main_window_kit.gd")
const HUD_CONTROLLER=preload("res://scripts/ui/original_ui/source_main_hud.gd")
const FUSION=preload("res://scripts/ui/original_ui/source_main_card_fusion_window.gd")
const COLLECTION=preload("res://scripts/ui/original_ui/source_main_card_collection_window.gd")
const ELIXIR=preload("res://scripts/ui/original_ui/source_main_half_elixir_window.gd")
const BUTTON=preload("res://scripts/ui/original_ui/source_button.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{},"externally_bound_texture_nodes":{}}
	var trees: Dictionary={}
	func scene(member: String) -> Dictionary:
		return trees.get(member,{})

class FakeHud extends Node:
	var catalog_data: Dictionary={}
	var card_collection_state: Dictionary={}

class NativeController extends Node:
	var handles: bool=true
	var opened: Array=[]
	var closed_all: int=0
	func try_open_feature_window(key: String, args: Array=[]) -> Dictionary:
		opened.append([key,args])
		return {"ok":handles,"handled":handles}
	func close_feature_windows(_except: String="") -> void:
		closed_all+=1

class RoutingHud extends "res://scripts/ui/renewal_hud.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String, _title: String, _description: String) -> void:
		active_section=section
		workspace.show()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_registry()
	_binding()
	_placement()
	_fusion_rules()
	_collection_filter()
	_routing()
	_fail_soft()
	print("ORIGINAL_UI_FEATURE_WINDOWS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _node(offset: int, kind: String, name: String, options: Dictionary={}, children: Array=[]) -> Dictionary:
	var widget: Dictionary={"name":name,"position":[0,0],"size":[100,40],"anchorPoint":[0,0],"rotationSkew":[0,0]}
	widget.merge(options,true)
	return {"_offset":offset,"classname":kind,"options":{"widgetOptions":widget},"children":children}

func _registry() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	for key: String in HUD_CONTROLLER.FEATURE_WINDOWS:
		var window: RefCounted=HUD_CONTROLLER.FEATURE_WINDOWS[key].new()
		check(window is KIT,key+" extends the window kit")
		var members: Array[String]=window.required_members()
		check(not members.is_empty() and members.all(func(member: String) -> bool:return member.begins_with("UI/") and member.ends_with(".csb")),key+" names original CSB members")
		var result: Dictionary=window.configure(FakePack.new(),hud)
		check(not result.get("ok",true) and result.get("code")=="source_window_member_missing" and not result.get("handled",true),key+" fails closed without its members")
		check(not window.is_open(),key+" is closed before opening")
	check(HUD_CONTROLLER.FEATURE_WINDOWS.keys()==["card_collection","card_fusion","card_awakening","titles","half_elixir","monsterbook","totems"],"the registered feature windows")
	hud.free()

func _binding() -> void:
	var pack:=FakePack.new()
	var row:=_node(40,"Panel","Row",{"touchEnabled":true},[_node(41,"Text","Label")])
	var tree: Dictionary={"nodeTree":_node(1,"Node","Node",{},[
		_node(10,"SingleNode","Nd_Top",{},[_node(11,"Button","Btn_Close",{"touchEnabled":true}),_node(12,"Text","Label_Title")]),
		_node(20,"ListView","ListView",{"touchEnabled":true},[row]),
		_node(30,"ImageView","Bg",{"touchEnabled":true}),
		_node(50,"SingleNode","Nd_Hidden",{},[_node(51,"Button","Btn_Gone",{"touchEnabled":true})]),
		_node(60,"LoadingBar","Gauge"),
		_node(70,"CheckBox","CB",{"touchEnabled":true})])}
	pack.trees["UI/Test/Test_All.csb"]=tree
	var kit:=KIT.new()
	kit._pack=pack
	var out: Dictionary={}
	var bound: Dictionary=kit._bind("UI/Test/Test_All.csb","",[],{"Nd_Top/Label_Title":{"role":"source_text","text":"제목"},"Nd_Hidden":{"exclude":true},"Gauge":{"percent":50.0}},out)
	var b: Dictionary=bound.bindings
	check(b[11].role=="button" and b[11].activate is Callable,"buttons get an inert original activation")
	check(b[12].role=="source_text" and b[12].text=="제목","spec merges by name path")
	check(b[20].role=="source_list" and b[20].row_offsets==[40] and b[20].input is Callable,"touch lists declare their authored rows and scroll input")
	check(b[30].role=="consume","touch images consume their touch")
	check(b[60].role=="source_percent" and is_equal_approx(float(b[60].percent),50.0),"gauges take the spec percent")
	check(b[70].role=="checkbox" and b[70].displaystate==false,"unbound checkboxes stay disabled")
	check(50 not in bound.scope and 51 not in bound.scope and not b.has(51),"excluded subtrees leave the node scope")
	check(out.has("/Nd_Top/Btn_Close") and int(out["/Nd_Top/Btn_Close"].offset)==11 and str(out["/Nd_Top/Btn_Close"].member)=="UI/Test/Test_All.csb","out keys map name paths to offsets")
	var listed: Dictionary=kit._bind("UI/Test/Test_All.csb","",[],{},{},"/ListView")
	check(listed.bindings[30].has("input") and not listed.bindings[30].has("role"),"row panels of a list forward drags to that list")

func _placement() -> void:
	var pack:=FakePack.new()
	pack.trees["UI/Test/Row.csb"]={"nodeTree":_node(1,"Node","Node",{},[_node(2,"Panel","Panel",{"position":[0,0],"size":[200,50],"anchorPoint":[0.5,0.5]})])}
	var kit:=KIT.new()
	kit._pack=pack
	var geometry: Dictionary=kit._row_geometry("UI/Test/Row.csb")
	check(geometry.size==Vector2(200,50) and geometry.origin==Vector2(-100,-25),"row geometry is the root panel rect")
	var content:=Node2D.new()
	var scene:=Node2D.new()
	KIT._place(content,scene,geometry,Vector2(10,300))
	check(scene.position==Vector2(110,-325),"rows are placed by their lower-left corner (Cocos y up)")
	kit._scrolls["/L"]={"content":content,"min":-200.0,"value":0.0}
	kit._scroll_to("/L",-500.0)
	check(is_equal_approx(content.position.y,-200.0),"scrolling stops at the last row")
	kit._scroll_to("/L",40.0)
	check(is_equal_approx(content.position.y,0.0),"scrolling stops at the first row")
	content.free()

func _fusion_rules() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var records: Array=[]
	for index: int in range(3):records.append({"name":"고급 %d" % index,"grade":"고급","sourceId":"m523:1:%d" % (100+index)})
	records.append({"name":"제한","grade":"고급","sourceId":"m523:1:200","source_merge_out_disabled":true})
	hud.catalog_data={"변신":records}
	var spare: Dictionary={}
	for record: Dictionary in records:spare[CARDS.card_id(record)]=2
	hud.card_collection_state={"owned":{"변신":{}},"spare":{"변신":spare}}
	var window=FUSION.new()
	window._hud=weakref(hud)
	window.category="변신"
	check(window._available("고급")==6,"merge-restricted duplicates are not fusion materials")
	window.grade="고급"
	window._collect()
	var used: int=0
	for entry: Dictionary in window._materials:used+=int(entry.count)
	check(used==int(CARDS.FUSION_MATERIALS["고급"]) and window._can_fuse(),"the existing rule's material count is registered")
	window.grade="유일"
	check(not window._can_fuse(),"the top grade cannot be fused")
	hud.free()

func _collection_filter() -> void:
	var window=COLLECTION.new()
	window._rows=[{"grade":"영웅","completed":true,"met_count":2},{"grade":"영웅","completed":false,"met_count":1},{"grade":"희귀","completed":false,"met_count":0}]
	window.grade="전체"
	var counts: Array=[]
	for state: int in range(4):
		window.state=state
		counts.append(window._filtered().size())
	check(counts==[3,1,2,1],"전체 / 진행 중 / 미완성 / 완성 filters")
	window.state=0
	window.grade="영웅"
	check(window._filtered().size()==2,"grade sidebar filters rows")

func _routing() -> void:
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(RoutingHud)
	var hud: RoutingHud=instance as RoutingHud
	hud.workspace=PanelContainer.new()
	hud.get_node("Root").add_child(hud.workspace)
	root.add_child(hud)
	var native:=NativeController.new()
	hud.add_child(native)
	hud.original_main_ui_controller=native
	hud.open_normal_card_collections("변신","card-1")
	check(native.opened[-1]==["card_collection",["변신","card-1"]] and not hud.workspace.visible and hud.active_section=="card_collections","card collections open the original window")
	hud.open_card_fusion("마법인형")
	check(native.opened[-1]==["card_fusion",["마법인형"]] and not hud.workspace.visible,"card fusion opens the original window")
	hud.open_titles523()
	check(native.opened[-1]==["titles",[]] and not hud.workspace.visible,"titles open the original window")
	hud.open_totems()
	check(native.opened[-1]==["totems",[]] and not hud.workspace.visible,"totems open the original window")
	hud.open_monsterbook523()
	check(native.opened[-1]==["monsterbook",[]] and not hud.workspace.visible,"the monster book opens the original window")
	hud.open_half_elixir()
	check(native.opened[-1]==["half_elixir",[]] and not hud.workspace.visible,"half elixir opens the original window")
	var attempts: int=native.opened.size()
	native.handles=false
	check(not hud._open_original_feature("titles") and native.opened.size()==attempts+1,"an unhandled window reports false (TWILIGHT view kept)")
	hud.original_main_ui_controller=null
	check(not hud._open_original_feature("titles"),"no original controller keeps the TWILIGHT view")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(source.contains("original_main_ui_controller.close_feature_windows()"),"closing the workspace closes the feature windows")
	hud.free()

## Regressions from the 523 probe: absent list nodes leave the window open,
## float pack numbers count as original integers, and 하프 엘릭서 refuses
## actions without a context instead of reading a missing source.
func _fail_soft() -> void:
	var missing: Dictionary=COLLECTION._optional({"ok":false,"error":"source_window_node_missing","suffix":"A/ListView"})
	check(missing.ok and int(missing.rows)==0 and (missing.scenes as Array).is_empty() and missing.missing=="A/ListView","an absent ListView fills as an empty list")
	var other: Dictionary=COLLECTION._optional({"ok":false,"error":"source_window_list_content_missing"})
	check(not other.ok,"other list failures still fail")
	check(COLLECTION.P=="Change_CollectionView/" and FUSION.P=="Change_DetailView_Mix/Nd_Card_Change/","page paths include the original Nd_Card_Change level")
	check(BUTTON._whole_zero(0) and BUTTON._whole_zero(0.0) and not BUTTON._whole_zero(255.0) and not BUTTON._whole_zero(0.5) and not BUTTON._whole_zero(null),"zero alpha reads from int or float pack numbers")
	check(SCENE._whole(-1396015326.0) and SCENE._whole(3) and not SCENE._whole(1.5) and not SCENE._whole("0"),"whole-number pack fields accept floats")
	var elixir=ELIXIR.new()
	check(not elixir._context_ready(),"no world means no 하프 엘릭서 context")
	for action: String in ["_extend","_reset","_charge"]:
		var refused: Dictionary=elixir.call(action)
		check(not refused.ok and refused.get("code")=="source_half_elixir_context_required",action+" is refused without a context")
	check(elixir._charge_id()=="","no charge item without a context")
	check(not elixir._stage().get("ok",true),"refresh without a context does not build the window")
