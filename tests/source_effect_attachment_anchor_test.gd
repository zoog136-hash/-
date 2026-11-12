extends SceneTree
## No-pixel test of the existing effect host's placement and node ownership.
## The factory stub does not assert source admission, rendering or native M timing.

class NoPixelsOverlay:
	extends Node2D
	var _overlay_facing: int = 0
	var _reference_overlay_parent: Dictionary = {"source_reference":{"row":123}}
	var reference_bank_status: Dictionary = {"error":"test_frame_unavailable"}
	var frame_available: bool = true
	var first_frame_position: Vector2
	var first_frame_top_level: bool = false
	var first_frame_placement: String = ""
	func advance_reference_source(_delta: float, _role: String, _facing: int) -> bool:
		first_frame_position = global_position
		first_frame_top_level = is_set_as_top_level()
		first_frame_placement = str(_reference_overlay_parent.get("placement_policy",""))
		return frame_available

class Factory:
	extends "res://scripts/animation/original_source_preview.gd"
	var frame_available: bool = true
	var requested: bool = true
	var last_overlay: Node2D
	func _make_selected_current_source_effect(selected: Dictionary, _facing: int, _budget: int = 0) -> Node2D:
		source_effect_status = selected.duplicate(true)
		if not requested: return null
		var overlay := NoPixelsOverlay.new()
		overlay.frame_available = frame_available
		last_overlay = overlay
		return overlay

# get_script().new() in the production ] host creates this same subclass.
# Only bank I/O and frame drawing are stubbed; whitelist dispatch/placement remain production.
class TokenPreview:
	extends "res://scripts/animation/original_source_preview.gd"
	var configured_input: Dictionary = {}
	var first_frame_transform: Transform2D
	var advanced: Array = []
	func _configure_reference_bank(path: String, pin: String, actor: int, roles: Dictionary, loops: Dictionary, initial: String, consumer: String, actors: Dictionary = {}) -> bool:
		configured_input = {"path":path,"pin":pin,"actor":actor,"roles":roles.duplicate(),"loops":loops.duplicate(),"initial":initial,"consumer":consumer,"actors":actors.duplicate()}
		_playback_tracks = {"idle":{"source_action_key":"%d:0" % actor}}
		return actor != 99
	func advance_reference_source(delta: float, role: String, direction: int) -> bool:
		first_frame_transform = global_transform
		advanced.append({"delta":delta,"role":role,"direction":direction})
		return true

