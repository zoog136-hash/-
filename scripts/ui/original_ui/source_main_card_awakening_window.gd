extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 card skill awakening window (partial node scope):
## Change_Awaken_All (close, 스킬 각성 tab) with its Change_Awaken_Skill page:
## title, current awakened skill, the 각성서 slot (the existing book item's
## own icon), 각 성 (World.skill_awakening.request_operation, which keeps
## eligibility, book consumption, roll and save) and 돌아가기. The page's
## 각성서 inventory (QuickSlotEdit_SlotSet) is absent from the 523 client and
## is left out of the pack scope (build_client523_main_ui_pack WHOLE_SCOPES).
## Not connected: the candidate skill list (Change_Upgrade_Skill_List names no
## row member), 옵션 각성 and 스킬 각성 경험치 pages, 각성서/조각 제작 and the
## price label (the tables name no awakening price).
const ROOT="UI/Change/Change_Awaken_All.csb"
const SKILL="UI/Change/Change_Awaken_Skill.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const OptionWindow=preload("res://scripts/ui/original_ui/source_main_option_awakening_window.gd")
const P="Nd_Skill/Nd_Skill/"
var category: String="변신"
var identity: String=""
var submitting: bool=false

func configure(pack: RefCounted, host: Node) -> Dictionary:
	var files: Dictionary = pack.manifest.get("files", {})
	if files.get(ROOT, {}).get("sha256") != "1a790cb7a91c8eac69562dd904bc82c9bb52fe4ab7a8ab2c2202ea16b01d2836" or files.get(SKILL, {}).get("sha256") != "aa50bea00b320c43f01112cca2c49aee65293a7fc40852a78b7c23b6c5f99fdd":
		return _fail("source_skill_awakening_identity_required")
	return super.configure(pack, host)

func required_members() -> Array[String]:
	return [ROOT,SKILL]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("skill_awakening") if owner!=null else null

func open(parent: Node, category_name: String, card_identity: String) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_card_awakening_runtime_unavailable")
	category=category_name
	identity=card_identity
	if not runtime.view(identity).get("ok",false):return _fail("source_card_awakening_view_unavailable")
	return open_window(parent)

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var snapshot: Dictionary=runtime.view(identity)
	var spec: Dictionary={}
	spec["Change_Awaken_Option"]={"exclude":true}
	spec["Change_Awaken_SkillExp"]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_Awaken_Tab_1"]={"visible":false}
	# Change_Awaken_All authors the skill/exp tab bar hidden (the client shows it).
	spec["Nd_Awaken_Tab_2"]={"visible":true}
	# Awaken result effects (white flash, exp take) belong to the reveal, not the page.
	spec["Change_Awaken_Skill/Fx_Whitescreen"]={"exclude":true}
	spec["Change_Awaken_Skill/Fx_Exp_Take"]={"exclude":true}
	# The dimmed clipping panel and its server_bg are shown by the reveal timeline.
	spec[P+"Panel_Bg_Clipping"]={"exclude":true}
	spec["Nd_Awaken_Tab_2/Btn_Skill_On"]={"visible":true}
	spec["Nd_Awaken_Tab_2/Btn_Skill_Off"]={"visible":false}
	spec["Nd_Awaken_Tab_2/Btn_Exp_On"]={"visible":false}
	spec["Nd_Awaken_Tab_2/Btn_Exp_Off"]={"visible":false}
	spec["Nd_Inventory/Btn_Production_Book"]={"visible":false}
	spec["Nd_Inventory/Btn_Production_Piece"]={"visible":false}
	var spell: int=int(snapshot.entry.spell_id)
	var current: String="현재 각성 스킬 없음" if spell==0 else "%s · Lv.%d" % [str(runtime.core.data.spells.get(str(spell),{}).get("name","")),int(snapshot.entry.level)]
	spec[P+"Label_Title"]={"role":"source_text","text":"%s 각성" % str(snapshot.card.get("name",""))}
	spec[P+"Label_Skill"]={"role":"source_text","text":current}
	var required: Dictionary=snapshot.get("book_requirement",{})
	var cost: int=int(required.get("fee",0))
	var can: bool=not required.is_empty() and world().gold>=cost and snapshot.get("can_awaken",false) and not snapshot.get("save_blocked",false)
	spec[P+"Btn_Production"]={"activate":Callable(self,"_review"),"displaystate":can}
	spec[P+"Btn_Production/Text_Price"]={"visible":true,"role":"source_text","text":OptionWindow._number(cost)}
	spec[P+"Fx_Btn_Production"]={"visible":false}
	spec[P+"Fx_Item_Active_Right"]={"visible":false}
	spec["Btn_Back"]={"activate":Callable(self,"_back")}
	spec["Change_Awaken_Skill/Nd_Skill/Label_Tip"]={"role":"source_text","text":"각성서 1장 소모\n재각성 시 스킬 Lv.1 · 경험치 0"}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var snapshot: Dictionary=runtime.view(identity)
	var book: Dictionary=snapshot.get("book",{})
	var picture: bool=false
	var located: Dictionary=_locate(root,out,"Nd_Item/Inventory_Slot/Sp_IconSample")
	var owner: Object=hud()
	if located.get("ok",false) and not book.is_empty() and owner!=null:
		var name: String=str(book.get("name",""))
		var context: Dictionary={"member":SLOT,"node_offset":located.offset,"reference":name,"source_slot_contract":Scene.external_scene_slot_contract(_pack,SLOT,located.offset)}
		picture=_show_picture(located.player,located.offset,InventoryImages.resolve_owned(owner,{"name":name,"reference":name,"record":book},context))
	return {"ok":true,"identity":identity,"can_awaken":bool(snapshot.get("can_awaken",false)),"book":str(book.get("name","")),"book_picture":picture,"candidates":(snapshot.get("candidates",[]) as Array).size()}

