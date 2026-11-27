extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 재화 정보 window: Gem_All (frame, title, close), opened by
## the HUD wallet's own Btn_Info (Hud_PayLayout). Each currency the game keeps
## (renewal_hud.currency_balances plus Adena: 아데나, 다이아, 명예 코인, 변신 /
## 마법인형 / 성물 제작 코인) is one Gem_List row: the currency item's own
## original icon in the Common_Slot picture (the inventory's item record and
## SourceImages.describe_item), its name and the held amount.
## Left empty (no TWILIGHT data): the acquisition places (Gem_All_Location,
## Gem_Popup_Source), the tooltip and lock / shop buttons, the help tooltip
## (Gem_ToolTip_Help), and a currency whose original icon is not known.
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT=preload("res://scripts/ui/original_ui/source_main_wallet_bindings.gd").CURRENCY_INFO_MEMBER
const ROW="UI/FloatingUi/Gem_List.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## The currencies the existing HUD keeps, in its own order.
const CURRENCIES: Array[String]=["아데나","다이아","명예 코인","변신 제작 코인","마법인형 제작 코인","성물 제작 코인"]
## Common_Slot keeps its button, frame and picture.
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Text_Amount","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]

func required_members() -> Array[String]:
	return [ROOT,ROW,SLOT]

func _root_member() -> String:
	return ROOT

## Gem_All_Layout sits at (191.3, 345) in FloatingUiScene.
func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func open(parent: Node) -> Dictionary:
	if hud()==null or world()==null:return _fail("source_currency_window_runtime_unavailable")
	return open_window(parent)

## {name: amount} of the existing balances (Adena from the world's gold).
func balances() -> Dictionary:
	var owner: Object=hud()
	var game: Object=world()
	var held: Variant=owner.get("currency_balances") if owner!=null else null
	var result: Dictionary={}
	for name: String in CURRENCIES:
		if name=="아데나":result[name]=int(game.get("gold")) if game!=null and game.get("gold")!=null else 0
		else:result[name]=int(held.get(name,0)) if held is Dictionary else 0
	return result

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Btn_HelpBox","Gem_All_Location","Gem_Popup_Source","Gem_ToolTip_Help"]:spec[name]={"exclude":true}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var amounts: Dictionary=balances()
	var rows: Array=[]
	for name: String in CURRENCIES:
		var record: Variant=world().call("_find_catalog_item_record",name) if world().has_method("_find_catalog_item_record") else null
		var info: Dictionary=SourceImages.describe_item(record,name) if record is Dictionary and not record.is_empty() else {}
		var id: int=int(info.get("item_class_id",0))
		var spec: Dictionary={"Panel/Label_Name":{"role":"source_text","text":name},
			"Panel/Label_Amount":{"role":"source_text","text":_number(int(amounts[name]))},
			"Panel/Nd_Tooltip":{"exclude":true},"Panel/Nd_BtnSet":{"exclude":true},
			"Common_Slot/Btn":{"activate":_open_item_info.bind(id),"displaystate":id>0},
			"Common_Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false}}
		for node: String in SLOT_EXCLUDED:spec["Common_Slot/"+node]={"exclude":true}
		rows.append({"member":ROW,"spec":spec,"info":info})
	var placed: Dictionary=_fill_list(root,out,"ListView",rows)
	if not placed.get("ok",false):return placed
	var icons: int=0
	for index: int in range(rows.size()):
		var icon: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Common_Slot/Sp_IconSample")
		if icon.get("ok",false) and _show_item_icon(icon.player,icon.offset,rows[index].info):icons+=1
	return {"ok":true,"rows":rows.size(),"icons":icons,"amounts":amounts}
