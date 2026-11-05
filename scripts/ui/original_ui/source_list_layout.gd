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
extends RefCounted
## Source ListViewReader + ListView/LinearLayoutManager initial row layout.
## This does not invent row content, scrolling input or a gameplay data model.
static func arrange(options: Dictionary, extent: Vector2, items: Array[Dictionary]) -> Dictionary:
	var direction: String=str(options.get("directionType",""))
	if direction not in ["","Vertical"]:return {"ok":false,"error":"unverified_original_list_direction"}
	var vertical: bool=direction=="Vertical"
	var alignment: String=str(options.get("horizontalType","") if vertical else options.get("verticalType",""))
	if alignment not in (["","Align_Right","Align_HorizontalCenter"] if vertical else ["","Align_Bottom","Align_VerticalCenter"]):return {"ok":false,"error":"unverified_original_list_gravity"}
	if items.is_empty():return {"ok":true,"positions":[],"empty_container_only":true}
	var total: float=float((items.size()-1)*int(options.itemMargin))
	for item: Dictionary in items:
		if bool(item.get("ignore_size",false)):return {"ok":false,"error":"unverified_intrinsic_list_item_size"}
		total+=float(item.size[1] if vertical else item.size[0])
	var inner:=Vector2(extent.x,maxf(extent.y,total)) if vertical else Vector2(maxf(extent.x,total),extent.y)
	var boundary: float=inner.y if vertical else 0.0
	var positions: Array[Vector2]=[]
	for index: int in range(items.size()):
		var item: Dictionary=items[index]
		var size_value:=Vector2(item.size[0],item.size[1])
		var anchor:=Vector2(item.anchor[0],item.anchor[1])
		var margin: float=0.0 if index==0 else float(options.itemMargin)
		var position:=Vector2(anchor.x*size_value.x,inner.y-(1.0-anchor.y)*size_value.y)
		if vertical:
			position.y=boundary-(1.0-anchor.y)*size_value.y-margin
			if alignment=="Align_Right":position.x=inner.x-(1.0-anchor.x)*size_value.x
			elif alignment=="Align_HorizontalCenter":position.x=inner.x/2.0-size_value.x*(0.5-anchor.x)
			boundary=position.y-anchor.y*size_value.y
		else:
			position.x=boundary+anchor.x*size_value.x+margin
			if alignment=="Align_Bottom":position.y=anchor.y*size_value.y
			elif alignment=="Align_VerticalCenter":position.y=inner.y/2.0-size_value.y*(0.5-anchor.y)
			boundary=position.x+(1.0-anchor.x)*size_value.x
		positions.append(Vector2(position.x,-position.y))
	return {"ok":true,"positions":positions,"inner_size":inner,"inner_position":Vector2(0.0,inner.y-extent.y),"source_rows":items.size(),"service_connected":false}
