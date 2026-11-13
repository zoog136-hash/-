extends "res://tests/reference_sp2_asset_sharing_test.gd"
## Synthetic SP2: validate warm effects once, preserve cold priming and rejection.
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

class CountingBank extends "res://scripts/resources/reference_sp2_bank.gd":
	var validations: int = 0
	var pixel_requests: int = 0
	func render_layer(layer: Dictionary, pixels: bool = true) -> Dictionary:
		validations += 1
		if pixels: pixel_requests += 1
		return super.render_layer(layer,pixels)

class ClockPreview extends "res://scripts/animation/original_source_preview.gd":
	var restarts: int = 0
	func installed() -> bool: return true
	func advance_reference_source(_delta: float, _role: String, _direction: int) -> bool:
		last_source_frame = 77
		return true
	func restart_reference_source(_role: String, _sequence: int) -> bool:
		restarts += 1
		return true

class ClockView extends "res://scripts/monsters/current523_source_bank_view.gd":
	var duration_reads: int = 0
	var attack_duration: float = 0.5
	func duration(_role: String) -> float:
		duration_reads += 1
		return attack_duration

func effect_fixture(directory: String, visibility: String) -> Dictionary:
	var member: String = "Sprite/9001-0.sp2"
	var raw_path: String = directory.path_join("raw/"+member)
	write_bytes(raw_path,make_sp2([0xF800,0x07E0,0x001F,0xFFFF],[[0,1,2,3]]))
	var path: String = directory.path_join("manifest.json")
	var sha: String = write_json(path,manifest([9001],{member:member_spec(member,raw_path)},"effect_once"))
	var bank := CountingBank.new()
	var opened: Dictionary = bank.load_static(path,sha,9001)
	check(opened.ok,"synthetic pinned effect fixture loads")
	var effect: Dictionary = preview_layer(bank,opened.layers[0],0)
	effect["kind"] = "clothes"
	effect["source_attributes"] = ["8"]
	effect["source_attributes_unresolved"] = visibility == "unresolved"
	var frame: Dictionary = {"duration":0.1,"source_ticks":1,"source_group":0,"source_frame":0,"layers":[],"effect_layers":[effect]}
	var directions: Array = []
	for _index: int in 8: directions.append([frame])
	var track: Dictionary = {"source_action_id":0,"source_action_key":"synthetic_effect","source_sprite_id":9001,"loop":true,"directions":directions,"static_pending_timing":false,"timing_origin":"synthetic"}
	var preview = PREVIEW.new()
	preview._root = directory
	preview._playback_mode = "strict" if visibility == "strict" else "compatible"
	preview._reference_bank = bank
	preview._configure_source_nodes({"source_sprite_id":9001},{"idle":track},0,path)
	root.add_child(preview)
	if visibility == "missing_node":
		for node: Node in preview._effect_nodes.values(): node.free()
		preview._effect_nodes.clear()
	bank.validations = 0
	bank.pixel_requests = 0
	return {"preview":preview,"bank":bank,"raw_path":raw_path,"effect":effect}

func clock_fixture() -> ClockView:
	var view := ClockView.new()
	var preview := ClockPreview.new()
	view._preview = preview
	view.add_child(preview)
	view._tracks = {"run":{}}
	return view

