extends RefCounted
## UI-owned node roles registered with the existing image-owner surface API.
## Metadata reuse only: never load the retired atlas pack or infer a grade.
const Surfaces=preload("res://scripts/ui/original_card_surfaces.gd")
const GradeBindings=preload("res://data/ui/base508_card_atlas.json")
const CurrentCards=preload("res://data/lineagem_base508/cards_patch523.json")
const Layout=preload("res://data/ui/base508_card_layout.json")
const GRADE_SHA="7ccc62ce1c95ff02cb833e09a68469a1f66ff739db0ada613e4fd498226984da"
const SOURCES={
	"UI/Change/Change_Card_A_Common.csb":{"sha":"a98120fedf60c03ed6b1a8347e3ce6ad8cd95b6ebdf4d87fb29b4bd1fc36b1e4","offset":2520},
	"UI/Change/Change_Card_A_Rare.csb":{"sha":"e1a45e737e107e49a6fbc87753dc56303883b9670d0a4cd06cd93db7169f88f2","offset":2524},
	"UI/Change/Change_Card_A_Unique.csb":{"sha":"80c492f2f35f9a021987a8366013e1b36df15a8ead6d224375f2279dbbd92ac8","offset":2568},
	"UI/Change/Change_Card_A_Legend.csb":{"sha":"dfdd5f57b20a100b321b3c97114e8e4fbb82960ec310f0ef894b8f47567348af","offset":2568},
	"UI/Change/Change_Card_A_Epic.csb":{"sha":"ff34c845841a818909497632ff6b1d485609039dede8ece1c03738346788613d","offset":2568},
	"UI/Change/Change_Card_A_Myth.csb":{"sha":"1dcc3c2bbe32ca9ca085af9611750bd329d9ddc0cc5665d6cd73ef450f52312a","offset":2564},
	"UI/Change/Change_Card_A_Sole.csb":{"sha":"675ef6e6628743034e2f19992b96354f1dfd00af6a445df676dea5a18350fe10","offset":2596}
}

static func bind(pack: RefCounted) -> Dictionary:
	if pack==null:return {"ok":false,"code":"source_card_frames_selected_pack_required"}
	# This existing UI family binding and the current523 card projection
	# reference byte-identical Grade rows. Do not use a localized label/rank.
	if GradeBindings.data.get("table_evidence",{}).get("Grade")!=GRADE_SHA or CurrentCards.data.get("source_table_sha256",{}).get("Grade")!=GRADE_SHA:return {"ok":false,"code":"source_card_frames_grade_identity_required"}
	var registered: Array=[]
	var unavailable: Array=[]
	for key: String in GradeBindings.data.grade_bindings:
		var declaration: Dictionary=GradeBindings.data.grade_bindings[key]
		var role: Dictionary=_role(pack,key,declaration)
		if not role.get("ok",false):unavailable.append(role);continue
		# The image owner decodes pixels and binds its existing grade_frame
		# consumer. This helper supplies identities, never another renderer.
		var result: Dictionary=Surfaces.bind("grade_frame",role.member,role.sha256,role.node_offset,role.grade_id)
		if not result.get("ok",false):unavailable.append({"grade_id":role.grade_id,"member":role.member,"owner_result":result});continue
		registered.append(role)
	return {"ok":not registered.is_empty(),"registered":registered,"unavailable":unavailable,"role":"grade_frame","consumer":"existing catalog_card_chrome texture_for/selected-preview frame","basis":"existing explicit UI grade-family binding; current523 Grade table SHA identical","grade_table_sha256":GRADE_SHA,"result_screen_background_bound":false,"dynamic_csb_registration_asserted":false,"actual_game_consumption_observed":false}

static func _role(pack: RefCounted, key: String, declaration: Dictionary) -> Dictionary:
	if not key.is_valid_int() or int(key)<=0 or declaration.get("grade",{}).get("ID")!=int(key):return {"ok":false,"code":"source_card_frames_exact_grade_required"}
	var member: String=str(declaration.get("prefab",""))
	if not SOURCES.has(member):return {"ok":false,"code":"source_card_frames_pinned_component_required","grade_id":int(key)}
	var identity: Dictionary=SOURCES[member]
	if pack.manifest.get("files",{}).get(member,{}).get("sha256")!=identity.sha:return {"ok":false,"code":"source_card_frames_active_component_identity_required","grade_id":int(key),"member":member}
	var scene: Dictionary=pack.scene(member)
	var scope: Variant=pack.manifest.get("node_scopes",{}).get(member)
	if scope is Array and not scope.has(identity.offset):return {"ok":false,"code":"source_card_frames_active_node_scope_required","grade_id":int(key),"member":member}
	var node: Dictionary=_find(scene.get("nodeTree",{}),int(identity.offset))
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",{})
	if node.get("classname")!="Sprite" or widget.get("name")!=declaration.get("sprite_node"):return {"ok":false,"code":"source_card_frames_original_node_role_required","grade_id":int(key)}
	var prior: Array=[]
	for candidate: Dictionary in Layout.data.screens.get(member,[]):
		if candidate.get("name")==declaration.sprite_node and candidate.get("table_offset")==identity.offset:
			for prior_ref: Dictionary in candidate.get("resources",[]):
				if prior_ref.get("field")=="fileNameData":prior.append(prior_ref)
	var resource_ref: Variant=options.get("fileNameData")
	if prior.size()!=1 or not resource_ref is Dictionary:return {"ok":false,"code":"source_card_frames_existing_reference_required","grade_id":int(key)}
	for field: String in ["path","plistFile","resourceType"]:
		if prior[0].get(field)!=resource_ref.get(field):return {"ok":false,"code":"source_card_frames_existing_reference_changed","grade_id":int(key)}
	return {"ok":true,"grade_id":int(key),"member":member,"sha256":identity.sha,"node_offset":identity.offset,"source_node_name":widget.name,"reference":resource_ref.duplicate(true),"authored_anchor":widget.get("anchorPoint"),"authored_position":widget.get("position"),"authored_size":widget.get("size"),"event":"read-only surface registration; no input callback"}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_find(child,offset)
		if not found.is_empty():return found
	return {}
