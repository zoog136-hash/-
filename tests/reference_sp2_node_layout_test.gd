extends "res://tests/reference_sp2_load_memo_test.gd"
## Synthetic immutable layout and actual bank/preview ownership regressions.
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func effect(id: int, flags: int, instance: String = "", unresolved: bool = false) -> Dictionary:
	var row: Dictionary = {"layer_id":id,"source_attributes":[str(flags)],"source_attributes_unresolved":unresolved,"blend_status":"synthetic"}
	if not instance.is_empty(): row["source_layer_instance_key"] = instance
	return row

func node_signature(view: Node) -> Array:
	var result: Array = []
	for child: Node in view.get_children():
		var entry: Dictionary = {"class":child.get_class()}
		if child is Sprite2D:
			entry["layer"] = child.get_meta("source_layer_id",-1)
			entry["instance"] = child.get_meta("source_layer_instance_key","")
			entry["style"] = child.get_meta("compatibility_style",{})
			entry["attributes"] = child.get_meta("source_attributes",[])
			entry["z"] = child.z_index
			entry["filter"] = child.texture_filter
			entry["color"] = child.modulate
			entry["visible"] = child.visible
			entry["material"] = child.material.get_class() if child.material != null else ""
			if child.material is CanvasItemMaterial: entry["blend"] = child.material.blend_mode
			if child.material is ShaderMaterial: entry["screen"] = child.material.get_shader_parameter("screen_operation")
		if child is BackBufferCopy: entry["copy_mode"] = child.copy_mode
		result.append(entry)
	return result

func run() -> void:
	var repeated: Dictionary = effect(20,128)
	var first: Dictionary = effect(20,8)
	var a: Dictionary = {"layers":[{},{}],"effect_layers":[first,effect(20,128,"105:0"),effect(30,8,"",true)]}
	var b: Dictionary = {"layers":[{},{},{}],"effect_layers":[repeated,effect(20,8,"105:1"),effect(22260,8),effect(22261,128)]}
	var tracks: Dictionary = {"idle":{"directions":[[a,b],[b,a]]},"attack":{"directions":[[b,a]]}}
	var record: Dictionary = {"body_id":22258,"tracks":tracks}
	var snapshot := PREPARED.new()
	snapshot.result = {"record":record}
	PREPARED.freeze(snapshot.result)
	var before: PackedByteArray = var_to_bytes(snapshot.result)
	HITCH._counters.clear()
	var layout: Dictionary = snapshot.layout()
	check(layout.layer_count == 3,"maximum body-layer slots retained")
	check(layout.effects.map(func(row: Dictionary) -> Variant: return PREPARED.effect_node_key(row)) == [20,"source_instance:105:0",30,"source_instance:105:1",22260,22261],"first source occurrence order and explicit identities retained")
	check(is_same(layout.effects[0],first) and not is_same(layout.effects[0],repeated),"first attributes win for repeated legacy physical identity")
	check(layout.is_read_only() and layout.effects.is_read_only() and layout.effects[0].is_read_only(),"plan and shared descriptors are immutable")
	check(var_to_bytes(snapshot.result) == before,"layout memo does not alter bank result bytes")
	check(int(HITCH._counters.get("sp2.layout_frames_scanned",0)) == 6,"cold layout visits each frame once")
	HITCH._counters.clear()
	check(is_same(layout,snapshot.layout()) and HITCH._counters == {"sp2.layout_hit":1},"warm layout returns exact memo without any frame scan")
	var old_screen_copy: bool = COMPOSITOR.screen_copy_available
	for available: bool in [false,true]:
		COMPOSITOR.screen_copy_available = available
		for mode: String in ["strict","compatible"]:
			var legacy := PREVIEW.new()
			var planned := PREVIEW.new()
			legacy._playback_mode = mode
			planned._playback_mode = mode
			legacy._configure_source_nodes(record,tracks.duplicate(true),3,"")
			planned._configure_source_nodes(record,tracks.duplicate(true),3,"",layout)
			check(node_signature(legacy) == node_signature(planned),"planned nodes equal mutable traversal including order/styles/Girtas: "+str(available)+" "+mode)
			check(legacy._effect_nodes.keys() == planned._effect_nodes.keys(),"same node identity order")
			for key: Variant in planned._effect_nodes:
				check(planned._effect_nodes[key] != legacy._effect_nodes[key],"nodes stay per-view")
				var left: Material = legacy._effect_nodes[key].material
				var right: Material = planned._effect_nodes[key].material
				if left != null: check(right != null and left != right,"materials stay per-view")
			legacy.free()
			planned.free()
	COMPOSITOR.screen_copy_available = old_screen_copy
	# Real immutable bank snapshots, invalidation and live ownership.
	PREPARED.clear()
	var data: Dictionary = fixture("user://node_layout_test_%d" % OS.get_process_id())
	var one := PREVIEW.new()
	var two := PREVIEW.new()
	HITCH._counters.clear()
	check(one._configure_reference_bank(data.path,data.sha,ACTOR,BINDINGS,LOOPS,"idle","npc"),"first actual preview prepares")
	check(int(HITCH._counters.get("sp2.layout_build",0)) == 1,"first actual preview builds layout")
	HITCH._counters.clear()
	check(two._configure_reference_bank(data.path,data.sha,ACTOR,BINDINGS,LOOPS,"idle","npc"),"second actual preview prepares")
	check(int(HITCH._counters.get("sp2.layout_hit",0)) == 1 and not HITCH._counters.has("sp2.layout_frames_scanned"),"live actual bank hit skips layout scans")
	check(is_same(one._reference_bank._prepared_snapshot,two._reference_bank._prepared_snapshot),"layout shares existing bank snapshot ownership")
	var owned: WeakRef = weakref(one._reference_bank._prepared_snapshot)
	one.free()
	check(owned.get_ref() != null,"second live view retains snapshot")
	two.free()
	check(owned.get_ref() == null and PREPARED.size() == 0,"layout adds no idle strong cache owner")
	var changed := PREVIEW.new()
	HITCH._counters.clear()
	check(changed._configure_reference_bank(data.path,data.sha,ACTOR,BINDINGS,LOOPS,"idle","npc"),"new life after last owner release prepares normally")
	check(int(HITCH._counters.get("sp2.layout_build",0)) == 1,"released snapshot layout is rebuilt, not retained globally")
	var old_snapshot: RefCounted = changed._reference_bank._prepared_snapshot
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	manifest["fixture_revision"] = "changed input"
	var new_sha: String = write_json(data.path,manifest)
	var fresh := PREVIEW.new()
	check(fresh._configure_reference_bank(data.path,new_sha,ACTOR,BINDINGS,LOOPS,"idle","npc"),"changed verified manifest can prepare")
	check(not is_same(old_snapshot,fresh._reference_bank._prepared_snapshot) and not is_same(old_snapshot.layout(),fresh._reference_bank._prepared_snapshot.layout()),"new input never reuses old layout")
	changed.free()
	fresh.free()
	print("REFERENCE_SP2_NODE_LAYOUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
