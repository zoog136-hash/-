extends SceneTree
## Production node configure/frame/diagnostic paths with a no-I/O bank and
## shared synthetic texel boundary. No original admission, GPU/cell-order claim.
const PHYSICAL: int = 20
class Bank:
	extends RefCounted
	var accept: bool = true
	func render_layer(_layer: Dictionary, _pixels: bool) -> Dictionary:
		return {"ok":accept,"error":"synthetic member unavailable" if not accept else ""}
class Preview:
	extends "res://scripts/animation/original_source_preview.gd"
	var fixture_textures: Dictionary = {}
	func _source_texture(layer: Dictionary) -> Texture2D:
		var id: int = int(layer.layer_id)
		if not fixture_textures.has(id):
			fixture_textures[id] = ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
		return fixture_textures[id]
	func install(effects: Array) -> void:
		clear()
		_playback_mode = "compatible"
		_reference_bank = Bank.new()
		var body: Dictionary = {"kind":"body","layer_id":10,"source_attributes":[],"source_attribute_projection":{"ok":true,"present":false,"flags":0},"offset":[0,0],"frame_provenance":{"fixture_slot":"body"}}
		var frame: Dictionary = {"source_group":0,"source_frame":0,"source_ticks":1,"duration":1.0,"layers":[body],"effect_layers":effects}
		var directions: Array = []
		for direction: int in 8: directions.append([frame.duplicate(true)])
		var track: Dictionary = {"source_sprite_id":10,"source_action_id":0,"source_action_key":"fixture","loop":true,"directions":directions,"static_pending_timing":false,"timing_origin":"synthetic boundary"}
		_configure_source_nodes({"source_sprite_id":10,"independent_source_layers":{}},{"idle":track},1,"")
		_role = "idle"
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_ATTACHMENT_INSTANCE_FAIL ",label)
func clothes(slot: String, flags: int, offset: Array, explicit: bool = true) -> Dictionary:
	var layer: Dictionary = {"kind":"clothes","layer_id":PHYSICAL,"path":"synthetic/20","source_attributes":[str(flags)],"source_attribute_projection":{"ok":true,"present":true,"flags":flags},"offset":offset,"frame_provenance":{"fixture_slot":slot},"source_binding_id":"legacy_trace_"+slot}
	if explicit: layer["source_layer_instance_key"] = slot
	return layer
func instance_node(view: Preview, key: String) -> Sprite2D:
	# The old renderer collapses both instances into its physical node. Retain
	# that handle for differential assertions, avoiding missing-field aborts.
	return view._effect_nodes.get("source_instance:"+key,view._effect_nodes.get(PHYSICAL)) as Sprite2D
func operation(node: Sprite2D) -> int:
	return int(node.get_meta("source_compositor",{}).get("operation",-1)) if node != null else -1
