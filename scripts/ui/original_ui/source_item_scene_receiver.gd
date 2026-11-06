extends RefCounted
## Typed live Forge-equipment receiver. Never asserts original-client attachment.
const SCRIPT_PATH="res://scripts/ui/original_ui/source_item_scene_receiver.gd"
const CONTROLLER_PATH="res://scripts/ui/original_ui/source_main_hud.gd"
const PLAYER_PATH="res://scripts/ui/original_ui/sprite_scene.gd"
const SCHEMA="twilight-item-scene-host-registration-v1"
const SPACE="twilight_host_sprite_anchor"
const Images=preload("res://scripts/ui/source523_image_assets.gd")
const Icons=preload("res://scripts/ui/source523_original_ui_icons.gd")
const FIRST_PIN="566a4a66e894abdb3a761e8c0cca51d95799c52989a097030cab76839d99fb19"
const ALICE_PIN="ebf14ad21218b6ac7d5a9e9e68ef3c81f366b78e0e725df04e2ec69f2a5894f0"
# Explicit, source-verified admission subset, not a new ItemClass/Icon resolver.
const SCENES={
 "UI/CsbFile/icon/Fx_Item_Armor_Pants_Myth_Eodin.csb":{"sha":"022dc8eb3ba72097b04f46263d7d622b2c753820ceeb337871493d2faf377401","pin":FIRST_PIN,"items":[242761,243271],"icon":83331,"asset":320181,"panel":340,"nodes":{288:["Node",-1],1192:["Sprite",288],340:["Panel",288],388:["Sprite",340]}},
 "UI/CsbFile/icon/Fx_Item_Armor_Shield_Myth_Eir.csb":{"sha":"375469b59bb6af5dee32027c4193dc0b469b1b8effd1116f993c03624cba9916","pin":FIRST_PIN,"items":[253282,253292],"icon":83762,"asset":321512,"panel":244,"nodes":{192:["Node",-1],1096:["Sprite",192],244:["Panel",192],292:["Sprite",244]}},
 "UI/CsbFile/icon/Fx_Item_Weapon_Bow_Myth_Alice.csb":{"sha":"83529910ff502e6817fd36eb33fe64ac67a451a69bff4a5fbc62a753497562a5","pin":ALICE_PIN,"items":[239911,239941],"icon":83063,"asset":319133,"panel":340,"nodes":{288:["Node",-1],1668:["Sprite",288],340:["Panel",288],864:["Sprite",340],392:["Sprite",340]}},
 "UI/CsbFile/icon/Fx_Item_Weapon_Staff_Myth_Alice.csb":{"sha":"4f766d2311025f1d46d0b11f0ce7e87a400cacc1b043136aaffe04d20a78dff1","pin":ALICE_PIN,"items":[239971,239981],"icon":83073,"asset":319143,"panel":340,"nodes":{288:["Node",-1],1676:["Sprite",288],340:["Panel",288],864:["Sprite",340],392:["Sprite",340]}},
 "UI/CsbFile/icon/Fx_Item_Weapon_Sword_Myth_Alice.csb":{"sha":"a060e7ff788346a7c179e229623a8c126203fab9656bfb6933f93c5c6e31a3c9","pin":ALICE_PIN,"items":[253302,253312],"icon":83992,"asset":321782,"panel":292,"nodes":{240:["Node",-1],1628:["Sprite",240],292:["Panel",240],816:["Sprite",292],344:["Sprite",292]}}
}
var _hud: WeakRef
var _controller: WeakRef
var _player: WeakRef
var _node: WeakRef
var _target: Dictionary={}
var _record: Dictionary={}
var _target_reference: String=""
var _physical_id: String=""
const ITEM_TABLE_SHA="adaf246e6a70c2e24f144a5147bebaff27e9168bc5a74da8bcf871ca1287a165"
const ITEM_ROWS={242761:"afdde819db00afe16fcfc82895c099136166f74339e6925fb1240ac0e0017105",243271:"6b58f2bce8f254d4afacbc159cf5e7197a659d5ead5b57dec835e966dc10185f",253282:"25d7a012f5d80d4487c860a1de4c450e90ad2a7bc3cfc6ea353323056d9c6434",253292:"f80595cea118b1d6869d2af467a0565d42dae66dacc6884cfd433beb897e3d63",239911:"bf1808d748644d66dc3abd7931d9e9adff82f5090efac95dfaa1dc5eadd0405e",239941:"306da141084e3ce6f755ae6231eb2c8b6f89bf53120f2f34528b73e9f6c70ab0",239971:"7b261f8bf0a9b163f5f5cad09887741476bb8f85bccb4fd710a76e7ab0808ca0",239981:"9ab9896d8c5bd6a3b1358b5e8c32c9c3c41edfa3083f04edf0626421e2272852",253302:"04285597646821567aaf17831851c0bc1be0d43e6017b11834181ba6e8e3de61",253312:"b27fc87f1e3275ed25e013a2ceaa3d4705bf7a0cec437db1d0e0ff96a64543c3"}

