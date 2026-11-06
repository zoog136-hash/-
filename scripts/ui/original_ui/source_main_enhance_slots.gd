extends RefCounted
## Explicit TWILIGHT host registration, not a recovered original controller.
## Supplied paired source Projects + official before/after guide + actual Forge inputs.
const Images=preload("res://scripts/ui/source523_image_assets.gd")
const MEMBER="UI/FloatingUi/Enchant_All.csb"
const SHA="5a22899447b7b750c01e500beba49d80d081d65669bfc77c91309fe58946face"
const COMMON="UI/CommonUi/Common_Slot.csb"
const COMMON_SHA="b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6"
const PROJECTS={"scroll":145044,"equipment":144788}
const PLUS=144460
const ICON=15012
const BUTTON=15728
const BACKGROUND=15316
const BASIS={"kind":"TWILIGHT_host_registration","original_controller_binding_recovered":false,"source_parent":"Node2100/Nd_Common142656/Nd_Slot144400","guide":"https://lm.ncsoft.jp/guides/lm/guides/item_enchant","guide_evidence":"weapon/armor before-and-after: selected scroll left, actual selected equipment right; original source pair and existing Forge typed inputs used together, not coordinates alone","original_geometry_modified":false,"original_callback_or_clip_policy_inferred":false}
var _forge: WeakRef
var _players: Dictionary={}
var _legacy: Dictionary={}
var _signature: int=0
var _cached: bool=false
var _status: Dictionary={}

func build(pack: RefCounted, forge: Control) -> Dictionary:
	for spec: Array in [[MEMBER,SHA],[COMMON,COMMON_SHA]]:
		if pack==null or pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return _fail("enhance_slots_original_identity_required")
	var tree: Dictionary=pack.scene(MEMBER)
	var bindings: Dictionary={}
	for role: String in PROJECTS:
		var node: Dictionary=_node_at(tree.get("nodeTree",{}),PROJECTS[role])
		if node.get("classname")!="ProjectNode" or node.get("options",{}).get("fileName")!="CommonUi/Common_Slot.csb":return _fail("enhance_slots_original_pair_not_in_selected_scope")
		bindings[PROJECTS[role]]={"role":"project","visible":true,"source_node_offsets":[BUTTON,BACKGROUND,ICON],"bindings":{BUTTON:{"role":"button","activate":Callable(),"displaystate":false},ICON:{"role":"source_asset_slot","visible":false}}}
	var scope: Array=PROJECTS.values()
	var plus: Dictionary=_node_at(tree.get("nodeTree",{}),PLUS)
	if plus.get("classname")=="Sprite" and plus.get("options",{}).get("fileNameData",{}).get("path")=="Com_Icn_Plus.png" and plus.options.fileNameData.get("plistFile")=="UI_Resource/Atlas_Common.plist":scope.append(PLUS)
	_forge=weakref(forge)
	var snapshot: Dictionary=_snapshot()
	if not snapshot.get("ok",false):_forge=null;return snapshot
	for role: String in PROJECTS:
		var view: TextureRect=forge.scroll_icon if role=="scroll" else forge.preview
		_legacy[role]={"view":weakref(view),"visible":view.visible,"replaced":false}
	return {"ok":true,"source_node_offsets":scope,"source_plus_connected":scope.has(PLUS),"bindings":bindings,"registration":BASIS.duplicate(true),"partial_source_scene":true}

func bind_renderer(renderer: Node2D) -> Dictionary:
	if not is_instance_valid(renderer) or renderer.get("source_member")!=MEMBER:return _fail("enhance_slots_actual_source_renderer_required")
	for role: String in PROJECTS:
		var child: Dictionary=renderer.project_player([PROJECTS[role]])
		if not child.get("ok",false) or child.player.get("source_member")!=COMMON or not child.player.source_nodes.has(ICON):return _fail("enhance_slots_actual_nested_receiver_required")
		_players[role]=weakref(child.player)
	return {"ok":true,"registration":BASIS.duplicate(true)}