func labels(view: Preview) -> Array:
	var out: Array = []
	for layer: Dictionary in view.reference_source_frame_status().get("selected_layers",[]): out.append(layer.get("fixture_slot"))
	return out
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := Preview.new()
	root.add_child(view)
	view.install([clothes("105:0",8,[3,-7]),clothes("105:1",128,[-11,13])])
	check(view._effect_nodes.size() == 2,"same physical sprite retains two explicit ordered instances")
	check(view.advance_reference_source(0.0,"idle",0),"production frame with repeated clothes is accepted")
	var first: Sprite2D = instance_node(view,"105:0")
	var second: Sprite2D = instance_node(view,"105:1")
	check(first != null and second != null and first != second,"explicit source instances use separate nodes")
	check(first.visible and second.visible and operation(first) == 1 and operation(second) == 2,"same physical file retains independent screen and multiply styles")
	check(first.position == Vector2(3,-7) and second.position == Vector2(-11,13),"source instance offsets remain independent")
	check(first.z_index == 1 and second.z_index == 1 and first.get_parent() == view and second.get_parent() == view,"existing layer order and parent ownership retained")
	check(first.texture == second.texture and view.fixture_textures.size() == 2,"instances share one physical texture alongside the body")
	check(first.get_meta("source_layer_instance_key","") == "105:0" and second.get_meta("source_layer_instance_key","") == "105:1","node metadata retains explicit source identities")
	var shown: Array = view.reference_source_frame_status().get("selected_layers",[])
	check(shown.size() == 3 and shown[1].get("source_layer_instance_key") == "105:0" and shown[2].get("source_layer_instance_key") == "105:1","shown provenance identifies both instances sharing physical pixels")
	var status: Dictionary = view.attachment_status()
	var compositor_keys: Array = []
	for row: Dictionary in status.recovered_source_compositors: compositor_keys.append(row.get("source_layer_instance_key"))
	check(status.source_layer_nodes == 2 and compositor_keys == ["105:0","105:1"],"attachment diagnostics preserve separate instance styles")
	var first_id: int = first.get_instance_id()
	var second_id: int = second.get_instance_id()
	var frame: Dictionary = view._playback_tracks.idle.directions[0][0]
	var a: Dictionary = frame.effect_layers[0]
	var b: Dictionary = frame.effect_layers[1]
	# Controlled bookkeeping boundary: a single shared texture charge, not one
	# charge per scene node. No real GPU lease acquisition is claimed here.
	var budget: Dictionary = {"limit":128,"used":64}
	view._reference_texture_budget = budget
	view._reference_texture_charges = {"shared_fixture_texture":16}
	frame.effect_layers = [b]
	check(view.advance_reference_source(0.0,"idle",0),"frame can select only the second repeated instance")
	check(not first.visible and second.visible and labels(view) == ["body","105:1"],"removed first instance hides without concealing or misreporting second")
	check(view._effect_nodes.size() == 2 and first.get_instance_id() == first_id and second.get_instance_id() == second_id,"frame changes reuse both configured source nodes")
	frame.effect_layers = [a,b]
	a.source_attribute_projection = {"ok":false}
	check(view.advance_reference_source(0.0,"idle",0),"unresolved instance metadata does not abort valid shared source")
	check(not first.visible and second.visible and operation(second) == 2,"invalid own flags hide only their instance")
	check(labels(view) == ["body","105:1"],"diagnostic visibility lookup uses instance identity")
	a.source_attribute_projection = {"ok":true,"present":true,"flags":8}
	check(view.advance_reference_source(0.0,"idle",0) and first.visible and second.visible,"restored instance is reused without reconstructing scene nodes")
	check(operation(first) == 1 and operation(second) == 2 and first.get_instance_id() == first_id and second.get_instance_id() == second_id,"reused instance restores its own style without changing sibling")
	check(budget.used == 64 and view.fixture_textures.size() == 2,"multiplicity does not multiply texture budget or texture creation")
	(view._reference_bank as Bank).accept = false
	check(not view.advance_reference_source(0.0,"idle",0),"existing member invalidation still rejects frame")
	check(view._effect_nodes.is_empty() and not is_instance_valid(first) and not is_instance_valid(second),"invalidation clears every instance exactly through existing owner lifecycle")
	check(budget.used == 48 and view.reference_source_frame_status().is_empty(),"invalidation releases shared charge once and removes stale provenance")
	view.clear()
	check(budget.used == 48,"repeated clear does not release shared charge twice")
	view.install([clothes("105:0",8,[3,-7]),clothes("105:1",128,[-11,13])])
	check(view._effect_nodes.size() == 2 and view.advance_reference_source(0.0,"idle",0),"reconfiguration recreates both explicit instances after invalidation")
	var owned: Array = view._effect_nodes.values()
	view.free()
	check(not is_instance_valid(owned[0]),"owner free retains existing instance cleanup")

	var legacy := Preview.new()
	root.add_child(legacy)
	legacy.install([clothes("oldA",8,[3,-7],false),clothes("oldB",128,[-11,13],false)])
	check(legacy._effect_nodes.size() == 1 and legacy._effect_nodes.has(PHYSICAL),"legacy physical-ID dictionary shape remains unchanged")
	legacy.advance_reference_source(0.0,"idle",0)
	var old: Sprite2D = legacy._effect_nodes[PHYSICAL]
	check(old.name == "SourceAttachment20" and not old.has_meta("source_layer_instance_key"),"legacy node names and metadata are not implicitly upgraded")
	check(operation(old) == 2 and old.position == Vector2(-11,13),"legacy no-field rendering keeps existing last-physical-entry behavior")
	check(not legacy.reference_source_frame_status().selected_layers[1].has("source_layer_instance_key"),"old source_binding_id does not become a native instance identity")
	legacy.free()

	var mixed := Preview.new()
	root.add_child(mixed)
	mixed.install([clothes("20",8,[3,-7]),clothes("legacy",128,[-11,13],false)])
	check(mixed._effect_nodes.size() == 2 and mixed._effect_nodes.has("source_instance:20") and mixed._effect_nodes.has(PHYSICAL),"qualified explicit string cannot collide with legacy physical integer")
	mixed.advance_reference_source(0.0,"idle",0)
	check(operation(mixed._effect_nodes.get("source_instance:20")) == 1 and operation(mixed._effect_nodes.get(PHYSICAL)) == 2,"explicit and legacy keys resolve consistently during active rendering")
	mixed.free()
	print("SOURCE_ATTACHMENT_INSTANCE_IDENTITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"production host node identity with synthetic textures and no-I/O bank; no original or GPU equivalence"}))
	quit(0 if failures.is_empty() else 1)
