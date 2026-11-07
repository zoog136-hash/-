extends RefCounted
## Exact original result roles for the actual existing card/phase owner.
## Metadata only: no texture decoder, renderer, phase clock or award logic.
const Families=preload("res://data/ui/base508_card_atlas.json")
const Current=preload("res://data/lineagem_base508/cards_patch523.json")
const GradeFrames=preload("res://scripts/ui/original_ui/source_main_card_frames.gd")
const SOURCE_API=preload("res://scripts/lineagem_base508.gd")
const RESULT="UI/Change/Change_Card_Result.csb"
const RESULT_SHA="846392b76ee58324528002be91665885a1466fb2b515e00e7d4c22ea69406ab1"
const GACHA="UI/Change/Change_Card_Gacha_Result.csb"
const GACHA_SHA="7b083ccf01c6a5038fe05a5ddb2d107be7ce45aeb9ffaeab2c9a34b95cdd862e"
const STAGE="UI/Change/Change_WinResult.csb"
const STAGE_SHA="c72f1dacbb855358c4ca25aa3326ffd565d4cd0bb6699ba02062521c7b153e7a"
const SPECIAL="UI/Mission/Mission_DungeonSpecial_Btn.csb"
const SPECIAL_SHA="289353c38b5f8efb7c3caf4913640819864f72c2868c327c71d97a5d4231462d"
const VARIANTS={
	"Sp_Card_Common":{"family":"Common","name":"Sp_Card_Common","fusion":[10856,3136],"draw":[16416,12600]},
	"Sp_Card_Rare":{"family":"Rare","name":"Sp_Card_Rare","fusion":[10572,2848],"draw":[16112,11996]},
	"Sp_Card_Unique":{"family":"Unique","name":"Sp_Card_Unique","fusion":[10288,2560],"draw":[15808,11392]},
	"Sp_Card_Legend":{"family":"legend","name":"Sp_Card_legend","fusion":[10004,2272],"draw":[15508,10792]},
	"Sp_Card_Epic":{"family":"Epic","name":"Sp_Card_Epic","fusion":[9720,1984],"draw":[15204,10188]}
}

static func selected_card(pack: RefCounted, actual_record: Dictionary, operation: String, phase: String) -> Dictionary:
	if operation not in ["fusion","draw"] or phase not in ["back","transition","front"]:return _missing("source_result_actual_operation_phase_required")
	if Families.data.table_evidence.Grade!=GradeFrames.GRADE_SHA or Current.data.source_table_sha256.Grade!=GradeFrames.GRADE_SHA:return _missing("source_result_grade_table_identity_required")
	var identity: Dictionary=current_card_identity(actual_record)
	if not identity.get("ok",false):return identity
	var grade: int=identity.grade_id
	var declared: Dictionary=Families.data.grade_bindings.get(str(grade),{})
	var variant: Variant=VARIANTS.get(declared.get("sprite_node",""))
	if not variant is Dictionary:return {"ok":false,"code":"source_result_original_grade_variant_absent","grade_id":grade,"source_id":identity.source_id,"default_variant_chosen":false}
	var member: String=RESULT if operation=="fusion" else GACHA
	var sha: String=RESULT_SHA if operation=="fusion" else GACHA_SHA
	var front: Dictionary=image_node(pack,member,sha,int(variant[operation][0]),"Sprite",str(variant.name),"ChangeImg/Card_Slot_"+str(variant.family)+".png",true)
	var back: Dictionary=image_node(pack,member,sha,int(variant[operation][1]),"Sprite",str(variant.name),"ChangeImg/Card_Slot_Back_"+str(variant.family)+".png",true)
	if not front.get("ok",false):return front
	if not back.get("ok",false):return back
	var tree: Dictionary=pack.layout_source(member)
	return {"ok":true,"schema":"twilight-original-result-card-roles-v1","source_id":identity.source_id,"grade_id":grade,"operation":operation,"phase":phase,"front":front,"back":back,"source_clips":tree.get("animationList",[]).duplicate(true),"source_action_duration":tree.get("action",{}).get("duration"),"phase_basis":"existing per-card Face.elapsed/duration and waiting_for_press; no source clip/seconds mapping","grade_basis":"existing UI grade-family declaration with identical current523 Grade SHA","whole_stage_background":false,"source_animation_started":false,"dynamic_csb_registration_asserted":false,"pixels_assigned":false}

