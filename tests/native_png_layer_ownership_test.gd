extends SceneTree
## Code fixture for lossless ownership and filtered-edge RGB, not original art.
const LAYERS=preload("res://scripts/maps/native_png_layers.gd")
func _initialize() -> void:
	var original:=Image.create(24,18,false,Image.FORMAT_RGBA8)
	for y: int in range(18):
		for x: int in range(24):original.set_pixel(x,y,Color8(30+x*7,40+y*8,100+x+y,255))
	var ground: Image=original.duplicate()
	var cuts: Array=[{"id":"tree","polygon_image":[[103,205],[112,201],[119,210],[109,215]],"foot_image":[110,215]}]
	var pieces: Array=LAYERS.split(ground,Vector2(100,200),cuts)
	var restored: Image=ground.duplicate();var seen: Dictionary={};var failures: Array=[]
	for piece: Dictionary in pieces:
		var origin:=Vector2i(piece.position[0]-100,piece.position[1]-200)
		var image: Image=piece.image
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var p: Vector2i=origin+Vector2i(x,y);var color: Color=image.get_pixel(x,y);var source: Color=original.get_pixelv(p)
				if Vector3(color.r,color.g,color.b)!=Vector3(source.r,source.g,source.b):failures.append("filtered foreground edge lost original RGB")
				if color.a==0:continue
				if seen.has(p) or ground.get_pixelv(p).a!=0:failures.append("duplicate visible owner")
				seen[p]=true;restored.set_pixelv(p,color)
	for y: int in range(18):
		for x: int in range(24):
			var a: Color=ground.get_pixel(x,y);var b: Color=original.get_pixel(x,y)
			if Vector3(a.r,a.g,a.b)!=Vector3(b.r,b.g,b.b):failures.append("filtered ground edge lost original RGB")
	if restored.get_data()!=original.get_data():failures.append("source RGBA roundtrip")
	if seen.is_empty() or pieces.is_empty():failures.append("no foreground pixels tested")
	print("NATIVE_PNG_OWNERSHIP_RESULT ",JSON.stringify({"checks":4,"exclusive_pixels":seen.size(),"failures":failures,"scope":"CODE_FIXTURE"}))
	quit(0 if failures.is_empty() else 1)
