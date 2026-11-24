extends SceneTree
## CPU routing always runs; optional GPU check reads exact private PNG/S32/TI2
## inputs and uses the production block viewport. Not an emulated full map.
const BG = preload("res://scripts/maps/current523_map_background.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
var baked_evidence: Dictionary = {}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	var left: int = (47<<8)|199
	var right: int = (47<<8)|202
	var ordinary: int = (47<<8)|198
	check(BG.dream_floor_background(-2,left) and BG.dream_floor_background(-2,right),"two verified 0x08 floor refs")
	check(not BG.dream_floor_background(-2,ordinary) and not BG.dream_floor_background(-1,left) and not BG.dream_floor_background(0,right),"ordinary Tile47 and upper layers remain unchanged")
	check(not BG.dream_floor_background(-2,4294967295) and not BG.dream_floor_background(-2,0),"no changes to blank or arbitrary floor")
	var lane := PackedInt64Array([10,20,left,34,20,right,58,20,ordinary])
	check(RENDERER._dream_floor_rects(lane)==PackedInt64Array([10,20,34,20]),"only exact flagged destination rects selected")
	var holes := PackedInt64Array([34,20,10,20,100,20,34,20,15,44,40,44])
	var runs: PackedInt64Array=RENDERER._dream_floor_runs(holes)
	check(runs==PackedInt64Array([10,20,48,100,20,24,15,44,24,40,44,24]),"same-y overlap/touch coalesced, gaps and distinct y preserved")
	check(BG.dream_layers(303,"303/").is_empty() and BG.dream_layers(22801,"111/").is_empty(),"strict logical Land and source folder")
	if OS.get_environment("TWILIGHT_DREAM_VERIFY_INSTALLED")=="1":
		# The release descriptor's ordinary environment selection is the only
		# image source here; never allow user://source523_map_bg to mask a miss.
		var resolved: Dictionary=BG.resolve_layers(22801)
		check(resolved.get("ok",false),"real source definitions and installed release images resolve: "+str(resolved.get("reason","")))
		if resolved.get("ok",false):
			check(resolved.sky.id==691 and resolved.cloud.id==690 and resolved.sky.sha256==BG.DREAM_SHA["normal_cloud_sky.png"] and resolved.cloud.sha256==BG.DREAM_SHA["normal_cloud.png"],"both real AssetView IDs and selected member bytes match")
		check(BG.dream_layers(22801,"303/","user://empty-dream-bg-fixture/").size()==2,"renderer gets both released images, no private override")
	else:
		check(BG.dream_layers(22801,"303/","user://empty-dream-bg-fixture/").is_empty(),"no selected image pack or override fails closed")
	var exact_input: String = OS.get_environment("TWILIGHT_DREAM_BACKGROUND_ORIGINALS")
	if not exact_input.is_empty():
		var actual: Dictionary = BG.dream_layers(22801,"303/",exact_input)
		check(actual.size()==2,"admit exact retained original images through production loader")
		var source: PackedByteArray = FileAccess.get_file_as_bytes(exact_input.path_join("80007ffd.s32"))
		var a: int = 0
		var b: int = 0
		for i: int in range(8192 if source.size()>=32768 else 0):
			var ref: int = source.decode_u32(i*4)
			a+=int(ref==left); b+=int(ref==right)
		check(a>0 and a==b,"actual retained Dream Island chunk references both flags")
		if a>0 and actual.size()==2:
			_check_source_block(source,actual,exact_input)
	var originals: String = OS.get_environment("TWILIGHT_DREAM_BACKGROUND_VISUAL")
	if not originals.is_empty():
		await _verify_render(originals,lane)
	print("CURRENT523_DREAM_BACKGROUND_RENDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"visual_requested":not originals.is_empty(),"source_block":baked_evidence}))
	quit(0 if failures.is_empty() else 1)

## Exercise the production worker projection/binning and _bake_block, even
## headless. Inputs are the original chunk's actual floor words. Translate
## the chunk to a local origin (not a phone camera or pixel capture).
func _check_source_block(raw: PackedByteArray, layers: Dictionary, directory: String) -> void:
	var halves:=PackedInt32Array(); var ys:=PackedInt32Array(); var kinds:=PackedInt32Array(); var refs:=PackedInt64Array()
	for idx: int in 8192:
		halves.append(idx&127); ys.append(idx>>7); kinds.append(-2); refs.append(raw.decode_u32(idx*4))
	var opts: Dictionary={"origin":Vector2i.ZERO,"overlap":{Vector2i.ZERO:true},"generic":true,"basis_x":Vector2(24,-12),"basis_y":Vector2(24,12),"shift":Vector2.ZERO,"grid_origin":Vector2i.ZERO}
	var projected: Dictionary=RENDERER._project_static(opts,halves,ys,kinds,refs).packed
	var bins: Dictionary=RENDERER._bin_chunk(projected)
	var best:=PackedInt64Array(); var cell:=Vector2i.ZERO
	for key: Vector2i in bins:
		var lane:=PackedInt64Array()
		for idx: int in bins[key][-2]:
			var ref: int=projected[-2][idx+2]
			if BG.dream_floor_background(-2,ref):
				lane.append(projected[-2][idx]); lane.append(projected[-2][idx+1]); lane.append(ref)
		if lane.size()>best.size(): best=lane; cell=key
	var atlas: Image=Image.load_from_file(directory.path_join("private_tile47_atlas.png"))
	if atlas==null or best.is_empty(): check(false,"original chunk floor and source Tile47 atlas required");return
	var renderer:=RENDERER.new()
	root.add_child(renderer)
	var built: Dictionary={"draws":best.size()/3,"count":best.size()/3,"raw_ff":0,"unresolved":0,"commands":{-2:best},"atlases":{47:ImageTexture.create_from_image(atlas)}}
	var old: Dictionary=renderer._bake_block(cell,built)
	renderer._dream_background=layers
	var current: Dictionary=renderer._bake_block(cell,built)
	check(not old.has("dream_floor_replaced") and current.get("dream_floor_replaced")==best.size()/3,"same production block kept before and admitted after")
	var runs: PackedInt64Array=RENDERER._dream_floor_runs(RENDERER._dream_floor_rects(best))
	var baseline: Dictionary={}; var compact: Dictionary={}
	for i: int in range(0,best.size(),3):
		for dx: int in 24: baseline[Vector2i(best[i]+dx,best[i+1])]=true
	for i: int in range(0,runs.size(),3):
		for dx: int in runs[i+2]: compact[Vector2i(runs[i]+dx,runs[i+1])]=true
	check(baseline==compact and current.dream_draw_runs==runs.size()/3 and current.dream_draw_runs<current.dream_floor_replaced,"preserve every original span, draw fewer rectangles in this source block")
	baked_evidence={"source":"80007ffd.s32","flagged_floor_slots":current.dream_floor_replaced,"draw_rect_runs":current.dream_draw_runs,"same_coverage":baseline==compact}
	renderer.free()

# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_DREAM_BACKGROUND_VISUAL
func _verify_render(directory: String,lane: PackedInt64Array) -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"visual verification needs renderer")
		return
	var actual: Dictionary = BG.dream_layers(22801,"303/",directory)
	check(actual.size()==2,"verify/load both exact original PNGs")
	var atlas: Image = Image.load_from_file(directory.path_join("private_tile47_atlas.png"))
	if atlas==null or actual.size()!=2:
		check(false,"both layers and original atlas required")
		return
	var tex: ImageTexture = ImageTexture.create_from_image(atlas)
	var renderer := RENDERER.new()
	root.add_child(renderer)
	var built: Dictionary = {"draws":3,"count":3,"raw_ff":0,"unresolved":0,"commands":{-2:lane},"atlases":{47:tex}}
	var before: Dictionary = renderer._bake_block(Vector2i.ZERO,built)
	renderer._dream_background = actual
	var after: Dictionary = renderer._bake_block(Vector2i.ZERO,built)
	await process_frame
	await RenderingServer.frame_post_draw
	var old: Image = before.viewport.get_texture().get_image()
	var new: Image = after.viewport.get_texture().get_image()
	check(after.get("dream_draw_runs")==1,"two adjacent slots share a single GPU draw command")
	check(after.get("dream_floor_replaced")==2,"runtime baked a bounded two-slot layer")
	check(old.get_region(Rect2i(10,20,48,24)).get_data()!=new.get_region(Rect2i(10,20,48,24)).get_data(),
		"rendered flag slots differ from original placeholder pixels")
	check(new.get_pixel(11,21).a>0.95 and new.get_pixel(35,21).a>0.95,"verified background fills admitted slots")
	check(old.get_region(Rect2i(58,20,24,24)).get_data()==new.get_region(Rect2i(58,20,24,24)).get_data(),"ordinary floor pixels unchanged")
	check(new.get_pixel(1,1).a==0.0,"no sky leaks outside marked floor")
	if OS.get_environment("TWILIGHT_DREAM_TEST_CAPTURE")=="1":
		old.get_region(Rect2i(0,12,96,44)).save_png(directory.path_join("renderer-before.png"))
		new.get_region(Rect2i(0,12,96,44)).save_png(directory.path_join("renderer-after.png"))
	renderer.free()
