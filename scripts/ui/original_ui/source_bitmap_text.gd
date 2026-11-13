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
	var staged: Dictionary=_stage(font_data,options.text,extent,keep_owned_font)
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
	if staged.has("draws"):
		_apply_glyphs(_glyph_layer,staged.draws)
	else:
		add_child(_glyph_layer)
	if is_instance_valid(previous) and previous!=_glyph_layer:
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

func _stage(font_data: Dictionary, value: String, extent: Vector2, reuse_owned: bool=false) -> Dictionary:
	# Validate every glyph/page/material before touching the visible layer.
	var planned: Dictionary=_layout(font_data,value,extent)
	if not planned.get("ok",false):return planned
	if reuse_owned and _can_reuse_layer():
		return {"ok":true,"layer":_glyph_layer,"draws":planned.draws,"native_size":planned.native_size}
	var layer:=Node2D.new()
	layer.name="OriginalBitmapGlyphs"
	_apply_glyphs(layer,planned.draws)
	return {"ok":true,"layer":layer,"native_size":planned.native_size}

func _layout(font_data: Dictionary, value: String, extent: Vector2) -> Dictionary:
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
	var draws: Array[Dictionary]=[]
	var origin:=Vector2((extent.x-width)/2.0,-extent.y+(extent.y-height)/2.0)
	for record: Dictionary in records:
		var glyph: Dictionary=record.glyph
		var texture: Variant=font_data.page_textures.get(glyph.page)
		if not texture is Texture2D:
			return _fail("source_bitmap_glyph_page_missing")
		if int(glyph.width)==0 or int(glyph.height)==0:continue
		var material: ShaderMaterial=SourceMaterial.original_default(texture)
		if material==null:
			return _fail("source_bitmap_material_unavailable")
		draws.append({"texture":texture,"material":material,
			"rect":Rect2(float(glyph.x),float(glyph.y),float(glyph.width),float(glyph.height)),
			"position":origin+Vector2(float(record.x),float(glyph.yoffset))})
	return {"ok":true,"draws":draws,"native_size":Vector2(width,height)}

func _can_reuse_layer() -> bool:
	if not is_instance_valid(_glyph_layer) or _glyph_layer.is_queued_for_deletion() or _glyph_layer.get_parent()!=self:return false
	# These nodes are private. Unexpected structure/metadata or layer styling
	# takes the original fresh-layer path instead of retaining foreign state.
	if _glyph_layer.get_script()!=null or not _glyph_layer.get_meta_list().is_empty():return false
	if _glyph_layer.transform!=Transform2D.IDENTITY or not _glyph_layer.visible or _glyph_layer.top_level:return false
	if _glyph_layer.modulate!=Color.WHITE or _glyph_layer.self_modulate!=Color.WHITE or _glyph_layer.material!=null or _glyph_layer.use_parent_material:return false
	if _glyph_layer.z_index!=0 or not _glyph_layer.z_as_relative or _glyph_layer.y_sort_enabled or _glyph_layer.show_behind_parent:return false
	if _glyph_layer.texture_filter!=CanvasItem.TEXTURE_FILTER_PARENT_NODE or _glyph_layer.texture_repeat!=CanvasItem.TEXTURE_REPEAT_PARENT_NODE:return false
	if _glyph_layer.light_mask!=1 or _glyph_layer.visibility_layer!=1 or _glyph_layer.clip_children!=CanvasItem.CLIP_CHILDREN_DISABLED:return false
	for child: Node in _glyph_layer.get_children():
		if not child is Sprite2D or child.is_queued_for_deletion() or child.get_script()!=null or child.get_child_count()!=0 or not child.get_meta_list().is_empty():return false
	return true

func _apply_glyphs(layer: Node2D, draws: Array) -> void:
	var existing: Array[Node]=layer.get_children()
	for index: int in draws.size():
		var sprite: Sprite2D
		if index<existing.size():sprite=existing[index] as Sprite2D
		else:
			sprite=Sprite2D.new()
		var record: Dictionary=draws[index]
		# Restore the fresh Sprite2D presentation while retaining node identity.
		sprite.top_level=false
		sprite.transform=Transform2D(0.0,record.position)
		sprite.visible=true
		sprite.modulate=Color.WHITE
		sprite.self_modulate=Color.WHITE
		sprite.z_index=0
		sprite.z_as_relative=true
		sprite.y_sort_enabled=false
		sprite.show_behind_parent=false
		sprite.light_mask=1
		sprite.visibility_layer=1
		sprite.clip_children=CanvasItem.CLIP_CHILDREN_DISABLED
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_PARENT_NODE
		sprite.texture_repeat=CanvasItem.TEXTURE_REPEAT_PARENT_NODE
		sprite.use_parent_material=false
		sprite.texture=record.texture
		sprite.centered=false
		sprite.hframes=1
		sprite.vframes=1
		sprite.frame=0
		sprite.offset=Vector2.ZERO
		sprite.flip_h=false
		sprite.flip_v=false
		sprite.region_enabled=true
		sprite.region_filter_clip_enabled=true
		sprite.region_rect=record.rect
		var prototype: ShaderMaterial=record.material
		var current: ShaderMaterial=sprite.material as ShaderMaterial
		if current==null or current==prototype or not bool(current.get_meta("source_private_display",false)) or bool(prototype.get_meta("source_private_display",false)) or current.shader!=prototype.shader or current.get_shader_parameter("source_pma")!=prototype.get_shader_parameter("source_pma") or current.get_shader_parameter("source_gray")!=prototype.get_shader_parameter("source_gray"):
			sprite.material=prototype
		SourceMaterial.bind_display(sprite,_display_color)
		if index>=existing.size():layer.add_child(sprite)
	# Retain only currently visible glyph slots, never a high-water pool.
	for index: int in range(existing.size()-1,draws.size()-1,-1):
		layer.remove_child(existing[index])
		existing[index].free()

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}
