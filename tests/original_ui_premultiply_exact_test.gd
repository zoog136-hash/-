extends SceneTree
## Full-byte comparison with the source Cocos scalar equation. This checks
## CPU RGBA8 conversion only, not a native GPU upload or private-pack render.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const OPT=preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")
var checks: int=0
var failures: Array[String]=[]
var checked_pixels: int=0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

static func scalar_reference(original: Image) -> PackedByteArray:
	var pixels: PackedByteArray=original.get_data()
	for at: int in range(0,pixels.size(),4):
		var alpha_plus_one: int=int(pixels[at+3])+1
		pixels[at]=(int(pixels[at])*alpha_plus_one)>>8
		pixels[at+1]=(int(pixels[at+1])*alpha_plus_one)>>8
		pixels[at+2]=(int(pixels[at+2])*alpha_plus_one)>>8
	return pixels

func compare(image: Image,label: String) -> void:
	var before: PackedByteArray=image.get_data()
	var actual: Image=OPT.convert(image)
	check(actual.get_data()==scalar_reference(image),label+": every output byte matches the Cocos equation")
	check(actual.get_data()==PACK.cocos_premultiply(image).get_data(),label+": complete bytes match the unchanged source-pack atlas path")
	check(actual.get_size()==image.get_size() and actual.get_format()==Image.FORMAT_RGBA8,label+": dimensions and RGBA8 format preserved")
	check(image.get_data()==before and image.get_format()==Image.FORMAT_RGBA8,label+": source pixels remain unchanged")
	var converted: PackedByteArray=actual.get_data()
	var alpha_preserved: bool=true
	for at: int in range(3,before.size(),4):
		if converted[at]!=before[at]:alpha_preserved=false;break
	check(alpha_preserved,label+": every alpha byte remains unchanged")
	checked_pixels+=image.get_width()*image.get_height()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Every RGB byte value appears with every alpha value; the blue mapping
	# is a permutation modulo 256, independent of the red/green ordering.
	var sweep:=PackedByteArray()
	sweep.resize(256*256*4)
	for alpha: int in 256:
		for channel: int in 256:
			var at: int=(alpha*256+channel)*4
			sweep[at]=channel;sweep[at+1]=255-channel;sweep[at+2]=(channel*73+7)%256;sweep[at+3]=alpha
	compare(Image.create_from_data(256,256,false,Image.FORMAT_RGBA8,sweep),"all channel/alpha pairs")
	var random:=RandomNumberGenerator.new()
	random.seed=20261112
	for size_value: Vector2i in [Vector2i(1,1),Vector2i(3,7),Vector2i(64,63),Vector2i(257,259),Vector2i(1024,1024)]:
		var pixels:=PackedByteArray()
		pixels.resize(size_value.x*size_value.y*4)
		for at: int in range(0,pixels.size(),4):pixels.encode_u32(at,random.randi())
		compare(Image.create_from_data(size_value.x,size_value.y,false,Image.FORMAT_RGBA8,pixels),"random "+str(size_value))
	# Exercise the decoded-PNG input route used by the image owner too.
	var source:=Image.create_from_data(256,256,false,Image.FORMAT_RGBA8,sweep)
	var decoded:=Image.new()
	var decoded_ok: bool=decoded.load_png_from_buffer(source.save_png_to_buffer())==OK
	check(decoded_ok,"synthetic PNG round trip decodes")
	if decoded_ok:
		decoded.convert(Image.FORMAT_RGBA8)
		compare(decoded,"decoded PNG")
	print("ORIGINAL_UI_PREMULTIPLY_EXACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"checked_pixels":checked_pixels,"scope":"synthetic_RGBA8_CPU_only"}))
	quit(0 if failures.is_empty() else 1)
