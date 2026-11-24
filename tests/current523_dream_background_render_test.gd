extends SceneTree
## CPU routing always runs; optional GPU check reads exact private PNG/S32/TI2
## inputs and uses the production block viewport. Not an emulated full map.
const BG = preload("res://scripts/maps/current523_map_background.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
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
	check(BG.dream_layers(303,"303/").is_empty() and BG.dream_layers(22801,"111/").is_empty(),"strict logical Land and source folder")
	check(BG.dream_layers(22801,"303/","user://empty-dream-bg-fixture/").is_empty(),"missing pair fails closed")
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
	var originals: String = OS.get_environment("TWILIGHT_DREAM_BACKGROUND_VISUAL")
	if not originals.is_empty():
		await _verify_render(originals,lane)
	print("CURRENT523_DREAM_BACKGROUND_RENDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"visual_requested":not originals.is_empty()}))
	quit(0 if failures.is_empty() else 1)

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