var checked: int = 0
var failures: int = 0
var failure_details: Array[String] = []
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		failure_details.append(label)
		printerr("SOURCE_EFFECT_ANCHOR_FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	owner.position = Vector2(100,200)
	var preview := Factory.new()
	owner.add_child(preview)
	preview.position = Vector2(7,-9)
	var selected: Dictionary = {"ok":true,"consumer":"spell_effect","source_reference":{"row":123}}
	var supplied: Dictionary = selected.duplicate(true)
	var point := Vector2(300,400)
	check(preview._spawn_current523_source_effect(selected,point,0),"finite event admitted by host")
	var fixed: NoPixelsOverlay = preview.last_overlay
	check(fixed.get_parent() == owner,"world effect keeps its existing owner for lifetime")
	check(fixed.is_set_as_top_level(),"finite point establishes world transform")
	check(fixed.global_position.is_equal_approx(point),"event world point retained")
	check(fixed.first_frame_position.is_equal_approx(point) and fixed.first_frame_top_level,"first frame sees world placement")
	check(fixed.first_frame_placement == "existing_caller_world_point","first frame receives placement evidence")
	check(preview.source_effect_status.get("placement_policy") == "existing_caller_world_point","host reports world placement")
	check(fixed._reference_overlay_parent.source_reference == selected.source_reference and selected == supplied,"source identities are preserved")
	owner.position += Vector2(23,37)
	owner.rotation = 0.7
	owner.scale = Vector2(2,3)
	check(fixed.global_position.is_equal_approx(point),"world event stays fixed after owner movement rotation and scale")
	check(fixed.global_transform.is_equal_approx(Transform2D(0.0,point)),"world event does not inherit owner rotation or scale")

	var apply_point: Vector2 = preview.global_position
	check(preview._spawn_current523_source_effect(selected,Vector2.INF,0),"apply event without point admitted")
	var attached: NoPixelsOverlay = preview.last_overlay
	check(not attached.is_set_as_top_level() and attached.get_parent() == owner,"unspecified point remains owner relative")
	check(attached.first_frame_position.is_equal_approx(apply_point) and not attached.first_frame_top_level,"apply first frame uses owner anchor")
	check(preview.source_effect_status.get("placement_policy") == "existing_owner_relative_apply_event","host reports owner placement")
	var local_point: Vector2 = attached.position
	owner.position += Vector2(-41,18)
	owner.rotation = -0.3
	owner.scale = Vector2(1.5,0.75)
	check(attached.global_position.is_equal_approx(owner.to_global(local_point)),"owner-relative event follows owner's full transform")
	check(fixed.global_position.is_equal_approx(point),"other effects retain their own placement")

	var death_point: Vector2 = preview.global_position
	check(preview._spawn_current523_source_effect(selected,Vector2.INF,0,true),"explicit fixed event supports unspecified point")
	var death: NoPixelsOverlay = preview.last_overlay
	owner.position += Vector2(30,40)
	check(death.is_set_as_top_level() and death.global_position.is_equal_approx(death_point),"explicit fixed/death behavior remains stable")
	check(preview._overlay_nodes.size() == 3,"host tracks all existing effects")
	attached.free()
	preview._prune_source_overlays()
	check(preview._overlay_nodes.size() == 2,"completed effects are still pruned safely")
	preview.clear()
	check(not is_instance_valid(fixed) and not is_instance_valid(death) and preview._overlay_nodes.is_empty(),"owner clear still frees fixed effects")

	preview.frame_available = false
	check(not preview._spawn_current523_source_effect(selected,point,0),"failed first frame remains rejected")
	check(not is_instance_valid(preview.last_overlay) and preview._overlay_nodes.is_empty(),"rejected frame is freed without tracking")
	check(preview.source_effect_status.get("reason") == "test_frame_unavailable","existing frame failure is retained")
	preview.frame_available = true
	preview.requested = false
	check(not preview._spawn_current523_source_effect(selected,point,0) and preview._overlay_nodes.is_empty(),"missing effect selection creates no node")
	preview.requested = true
	check(preview._spawn_current523_source_effect(selected,point,0),"effect can be spawned after rejection")
	var child: Node2D = preview.last_overlay
	check(child.global_position.is_equal_approx(point),"new event uses world point under an already transformed owner")
	check(child.global_transform.is_equal_approx(Transform2D(0.0,point)),"new world event starts without inherited owner rotation or scale")
	owner.free()
	check(not is_instance_valid(child),"top-level placement preserves parent lifetime cleanup")
	run_reference_token_checks()
	print("SOURCE_EFFECT_ATTACHMENT_ANCHOR "+JSON.stringify({"checks":checked,"failures":failure_details,"failure_count":failures,"no_pixel_host_only":true}))
	quit(1 if failures else 0)

func run_reference_token_checks() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	owner.position = Vector2(500,-200)
	owner.rotation = 0.7
	owner.scale = Vector2(2,0.75)
	var preview := TokenPreview.new()
	owner.add_child(preview)
	preview.position = Vector2(-19,23)
	preview._playback_mode = "compatible"
	preview._manifest_path = "user://no-pixel-token-bank.json"
	preview._record = {"source_sprite_id":100}
	preview._reference_card_context = {"request_key":"synthetic:no_pixels","consumer":"transform","manifest_sha256":"fixture_pin_not_source_evidence"}
	preview._reference_texture_budget = {"limit":1000,"used":0}
	var binding: Dictionary = {"classification":"normal_visual","source_action_key":"101:4","target_sprite_id":42,"child_action_id":0,"child_source_action_key":"42:0"}
	var track: Dictionary = {"source_sprite_id":101,"source_action_id":4,"source_action_key":"101:4","loop":false,"source_annotations":[{"token_index":0,"raw":"]42"}]}
	preview._reference_overlay_parents = {"101:4":{"0":[binding]}}
	var event_point: Vector2 = preview.global_position
	preview._playback_mode = "strict"
	preview._dispatch_reference_overlays([{"duration":0.1}],track,0.1,5)
	check(preview._overlay_nodes.is_empty(),"strict mode still suppresses token overlay dispatch")
	preview._playback_mode = "compatible"
	preview._is_overlay = true
	preview._dispatch_reference_overlays([{"duration":0.1}],track,0.1,5)
	check(preview._overlay_nodes.is_empty(),"nested overlay dispatch remains suppressed")
	preview._is_overlay = false
	var no_literal: Dictionary = track.duplicate(true)
	no_literal["source_annotations"] = [{"token_index":0,"raw":"no bracket target"}]
	preview._dispatch_reference_overlays([{"duration":0.1}],no_literal,0.1,5)
	check(preview._overlay_nodes.is_empty(),"whitelist without literal source token creates no effect")
	preview._reference_overlay_key = ""
	preview._dispatch_reference_overlays([{"duration":0.1}],track,0.1,5)
	check(preview._overlay_nodes.size() == 1,"literal whitelisted token reaches production host")
	if preview._overlay_nodes.is_empty():
		owner.free()
		return
	var token: TokenPreview = preview._overlay_nodes[0]
	check(token.get_script() == preview.get_script(),"production get_script factory creates the diagnostic subclass")
	check(token.get_parent() == owner and token.is_set_as_top_level(),"token snapshots world transform while retaining scene owner")
	check(token.global_position.is_equal_approx(event_point),"token starts at parent event point")
	check(token.first_frame_transform.is_equal_approx(Transform2D(0.0,event_point)),"first token frame sees snapshot without owner rotation or scale")
	check(token._overlay_facing == 5 and token.advanced == [{"delta":0.0,"role":"idle","direction":5}],"existing first advance and stored facing are preserved")
	check(token.configured_input == {"path":preview._manifest_path,"pin":preview._reference_card_context.manifest_sha256,"actor":42,"roles":{"idle":0},"loops":{"idle":false},"initial":"idle","consumer":"overlay","actors":{}},"exact child binding and one-shot policy pass unchanged to bank")
	check(token._reference_overlay_parent.host_policy == "existing_bracket_sprite_single_action_visual_only" and token._reference_overlay_parent.source_actor_id == 101 and token._reference_overlay_parent.source_action_id == 4 and token._reference_overlay_parent.source_token_index == 0,"token provenance and host label remain intact")
	check(token._reference_overlay_parent.ancestor_actor_ids == [100,101] and token._is_overlay and token.z_index == 2,"ancestry nested guard and layer order remain intact")
	token._reference_texture_budget["used"] = 37
	check(preview._reference_texture_budget.used == 37,"token keeps existing shared texture budget")
	owner.position += Vector2(91,-63)
	owner.rotation = -0.4
	owner.scale = Vector2(0.5,3)
	preview.position += Vector2(17,29)
	check(token.global_transform.is_equal_approx(Transform2D(0.0,event_point)),"token stays at snapshot after owner and preview transforms change")
	check(token._overlay_facing == 5,"later owner motion does not change stored facing")
	preview._dispatch_reference_overlays([{"duration":0.1}],track,0.1,5)
	check(preview._overlay_nodes.size() == 1,"same token boundary is not emitted twice")

	# Reuse the production host to exercise its existing binding/loader rejections.
	var count: int = owner.get_child_count()
	var wrong: Dictionary = binding.duplicate(true)
	wrong["child_source_action_key"] = "different_action"
	check(not preview._spawn_reference_overlay(wrong,track,0,5),"wrong child action key remains rejected")
	check(owner.get_child_count() == count and preview._overlay_nodes.size() == 1,"rejected child action is freed without tracking")
	var missing: Dictionary = binding.duplicate(true)
	missing["target_sprite_id"] = 99
	check(not preview._spawn_reference_overlay(missing,track,0,5),"unavailable bank remains rejected")
	check(owner.get_child_count() == count and preview._overlay_nodes.size() == 1,"unavailable bank node is freed")
	preview.clear()
	check(not is_instance_valid(token) and preview._overlay_nodes.is_empty(),"owner clear still frees snapshot token")
	preview._record = {"source_sprite_id":100}
	preview._reference_card_context = {"request_key":"synthetic:no_pixels","consumer":"transform","manifest_sha256":"fixture_pin_not_source_evidence"}
	check(preview._spawn_reference_overlay(binding,track,0,5),"token host can be reused after clear")
	var final_token: Node2D = preview._overlay_nodes[0]
	owner.free()
	check(not is_instance_valid(final_token),"scene owner free cleans up top-level token")
