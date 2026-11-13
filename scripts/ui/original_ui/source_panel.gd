# Copyright (c) 2013-2014 Chukong Technologies Inc.
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
extends Node2D
## LayoutReader's supplied background fields; no replacement artwork.
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const DESTINATION_COPY=preload("res://scripts/ui/original_ui/source_destination_copy.gd")
var _options: Dictionary={}
var _color: Polygon2D
var _color_copy: BackBufferCopy
var _image: CanvasItem
static var _layer_material: ShaderMaterial

func configure(pack: RefCounted, options: Dictionary, extent: Vector2) -> Dictionary:
	_options=options.duplicate(true)
	var kind: int=int(options.colorType)
	if kind not in [0,1]:return {"ok":false,"error":"unknown_original_panel_color_type"}
	if kind!=0:
		var copy:=DESTINATION_COPY.new()
		copy.z_index=-2
		_color_copy=copy
		add_child(copy)
		_color=Polygon2D.new()
		_color.polygon=PackedVector2Array([Vector2.ZERO,Vector2(extent.x,0),Vector2(extent.x,-extent.y),Vector2(0,-extent.y)])
		_color.z_index=-2
		_color.material=layer_material()
		add_child(_color)
		copy.track(_color)
	var reference: Dictionary=options.backGroundImageData
	if not str(reference.get("path","")).is_empty():
		var texture: Texture2D=pack.texture(reference,true)
		if texture==null:return {"ok":false,"error":"original_panel_background_texture_missing"}
		if bool(options.backGroundScale9Enabled):
			var nine=preload("res://scripts/ui/original_ui/source_scale9.gd").new()
			var result: Dictionary=nine.configure(texture,extent,options.capInsets)
			if not result.ok:nine.free();return result
			nine.position=Vector2(0,-extent.y)
			_image=nine
		else:
			var flat:=Sprite2D.new()
			flat.texture=texture
			flat.position=Vector2(extent.x/2.0,-extent.y/2.0)
			flat.material=MATERIAL.original_default(texture)
			_image=flat
		_image.z_index=-1
		add_child(_image)
	set_source_display(Color.WHITE)
	return {"ok":true}

func set_source_display(display: Color) -> void:
	if _image!=null:MATERIAL.bind_tree_display(_image,display)
	if _color==null:return
	var alpha: float=float(int(int(_options.bgColorOpacity)*display.a8/255.0))/255.0
	_color.visible=alpha>0.0
	_color_copy.visible=alpha>0.0
	var source: Array=_options.bgColor
	var start:=Color(float(int(int(source[1])*display.r8/255.0))/255.0,float(int(int(source[2])*display.g8/255.0))/255.0,float(int(int(source[3])*display.b8/255.0))/255.0,alpha)
	var colors:=PackedColorArray([start,start,start,start])
	_color.vertex_colors=colors

static func layer_material() -> ShaderMaterial:
	if _layer_material!=null:return _layer_material
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D original_destination : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
    vec4 source = COLOR;
    vec4 destination = textureLod(original_destination, SCREEN_UV, 0.0);
    COLOR = source * source.a + destination * (1.0-source.a);
}
"""
	# Android: the destination copy samples black (see SourceBlend); the same
	# source-over result comes from the fixed mix blend.
	if not preload("res://scripts/ui/original_ui/source_blend.gd").screen_copy_available:
		shader.code="""shader_type canvas_item;
render_mode unshaded, blend_mix;
void fragment() {
    COLOR = clamp(COLOR, vec4(0.0), vec4(1.0));
}
"""
		DESTINATION_COPY.mark_copy_free(shader)
	_layer_material=ShaderMaterial.new()
	_layer_material.shader=shader
	return _layer_material
