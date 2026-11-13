# /****************************************************************************
#  Copyright (c) 2013      Zynga Inc.
#  Copyright (c) 2013-2014 Chukong Technologies Inc.
#  
#  http://www.cocos2d-x.org
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#  ****************************************************************************/
extends Node2D
## Single-line BMP subset of LabelTextFormatter::createStringSprites, translated
## from the retained Cocos reference above. Original glyph pixels only.
## font_data is parser.font_data plus page_textures:{int:Texture2D}.
## This node uses the widget-local rectangle (0,-extent.y)..(extent.x,0).
## Widget origin, anchor and serialized scale remain the caller's responsibility.
const SourceMaterial=preload("res://scripts/ui/original_ui/source_material.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var _font_data: Dictionary={}
var _options: Dictionary={}
var _extent: Vector2
var _glyph_layer: Node2D
var _display_color: Color=Color.WHITE
var native_size: Vector2

func configure(font_data: Dictionary, options: Dictionary, extent: Vector2) -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_configure(font_data,options,extent,false)
	FRAME_HITCH.detail("ui.bitmap_configure",started)
	return result

func _configure(font_data: Dictionary, options: Dictionary, extent: Vector2, keep_owned_font: bool) -> Dictionary:
	if not extent.is_finite() or extent.x<0 or extent.y<0:return _fail("source_bitmap_widget_extent_invalid")
	if not options.get("text") is String:return _fail("source_bitmap_text_missing")
	for key: String in ["common","pages","glyphs","kernings","page_textures"]:
		if not font_data.get(key) is Dictionary:return _fail("source_bitmap_font_data_missing_"+key)
	var common: Dictionary=font_data.common
	if not common.has("lineHeight") or float(common.lineHeight)<=0 or common.get("packed")!=0:return _fail("source_bitmap_common_unsupported")
	for page_id: Variant in font_data.pages:
		var texture: Variant=font_data.page_textures.get(page_id)
		if not texture is Texture2D:return _fail("source_bitmap_page_texture_missing")
		if texture.get_width()!=common.get("scaleW") or texture.get_height()!=common.get("scaleH"):return _fail("source_bitmap_page_texture_dimensions_mismatch")
	var staged: Dictionary=_stage(font_data,options.text,extent)
	if not staged.get("ok",false):return staged
	# Nothing displayed is replaced until all glyphs, pages and materials exist.
	var previous: Node2D=_glyph_layer
	_glyph_layer=staged.layer
	# Public configure always isolates the caller's mutable descriptor. A text
	# update already uses this instance's owned snapshot: keep validating it,
	# but do not recopy every unused glyph/kerning entry on each number change.
	if not keep_owned_font:_font_data=font_data.duplicate(true)
	_options=options.duplicate(true)
	_extent=extent
	native_size=staged.native_size
	add_child(_glyph_layer)
	if previous!=null:
		remove_child(previous)
		previous.free()
	return {"ok":true,"native_size":native_size}

func set_source_text(value: String) -> Dictionary:
	if _font_data.is_empty():return _fail("source_bitmap_not_configured")
	var started: int=FRAME_HITCH.now()
	var next: Dictionary=_options.duplicate(true)
	next.text=value
	var result: Dictionary=_configure(_font_data,next,_extent,true)
	# Inclusive detail only: callers can already account for this work in HUD
	# or menu sections. Do not introduce a second top-level elapsed section.
	FRAME_HITCH.detail("ui.bitmap_update",started)
	return result

func set_source_display(color: Color) -> void:
	_display_color=color
	if _glyph_layer!=null:
		for glyph: Node in _glyph_layer.get_children():
			SourceMaterial.bind_display(glyph,color)

func _stage(font_data: Dictionary, value: String, extent: Vector2) -> Dictionary:
	var glyphs: Dictionary=font_data.glyphs
	var kernings: Dictionary=font_data.kernings
	var records: Array=[]
	var next_x: float=0.0
	var longest: float=0.0
	var previous: int=-1
	var last_advance: float=0.0
	var last_width: float=0.0
	for index: int in range(value.length()):
		var codepoint: int=value.unicode_at(index)
		if codepoint==0 or codepoint==10 or codepoint==13 or codepoint>65535 or (codepoint>=55296 and codepoint<=57343):return _fail("source_bitmap_singleline_bmp_required")
		if not glyphs.has(codepoint):return {"ok":false,"error":"source_bitmap_glyph_missing","codepoint":codepoint}
		var glyph: Dictionary=glyphs[codepoint]
		if glyph.get("chnl")!=15:return _fail("source_bitmap_glyph_channel_unsupported")
		var kerning: float=float(kernings.get("%d:%d" % [previous,codepoint],0)) if previous>=0 else 0.0
		records.append({"glyph":glyph,"x":next_x+float(glyph.xoffset)+kerning})
		next_x+=float(glyph.xadvance)+kerning
		longest=maxf(longest,next_x)
		last_advance=float(glyph.xadvance)
		last_width=float(glyph.width)
		previous=codepoint
	# Native final-glyph adjustment uses width versus xAdvance, not xoffset.
	var width: float=longest-last_advance+last_width if last_advance<last_width else longest
	var height: float=float(font_data.common.lineHeight)
	var layer:=Node2D.new()
	layer.name="OriginalBitmapGlyphs"
	var origin:=Vector2((extent.x-width)/2.0,-extent.y+(extent.y-height)/2.0)
	for record: Dictionary in records:
		var glyph: Dictionary=record.glyph
		var texture: Variant=font_data.page_textures.get(glyph.page)
		if not texture is Texture2D:
			layer.free()
			return _fail("source_bitmap_glyph_page_missing")
		if int(glyph.width)==0 or int(glyph.height)==0:continue
		var material: ShaderMaterial=SourceMaterial.original_default(texture)
		if material==null:
			layer.free()
			return _fail("source_bitmap_material_unavailable")
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		sprite.centered=false
		sprite.region_enabled=true
		sprite.region_filter_clip_enabled=true
		sprite.region_rect=Rect2(float(glyph.x),float(glyph.y),float(glyph.width),float(glyph.height))
		sprite.position=origin+Vector2(float(record.x),float(glyph.yoffset))
		sprite.material=material
		SourceMaterial.bind_display(sprite,_display_color)
		layer.add_child(sprite)
	return {"ok":true,"layer":layer,"native_size":Vector2(width,height)}

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}
