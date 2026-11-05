extends Node2D
## Cocos LoadingBar's source texture rectangle, not an invented progress skin.
var _sprite: Sprite2D
var _texture: Texture2D
var _extent: Vector2
var _direction: int
func configure(pack: RefCounted, options: Dictionary) -> Dictionary:
	_texture=pack.texture(options.textureData,true)
	if _texture==null:return {"ok":false,"error":"original_loading_texture_missing"}
	_direction=int(options.direction)
	if _direction not in [0,1]:return {"ok":false,"error":"unsupported_loading_direction"}
	var widget: Dictionary=options.widgetOptions
	_extent=Vector2(widget.size[0],widget.size[1])
	_sprite=Sprite2D.new()
	_sprite.texture=_texture
	_sprite.material=preload("res://scripts/ui/original_ui/source_material.gd").original_default(_texture)
	if _sprite.material==null:_sprite.free();return {"ok":false,"error":"original_material_unavailable"}
	_sprite.centered=false
	_sprite.region_enabled=true
	_sprite.region_filter_clip_enabled=true
	_sprite.scale=Vector2.ONE if bool(widget.ignoreSize) else _extent/_texture.get_size()
	add_child(_sprite)
	set_source_percent(float(options.percent))
	return {"ok":true}
func set_source_percent(percent: float) -> void:
	var width: float=_texture.get_width()*clampf(percent,0.0,100.0)/100.0
	_sprite.visible=width>0
	_sprite.region_rect=Rect2(0,0,width,_texture.get_height())
	_sprite.flip_h=_direction==1
	var length: float=_texture.get_width()*_sprite.scale.x
	_sprite.position=Vector2(length-width*_sprite.scale.x if _direction==1 else 0.0,-(_extent.y+_texture.get_height()*_sprite.scale.y)/2.0)