func _review() -> Dictionary:
	var owner: Node=hud()
	if not is_open() or owner == null or owner.get_node_or_null("Root/TwilightConfirmation") != null:
		return _fail("skill_awakening_review_unavailable")
	var snapshot: Dictionary = _runtime().view(identity)
	var requirement: Dictionary = snapshot.get("book_requirement",{})
	if requirement.is_empty() or not snapshot.get("can_awaken",false): return _fail("skill_awakening_target_unavailable")
	var body: String = "%s\n%s × 1장 · %s 아데나" % [snapshot.card.name, snapshot.book.name, OptionWindow._number(int(requirement.fee))]
	if int(snapshot.entry.spell_id) > 0: body += "\n현재 스킬을 교체하고 Lv.1 · 경험치 0부터 시작합니다."
	var revision: int = _runtime().progress.revision
	var scene_at_review: int = _scene.get_instance_id()
	owner.confirm_awakening_action("스킬 각성 확인",body,"각성",Callable(self,"_awaken").bind(identity, revision, scene_at_review))
	return {"ok":true,"reviewing":true}

func _awaken(_count: int, target: String, revision: int, scene_at_review: int) -> Dictionary:
	if submitting or not is_open() or identity != target or _scene.get_instance_id() != scene_at_review: return _fail("skill_awakening_review_expired")
	var runtime: Object=_runtime()
	submitting = true
	var result: Dictionary=runtime.request_operation(identity,{"expected_revision":revision})
	submitting = false
	if result.get("ok",false):
		var snapshot: Dictionary = runtime.view(identity)
		var entry: Dictionary = snapshot.entry
		var spell: String = str(runtime.core.data.spells.get(str(int(entry.spell_id)),{}).get("name",""))
		_stage()
		var owner: Node = hud()
		var outcome: Dictionary = {"ok":true, "success":true, "skill_name":spell+" · Lv."+str(entry.level)}
		if not owner.present_source_awakening_result(snapshot.target_record, outcome, owner._option_awakening_settings()):
			_message("각성: " + str(outcome.skill_name))
	else:
		_message(str(result.get("error","각성할 수 없습니다")))
	return result

func _back() -> Dictionary:
	return _route("open_catalog",[category])
