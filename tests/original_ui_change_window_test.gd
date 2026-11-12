extends SceneTree
## The original 523 polymorph window (source_main_change_window.gd).
## Without arguments (no original files): every TWILIGHT card grade has an
## original Change_Card_A prefab, each card picture node is declared as an
## external original slot, a pack without the members fails closed, owned
## cards are listed highest grade first, option lines split into the row's
## two labels, and the HUD opens the window first for 변신/마법인형 while
## the apply path stays catalog_equip_requested.
## Real input: -- --pack=<private original main UI pack directory>: the window
## mounts from the original CSBs with the catalog's owned cards.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeHud extends Node:
	signal catalog_equip_requested(category: String, record: Dictionary)
	var catalog_data: Dictionary={}
	var card_collection_state: Dictionary={}
	var character_state: Dictionary={}

class NativeController extends Node:
	var handles: bool=true
	var categories: Array[String]=[]
	func try_open_change_window(category: String) -> Dictionary:
		categories.append(category)
		return {"ok":handles,"handled":handles}

# Exercise the production routing without loading a private original pack or
# constructing a second browser. Existing UI suites cover that browser itself.
class RoutingHud extends "res://scripts/ui/renewal_hud.gd":
	var browser_categories: Array[String]=[]
	var reorders: int=0
	var selections: int=0
	var controls_refreshes: int=0
	var marker_refreshes: int=0
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _reset_catalog_drag() -> void:pass
	func _sync_screen_focus() -> void:pass
	func _open_window(section: String, _title: String, _description: String) -> void:
		active_section=section
		catalog_panel.hide()
		workspace.show()
	func _open_catalog_browser(category: String) -> void:
		catalog_browser_active=true
		browser_categories.append(category)
		catalog_panel.show()
	func _refresh_catalog_owned_order() -> void:reorders+=1
	func _refresh_card_controls() -> void:
		controls_refreshes+=1
		super._refresh_card_controls()
	func _refresh_option_awakening_markers() -> void:
		marker_refreshes+=1
		super._refresh_option_awakening_markers()
	func _on_catalog_item_selected(_index: int) -> void:selections+=1

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_grades_and_slots()
	_fails_closed()
	_owned_order()
	_option_split()
	_catalog_routing()
	_hidden_browser_state()
	_hud_hooks()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_CHANGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _grades_and_slots() -> void:
	for grade: String in CARDS.GRADES:
		check(WINDOW.GRADE_MEMBERS.has(grade),"grade has an original card prefab: "+grade)
	var external: Dictionary=SOURCE_PACK.CODE_EXTERNAL_TEXTURE_NODES
	for member: String in WINDOW.CARD_NODES:
		check(int(WINDOW.CARD_NODES[member].sample) in external.get(member,[]),"card picture node declared external: "+member)
		check(member in WINDOW.GRADE_MEMBERS.values(),"prefab is used by a grade: "+member)
	check(WINDOW.SAMPLE in external.get(WINDOW.DETAIL,[]),"detail illustration node declared external")
	# Transcend frames are 508-only; the window mounts no transcend node.
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(not source.contains("Transcend.csb") and not source.contains("14884"),"no transcend node is mounted")

func _fails_closed() -> void:
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var result: Dictionary=window.configure(FakePack.new(),hud)
	check(not result.get("ok",true) and result.get("code")=="source_change_window_member_missing","missing members fail closed: "+str(result))
	check(not window.is_open(),"nothing is open")
	hud.free()

func _owned_order() -> void:
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var low: Dictionary={"name":"A","grade":"고급","sourceId":"m508:1:1"}
	var high: Dictionary={"name":"B","grade":"영웅","sourceId":"m508:1:2"}
	var missing: Dictionary={"name":"C","grade":"전설","sourceId":"m508:1:3"}
	hud.catalog_data={"변신":[low,high,missing]}
	hud.card_collection_state={"owned":{"변신":{CARDS.card_id(low):true,CARDS.card_id(high):true}}}
	window._hud=weakref(hud)
	window._category="변신"
	var cards: Array[Dictionary]=window._owned_cards()
	check(cards.size()==2,"only owned cards are listed: "+str(cards.size()))
	check(cards.size()==2 and cards[0].name=="B" and cards[1].name=="A","highest grade first")
	hud.character_state={"equipped":{"변신":high}}
	check(window._equipped_id()==CARDS.card_id(high),"equipped card identity follows the catalog")
	# Applying emits the existing catalog equip signal with the card record.
	var emitted: Array=[]
	hud.catalog_equip_requested.connect(func(category: String, record: Dictionary) -> void: emitted.append([category,record]))
	window._cards=cards
	window._selected=CARDS.card_id(low)
	var applied: Dictionary=window._apply_selected()
	check(applied.get("existing_equip_requested",false) and emitted.size()==1 and emitted[0][0]=="변신" and emitted[0][1].name=="A","apply uses catalog_equip_requested: "+str(applied))
	window._selected=CARDS.card_id(high)
	check(window._apply_selected().get("already_applied",false) and emitted.size()==1,"the applied card is not re-applied")
	hud.free()

func _option_split() -> void:
	check(_split("SP +1")==["SP","+1"],"value suffix goes to the value label")
	check(_split("최대 공격 거리 제한 +1")==["최대 공격 거리 제한","+1"],"multi-word option")
	check(_split("대미지 리덕션")==["대미지 리덕션",""],"no value keeps one label")

static func _split(line: String) -> Array:
	var cut: int=line.rfind(" ")
	if cut>0 and line.substr(cut+1).left(1) in ["+","-"]:return [line.left(cut),line.substr(cut+1)]
	return [line,""]

