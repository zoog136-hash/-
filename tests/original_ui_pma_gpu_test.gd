extends SceneTree
## Real Compatibility renderer readback of synthetic owner textures only.
## Run with a display/Xvfb, never --headless. This is not Android/private art.
const PIXELS=preload("res://scripts/ui/original_ui/source_asset_pixels.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _image(size_value: Vector2i, seed_value: int) -> Image:
	var pixels:=PackedByteArray()
	pixels.resize(size_value.x*size_value.y*4)
	var random:=RandomNumberGenerator.new()
	random.seed=seed_value
	for at: int in range(0,pixels.size(),4):pixels.encode_u32(at,random.randi())
	return Image.create_from_data(size_value.x,size_value.y,false,Image.FORMAT_RGBA8,pixels)

func _owner(source: Texture2D) -> Dictionary:
	return {"ok":true,"texture":source,"status":"verified_original_texture","provenance":{"member":{"format":"PNG","sha256":"synthetic-only"}},"consumer":"GPU regression"}

func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func _pixels_match(texture: Texture2D, expected: Image) -> bool:
	var actual: Image=texture.get_image()
	return actual!=null and actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("ORIGINAL_UI_PMA_GPU requires a real renderer; use Xvfb/OpenGL")
		quit(1)
		return
	PIXELS._pma_cache.clear()
	var image: Image=_image(Vector2i(4,4),1)
	var source:=ImageTexture.create_from_image(image)
	var owner: Dictionary=_owner(source)
	var first: Dictionary=PIXELS.consume_owner_result(owner)
	await _frame()
	check(first.ok and _pixels_match(first.texture,PACK.cocos_premultiply(image)),"first upload preserves every synthetic PMA byte on real renderer")
	check(_pixels_match(source,image),"original straight RGBA source remains unchanged")
	check(PIXELS.consume_owner_result(owner).texture==first.texture,"warm real-renderer request reuses the same texture")
	var updated_image: Image=_image(Vector2i(4,4),2)
	source.update(updated_image)
	await _frame()
	var updated: Dictionary=PIXELS.consume_owner_result(owner)
	await _frame()
	check(updated.texture!=first.texture and _pixels_match(updated.texture,PACK.cocos_premultiply(updated_image)),"source update invalidates and reads the new GPU pixels")
	check(_pixels_match(source,updated_image),"source update bytes remain straight and unmodified")
	var replaced_image: Image=_image(Vector2i(3,2),3)
	source.set_image(replaced_image)
	await _frame()
	var replaced: Dictionary=PIXELS.consume_owner_result(owner)
	await _frame()
	check(replaced.texture!=updated.texture and _pixels_match(replaced.texture,PACK.cocos_premultiply(replaced_image)),"source set_image invalidates dimensions and pixels")
	check(_pixels_match(first.texture,PACK.cocos_premultiply(image)),"previous external texture remains valid after source changes")
	replaced.texture.update(_image(Vector2i(3,2),4))
	await _frame()
	var repaired: Dictionary=PIXELS.consume_owner_result(owner)
	await _frame()
	check(repaired.texture!=replaced.texture and _pixels_match(repaired.texture,PACK.cocos_premultiply(replaced_image)),"mutated derivative is rebuilt from the verified source")
	repaired.texture.set_image(_image(Vector2i(2,2),5))
	await _frame()
	var resized: Dictionary=PIXELS.consume_owner_result(owner)
	await _frame()
	check(resized.texture!=repaired.texture and _pixels_match(resized.texture,PACK.cocos_premultiply(replaced_image)),"resized derivative cannot poison a future request")
	check(_pixels_match(source,replaced_image),"all conversions preserve the latest source pixels")
	PIXELS._pma_cache.clear()
	print("ORIGINAL_UI_PMA_GPU_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"driver":RenderingServer.get_video_adapter_name(),"renderer":"Compatibility/OpenGL","private_pack_used":false,"android_measured":false}))
	quit(0 if failures.is_empty() else 1)