func run() -> void:
	var old_copy: bool = COMPOSITOR.screen_copy_available
	COMPOSITOR.screen_copy_available = false
	var directory: String = "user://source_effect_once_%d" % OS.get_process_id()
	for visibility: String in ["visible","strict","unresolved","missing_node"]:
		var sample: Dictionary = effect_fixture(directory.path_join(visibility),visibility)
		var view = sample.preview
		check(view.advance_reference_source(0.0,"idle",0),visibility+" initial advance succeeds")
		var first_calls: int = 2 if visibility == "visible" else 1
		check(sample.bank.validations == first_calls,visibility+" initial validation preserves shared texture priming")
		check(view.advance_reference_source(0.02,"idle",0),visibility+" repeated advance succeeds")
		check(sample.bank.validations == first_calls+1,visibility+" repeated frame verifies exactly once")
		if visibility == "visible":
			var texture: Texture2D = view._effect_nodes.values()[0].texture
			check(texture != null and image_sha(texture.get_image()) == unshared_hash(sample.raw_path,0),"drawn effect retains exact decoded pixels")
			check(view._effect_nodes.values()[0].visible,"compatible effect remains visible")
		elif visibility != "missing_node": check(not view._effect_nodes.values()[0].visible,visibility+" effect remains hidden")
		view.free()
		for warm: bool in [false,true]:
			for mutation: String in ["changed_size","deleted"]:
				var trial: Dictionary = effect_fixture(directory.path_join(visibility+str(warm)+mutation),visibility)
				if warm: check(trial.preview.advance_reference_source(0.0,"idle",0),"warm fixture draws before mutation")
				if mutation == "deleted": DirAccess.remove_absolute(trial.raw_path)
				else: write_bytes(trial.raw_path,FileAccess.get_file_as_bytes(trial.raw_path)+PackedByteArray([0]))
				var before: int = trial.bank.validations
				check(not trial.preview.advance_reference_source(0.02,"idle",0),"reject "+visibility+" "+mutation+" warm="+str(warm))
				check(trial.bank.validations == before+1,"failure validated once and aborted")
				check(trial.preview._reference_bank == null and trial.preview._effect_nodes.is_empty(),"failed effect releases preview state")
				trial.preview.free()
	# A warm owned texture still verifies hidden effects and missing nodes.
	for hidden: bool in [true,false]:
		var retained: Dictionary = effect_fixture(directory.path_join("retained"+str(hidden)),"visible")
		check(retained.preview.advance_reference_source(0.0,"idle",0),"retained texture first draws")
		if hidden: retained.effect.source_attributes_unresolved = true
		else:
			for node: Node in retained.preview._effect_nodes.values(): node.free()
			retained.preview._effect_nodes.clear()
		var before: int = retained.bank.validations
		check(retained.preview.advance_reference_source(0.01,"idle",0) and retained.bank.validations == before+1,"warm hidden/missing node validates once")
		if hidden: check(not retained.preview._effect_nodes.values()[0].visible,"warm unresolved effect hides its retained texture")
		DirAccess.remove_absolute(retained.raw_path)
		check(not retained.preview.advance_reference_source(0.01,"idle",0) and retained.bank.validations == before+2,"warm hidden/missing node rejects deletion")
		retained.preview.free()
	# Existing texture budget failure still aborts before a cold allocation.
	var budget: Dictionary = effect_fixture(directory.path_join("budget"),"visible")
	budget.preview._reference_texture_budget = {"limit":1,"used":0}
	check(not budget.preview.advance_reference_source(0.0,"idle",0),"cold texture budget refusal survives validation consolidation")
	check(budget.bank.validations == 2 and budget.preview.reference_bank_status.get("reason") == "source_texture_budget_exceeded","cold budget failure retains priming and original reason")
	budget.preview.free()
	# A new bank can share an existing texture even before it owns a parse key.
	var shared_dir: String = directory.path_join("shared")
	var first: Dictionary = effect_fixture(shared_dir,"visible")
	check(first.preview.advance_reference_source(0.0,"idle",0),"first texture owner draws")
	var shared_texture: Texture2D = first.preview._effect_nodes.values()[0].texture
	var second: Dictionary = effect_fixture(shared_dir,"visible")
	second.bank._release_parsed()
	check(second.bank.parsed_asset_key(str(second.effect.member)).is_empty(),"new owner begins without a parsed key")
	var created: int = int(ASSETS.stats().texture.counters.get("created",0))
	HITCH._counters.clear()
	check(second.preview.advance_reference_source(0.0,"idle",0),"unprimed second owner draws")
	check(is_same(shared_texture,second.preview._effect_nodes.values()[0].texture),"cold priming reuses the existing shared texture")
	check(int(ASSETS.stats().texture.counters.get("created",0)) == created,"cold shared handoff makes no additional texture")
	check(second.bank.validations == 2 and second.bank.pixel_requests == 0 and not HITCH._counters.has("sp2.texture_created"),"cold shared handoff primes without pixel decode or texture upload")
	first.preview.free();second.preview.free()
	# The real preview's nonreference path still draws its ordinary PNG layer.
	var legacy: Dictionary = effect_fixture(directory.path_join("legacy"),"visible")
	var png: String = directory.path_join("legacy/effect.png")
	var picture: Image = Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	picture.fill(Color.RED)
	check(picture.save_png(png) == OK,"synthetic legacy PNG written")
	legacy.preview._reference_bank = null
	legacy.effect.path = "effect.png"
	legacy.effect.texture_key = "legacy_effect"
	legacy.preview._advance_selected_source(0.0,0)
	check(legacy.bank.validations == 0 and legacy.preview._effect_nodes.values()[0].visible,"nonreference effect avoids bank and still displays")
	check(image_sha(legacy.preview._effect_nodes.values()[0].texture.get_image()) == image_sha(picture),"nonreference pixels unchanged")
	legacy.preview.free()
	var actor := clock_fixture()
	for state: String in ["idle","walk","run","patrol","chase","hit"]:
		actor.advance(0.01,state,0,0,false,false)
		check(actor.duration_reads == 0,"no unused attack-duration scan for "+state)
	actor.advance(0.01,"idle",0,0,false,true)
	check(actor._role == "death" and actor.duration_reads == 0,"death role avoids unused attack-duration scan")
	actor.advance(0.49,"idle",0,1,true,false)
	check(actor._role == "attack" and actor._source_attack and actor.duration_reads == 1,"attack keeps its pre-deadline state")
	actor.advance(0.01,"idle",0,1,false,false)
	check(not actor._source_attack and actor.duration_reads == 2,"attack ends on the same duration boundary")
	actor.advance(0.01,"idle",0,1,false,false)
	check(actor._role == "idle" and actor.duration_reads == 2 and actor.last_source_frame == 77,"post-attack idle clock and frame are retained")
	var other := clock_fixture()
	other.attack_duration = 0.0
	other.advance(0.01,"idle",0,1,true,false)
	check(not other._source_attack and other.duration_reads == 1 and actor.duration_reads == 2,"zero-duration attack completion and instance isolation retained")
	actor.free();other.free()
	COMPOSITOR.screen_copy_available = old_copy
	print("SOURCE_EFFECT_VALIDATION_ONCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
