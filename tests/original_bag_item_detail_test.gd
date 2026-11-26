extends SceneTree
## The selected bag item's information is the original bag tooltip
## (ToolTipScene Inventory_ToolTip_Layout = UI/ToolTip/ToolTip_HudType_Right.csb)
## when the UI pack admits it whole (user list 2026-11-26 #12: "아이템 상세
## UI 원본 아님"). Other callers (reward windows) keep ToolTip_CommonType, and
## a pack that scopes only the bag tooltip's name header keeps CommonType too.
## Always: the pack builder packs HudType_Right whole (minus the absent
## ToolTip_Popup_Info) before ToolTipScene, the bag/CommonType selection and
## the original node spec (name, values, 안전강화, 획득처, Btn_Close,
## unconnected side buttons out) through a capture tree.
## With TWILIGHT_SOURCE_UI (a pack built from this checkout): the real tooltip
## opens with its original info list rows, buttons and close.
##   godot --headless --path <repo> --script res://tests/original_bag_item_detail_test.gd
const TOOLTIP = preload("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ORIGINAL_BAG_ITEM_DETAIL_FAIL: " + label)

func _initialize() -> void:
	builder_scope()
	routing_sources()
	capture_spec()
	_finish.call_deferred()

func _finish() -> void:
	real_pack()
	print("ORIGINAL_BAG_ITEM_DETAIL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func builder_scope() -> void:
	# The Core stage copies only the game tree; a full checkout checks the builder.
	if not FileAccess.file_exists("res://tools/ui/build_client523_main_ui_pack.py"):
		evidence["builder"] = "builder not staged: checked on a full checkout"
		return
	var text: String = FileAccess.get_file_as_string("res://tools/ui/build_client523_main_ui_pack.py")
	check(text.contains("EARLY_WHOLE_SCOPES = [\n    (\"UI/ToolTip/ToolTip_HudType_Right.csb\", [688]),\n]"), "the builder packs the whole bag tooltip minus the absent ToolTip_Popup_Info")
	check(not text.contains("(\"UI/ToolTip/ToolTip_HudType_Right.csb\", [37228"), "the old name/lock-only node scope is gone")
	var early: int = text.find("for member, excluded in EARLY_WHOLE_SCOPES:\n        builder.node_scene")
	var nodes: int = text.find("for member, offsets in NODE_SCOPES:\n        builder.node_scene")
	check(early > 0 and nodes > early, "the bag tooltip is scoped before ToolTipScene mounts it")

func routing_sources() -> void:
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(hud.contains("_item_tooltip.open(_coordinates,reference,title,item_class_id,grade_id,record,actions,_hud.get_ref(),_is_bag_selection(reference))"), "the HUD marks the bag's own selection")
	check(hud.contains("return inventory_is_open() and bag is Object and is_instance_valid(bag) and not reference.is_empty() and str(bag.get(\"selected_item\"))==reference"), "only the open bag's selected entry is a bag item")
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"), "no picture is drawn")
	check(TOOLTIP.DETAIL_MEMBER == "UI/ToolTip/ToolTip_HudType_Right.csb" and TOOLTIP.DETAIL_POSITION == Vector2(1008.0, -345.0), "the ToolTipScene Inventory_ToolTip_Layout member at its authored position")

class CaptureTree extends RefCounted:
	var spec: Dictionary
	var member: String
	func scene_of(shown: String, bindings: Dictionary, _out: Dictionary) -> Dictionary:
		spec = bindings
		member = shown
		return {"ok":false,"code":"capture_original_tooltip_spec"}

func capture_spec() -> void:
	var popup = TOOLTIP.new()
	var parent := Node2D.new()
	var capture := CaptureTree.new()
	popup._tree = capture
	var action := func() -> Dictionary: return {"ok":true}
	# A pack without the whole bag tooltip: CommonType even for the bag.
	popup._detail_available = false
	popup.open(parent, "held@@@1", "장검", 702, 0, {"small_damage":8,"large_damage":12}, {"acquisition":action}, null, true)
	check(capture.member == TOOLTIP.MEMBER, "a header-only pack keeps the common popup")
	popup._detail_available = true
	popup.open(parent, "m523:item:702", "장검", 702, 0, {}, {"acquisition":action})
	check(capture.member == TOOLTIP.MEMBER, "a reward/other caller keeps the common popup")
	popup.open(parent, "held@@@1", "장검", 702, 0, {"small_damage":8,"large_damage":12}, {"acquisition":action,"delete":action}, null, true)
	var spec: Dictionary = capture.spec
	check(capture.member == TOOLTIP.DETAIL_MEMBER, "the selected bag item opens the original bag tooltip")
	check(spec.get("Title/Label",{}).get("text") == "장검", "original Title/Label carries the name")
	check(spec.get("ListView_BasicInfo/Panel_set/Text_Title",{}).get("text") == "대미지" and spec.get("ListView_BasicInfo/Panel_set/Text_Desc",{}).get("text") == "8 / 12", "first ListView_BasicInfo row carries the record values")
	check(spec.get("ToolTip_Button/ItemDrop_On/Button",{}).get("activate") == action, "획득처 runs the bag's acquisition action")
	for group: String in ["Business","Del","Warehouse","Probability","Detail"]:
		check((spec.get("Icon_Set",{}).get("exclude",false) or spec.get("Icon_Set/"+group+"_On",{}).get("exclude",false)) and not spec.has("Icon_Set/"+group+"_On/Btn_Icon"), "no Com_Btn_TypeB icon button (cap insets past its frame): " + group)
	check(spec.get("Icon_Set",{}).get("exclude",false), "no safe level and no icon action: the icon strip is out")
	popup.open(parent, "held@@@1", "장검", 702, 0, {}, {"safe_level":6}, null, true)
	check(capture.member == TOOLTIP.DETAIL_MEMBER and capture.spec.get("Icon_Set/Enchant_On/Text_Enchant",{}).get("text") == "+6", "안전강화 +6 label on the bag tooltip")
	for group: String in ["Business","Del","Warehouse","Probability","Detail"]:
		check(capture.spec.get("Icon_Set/"+group+"_On",{}).get("exclude",false), "with 안전강화 shown, icon button stays out: " + group)
	popup.open(parent, "held@@@3", "상자", 133023, 0, {}, {"probability":action,"acquisition":action}, null, true)
	check(capture.member == TOOLTIP.MEMBER and capture.spec.get("Icon_Set/Probability_On/Btn_Icon",{}).get("activate") == action, "a box with disclosed probability keeps the common popup and its 확률정보")
	popup.open(parent, "held@@@1", "장검", 702, 0, {"small_damage":8,"large_damage":12}, {"acquisition":action,"delete":action}, null, true)
	check((spec.get("Btn_Close",{}).get("activate") as Callable).is_valid(), "the original Btn_Close closes it")
	for name: String in ["ToolTip_Button/Compare_On","ToolTip_Button/Repair_On","ToolTip_Button/Solution_On","ToolTip_Button/Business_On","ToolTip_Button/Registration_On","ItemInfo/ListView_SetBuff","ItemInfo/Nd_Lock","ItemInfo/Nd_Unlock","Icon_Set/Warehouse_On"]:
		check(spec.get(name,{}).get("exclude",false), "unconnected original control is out: " + name)
	check(not spec.has("ND_ItemList/Slot/Sp_IconSample") and not spec.has("Nd_Btn"), "no CommonType-only node names in the bag tooltip spec")
	popup.open(parent, "held@@@2", "물약", 233, 0, {}, {}, null, true)
	check(capture.spec.get("ToolTip_Button/ItemDrop_On",{}).get("exclude",false), "no acquisition action: 획득처 is out")
	parent.free()

func real_pack() -> void:
	var root_path: String = OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	if root_path.is_empty() or sha.is_empty():
		evidence["real"] = "original UI pack not installed: real bag tooltip skipped"
		return
	var pack = PACK.new()
	var opened: Dictionary = pack.open(root_path, sha)
	if not opened.get("ok", false):
		evidence["real"] = "UI pack did not open: " + str(opened.get("error", ""))
		return
	if not TOOLTIP.detail_supported(pack):
		evidence["real"] = "UI pack scopes only the bag tooltip header (older pack): common popup kept"
		return
	var popup = TOOLTIP.new()
	check(popup.configure(pack).get("bag_detail", false), "the popup admits the whole bag tooltip")
	var parent := Node2D.new()
	get_root().add_child(parent)
	var action := func() -> Dictionary: return {"ok":true}
	var result: Dictionary = popup.open(parent, "held@@@1", "장검", 702, 0, {"small_damage":8,"large_damage":12,"hit":2}, {"acquisition":action}, null, true)
	evidence["real"] = {"ok":result.get("ok"),"member":result.get("member"),"rows":result.get("rows",[]).size(),"extra":result.get("extra_rows"),"problem":result.get("rows_problem","")}
	check(result.get("ok", false) and popup.is_open() and result.get("member") == TOOLTIP.DETAIL_MEMBER, "the original bag tooltip opens")
	check(int(result.get("extra_rows", 0)) == result.get("rows", []).size() - 1, "every value row is an original Panel_set row")
	for path: String in ["Title/Label","ItemInfo/ListView_BasicInfo","ToolTip_Button/ItemDrop_On/Button","Btn_Close","Inven_Base/Bg"]:
		var located: Dictionary = TREE.locate(popup._scene, popup._out, path)
		check(located.get("ok", false) and (located.player.source_nodes[located.offset] as Node2D).is_visible_in_tree(), "original node shown: " + path)
	for path: String in ["ToolTip_Button/Compare_On","ToolTip_Button/Repair_On","ToolTip_Button/BasicInfo","ItemInfo/ListView_SetBuff"]:
		check(not TREE.locate(popup._scene, popup._out, path).get("ok", false), "unconnected original node not mounted: " + path)
	var close_button: Dictionary = TREE.locate(popup._scene, popup._out, "Btn_Close")
	var native: Node = close_button.player.source_nodes[close_button.offset] if close_button.get("ok", false) else null
	var button: Object = native.get_meta("source_button") if is_instance_valid(native) and native.has_meta("source_button") else null
	check(button != null and (button.get("_activation") as Callable).is_valid(), "Btn_Close is bound")
	if button != null: (button.get("_activation") as Callable).call()
	check(not popup.is_open(), "Btn_Close closes the bag tooltip")
	parent.free()
