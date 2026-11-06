extends RefCounted
## Explicit surface bindings into the already selected original UI pack.
## No grade/name/path guessing, generated art, legacy atlas, or new selection.
const Selection=preload("res://scripts/ui/original_ui/source_main_selection.gd")
const SOURCE_API="res://scripts/lineagem_base508.gd"
const Roles: Array[String]=["reveal_back","reveal_background","fusion_background","awakening_background","grade_frame"]
static var _bindings: Dictionary={}

static func _missing(role: String, reason: String) -> Dictionary:
	return {"ok":false,"status":reason,"role":role,"texture":null,"actual_game_consumption_observed":false}

static func _selected_identity() -> Array[String]:
	var root: String=OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-ui="):root=argument.trim_prefix("--source-ui=")
		elif argument.begins_with("--source-ui-sha256="):sha=argument.trim_prefix("--source-ui-sha256=")
	return [root,sha]

static func _nodes(node: Dictionary, offset: int, found: Array[Dictionary]) -> void:
	if node.get("_offset")==offset:found.append(node)
	for child: Dictionary in node.get("children",[]):_nodes(child,offset,found)

static func bind(role: String, member: String, member_sha256: String, node_offset: int, grade_id: int=0) -> Dictionary:
	# The original UI owner must provide the real semantic role and exact node.
	# This API never assigns one of the main HUD's unrelated images to a card.
	if role not in Roles or node_offset<=0 or (role=="grade_frame" and grade_id<=0) or (role!="grade_frame" and grade_id!=0):return _missing(role,"source_card_surface_exact_role_and_identity_required")
	var selected: Dictionary=Selection.selected_pack()
	if not selected.get("ok",false) or not selected.get("selected",false):return _missing(role,"source_card_surface_selected_original_ui_required")
	var pack: RefCounted=selected.pack
	var entry: Dictionary=pack.manifest.get("files",{}).get(member,{})
	var scene: Dictionary=pack.scene(member)
	if entry.get("sha256")!=member_sha256 or member_sha256.length()!=64 or scene.get("_source_sha256")!=member_sha256:return _missing(role,"source_card_surface_scene_identity_required")
	var scope: Variant=pack.manifest.get("node_scopes",{}).get(member)
	if scope is Array and not scope.has(node_offset):return _missing(role,"source_card_surface_node_outside_selected_scope")
	var found: Array[Dictionary]=[]
	_nodes(scene.get("nodeTree",{}),node_offset,found)
	if found.size()!=1 or found[0].get("classname") not in ["Sprite","ImageView"]:return _missing(role,"source_card_surface_unique_original_image_node_required")
	var options: Dictionary=found[0].get("options",{})
	var reference: Variant=options.get("fileNameData")
	if not reference is Dictionary or str(reference.get("path","")).is_empty():return _missing(role,"source_card_surface_original_fileNameData_required")
	var texture: Texture2D=pack.texture(reference,true)
	if texture==null:return _missing(role,"source_card_surface_original_pixels_unavailable")
	var key: String=role+":"+str(grade_id)
	_bindings[key]={"pack":pack,"texture":texture,"selection":_selected_identity(),"role":role,"source_grade_id":grade_id,"member":member,"member_sha256":member_sha256,"node_offset":node_offset,"source_field":"fileNameData","reference":reference.duplicate(true),"manifest_sha256":pack.manifest_sha256}
	return {"ok":true,"role":role,"registered":true,"rendered":false}

static func resolve(role: String, record: Dictionary={}) -> Dictionary:
	if role not in Roles:return _missing(role,"source_card_surface_role_unsupported")
	var grade_id: int=0
	if role=="grade_frame":
		# Current523 preserves m508 saved identities in the actual card model.
		# Its source label is ABI, not permission to load a historical frame.
		if record.get("source") not in ["lineagem_base508","lineagem_patch523"] or not ResourceLoader.exists(SOURCE_API):return _missing(role,"source_card_surface_original_card_identity_required")
		var api: Script=load(SOURCE_API)
		var canonical: Dictionary=api.canonical(record) if api!=null else {}
		if canonical.is_empty() or canonical.get("source_snapshot")!="patch523" or canonical.get("sourceId")!=record.get("sourceId"):return _missing(role,"source_card_surface_current_card_definition_required")
		var original: Variant=canonical.get("source_original")
		if not original is Dictionary or original.get("source_snapshot")!="patch523" or original.get("card_id")!=canonical.get("source_card_id") or original.get("grade_id")!=canonical.get("source_grade_id"):return _missing(role,"source_card_surface_current_card_definition_required")
		var source_grade: Variant=canonical.get("source_grade_id")
		if typeof(source_grade) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(source_grade)) or float(source_grade)!=floor(float(source_grade)) or source_grade<=0:return _missing(role,"source_card_surface_original_grade_identity_required")
		grade_id=int(source_grade)
	var binding: Dictionary=_bindings.get(role+":"+str(grade_id),{})
	if binding.is_empty():return _missing(role,"source_card_surface_original_node_role_pending")
	if binding.selection!=_selected_identity():return _missing(role,"source_card_surface_selection_changed_rebind_required")
	var evidence: Dictionary=binding.duplicate()
	evidence.erase("texture");evidence.erase("pack");evidence.erase("selection")
	if role=="grade_frame":
		evidence["caller_card_identity"]=str(record.get("sourceId",""))
		evidence["grade_basis"]="current523_canonical_card_and_preserved_original_grade_id"
	return {"ok":true,"status":"original","role":role,"texture":binding.texture,"provenance":evidence,"actual_game_consumption_observed":false}