static func capture_forge(hud: Node, role: String="equipment") -> Dictionary:
	if role!="equipment":return _fail("host_item_scene_equipment_receiver_required")
	if not is_instance_valid(hud):return _fail("host_item_scene_live_hud_required")
	var controller: Variant=hud.get("original_main_ui_controller")
	if not controller is Node or not is_instance_valid(controller) or not controller.is_inside_tree():return _fail("host_item_scene_live_controller_required")
	var script: Script=controller.get_script()
	if script==null or script.resource_path!=CONTROLLER_PATH:return _fail("host_item_scene_actual_controller_required")
	var current: Dictionary=controller.original_enhance_slot_receiver(role)
	if not current.get("ok",false):return current
	if not current.get("physical_instance_id") is String or current.physical_instance_id.is_empty():return _fail("host_item_scene_owned_physical_target_required")
	var factory: Script=load(SCRIPT_PATH)
	var receiver: RefCounted=factory.new()
	receiver._hud=weakref(hud);receiver._controller=weakref(controller);receiver._player=weakref(current.player)
	receiver._node=weakref(current.player.source_nodes[15012])
	receiver._record=current.record.duplicate(true);receiver._target_reference=current.actual_target_reference;receiver._physical_id=current.physical_instance_id
	receiver._target={"member":current.source_member,"source_sha256":current.source_sha256,"manifest_sha256":current.player.source_pack.manifest_sha256,"node_offset":15012}
	var registration: Dictionary={"schema":SCHEMA,"kind":"TWILIGHT_host_registration","space":SPACE,"original_registration_confirmed":false,"receiver":receiver,"target":receiver._target.duplicate(true),"host_policy":"identity original item-CSB root at actual live equipment Common_Slot15012 authored Sprite anchor; no fit/offset or inferred playback"}
	return {"ok":true,"receiver":receiver,"registration":registration,"target":receiver._target.duplicate(true),"current_raw_record":receiver._record.duplicate(true),"actual_target_reference":receiver._target_reference,"physical_instance_id":receiver._physical_id,"rendered":false}