func _routing_hud() -> RoutingHud:
	# Retain the actual HUD scene's @onready targets while replacing only its
	# browser construction/transition work with counters.
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(RoutingHud)
	var hud: RoutingHud=instance as RoutingHud
	var ui_root: Control=hud.get_node("Root")
	hud.workspace=PanelContainer.new()
	ui_root.add_child(hud.workspace)
	hud.catalog_panel=PanelContainer.new()
	ui_root.add_child(hud.catalog_panel)
	hud.catalog_list=ItemList.new()
	hud.catalog_panel.add_child(hud.catalog_list)
	hud.catalog_search=LineEdit.new()
	hud.catalog_panel.add_child(hud.catalog_search)
	root.add_child(hud)
	return hud

func _catalog_routing() -> void:
	var hud:=_routing_hud()
	var native:=NativeController.new()
	hud.add_child(native)
	hud.original_main_ui_controller=native
	for category: String in ["변신","마법인형"]:
		hud.open_catalog(category)
		check(hud.browser_categories.is_empty(),"handled "+category+" creates no hidden browser")
		check(hud.active_section==category and hud.catalog_category==category and not hud.workspace.visible,"native category stays active while workspace is hidden")
	check(native.categories==["변신","마법인형"],"each native window is attempted once")
	native.handles=false
	hud.open_catalog("변신")
	check(hud.browser_categories==["변신"] and hud.workspace.visible,"unsupported original state opens the current browser once")
	hud.original_main_ui_controller=null
	hud.open_catalog("마법인형")
	check(hud.browser_categories==["변신","마법인형"],"an unselected original pack retains the current browser")
	hud.original_main_ui_controller=native
	var native_attempts: int=native.categories.size()
	for category: String in ["아이템","성물"]:hud.open_catalog(category)
	check(native.categories.size()==native_attempts and hud.browser_categories==["변신","마법인형","아이템","성물"],"item and relic browsers do not attempt a polymorph window")
	hud.free()

func _hidden_browser_state() -> void:
	var hud:=_routing_hud()
	hud.active_section="성물"
	hud.catalog_category="성물"
	hud.catalog_panel.hide()
	hud.workspace.hide()
	var record: Dictionary={"name":"old relic","grade":"일반","sourceId":"m508:98:1"}
	hud.catalog_results=[record]
	hud.catalog_list.add_item("A")
	hud.catalog_list.select(0)
	hud.catalog_list.set_item_metadata(0,"old relic metadata")
	var old_icon:=PlaceholderTexture2D.new()
	hud.catalog_list.set_item_icon(0,old_icon)
	var native:=NativeController.new()
	hud.add_child(native)
	hud.original_main_ui_controller=native
	hud.open_catalog("변신")
	hud.set_card_collection_state({"owned":{"변신":{CARDS.card_id(record):true}}})
	check(hud.reorders==0 and hud.selections==0,"a hidden browser does not rebuild stale card rows")
	check(hud.controls_refreshes==0 and hud.marker_refreshes==0,"native ownership updates skip both hidden browser refreshes")
	check(hud.catalog_list.get_item_metadata(0)=="old relic metadata" and hud.catalog_list.get_item_icon(0)==old_icon,"native category ownership cannot decorate old relic rows")
	hud._refresh_option_awakening_markers()
	check(hud.catalog_list.get_item_metadata(0)=="old relic metadata" and hud.catalog_list.get_item_icon(0)==old_icon,"the marker's own hidden guard also protects other update callers")
	hud.marker_refreshes=0
	hud.original_main_ui_controller=null
	var saved: Dictionary={"query":"saved query","grade":"희귀","page":2,"id":"saved card","scroll":73.0}
	hud.catalog_view_state["변신"]=saved.duplicate(true)
	hud._close_workspace()
	check(hud.catalog_view_state["변신"]==saved,"closing a native window preserves the saved browser selection and scroll")
	hud.active_section="변신"
	hud.catalog_browser_active=true
	hud.catalog_panel.show()
	hud.set_card_collection_state({"owned":{"변신":{}}})
	check(hud.reorders==1 and hud.selections==1,"the visible browser still refreshes ownership and selection")
	check(hud.controls_refreshes==1 and hud.marker_refreshes==1 and hud.catalog_list.get_item_metadata(0)==CARDS.card_id(record),"the visible browser still executes its real controls and marker updates")
	hud.catalog_search.text="current query"
	hud.catalog_grade_filter="일반"
	hud.selected_catalog_record=record
	hud._hide_aux_panels()
	check(hud.catalog_view_state["변신"].query=="current query" and hud.catalog_view_state["변신"].id==record.sourceId,"closing the current browser still records its own view")
	hud.free()

func _hud_hooks() -> void:
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_change_window(category)") and renewal.contains("try_open_change_window"),"open_catalog opens the original window first")
	check(renewal.contains("close_change_window()"),"closing the workspace closes the window")
	var main_hud: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_hud.contains("func try_open_change_window") and main_hud.contains("ChangeWindow.ROOT"),"main HUD controller owns the window")
	var window: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(window.contains("\"catalog_equip_requested\""),"window applies through the existing equip signal")

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var hud:=FakeHud.new()
	root.add_child(hud)
	var configured: Dictionary=WINDOW.new().configure(pack,hud)
	check(configured.get("ok",false),"window configures from the original pack: "+str(configured))
	var window=WINDOW.new()
	window.configure(pack,hud)
	var parent:=Node2D.new()
	root.add_child(parent)
	var opened: Dictionary=window.open(parent,"변신")
	check(opened.get("handled",false) and opened.get("cards")==0,"window mounts with no owned cards: "+str(opened))
	window.close()
	await process_frame
	parent.queue_free()
	hud.queue_free()
