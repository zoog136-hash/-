extends RefCounted
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
## The original 523 grade light of a revealed card, for the windows that show
## a card result in the client cell Change_Fusion_Card (BM_Gacha 카드 뽑기,
## CardChange_Result 다시 뽑기 확정, Change_Fusion_All 합성 결과).
## Change_Fusion_Card leaves two ProjectNodes without a file (Fx_Glow/
## Fx_Greade and Fx_Result_Start): the client fills them per grade with its
## Fx_Change_ActiveGreade_<grade> and Fx_Change_Active_<grade> scenes
## (UI/Change, clip Fx_Active each), shows Fx_Outline_Front
## (Fx_Change_Outline_Loop, a loop clip per grade) and plays the cell's own
## Fx_Start_Active flash. The scenes, clips and grade names are the client's;
## which grades light up (영웅 이상, user request 2026-11-20) and the order of
## the clips are TWILIGHT 근사 (the client code that picks them is not in the
## data). Grade names: Change_Card_A_<name> as source_main_change_page.
const LIGHT_GRADES: Array[String]=["영웅","전설","신화","유일"]
const ACTIVE_GRADE={"영웅":"UI/Change/Fx_Change_ActiveGreade_Legend.csb","전설":"UI/Change/Fx_Change_ActiveGreade_Epic.csb",
	"신화":"UI/Change/Fx_Change_ActiveGreade_Myth.csb","유일":"UI/Change/Fx_Change_ActiveGreade_Sole.csb"}
const ACTIVE={"영웅":"UI/Change/Fx_Change_Active_Legend.csb","전설":"UI/Change/Fx_Change_Active_Epic.csb",
	"신화":"UI/Change/Fx_Change_Active_Myth.csb","유일":"UI/Change/Fx_Change_Active_Sole.csb"}
## Fx_Change_Outline_Loop clips.
const OUTLINE={"영웅":"Fx_Legend_Loop","전설":"Fx_Epic_Loop","신화":"Fx_Myth_Loop","유일":"Fx_Sole_Loop"}
const CLIP="Fx_Active"
const CELL_CLIP="Fx_Start_Active"
## Change_Fusion_Card nodes a result cell never shows (the roulette, the
## amount badge and the waiting loops belong to the client's draw states).
const CELL_HIDDEN: Array[String]=["Card_Roultte","Nd_info","Fx_Result_Loop_1","Panel/Fx_Result_Loop_2"]
## The light nodes; the two empty ProjectNodes are always left out (their
## scenes are mounted at their place by light()).
const CELL_LIGHT: Array[String]=["Fx_Glow","Fx_Outline_Front"]
const CELL_EMPTY: Array[String]=["Fx_Glow/Fx_Greade","Fx_Result_Start"]
## The actual frame-sheet Sprite in each Fx_Change_ActiveGreade member.
## Other nodes in those scenes draw the grade glow and card outline.
const LIGHTNING_SPRITES={"영웅":872,"전설":2740,"신화":2752,"유일":2756}
const FACE_NAME="SourceAwardFace"

static func lit(grade: String) -> bool:
	return grade in LIGHT_GRADES

## The scene members of the light (the UI pack carries them from ui43 on).
static func members() -> Array[String]:
	var found: Array[String]=[]
	for grade: String in LIGHT_GRADES:
		found.append(str(ACTIVE_GRADE[grade]))
		found.append(str(ACTIVE[grade]))
	return found

## True when the window's pack has the light scenes of `grade`.
static func available(window: Object, grade: String) -> bool:
	if not lit(grade):return false
	var pack: Variant=window.get("_pack")
	if pack==null:return false
	var scenes: Dictionary=pack.manifest.get("scenes",{})
	return scenes.has(str(ACTIVE_GRADE[grade])) and scenes.has(str(ACTIVE[grade]))

## Spec entries for the Change_Fusion_Card at `prefix` (ends with "/").
static func cell_spec(window: Object, spec: Dictionary, prefix: String, grade: String, pending: bool=false) -> void:
	for name: String in CELL_HIDDEN+CELL_EMPTY:spec[prefix+name]={"exclude":true}
	if not available(window,grade):
		for name: String in CELL_LIGHT:spec[prefix+name]={"exclude":true}
	else:
		spec[prefix+"Fx_Outline_Front"]={"visible":not pending}

static func cell_node(window: Object, root: Node2D, out: Dictionary, path: String) -> Node2D:
	var located: Dictionary=window._locate(root,out,path)
	return located.player.source_nodes.get(located.offset) as Node2D if located.get("ok",false) else null

static func set_visible(window: Object, root: Node2D, out: Dictionary, path: String, value: bool) -> void:
	var node: Node2D=cell_node(window,root,out,path)
	if node!=null:node.visible=value

