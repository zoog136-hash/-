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
## Cocos3.6 space/CJK word boundaries, measured by the same original FontFile
## used by this renderer. No substitute font, ellipsis, text or pagination.
static func lines(font: FontFile, value: String, font_size: int, width: float) -> Dictionary:
	if width<=0 or not is_finite(width):return {"ok":false,"error":"original_wrap_width_required"}
	var output: PackedStringArray=[]
	var committed: String=""
	var pending: String=""
	for index: int in range(value.length()):
		var character: String=value[index]
		var code: int=value.unicode_at(index)
		if code>0xffff:return {"ok":false,"error":"original_utf16_wrap_not_connected_for_supplementary_character"}
		if character=="\n":
			output.append(committed+_trim_tail(pending))
			committed="";pending=""
			continue
		if _space(code):
			committed+=pending+character
			pending=""
			continue
		var cjk: bool=_cjk(code)
		if not pending.is_empty() and _cjk(pending.unicode_at(pending.length()-1)) and not cjk:
			committed+=pending
			pending=character
			continue
		var candidate: String=committed+pending+character
		if font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=width:
			pending+=character
		elif cjk:
			var previous: String=_trim_tail(committed+pending)
			if previous.is_empty():
				output.append(character)
				pending=""
			else:
				output.append(previous)
				pending=character
			committed=""
		else:
			pending+=character
			if not _trim_tail(committed).is_empty():output.append(_trim_tail(committed))
			committed=""
	output.append(committed+pending)
	for line: String in output:
		if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:return {"ok":false,"error":"original_unbreakable_word_exceeds_source_width"}
	return {"ok":true,"lines":output}

static func _trim_tail(value: String) -> String:
	var end: int=value.length()
	while end>0 and _space(value.unicode_at(end-1)):end-=1
	return value.substr(0,end)

static func _space(code: int) -> bool:
	return (code>=0x0009 and code<=0x000d) or code in [0x0020,0x0085,0x00a0,0x1680,0x2028,0x2029,0x202f,0x205f,0x3000] or (code>=0x2000 and code<=0x200a)

static func _cjk(code: int) -> bool:
	for bounds: Array in [[0x4e00,0x9fbf],[0x2e80,0x2fdf],[0x2ff0,0x30ff],[0x3100,0x31bf],[0xac00,0xd7af],[0xf900,0xfaff],[0xfe30,0xfe4f],[0x31c0,0x4dff]]:
		if code>=bounds[0] and code<=bounds[1]:return true
	return false