static func current_card_identity(actual_record: Dictionary) -> Dictionary:
	var canonical: Dictionary=SOURCE_API.canonical(actual_record)
	var raw: Variant=canonical.get("source_original_card")
	var grade: Variant=canonical.get("source_grade_id")
	if canonical.is_empty() or canonical.get("sourceId")!=actual_record.get("sourceId") or canonical.get("source_snapshot")!="patch523" or not raw is Dictionary or not _positive(grade) or raw.get("GradeID")!=grade or raw.get("ID")!=canonical.get("source_card_id"):return _missing("source_result_actual_current_card_identity_required")
	return {"ok":true,"source_id":canonical.sourceId,"grade_id":int(grade)}

static func fusion_stage(pack: RefCounted, operation: String) -> Dictionary:
	if operation!="fusion":return _missing("source_result_draw_stage_parent_unestablished")
	var layers: Array=[]
	for spec: Array in [[8456,"Img_BG","ProductionImg/Sp_BG.png"],[8124,"Img_BG2","ProductionImg/ResultBG_B.png"]]:
		var layer: Dictionary=image_node(pack,STAGE,STAGE_SHA,int(spec[0]),"ImageView",str(spec[1]),str(spec[2]),true)
		if not layer.get("ok",false):return layer
		layers.append(layer)
	return {"ok":true,"operation":"fusion","member":STAGE,"source_sha256":STAGE_SHA,"background_layers":layers,"source_design_extent":[1200,675],"original_title":"합성 결과","requires_authored_tint_scale9_and_layer_order":true,"inner_card_background_11140_used":false,"parent_registration_established":false,"pixels_assigned":false}

static func special_entrance_target(pack: RefCounted) -> Dictionary:
	var target: Dictionary=image_node(pack,SPECIAL,SPECIAL_SHA,28700,"ImageView","Img_Special","Effect/Common_Effect_texture/Mission_Dummy.png",false)
	if not target.get("ok",false):return target
	if target.authored_widget.get("size")!=[154.0,262.0] or target.image_view.get("scale9Enabled")!=0:return _missing("source_special_original_image_view_shape_required")
	return {"ok":true,"role":"SpecialDungeon.EntranceAssetID","original_target":target,"sample_pixels_must_not_be_used":true,"runtime_target_registered":false,"missing_registration":"Mission_DungeonSpecial_Btn root Panel392 to Mission_Dungeon_Special ListView_Daily2560 item; ImageView static-asset receiver","ui_map_coordinates_used":false,"pixels_assigned":false}

static func image_node(pack: RefCounted, member: String, sha: String, offset: int, kind: String, name: String, path: String, active_required: bool) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(member,{}).get("sha256")!=sha:return _missing("source_result_component_identity_required",member)
	var tree: Dictionary=pack.scene(member) if active_required else pack.layout_source(member)
	var found: Array=[]
	_find(tree.get("nodeTree",{}),offset,[],found)
	if found.size()!=1:return _missing("source_result_original_target_scope_required",member)
	var node: Dictionary=found[0].node
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var ref: Variant=options.get("fileNameData")
	if node.get("classname")!=kind or widget.get("name")!=name or not ref is Dictionary or ref.get("path")!=path:return _missing("source_result_exact_original_role_required",member)
	return {"ok":true,"pack":pack,"manifest_sha256":pack.manifest_sha256,"member":member,"source_sha256":sha,"node_offset":offset,"node_type":kind,"node_name":name,"fileNameData":ref.duplicate(true),"authored_widget":widget.duplicate(true),"parent_chain":found[0].parents,"image_view":{"scale9Enabled":options.get("scale9Enabled"),"capInsets":options.get("capInsets"),"scale9Size":options.get("scale9Size")},"runtime_scope_required":active_required}

static func _find(node: Dictionary, offset: int, parents: Array, found: Array) -> void:
	if node.get("_offset")==offset:found.append({"node":node,"parents":parents.duplicate(true)})
	var options: Dictionary=node.get("options",{})
	var chain: Array=parents.duplicate()
	chain.append({"offset":node.get("_offset"),"type":node.get("classname"),"options":options.get("widgetOptions",options.get("nodeOptions",options)).duplicate(true)})
	for child: Dictionary in node.get("children",[]):_find(child,offset,chain,found)

static func _positive(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value)) and value>0

static func _missing(code: String, member: String="") -> Dictionary:
	return {"ok":false,"code":code,"member":member,"pixels_assigned":false}
