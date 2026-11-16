extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 제작 결과 window (ProductionResultScene /
## Production_Result) for one finished craft of the existing crafting
## (world.crafting_log's last entry, opened by source_main_production_window
## after its own 제작). It shows what the craft already saved; nothing here
## rolls, pays or stores.
## - Nd_Info: 대성공 / 성공 / 실패 counts: an outcome recipe's label (the
##   original ItemCraftOutputTypeID 0 실패 / 1 성공 / 2 대성공, matched by the
##   produced item), otherwise 성공 × batches;
## - ListView_Item: one Production_Result_List row (the item's original
##   picture, name ×quantity), none for 지급 없음;
## - 확 인 closes it.
## Left out: Skip (no reveal to skip here), the reveal effects and particles.
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT="UI/ProductionResultScene.csb"
const RESULT="UI/Production/Production_Result.csb"
const ROW="UI/Production/Production_Result_List.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const P="Production_Result_Layout/"
const LABELS: Array[String]=["대성공","성공","실패"]
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Text_Amount","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
var result: Dictionary={}

func required_members() -> Array[String]:
	return [ROOT,RESULT,ROW,SLOT]

func _root_member() -> String:
	return ROOT

## ProductionResultScene is laid out on the 1200x675 design frame.
func _root_position() -> Vector2:
	return Vector2.ZERO

## `craft`: {name, quantity, batch, label (대성공 / 성공 / 실패 or ""),
## item_class_id}.
func open(parent: Node, craft: Dictionary) -> Dictionary:
	result=craft.duplicate(true)
	return open_window(parent)

## {대성공, 성공, 실패} counts of one craft.
static func counts(craft: Dictionary) -> Dictionary:
	var found: Dictionary={"대성공":0,"성공":0,"실패":0}
	var label: String=str(craft.get("label",""))
	if int(craft.get("quantity",0))<=0:label="실패"
	if label.is_empty():
		found["성공"]=maxi(1,int(craft.get("batch",1)))
	elif found.has(label):
		found[label]=1
	return found

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec[P+"Nd_BG/Img_BG"]={"role":"consume"}
	spec[P+"Nd_BG/Fx_Particle"]={"exclude":true}
	spec[P+"Fx_Active"]={"exclude":true}
	spec[P+"Btn_Skip"]={"exclude":true}
	spec[P+"Btn_Ok"]={"activate":Callable(self,"_close_requested")}
	spec[P+"Nd_Floating_Result/Img_Touchable"]={"role":"consume"}
	for fx: String in ["Fx_LineGlow","Fx_LineGlow_1","Fx_LineGlow_1_0"]:spec[P+"Nd_Info/"+fx]={"exclude":true}
	var found: Dictionary=counts(result)
	for index: int in range(LABELS.size()):
		spec[P+"Nd_Info/Fx_Text_%02d/Text_Info_%d_Value" % [index+1,index+1]]={"role":"source_text","text":"%d회" % int(found[LABELS[index]])}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var rows: Array=[]
	if int(result.get("quantity",0))>0:
		var spec: Dictionary={"Panel_Result_List/Label_Item":{"role":"source_text","text":"%s ×%s" % [str(result.get("name","")),_number(int(result.quantity))]},"Fx_Point":{"exclude":true}}
		spec["Production_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		for name: String in SLOT_EXCLUDED:spec["Production_Slot/"+name]={"exclude":true}
		spec["Production_Slot/Btn"]={"activate":Callable(self,"_ignore")}
		rows.append({"member":ROW,"spec":spec})
	var placed: Dictionary=_fill_list(root,out,P+"Nd_Floating_Result/ListView_Item",rows)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	# The row fades in with the client's own Fx_Result_Active clip (its start
	# keyframe is transparent).
	for scene: Node2D in placed.scenes:scene.play("Fx_Result_Active",false)
	if not rows.is_empty():
		var icon: Dictionary=_locate(placed.scenes[0],placed.outs[0],"Production_Slot/Sp_IconSample")
		var id: int=int(result.get("item_class_id",0))
		if icon.get("ok",false) and id>0:
			var info: Dictionary=SourceImages.describe_item_class(id,str(result.get("name","")))
			if _show_picture(icon.player,icon.offset,{"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}):pictures+=1
	return {"ok":true,"rows":rows.size(),"counts":counts(result),"pictures":pictures}

## 확 인: only this window closes (the 제작 window stays).
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