func validate_descriptor(descriptor: Dictionary) -> Dictionary:
	var current: Dictionary=_current()
	if not current.get("ok",false):return current
	var registration: Variant=descriptor.get("registration")
	if not registration is Dictionary or registration.get("schema")!=SCHEMA or registration.get("kind")!="TWILIGHT_host_registration" or registration.get("space")!=SPACE or typeof(registration.get("original_registration_confirmed"))!=TYPE_BOOL or registration.original_registration_confirmed!=false or registration.get("receiver")!=self or registration.get("target")!=_target:return _fail("host_item_scene_typed_registration_mismatch")
	# These five source cases declare clips, but no trigger/repeat policy.
	if descriptor.has("playback"):return _fail("host_item_scene_playback_policy_not_declared")
	var member: Variant=descriptor.get("member")
	if not member is String or not SCENES.has(member):return _fail("host_item_scene_original_case_not_admitted")
	var spec: Dictionary=SCENES[member]
	if descriptor.get("source_sha256")!=spec.sha or descriptor.get("manifest_sha256")!=spec.pin:return _fail("host_item_scene_original_member_pin_mismatch")
	var pack: Variant=descriptor.get("pack")
	if not pack is RefCounted or not is_instance_valid(pack) or pack.get("manifest_sha256")!=spec.pin:return _fail("host_item_scene_selected_pack_required")
	var bindings: Variant=descriptor.get("bindings",{})
	if not bindings is Dictionary or not bindings.is_empty():return _fail("host_item_scene_full_original_hierarchy_required")
	var info: Dictionary=Images.describe_item(current.record)
	var canonical: Variant=info.get("provenance")
	if info.get("reason")!="unsupported_csb" or info.get("source_snapshot")!="patch523" or not canonical is Dictionary or canonical.get("source_table")!="ItemClass" or canonical.get("source_field")!="IconID" or canonical.get("path")!=member or canonical.get("asset_type_id")!=101:return _fail("host_item_scene_current_canonical_item_required")
	if info.get("item_class_id") not in spec.items or canonical.get("source_id")!=info.item_class_id or canonical.get("icon_id")!=spec.icon or canonical.get("asset_id")!=spec.asset:return _fail("host_item_scene_current_item_icon_asset_mismatch")
	if canonical.get("source_table_sha256")!=ITEM_TABLE_SHA or canonical.get("source_row_canonical_sha256")!=ITEM_ROWS.get(int(info.item_class_id)):return _fail("host_item_scene_reviewed_current_source_row_required")
	var identity: Variant=descriptor.get("image_owner_identity")
	if not identity is Dictionary or identity.get("icon_id")!=canonical.icon_id or identity.get("asset_id")!=canonical.asset_id or identity.get("image_pack_manifest_sha256")!=canonical.get("manifest_sha256"):return _fail("host_item_scene_image_owner_identity_required")
	var consumer: Variant=identity.get("consumer")
	if not consumer is Dictionary:return _fail("host_item_scene_current_consumer_proof_required")
	for field: String in ["source_table","source_id","source_field","source_row_canonical_sha256","source_table_sha256"]:
		if not canonical.has(field) or consumer.get(field)!=canonical[field]:return _fail("host_item_scene_current_consumer_proof_changed")
	if str(consumer.source_row_canonical_sha256).length()!=64 or str(consumer.source_table_sha256).length()!=64:return _fail("host_item_scene_source_row_table_sha_required")
	var selected: Variant=Icons.bindings.get(str(int(canonical.icon_id)))
	if not selected is Dictionary or selected.get("member")!=member or selected.get("reviewed_current523_manifest_sha256")!=spec.pin or selected.get("current523_scene_sha256")!=spec.sha or selected.get("asset_id")!=canonical.asset_id or selected.get("asset_type_id")!=101 or "UI/CsbFile/"+str(selected.get("file_path",""))!=member:return _fail("host_item_scene_current_icon_selection_changed")
	var selected_pack: RefCounted=Icons.packs_by_manifest.get(spec.pin)
	if selected_pack==null and Icons.pack!=null and Icons.pack.manifest_sha256==spec.pin:selected_pack=Icons.pack
	if selected_pack!=pack:return _fail("host_item_scene_pack_not_currently_selected")
	var tree: Dictionary=pack.scene(member)
	if tree.get("_source_sha256")!=spec.sha or tree.get("_partial_source_scene",false):return _fail("host_item_scene_complete_original_scene_required")
	var nodes: Dictionary={}
	_collect(tree.get("nodeTree",{}),-1,nodes)
	if nodes.size()!=spec.nodes.size():return _fail("host_item_scene_original_node_set_changed")
	for offset: int in spec.nodes:
		if not nodes.has(offset) or nodes[offset].node.get("classname")!=spec.nodes[offset][0] or nodes[offset].parent!=spec.nodes[offset][1]:return _fail("host_item_scene_original_hierarchy_changed")
	if nodes[int(spec.panel)].node.get("options",{}).get("clipEnabled")!=1:return _fail("host_item_scene_required_original_clip_missing")
	return {"ok":true,"registration_kind":"TWILIGHT_host_registration","original_registration_confirmed":false,"target":_target.duplicate(true),"physical_instance_id":_physical_id,"source_internal_proof":{"member":member,"source_sha256":spec.sha,"manifest_sha256":spec.pin,"full_node_count":nodes.size(),"required_panel_clip_preserved":true,"blend_and_transform_support":"existing strict full-scene renderer must accept; no omitted nodes or flattened textures"},"runtime_rendering_verified":false}

func validate_attachment(renderer: Node2D, offset: int, descriptor: Dictionary) -> Dictionary:
	if _player==null or _player.get_ref()!=renderer or offset!=15012:return _fail("host_item_scene_actual_destination_changed")
	return validate_descriptor(descriptor)

func _current() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var controller: Object=_controller.get_ref() if _controller!=null else null
	var player: Object=_player.get_ref() if _player!=null else null
	var node: Object=_node.get_ref() if _node!=null else null
	if not is_instance_valid(hud) or not is_instance_valid(controller) or hud.get("original_main_ui_controller")!=controller or not controller.is_inside_tree():return _fail("host_item_scene_controller_replaced_or_freed")
	if not player is Node2D or not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or not player.is_visible_in_tree() or not is_instance_valid(node) or node.is_queued_for_deletion():return _fail("host_item_scene_live_destination_required")
	var current: Dictionary=controller.original_enhance_slot_receiver("equipment")
	if not current.get("ok",false):return current
	if current.player!=player or current.record!=_record or current.actual_target_reference!=_target_reference or current.get("physical_instance_id")!=_physical_id or player.source_nodes.get(15012)!=node:return _fail("host_item_scene_selected_record_or_receiver_changed")
	if player.get_script()==null or player.get_script().resource_path!=PLAYER_PATH or player.source_pack!=controller.source_role_pack() or player.source_member!=_target.member or player.source_pack.manifest_sha256!=_target.manifest_sha256 or player.source_pack.manifest.get("files",{}).get(_target.member,{}).get("sha256")!=_target.source_sha256 or not node.get_meta("source_asset_slot",false):return _fail("host_item_scene_target_root_or_pin_changed")
	return current

static func _collect(node: Dictionary, parent: int, result: Dictionary) -> void:
	var offset: int=int(node.get("_offset",-1))
	result[offset]={"node":node,"parent":parent}
	for child: Dictionary in node.get("children",[]):_collect(child,offset,result)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"error":code,"code":code,"runtime_rendering_verified":false}
