extends RefCounted
## Split only reviewed original pixels while decoding one bounded chunk.
## No private archive rewrite, enlarged texture, repainting or duplicate owner.
static func split(image: Image, origin: Vector2, cuts: Array) -> Array[Dictionary]:
	var pieces: Array[Dictionary]=[]
	var chunk_box:=Rect2(origin,Vector2(image.get_size()))
	for cut: Dictionary in cuts:
		var polygon:=PackedVector2Array()
		for point: Array in cut.polygon_image: polygon.append(Vector2(point[0],point[1]))
		var box:=Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: box=box.expand(point)
		box=box.grow(1).intersection(chunk_box)
		if not box.has_area(): continue
		var start:=Vector2i(box.position.floor())
		var size:=Vector2i(box.end.ceil())-start
		var layer:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		var owned: int=0
		for y: int in range(size.y):
			for x: int in range(size.x):
				var global_pixel:=Vector2(start+Vector2i(x,y))
				if not Geometry2D.is_point_in_polygon(global_pixel+Vector2(.5,.5),polygon): continue
				var local:=Vector2i(global_pixel-origin)
				var pixel: Color=image.get_pixelv(local)
				if pixel.a==0: continue
				layer.set_pixel(x,y,pixel);image.set_pixelv(local,Color.TRANSPARENT);owned+=1
		if owned>0:
			pieces.append({"id":cut.id,"image":layer,"position":[start.x,start.y],"size":[size.x,size.y],"foot_image":cut.foot_image,"owned_pixels":owned})
	return pieces
