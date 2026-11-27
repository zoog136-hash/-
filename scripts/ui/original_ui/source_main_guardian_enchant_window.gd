extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 강화 preview and result. GrowthRuntime owns the quote, roll,
## currency and save. As in the existing offline guardian search, tap the
## card to confirm a choice on touch screens.
const ROOT = "UI/SkillTree/SkillTree_Popup_SkillEnchant.csb"
const REVEAL = "UI/SkillTree/SkillTree_RandomOpen_Enchant.csb"
const CARD = "UI/SkillTree/SkillTree_Card_Enchant_Default.csb"
const RESULT = "UI/SkillTree/SkillTree_Card_Enchant_Result.csb"
const ROW = "UI/SkillTree/SkillTree_Text_02.csb"
const BACKGROUND = {"path":"FullFrameUI_BG01.png","plistFile":"UI_Resource/Atlas_Texture.plist","resourceType":1}
const R = "SkillTree_RandomOpen_Enchant_Layout/"
const GrowthView = preload("res://scripts/growth/growth_view.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

enum Phase {PREVIEW, CARD, RESULT}
var phase: Phase = Phase.PREVIEW
var group: String
var slot: String
var before_level: int
var shown_level: int
var won: bool
var offer: Dictionary = {}

func required_members() -> Array[String]:
	return [ROOT, REVEAL, CARD, RESULT, ROW]

func _root_member() -> String:
	return ROOT

func _runtime() -> RefCounted:
	var owner: Object = world()
	return owner.get("growth") if owner != null else null

func open(parent: Node, star: String, id: String) -> Dictionary:
	var runtime: RefCounted = _runtime()
	if runtime == null or not (runtime.state.get("nodes",[]) as Array).has(id) or not runtime.guardian_source.has_node(id):
		return _fail("source_guardian_enchant_slot_unavailable")
	var level: int = runtime.guardian_level(id)
	if runtime.guardian_source.upgrade(id,level+1).is_empty():
		return _fail("source_guardian_enchant_level_unavailable")
	group = star
	slot = id
	before_level = level
	shown_level = level
	won = false
	offer = {}
	phase = Phase.PREVIEW
	return open_window(parent)

func close() -> void:
	offer = {}
	super.close()

func _spec() -> Dictionary:
	var preview: bool = phase == Phase.PREVIEW
	var card: bool = phase == Phase.CARD
	var result: bool = phase == Phase.RESULT
	var runtime: RefCounted = _runtime()
	var name: String = str(runtime.node(slot).get("name",""))
	var spec: Dictionary = {
		"Nd_Title":{"visible":preview or card},
		"Nd_Enchant":{"exclude":result},
		"Nd_Preview":{"exclude":not preview},
		"Img_Block":{"exclude":true},
		"Particle":{"exclude":true},
		"Fx_Img_BG_Particle":{"exclude":true},
		"Fx_Start_Loop":{"exclude":true},
		"Card_GuidBox":{"visible":card},
		"SkillTree_RandomOpen_Enchant_Layout":{"exclude":not result},
	}
	spec["Nd_Enchant/Btn_Cancle"] = {"activate":Callable(self,"_back")}
	if card:
		spec["Nd_Enchant/Btn_Enchant"] = {"exclude":true}
		spec["Nd_Enchant/Btn_Probability"] = {"exclude":true}
	if preview:
		var quote: Dictionary = runtime.quote("guardian_enchant",slot)
		var upgrade: Dictionary = runtime.guardian_source.upgrade(slot,before_level+1)
		var cost: String = _number(int(upgrade.get("CurrencyCost",0)))
		var enabled: bool = quote.get("ok",false)
		spec["Nd_Enchant/Btn_Enchant"] = {"activate":Callable(self,"_begin"),"displaystate":enabled}
		spec["Nd_Enchant/Btn_Enchant/Normal"] = {"visible":enabled}
		spec["Nd_Enchant/Btn_Enchant/Disabled"] = {"visible":not enabled}
		spec["Nd_Enchant/Btn_Enchant/Normal/Label_Amount"] = {"role":"source_text","text":cost}
		spec["Nd_Enchant/Btn_Enchant/Disabled/Label_Amount"] = {"role":"source_text","text":cost}
		spec["Nd_Enchant/Btn_Probability"] = {"activate":Callable(self,"_probability")}
		for preview_panel: String in ["Nd_Before","Nd_After"]:
			var level: int = before_level + int(preview_panel == "Nd_After")
			var skill: String = "Nd_Preview/"+preview_panel+"/Nd_Skill/"
			spec[skill+"Common_Slot"] = {"exclude":true}
			spec[skill+"Label_SkillName"] = {"role":"source_text","text":"%s  Lv.%d" % [name,level]}
	if result:
		spec[R+"Nd_DragLine"] = {"exclude":true}
		spec[R+"Btn_Close"] = {"exclude":true}
		spec[R+"Btn_Cancle"] = {"exclude":true}
		spec[R+"Text_Close"] = {"visible":true}
		spec[R+"Text_Success"] = {"visible":won}
		spec[R+"Text_Success_Level"] = {"role":"source_text","text":"Lv.%d" % shown_level,"visible":won}
		spec[R+"Text_Fail"] = {"visible":not won}
		spec[R+"SkillTree_Card_Enchant_Result"] = {"visible":true}
		spec[R+"SkillTree_Card_Enchant_Result/Nd_Success"] = {"visible":won}
		spec[R+"SkillTree_Card_Enchant_Result/Nd_Fail"] = {"visible":not won}
		spec[R+"SkillTree_Card_Enchant_Result/Nd_Success/Sp_Illust_Load"] = {"visible":false}
		spec[R+"SkillTree_Card_Enchant_Result/Nd_Success/Sp_SkillIcon"] = {"visible":false}
		spec[R+"SkillTree_Card_Enchant_Result/Nd_Success/Text"] = {"role":"source_text","text":name}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	# The popup and nested reveal start at a translucent authored frame.
	# Use the completed source entry pose before the controls accept input.
	var pose: String = "Fx_Enchant_Open" if phase == Phase.RESULT else "Fx_Start"
	for clip: Dictionary in root.source_tree.get("animationList",[]):
		if clip.name == pose:
			root.seek_frame(float(clip.endIndex))
			break
	var background: Dictionary = _locate(root,out,"Node_Bg")
	var texture: Texture2D = _pack.texture(BACKGROUND,true) if background.get("ok",false) else null
	if texture == null: return _fail("source_guardian_enchant_background_unavailable")
	var area := Control.new()
	area.position = Vector2(-800,-337.5)
	area.size = Vector2(1600,675)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	# Under the source buttons, this keeps the playfield from taking a tap.
	root.add_child(area)
	root.move_child(area,0)
	var image := Sprite2D.new()
	image.texture = texture
	image.scale = area.size / texture.get_size()
	image.z_index = -1
	background.player.source_nodes[background.offset].add_child(image)
	match phase:
		Phase.PREVIEW:
			for value: Array in [["Nd_Before",before_level],["Nd_After",before_level+1]]:
				var list: Dictionary = _fill_list(root,out,"Nd_Preview/"+value[0]+"/ListView",_preview_rows(int(value[1])))
				if not list.get("ok",false): return list
		Phase.CARD:
			# Keep the authored exit button while the card is awaiting confirmation.
			var card: Dictionary = _scene_of(CARD,{"Btn":{"activate":Callable(self,"_commit"),"touch_enabled":true}}, {})
			if not card.get("ok",false): return card
			var position: Dictionary = _locate(root,out,"Card_GuidBox")
			if not position.get("ok",false):
				card.scene.free()
				return position
			var host: Node2D = position.player.source_nodes[position.offset]
			var content: Node2D = host.get_node("SourceContentOrigin")
			var geometry: Dictionary = _row_geometry(CARD)
			_place(content,card.scene,geometry,(_node_size(out,"Card_GuidBox")-geometry.size)*0.5)
			card.scene.play("Fx_Start")
		Phase.RESULT:
			area.gui_input.connect(_close_result)
			var panel: Node2D = _project(root,out,"SkillTree_RandomOpen_Enchant_Layout")
			var card: Node2D = _project(root,out,R+"SkillTree_Card_Enchant_Result")
			if panel == null or card == null: return _fail("source_guardian_enchant_result_missing")
			panel.play("Fx_Open_End_Success" if won else "Fx_Open_End_Fail")
			card.play("Fx_Success_Start" if won else "Fx_Fail_Start")
	return {"ok":true,"phase":phase,"level":shown_level,"won":won}

func _preview_rows(level: int) -> Array:
	var runtime: RefCounted = _runtime()
	var lines: Array = []
	var effects: Dictionary = runtime.guardian_source.effects(slot,level)
	if not effects.is_empty(): lines.append(["능력치",GrowthView.effect_text(runtime,effects)])
	var detail: String = runtime.guardian_source.detail(slot,level)
	for value: String in detail.split("\n",false):
		var parts: PackedStringArray = value.split(" · ",false)
		for i: int in parts.size():
			lines.append(["효과" if i == 0 else "",parts[i]])
	var rows: Array = []
	for line: Array in lines:
		rows.append({"member":ROW,"spec":{
			"Nd_Skill/Text_Title":{"role":"source_text","text":line[0]},
			"Nd_Skill/Text_Desc":{"role":"source_text","text":line[1]},
		}})
	return rows

func _project(root: Node2D, out: Dictionary, suffix: String) -> Node2D:
	var located: Dictionary = _locate(root,out,suffix)
	if not located.get("ok",false): return null
	var node: Node2D = located.player.source_nodes.get(located.offset)
	if not is_instance_valid(node) or not node.has_meta("source_project_player"): return null
	return node.get_meta("source_project_player") as Node2D

func _probability() -> Dictionary:
	var upgrade: Dictionary = _runtime().guardian_source.upgrade(slot,before_level+1)
	if upgrade.is_empty(): return _fail("source_guardian_enchant_level_unavailable")
	var chance: float = float(upgrade.Probability)/10000.0
	_message("수호성 Lv.%d → %d · 성공률 %.2f%% · 수호석 %d개\n실패하면 재료만 소모됩니다." % [before_level,before_level+1,chance,int(upgrade.CurrencyCost)])
	return {"ok":true}

func _begin() -> Dictionary:
	if not is_open() or phase != Phase.PREVIEW: return _fail("source_guardian_enchant_preview_inactive")
	var runtime: RefCounted = _runtime()
	if runtime.guardian_level(slot) != before_level: return _back()
	offer = runtime.quote("guardian_enchant",slot)
	if not offer.get("ok",false):
		_message(str(offer.get("message","수호성 강화 불가")))
		return offer
	phase = Phase.CARD
	var built: Dictionary = _stage()
	if not built.get("ok",false):
		phase = Phase.PREVIEW
		offer = {}
		_message("원본 수호성 강화 카드를 열 수 없습니다.")
	return built

func _commit() -> Dictionary:
	if not is_open() or phase != Phase.CARD or offer.is_empty(): return _fail("source_guardian_enchant_card_inactive")
	var quoted: Dictionary = offer
	offer = {}
	var runtime: RefCounted = _runtime()
	var response: Dictionary = runtime.execute("guardian_enchant",slot,1,int(quoted.revision),int(quoted.day))
	_message(str(response.get("message","수호성 강화 불가")))
	if not response.get("ok",false):
		_back()
		return response
	shown_level = runtime.guardian_level(slot)
	won = shown_level > before_level
	phase = Phase.RESULT
	var started: int = FRAME_HITCH.now()
	var built: Dictionary = _stage()
	FRAME_HITCH.detail("growth.guardian_result",started)
	if not built.get("ok",false): _back()
	return response

func _close_result(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if not event.pressed and phase == Phase.RESULT: _back()

func _back() -> Dictionary:
	offer = {}
	var owner: Object = hud()
	var controller: Variant = owner.get("original_main_ui_controller") if owner != null else null
	if is_instance_valid(controller):
		var opened: Dictionary = controller.try_open_feature_window("guardians",[group])
		if opened.get("handled",false): return opened
	return _close_requested()