func refresh() -> Dictionary:
	var snapshot: Dictionary=_snapshot()
	if not snapshot.get("ok",false):clear();return snapshot
	var reader: RefCounted=Images.active()
	var signature: int=hash([snapshot.scroll,snapshot.equipment,snapshot.scroll_record,snapshot.equipment_record,reader.get_instance_id() if reader!=null else 0])
	if _cached and signature==_signature:return _status.duplicate(true)
	clear()
	var results: Dictionary={}
	for role: String in PROJECTS:
		var player: Node2D=_players[role].get_ref() if _players.has(role) else null
		if not is_instance_valid(player) or player.is_queued_for_deletion():return _fail("enhance_slots_live_nested_receiver_required")
		var record: Dictionary=snapshot[role+"_record"]
		# This is the existing image owner's exact original ItemClass/Icon/Asset path.
		# A CSB icon without its separate established registration remains pending.
		var image: Dictionary=Images.describe_item(record,str(record.get("name","")))
		if not image.get("ok",false) or image.get("route")!="source523_images" or image.get("status")!="original_linked" or image.get("original_bytes_unchanged")!=true or not image.get("texture") is Texture2D:
			var pending: Dictionary=image.duplicate(true);pending.erase("texture")
			results[role]={"assigned":false,"owner_result":pending}
			continue
		var owner_result: Dictionary=image.duplicate(true)
		var assigned: Dictionary=player.set_bound_source_visual_result(ICON,owner_result)
		if assigned.get("ok",false):assigned=player.set_bound_visible(ICON,true)
		var evidence: Dictionary=image.duplicate(true);evidence.erase("texture")
		results[role]={"assigned":assigned.get("ok",false),"image":evidence,"receiver_result":assigned}
		if assigned.get("ok",false):
			var view: Object=_legacy[role].view.get_ref()
			if is_instance_valid(view):view.hide();_legacy[role].replaced=true
	_signature=signature;_cached=true
	_status={"ok":true,"target_reference":snapshot.equipment,"scroll_reference":snapshot.scroll,"roles":results,"registration":BASIS.duplicate(true),"game_state_written":false,"runtime_rendering_verified":false}
	return _status.duplicate(true)

func receiver(role: String) -> Dictionary:
	if not PROJECTS.has(role):return _fail("enhance_slots_unknown_host_role")
	var snapshot: Dictionary=_snapshot()
	if not snapshot.get("ok",false):return snapshot
	var player: Node2D=_players[role].get_ref() if _players.has(role) else null
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree():return _fail("enhance_slots_live_receiver_required")
	return {"ok":true,"player":player,"host_role":role,"source_member":COMMON,"source_sha256":COMMON_SHA,"node_offset":ICON,"parent_member":MEMBER,"parent_sha256":SHA,"project_path":[724,PROJECTS[role]],"actual_scroll_reference":snapshot.scroll,"actual_target_reference":snapshot.equipment,"record":snapshot[role+"_record"].duplicate(true),"registration":BASIS.duplicate(true),"csb_icon_root_registration_confirmed":false,"runtime_rendering_verified":false}

func invalidate_images() -> void:
	_cached=false

func clear() -> void:
	for role: String in PROJECTS:
		var player: Node2D=_players[role].get_ref() if _players.has(role) else null
		if is_instance_valid(player) and not player.is_queued_for_deletion():player.clear_bound_source_image(ICON)
		if _legacy.has(role) and _legacy[role].replaced:
			var view: Object=_legacy[role].view.get_ref()
			if is_instance_valid(view):view.visible=_legacy[role].visible
			_legacy[role].replaced=false
	_cached=false;_status.clear()

func close() -> void:
	clear();_players.clear();_legacy.clear();_forge=null

func _snapshot() -> Dictionary:
	var forge: Object=_forge.get_ref() if _forge!=null else null
	if not forge is Control or not is_instance_valid(forge) or not forge.is_inside_tree() or not forge.is_visible_in_tree() or forge.is_queued_for_deletion() or forge.get("mode")!="target":return _fail("enhance_slots_live_ordinary_forge_required")
	var script: Script=forge.get_script()
	if script==null or script.resource_path!="res://scripts/ui/renewal_forge.gd":return _fail("enhance_slots_actual_forge_type_required")
	var index: Variant=forge.get("selected_index")
	var values: Variant=forge.get("values")
	var listing: Variant=forge.get("listing")
	if typeof(index)!=TYPE_INT or not values is Array or index<0 or index>=values.size() or not listing is ItemList or not is_instance_valid(listing) or index>=listing.item_count or listing.get_selected_items()!=PackedInt32Array([index]):return _fail("enhance_slots_actual_selected_row_required")
	var entry: Variant=values[index]
	var scroll: Variant=forge.get("scroll_name")
	if not entry is Dictionary or not entry.get("target_id") is String or entry.target_id.is_empty() or listing.get_item_metadata(index)!=entry.target_id or not scroll is String or scroll.is_empty():return _fail("enhance_slots_exact_owner_references_required")
	var hud: Variant=forge.get("hud")
	var bag: Variant=hud.get("lineage_inventory_ui") if is_instance_valid(hud) else null
	if not is_instance_valid(bag) or not bag.get("inventory") is Dictionary or int(bag.inventory.get(scroll,0))<=0:return _fail("enhance_slots_owned_scroll_required")
	if not forge.get("scroll_icon") is TextureRect or not forge.get("preview") is TextureRect:return _fail("enhance_slots_existing_owner_image_views_required")
	for role: String in _legacy:
		if _legacy[role].view.get_ref()!=(forge.scroll_icon if role=="scroll" else forge.preview):return _fail("enhance_slots_owner_image_view_replaced")
	var scroll_record: Dictionary=bag.call("_find_item_record",scroll)
	scroll_record=bag.call("_item_visual_record",scroll,scroll_record)
	var equipment_record: Dictionary=forge.call("_image_record",entry)
	return {"ok":true,"scroll":scroll,"equipment":entry.target_id,"scroll_record":scroll_record,"equipment_record":equipment_record}

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
