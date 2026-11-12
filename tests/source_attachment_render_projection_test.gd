extends SceneTree
## Production frame dispatch with synthetic texels and a no-I/O bank boundary.
## Verifies metadata selection, not original admission or native cell ordering.

class Bank:
	extends RefCounted
	func render_layer(_layer: Dictionary, _pixels: bool) -> Dictionary: return {"ok":true}

class Preview:
	extends "res://scripts/animation/original_source_preview.gd"
	var fixture_texture: Texture2D
	func _source_texture(_layer: Dictionary) -> Texture2D:
		if fixture_texture == null:
			fixture_texture = ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
		return fixture_texture
	func _configure_reference_bank(_path: String, _pin: String, actor: int, roles: Dictionary, _loops: Dictionary, initial: String, _consumer: String, _actors: Dictionary = {}) -> bool:
		if not playback_mode_override.is_empty(): _playback_mode = playback_mode_override
		var layer: Dictionary = {"kind":"body","source_attributes":["128"],"source_attribute_projection":{"ok":true,"flags":128,"present":true},"layer_id":actor,"offset":[-7,9],"frame_provenance":{}}
		var frame: Dictionary = {"source_group":0,"source_frame":0,"source_ticks":1,"duration":1.0,"layers":[layer],"effect_layers":[]}
		var directions: Array = []
		for index: int in 8: directions.append([frame.duplicate(true)])
		var tracks: Dictionary = {initial:{"source_sprite_id":actor,"source_action_id":roles[initial],"source_action_key":"fixture-action","loop":true,"directions":directions}}
		_reference_bank = Bank.new()
		return _configure_source_nodes({"source_sprite_id":actor,"independent_source_layers":{}},tracks,1,"")

