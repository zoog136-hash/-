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
extends "res://scripts/ui/original_ui/source_button.gd"
## Original UICheckBox's five renderers and state transitions.
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const FIELDS=["backGroundBoxData","backGroundBoxSelectedData","frontCrossData","backGroundBoxDisabledData","frontCrossDisabledData"]
var renderers: Array[Sprite2D]=[]
var selected: bool=false
var _source_options: Dictionary={}
var _background_scale:=Vector2.ONE
var _source_display:=Color.WHITE
var _selection_callback: Callable

func configure(pack: RefCounted, options: Dictionary, _omit_invisible_title: bool=false) -> Dictionary:
	# Keep the Button configure signature; a CheckBox has no title renderer.
	_source_options=options.duplicate(true)
	var widget: Dictionary=options.widgetOptions
	if bool(widget.ignoreSize):return {"ok":false,"error":"unverified_intrinsic_checkbox_size"}
	_extent=Vector2(widget.size[0],widget.size[1])
	for field: String in FIELDS:
		var sprite:=Sprite2D.new()
		sprite.name=field
		var reference: Dictionary=options[field]
		if not str(reference.path).is_empty():
			sprite.texture=pack.texture(reference,true)
			if sprite.texture==null:sprite.free();return {"ok":false,"error":"original_checkbox_texture_missing:"+field}
			sprite.material=MATERIAL.original_default(sprite.texture)
		add_child(sprite);renderers.append(sprite)
	# Reader applies selected/bright before the first adaptRenderers visit.
	renderers[2].visible=false
	set_source_state("normal")
	set_selected(bool(options.selectedState))
	set_source_state("normal" if bool(options.displaystate) else "disabled")
	for sprite: Sprite2D in renderers:
		if sprite.texture!=null:
			sprite.position=Vector2(_extent.x/2.0,-_extent.y/2.0)
			sprite.scale=_extent/sprite.texture.get_size()
	if renderers[0].texture!=null:_background_scale=renderers[0].scale
	return {"ok":true,"selected":selected,"inspection_only":true}

func set_selected(value: bool) -> Dictionary:
	if selected!=value:
		selected=value
		if renderers.size()==5:renderers[2].visible=selected
	return {"ok":true,"selected":selected}

func _normal_materials(gray: bool) -> void:
	for index: int in [0,2]:
		var sprite: Sprite2D=renderers[index]
		if sprite.texture!=null:sprite.material=MATERIAL.original_default(sprite.texture,gray)

func set_source_state(state: String) -> Dictionary:
	if state not in ["normal","pressed","disabled"] or renderers.size()!=5:return {"ok":false,"error":"unknown_original_checkbox_state"}
	if state=="normal":
		renderers[0].visible=true
		for index: int in [1,3,4]:renderers[index].visible=false
		_normal_materials(false)
		renderers[0].scale=_background_scale;renderers[2].scale=_background_scale
		if selected:renderers[2].visible=true
	elif state=="pressed":
		_normal_materials(false)
		if str(_source_options.backGroundBoxSelectedData.path).is_empty():
			renderers[0].scale=_background_scale+Vector2(0.1,0.1)
			renderers[2].scale=_background_scale+Vector2(0.1,0.1)
		else:
			renderers[0].visible=false;renderers[1].visible=true
			renderers[3].visible=false;renderers[4].visible=false
	else:
		if str(_source_options.backGroundBoxDisabledData.path).is_empty() or str(_source_options.frontCrossDisabledData.path).is_empty():
			_normal_materials(true)
		else:
			renderers[0].visible=false;renderers[3].visible=true
		renderers[1].visible=false;renderers[2].visible=false
		renderers[0].scale=_background_scale;renderers[2].scale=_background_scale
		if selected:renderers[4].visible=true
		_armed=false
	current_state=state
	set_source_display(_source_display)
	return {"ok":true,"state":state,"selected":selected,"inspection_only":not _selection_callback.is_valid()}

func set_source_display(color: Color) -> void:
	_source_display=color
	MATERIAL.bind_tree_display(self,color)

func bind_activation(callback: Callable, extent: Vector2, source_touch: bool) -> void:
	_selection_callback=callback
	super.bind_activation(_toggle_and_dispatch,extent,source_touch)

func _toggle_and_dispatch() -> Variant:
	set_selected(not selected)
	return _selection_callback.call(selected)
