extends SceneTree
## Full-byte comparison with the source Cocos scalar equation. This checks
## CPU RGBA8 conversion only, not a native GPU upload or private-pack render.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const ATLAS=preload("res://scripts/ui/original_ui/atlas_pixels.gd")
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
	check(actual.get_data()==PACK.cocos_premultiply(image).get_data(),label+": source-pack atlas wrapper uses the same exact conversion")
	check(actual.get_size()==image.get_size() and actual.get_format()==Image.FORMAT_RGBA8,label+": dimensions and RGBA8 format preserved")
	check(image.get_data()==before and image.get_format()==Image.FORMAT_RGBA8,label+": source pixels remain unchanged")
	var converted: PackedByteArray=actual.get_data()
	var alpha_preserved: bool=true
	for at: int in range(3,before.size(),4):
		if converted[at]!=before[at]:alpha_preserved=false;break
	check(alpha_preserved,label+": every alpha byte remains unchanged")
	checked_pixels+=image.get_width()*image.get_height()

func check_atlas_crop() -> void:
	var page:=Image.create_empty(6,5,false,Image.FORMAT_RGBA8)
	for y: int in page.get_height():
		for x: int in page.get_width():
			page.set_pixel(x,y,Color8(x*31+1,y*43+1,x+y,[0,1,128,254,255][y]))
	var before: PackedByteArray=page.get_data()
	for rotated: bool in [false,true]:
		for padded: bool in [false,true]:
			var spec: Dictionary={"rect":[1,1,3,2],"source_rect":[2,1,3,2] if padded else [0,0,3,2],
				"source_size":[7,5] if padded else [3,2],"rotated":rotated}
			var raw: Dictionary=ATLAS.decode(page,spec)
			var converted: Dictionary=ATLAS.decode(page,spec,true)
			check(raw.error=="" and converted.error=="","valid atlas geometry")
			check(converted.image.get_size()==raw.image.get_size() and converted.image.get_data()==scalar_reference(raw.image),
				"trim, rotation and padding preserve full-canvas scalar PMA")
	var tile: Dictionary={"rect":[0,0,1,1],"source_rect":[1,0,1,1],"source_size":[3,2]}
	var verified:=Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	verified.fill(Color8(254,254,254,255))
	verified.set_pixel(1,0,Color8(254,254,254,254))
	verified.set_meta(ATLAS.OPAQUE_CROPS,{})
	for _repeat: int in 2:
		check(ATLAS.decode(verified,tile,true).image.get_pixel(1,0)==Color8(254,254,254,255),"reused opaque crop keeps its original placement")
	check(verified.get_meta(ATLAS.OPAQUE_CROPS).size()==1,"repeated crop records a single opaque rectangle")
	tile.rect[0]=1
	check(ATLAS.decode(verified,tile,true).image.get_pixel(1,0)==Color8(253,253,253,254),"other rectangles still convert their partial alpha")
	var replacement:=Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	replacement.fill(Color8(254,254,254,254))
	replacement.set_meta(ATLAS.OPAQUE_CROPS,{})
	tile.rect[0]=0
	check(ATLAS.decode(replacement,tile,true).image.get_pixel(1,0)==Color8(253,253,253,254) and replacement.get_meta(ATLAS.OPAQUE_CROPS).is_empty(),"replacement page cannot inherit an opaque proof")
	check(not page.has_meta(ATLAS.OPAQUE_CROPS),"caller-owned images do not retain opacity proofs")
	var invalid: Dictionary={"rect":[0,0,3,2],"source_rect":[1,1,3,2],"source_size":[3,2]}
	check(ATLAS.decode(page,invalid,true)=={"error":"trim_out_of_canvas"},"PMA preserves invalid frame rejection")
	check(before==page.get_data(),"PMA reconstruction leaves the shared atlas unchanged")

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
	var opaque:=Image.create_empty(127,93,false,Image.FORMAT_RGBA8)
	opaque.fill(Color8(183,44,79,255))
	compare(opaque,"fully opaque RGBA8")
	var near_opaque:=Image.create_empty(11,9,false,Image.FORMAT_RGBA8)
	near_opaque.fill(Color8(253,128,17,255))
	near_opaque.set_pixel(10,8,Color8(253,128,17,254))
	compare(near_opaque,"near-opaque RGBA8 including alpha 254")
	var gray:=Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	gray.fill(Color8(171,171,171,254))
	compare(gray,"grayscale alpha 254")
	var bright:=Image.create_empty(256,3,false,Image.FORMAT_RGBA8)
	bright.fill(Color8(254,254,254,255))
	compare(bright,"opaque despite many RGB bytes of 254")
	check(not is_same(OPT.convert(bright),bright) and is_same(OPT.convert(bright,true),bright),"only an owned opaque crop is returned by identity")
	bright.set_pixel(255,2,Color8(127,71,43,254))
	compare(bright,"one alpha 254 after many bright RGB bytes")
	check(not is_same(OPT.convert(bright,true),bright),"a near-opaque crop still requires conversion")
	check_atlas_crop()
	var transparent:=Image.create_empty(17,21,false,Image.FORMAT_RGBA8)
	transparent.fill(Color8(183,44,79,0))
	compare(transparent,"transparent pixels with nonzero stored RGB")
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