var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var preview := Preview.new()
	root.add_child(preview)
	preview._playback_mode = "compatible"
	preview._configure_reference_bank("","",10,{"idle":0},{"idle":true},"idle","")
	preview._role = "idle"
	var layer: Dictionary = preview._playback_tracks.idle.directions[0][0].layers[0]
	layer.source_attributes = ["128","8"]
	layer.source_attributes_unresolved = true
	check(preview.advance_reference_source(0,"idle",0),"production frame accepted")
	check(preview._layers[0].visible and preview._layers[0].get_meta("source_compositor",{}).get("operation",-1) == 2,"draw uses requested own projection despite alias trace")
	check(layer.source_attributes == ["128","8"],"raw source trace retained by draw")
	check(preview._layers[0].position == Vector2(-7,9),"source offset retained")
	layer.source_attribute_projection = {"ok":true,"flags":0,"present":false}
	preview.advance_reference_source(0,"idle",0)
	check(preview._layers[0].visible and preview._layers[0].material == null,"default own flags render normally despite unused alias flags")
	layer.source_attribute_projection = {"ok":false}
	preview.advance_reference_source(0,"idle",0)
	check(not preview._layers[0].visible,"unresolved own projection cannot fall back to alias flags")
	layer.erase("source_attribute_projection")
	layer.erase("source_attributes")
	layer.erase("source_attributes_unresolved")
	preview.advance_reference_source(0,"idle",0)
	check(preview._layers[0].visible and preview._layers[0].material == null,"legacy static DTO without attribute proof retains its normal raw presentation")
	check(preview.reference_source_frame_status().selected_layers.size() == 1,"static DTO provenance is still shown")
	# Old delivered banks can carry a shadow as an independent child. It must
	# still borrow the parent flags; its child body metadata is not a draw owner.
	layer.source_attribute_projection = {"ok":true,"flags":0,"present":false}
	layer.source_attributes = []
	var attachment: Dictionary = {"kind":"shadow","from_sprite_id":10,"target_sprite_id":11,"child_action_id":0,"child_source_action_key":"fixture-action","source_declaration":{},"dispatch_policy":"legacy_host_policy"}
	preview._record.independent_source_layers = {"idle":[attachment]}
	preview._reference_card_context = {"consumer":"transform","ancestor_actor_ids":[]}
	check(preview.advance_reference_source(0,"idle",0),"legacy attached shadow advances")
	check(preview._reference_source_children.size() == 1,"shadow remains linked")
	var child: Preview = preview._reference_source_children.values()[0]
	check(child._layers[0].visible and child._layers[0].get_meta("source_compositor",{}).get("operation",-1) == 0,"independent shadow uses parent average rather than child multiply: "+JSON.stringify({"visible":child._layers[0].visible,"style":child._layers[0].get_meta("source_compositor",{}),"parent":child._reference_attachment_parent,"mode":child._playback_mode}))
	check(child._layers[0].get_meta("source_compositor",{}).get("flags",-1) == 1,"effective shadow flags retain injected1")
	check(child.get_parent() == preview and child.z_index == -1,"ownership and existing layer order retained")
	check(child._reference_attachment_parent.has("parent_draw_attributes") and child._reference_attachment_parent.has("parent_draw_attributes_unresolved") and child._reference_attachment_parent.parent_draw_attributes.is_empty() and not child._reference_attachment_parent.parent_draw_attributes_unresolved,"resolved absent parent104 is carried to child")
	preview.free()
	# An inline101 projection explicitly delegates to parent draw context. Its
	# own metadata is not unresolved source art; strict mode keeps the legacy
	# raw-shadow presentation while compatible mode can recover parent average.
	var inline := Preview.new()
	root.add_child(inline)
	inline.playback_mode_override = "strict"
	inline._configure_reference_bank("","",20,{"idle":0},{"idle":true},"idle","")
	var frame: Dictionary = inline._playback_tracks.idle.directions[0][0]
	frame.layers[0].source_attributes = []
	frame.layers[0].source_attribute_projection = {"ok":true,"flags":0,"present":false}
	frame.layers.append({"kind":"shadow","source_attributes":[],"source_attributes_unresolved":false,"source_attribute_projection":{"ok":false,"flags":0,"present":false,"origin":"shadow_requires_parent_actor_flags"},"layer_id":21,"offset":[4,6],"frame_provenance":{}})
	var shadow := Sprite2D.new()
	inline.add_child(shadow)
	inline._layers.append(shadow)
	check(inline.advance_reference_source(0,"idle",0),"strict production inline shadow frame accepted")
	check(shadow.visible and shadow.material == null and not shadow.has_meta("source_compositor"),"strict inline shadow retains legacy presentation despite parent-context projection marker")
	inline._playback_mode = "compatible"
	check(inline.advance_reference_source(0,"idle",0) and shadow.visible and shadow.get_meta("source_compositor",{}).get("operation",-1) == 0,"compatible inline shadow ignores own context marker and borrows resolved parent flags")
	frame.layers[0].source_attribute_projection = {"ok":true,"flags":8,"present":true}
	check(inline.advance_reference_source(0,"idle",0) and shadow.get_meta("source_compositor",{}).get("flags",-1) == 9 and shadow.get_meta("source_compositor",{}).get("operation",-1) == 1,"verified parent own8 unlocks shadow9 screen")
	frame.layers[0].source_attribute_projection = {"ok":true,"flags":128,"present":true}
	check(inline.advance_reference_source(0,"idle",0) and shadow.get_meta("source_compositor",{}).get("flags",-1) == 129 and shadow.get_meta("source_compositor",{}).get("operation",-1) == 0,"verified parent own128 unlocks shadow129 average")
	frame.layers[0].erase("source_attribute_projection")
	frame.layers[0].source_attributes = ["8"]
	check(inline.advance_reference_source(0,"idle",0) and shadow.material == null,"legacy raw parent8 does not unlock verified shadow9")
	frame.layers[0].source_attribute_projection = {"ok":false}
	check(inline.advance_reference_source(0,"idle",0) and shadow.material == null,"invalid parent projection does not unlock shadow9")
	inline.free()
	print("SOURCE_ATTACHMENT_RENDER_PROJECTION "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