static func prepare_face(window: Object, root: Node2D, out: Dictionary, cell: String, card: Dictionary, shown: bool) -> Dictionary:
	var grade: String=str(card.get("grade",""))
	var panel: Node2D=cell_node(window,root,out,cell+"/Panel")
	if panel==null or not Page.GRADE_MEMBERS.has(grade) or window.get("_pack")==null:return {"ok":true,"picture":false}
	var face_out: Dictionary={}
	var spec: Dictionary={"Panel_Root":{"role":"consume"},"Panel_Root/CB_Check":{"exclude":true},
		"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},"Nd_Character/CardSample_A":{"exclude":true},
		"Panel_Root/Panel_Fx":{"exclude":true},"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}
	var face: Dictionary=window._scene_of(str(Page.GRADE_MEMBERS[grade]),spec,face_out)
	if not face.get("ok",false):return face
	face.scene.name=FACE_NAME
	face.scene.visible=shown
	panel.add_child(face.scene)
	var target: Dictionary=window._locate(face.scene,face_out,"Nd_Character/CardSample")
	if not target.get("ok",false):return {"ok":true,"picture":false}
	var detail: Dictionary=Presentation.detail(card,true,false)
	if detail.get("status")!="original" or not detail.get("texture") is Texture2D:return {"ok":true,"picture":false}
	detail["ok"]=true
	return {"ok":true,"picture":window._show_picture(target.player,target.offset,detail)}

static func finish_reel(window: Object, root: Node2D, out: Dictionary, cell: String) -> void:
	var panel: Node2D=cell_node(window,root,out,cell+"/Panel")
	if panel!=null:
		panel.show()
		var face: Node2D=panel.get_node_or_null(FACE_NAME)
		if face!=null:face.show()
	set_visible(window,root,out,cell+"/Text_Card_Name",true)

## Scope the discharge to the verified texture track. No grade border,
## particles or replacement images are created for the reel.
static func prepare_lightning(pack: RefCounted, grade: String) -> Node2D:
	if pack==null or not LIGHTNING_SPRITES.has(grade):return null
	var member: String=ACTIVE_GRADE[grade]
	if not pack.manifest.get("scenes",{}).has(member):return null
	var scope: Array[int]=[int(LIGHTNING_SPRITES[grade])]
	var scene:=Scene.new()
	var built: Dictionary=scene.configure_nodes(pack,member,scope,{})
	if not built.get("ok",false):
		scene.free()
		return null
	scene.name="SourceCardLightning"
	scene.hide()
	return scene

## Mounts and plays the grade light in the built cell at `prefix` (no "/"):
## {lit, scenes}. Nothing changes for a grade below 영웅 or without the scenes.
static func light(window: Object, root: Node2D, out: Dictionary, prefix: String, grade: String, include_lightning: bool=true) -> Dictionary:
	if not available(window,grade):return {"lit":false}
	var scenes: int=0
	var glow: Dictionary=window._locate(root,out,prefix+"/Fx_Glow")
	var cell: Dictionary=window._locate(root,out,prefix)
	var layers: Array=[[cell,str(ACTIVE[grade])]]
	if include_lightning:layers.push_front([glow,str(ACTIVE_GRADE[grade])])
	for pair: Array in layers:
		var located: Dictionary=pair[0]
		if not located.get("ok",false):continue
		var host: Variant=located.player.source_nodes.get(located.offset)
		if not host is Node2D:continue
		var fx_out: Dictionary={}
		var built: Dictionary=window._scene_of(str(pair[1]),{},fx_out)
		if not built.get("ok",false):continue
		(host as Node2D).add_child(built.scene)
		if built.scene.play(CLIP,false).get("ok",false):scenes+=1
	var nested: Node2D=project(window,root,out,prefix)
	# The flash, then the name (Fx_Start_Active ends with Text_Card_Name clear).
	if nested!=null:chain(nested,CELL_CLIP,"Fx_Cardname")
	var outline: Node2D=project(window,root,out,prefix+"/Fx_Outline_Front")
	if outline!=null:
		set_visible(window,root,out,prefix+"/Fx_Outline_Front",true)
		outline.play(str(OUTLINE[grade]),true)
	return {"lit":scenes>0,"scenes":scenes}

## The nested player of the ProjectNode at `suffix`.
static func project(window: Object, root: Node2D, out: Dictionary, suffix: String) -> Node2D:
	var located: Dictionary=window._locate(root,out,suffix)
	if not located.get("ok",false):return null
	var node: Node=located.player.source_nodes.get(located.offset)
	var nested: Variant=node.get_meta("source_project_player") if node!=null and node.has_meta("source_project_player") else null
	return nested if nested is Node2D else null

## Plays `first`, then `then` once `first` has run its length (60 frames a
## second, the clip's own speed).
static func chain(player: Node2D, first: String, then: String) -> void:
	if not player.play(first,false).get("ok",false):
		player.play(then,false)
		return
	var length: float=0.0
	for clip: Dictionary in player.source_tree.get("animationList",[]):
		if clip.name==first:length=float(clip.endIndex)-float(clip.startIndex)
	var speed: float=maxf(0.01,float(player.source_tree.get("action",{}).get("speed",1.0)))
	var ref: WeakRef=weakref(player)
	var tree: SceneTree=Engine.get_main_loop() as SceneTree
	tree.create_timer(length/60.0/speed).timeout.connect(func() -> void:
		var live: Variant=ref.get_ref()
		if live!=null and is_instance_valid(live):live.play(then,false))
