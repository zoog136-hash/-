extends Control
## Source cap-inset geometry, including negative center scales in small controls.
## Cocos 3.6 Scale9Sprite uses source corners, not a minimum control size.
func configure(texture: Texture2D, target: Vector2, source_cap: Array) -> Dictionary:
	var extent: Vector2=texture.get_size()
	var cap:=Rect2(float(source_cap[0]),float(source_cap[1]),float(source_cap[2]),float(source_cap[3]))
	if cap==Rect2():cap=Rect2(extent/3.0,extent/3.0)
	if cap.size.x<=0 or cap.size.y<=0:return {"ok":false,"error":"unsupported_zero_center"}
	# Upstream disables clipping for this legacy case, possibly sampling outside
	# the source sprite. A reconstructed frame cannot prove those outside pixels.
	if cap.end.x>extent.x and cap.end.y>extent.y:return {"ok":false,"error":"unsupported_unclipped_cap_overrun"}
	var sx: Array[float]=[0.0,cap.position.x,cap.end.x,extent.x]
	var sy: Array[float]=[0.0,cap.position.y,cap.end.y,extent.y]
	var dx: Array[float]=[0.0,sx[1],target.x-(extent.x-sx[2]),target.x]
	var dy: Array[float]=[0.0,sy[1],target.y-(extent.y-sy[2]),target.y]
	# Preserve center/edge/corner drawing order when negative scales overlap.
	for cell: Vector2i in [Vector2i(1,1),Vector2i(1,0),Vector2i(1,2),Vector2i(0,1),Vector2i(2,1),Vector2i(0,0),Vector2i(2,0),Vector2i(0,2),Vector2i(2,2)]:
		var x: int=cell.x
		var y: int=cell.y
		var source:=Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y])
		if source.size.x<=0 or source.size.y<=0:continue
		var clipped: Rect2=source.intersection(Rect2(Vector2.ZERO,extent))
		if not clipped.has_area():continue
		var factor:=Vector2((dx[x+1]-dx[x])/source.size.x,(dy[y+1]-dy[y])/source.size.y)
		var part:=Sprite2D.new()
		part.name="SourceSlice_%d_%d"%[x,y]
		part.texture=texture
		part.centered=false
		part.region_enabled=true
		part.region_rect=clipped
		part.region_filter_clip_enabled=true
		part.scale=factor
		part.position=Vector2(dx[x],dy[y])+(clipped.position-source.position)*factor
		add_child(part)
	size=target
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	return {"ok":true}
