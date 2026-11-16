extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 획득 가능 아이템 window (Probability_All, Nd_Type03 list)
## for one lucky bag item: its original LuckyBagEntity rows
## (record.source_use_spec rewards: item, amount, 축복/저주, +N, class
## limits, Probability / IsGiven), filtered to the character's class like the
## existing item use. Probability is the original raw value over the bag's
## source denominator (10,000,000), else over the class total; IsGiven rows
## show 확정. Nothing here opens the bag.
## Left out: the grade tabs (Nd_Type01), the 확정/확률 보상 tabs (Nd_Type02; the
## single list shows both kinds), the card notice and the popup effects.
const NATIVE_FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const ItemUse=preload("res://scripts/loot/patch523_item_use.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT="UI/FloatingUi/Probability_All.csb"
const ROW="UI/FloatingUi/Probability_List_Item.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const BAG_KINDS: Array[String]=["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]
const BLESSING={2:"축복받은 ",3:"저주받은 "}
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
var title: String=""
var rows: Array=[]

func required_members() -> Array[String]:
	return [ROOT,ROW,SLOT]

func _root_member() -> String:
	return ROOT

## Centred on the 1200x675 design frame (FloatingUiScene names no
## Probability_All layout).
func _root_position() -> Vector2:
	return Vector2(600.0,-345.0)

## True when `record` is a lucky bag with original rows.
static func is_bag(record: Dictionary) -> bool:
	var spec: Variant=NATIVE_FIELDS.full(record).get("source_use_spec",{}) if not record.is_empty() else {}
	return spec is Dictionary and str(spec.get("kind","")) in BAG_KINDS and not (spec.get("rewards",[]) as Array).is_empty()

## The bag's rows for class `class_id`: [{item_class_id, name, amount,
## percent (-1 for 확정), given}].
static func bag_rows(record: Dictionary, class_id: int) -> Array:
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	var denominator: int=int(spec.get("source_probability_denominator",0))
	if denominator<=0:denominator=int(spec.get("class_probability_totals",{}).get(str(class_id),0))
	var found: Array=[]
	for reward: Dictionary in spec.get("rewards",[]):
		if not ItemUse.class_matches(reward.get("class_ids",[]),class_id):continue
		var given: bool=int(reward.get("entity_type_id",0))==1
		var raw: int=int(reward.get("probability_raw",0)) if typeof(reward.get("probability_raw")) in [TYPE_INT,TYPE_FLOAT] else 0
		if not given and raw<=0:continue
		var item: Dictionary=DROPS.cached_definition(str(int(reward.item_class_id))).get("native_record",{})
		if item.is_empty():item=DROPS.definition_id(str(int(reward.item_class_id))).get("native_record",{})
		var enchant: int=int(reward.enchant) if reward.get("enchant")!=null else 0
		var name: String=str(NATIVE_FIELDS.field(item,"source_display_name",item.get("name","?")))
		found.append({"item_class_id":int(reward.item_class_id),"amount":int(reward.get("amount",1)),"given":given,
			"name":"%s%s%s" % ["+%d " % enchant if enchant>0 else "",str(BLESSING.get(int(reward.get("bless_raw",1)),"")),name],
			"percent":-1.0 if given else (100.0*float(raw)/float(denominator) if denominator>0 else -2.0)})
	return found

static func percent_text(percent: float) -> String:
	if percent<=-2.0:return "-"
	if percent<0.0:return "확정"
	return "%.6f%%" % percent

## `class_id`: the character's original ClassID (the item use's own filter).
func open(parent: Node, record: Dictionary, class_id: int) -> Dictionary:
	if not is_bag(record):return _fail("source_box_probability_not_a_bag")
	rows=bag_rows(record,class_id)
	if rows.is_empty():return _fail("source_box_probability_rows_empty")
	title=str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name","")))
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Btn_Back"]={"exclude":true}
	for name: String in ["Nd_Type01","Nd_Type02","Nd_Notice","Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[name]={"exclude":true}
	spec["Nd_Type03"]={"visible":true}
	spec["Nd_Title/Label"]={"role":"source_text","text":title if not title.is_empty() else "획득 가능 아이템"}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var specs: Array=[]
	for row: Dictionary in rows:
		var spec: Dictionary={"Panel/Nd_Special":{"visible":false},
			"Panel/Label_ItemName":{"role":"source_text","text":"%s ×%s" % [str(row.name),_number(int(row.amount))]},
			"Panel/Label_Probability":{"role":"source_text","text":percent_text(float(row.percent))},
			"Panel/Label_ItemDsc":{"visible":false}}
		spec["Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		for name: String in SLOT_EXCLUDED:spec["Common_Slot/"+name]={"exclude":true}
		spec["Common_Slot/Text_Amount"]={"visible":false}
		spec["Common_Slot/Btn"]={"activate":Callable(self,"_ignore")}
		specs.append({"member":ROW,"spec":spec})
	var placed: Dictionary=_fill_list(root,out,"Nd_Type03/ListView_ItemList",specs)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	for index: int in range(specs.size()):
		var icon: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Common_Slot/Sp_IconSample")
		var id: int=int(rows[index].item_class_id)
		if not icon.get("ok",false) or id<=0:continue
		var info: Dictionary=SourceImages.describe_item_class(id,str(rows[index].name))
		if _show_picture(icon.player,icon.offset,{"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}):pictures+=1
	return {"ok":true,"rows":specs.size(),"pictures":pictures}

## Only this window closes.
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
