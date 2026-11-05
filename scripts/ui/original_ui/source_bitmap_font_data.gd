extends RefCounted
## Text BMFont descriptor only; original page bytes are fetched by source_pack.
## Success: {ok:true,font_data:{info,common,pages,glyphs,kernings}}.
## The renderer also requires font_data.page_textures keyed by exact page ID.

static func parse(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size()>4194304:return _fail("source_bitmap_descriptor_size")
	var text: String=raw.get_string_from_utf8()
	if text.begins_with("\ufeff"):text=text.substr(1)
	if text.begins_with("BMF") or text.strip_edges().begins_with("<"):return _fail("source_bitmap_descriptor_format_unsupported")
	var info: Dictionary={}
	var common: Dictionary={}
	var pages: Dictionary={}
	var glyphs: Dictionary={}
	var kernings: Dictionary={}
	var expected_chars: int=-1
	var expected_kernings: int=-1
	var field_pattern:=RegEx.new()
	field_pattern.compile('([A-Za-z][A-Za-z0-9]*)=("[^"]*"|[^\\s]+)')
	for line_value: String in text.split("\n"):
		var line: String=line_value.strip_edges()
		if line.is_empty():continue
		var split_at: int=line.find(" ")
		if split_at<1:return _fail("source_bitmap_descriptor_record_invalid")
		var kind: String=line.substr(0,split_at)
		var body: String=line.substr(split_at+1).strip_edges()
		var fields: Dictionary={}
		var consumed: int=0
		for matched: RegExMatch in field_pattern.search_all(body):
			if not body.substr(consumed,matched.get_start()-consumed).strip_edges().is_empty():return _fail("source_bitmap_descriptor_field_invalid")
			var key: String=matched.get_string(1)
			if fields.has(key):return _fail("source_bitmap_descriptor_duplicate_field")
			var value: String=matched.get_string(2)
			fields[key]=value.substr(1,value.length()-2) if value.begins_with('"') else value
			consumed=matched.get_end()
		if fields.is_empty() or not body.substr(consumed).strip_edges().is_empty():return _fail("source_bitmap_descriptor_field_invalid")
		match kind:
			"info":
				if not info.is_empty():return _fail("source_bitmap_descriptor_duplicate_info")
				info=fields
			"common":
				if not common.is_empty():return _fail("source_bitmap_descriptor_duplicate_common")
				if not _integers(fields,["lineHeight","base","scaleW","scaleH","pages","packed"]):return _fail("source_bitmap_common_fields_missing")
				common=fields
			"page":
				if not _integers(fields,["id"]) or not fields.has("file"):return _fail("source_bitmap_page_fields_missing")
				var page_id: int=fields.id
				var file: String=fields.file
				if page_id<0 or pages.has(page_id) or file.is_empty() or file.contains("\\") or file.contains(":") or file.begins_with("/"):return _fail("source_bitmap_page_invalid")
				for part: String in file.split("/"):
					if part in ["",".",".."]:return _fail("source_bitmap_page_path_invalid")
				pages[page_id]={"id":page_id,"file":file}
			"chars":
				if expected_chars!=-1 or not _integers(fields,["count"]) or int(fields.count)<0:return _fail("source_bitmap_chars_count_invalid")
				expected_chars=fields.count
			"char":
				if not _integers(fields,["id","x","y","width","height","xoffset","yoffset","xadvance","page","chnl"]):return _fail("source_bitmap_glyph_fields_missing")
				var codepoint: int=fields.id
				if codepoint<0 or codepoint>65535 or (codepoint>=55296 and codepoint<=57343) or glyphs.has(codepoint):return _fail("source_bitmap_glyph_id_unsupported")
				if fields.chnl!=15:return _fail("source_bitmap_glyph_channel_unsupported")
				if fields.x<0 or fields.y<0 or fields.width<0 or fields.height<0:return _fail("source_bitmap_glyph_rect_invalid")
				glyphs[codepoint]=fields
			"kernings":
				if expected_kernings!=-1 or not _integers(fields,["count"]) or int(fields.count)<0:return _fail("source_bitmap_kernings_count_invalid")
				expected_kernings=fields.count
			"kerning":
				if not _integers(fields,["first","second","amount"]):return _fail("source_bitmap_kerning_fields_missing")
				var pair: String="%d:%d" % [int(fields.first),int(fields.second)]
				if kernings.has(pair):return _fail("source_bitmap_kerning_duplicate")
				kernings[pair]=int(fields.amount)
			_:return _fail("source_bitmap_descriptor_record_unsupported")
	if info.is_empty() or common.is_empty() or expected_chars<0 or expected_chars!=glyphs.size():return _fail("source_bitmap_descriptor_incomplete")
	if not _integers(info,["size","unicode"]) or info.unicode!=1:return _fail("source_bitmap_encoding_unsupported")
	if common.packed!=0:return _fail("source_bitmap_packed_unsupported")
	if common.lineHeight<=0 or common.scaleW<=0 or common.scaleH<=0 or common.pages<=0 or common.pages!=pages.size():return _fail("source_bitmap_common_dimensions_invalid")
	for page_id: int in range(common.pages):
		if not pages.has(page_id):return _fail("source_bitmap_page_ids_invalid")
	for glyph: Dictionary in glyphs.values():
		if not pages.has(glyph.page) or glyph.x+glyph.width>common.scaleW or glyph.y+glyph.height>common.scaleH:return _fail("source_bitmap_glyph_page_bounds_invalid")
	if (expected_kernings<0 and not kernings.is_empty()) or (expected_kernings>=0 and expected_kernings!=kernings.size()):return _fail("source_bitmap_kernings_count_mismatch")
	return {"ok":true,"font_data":{"info":info,"common":common,"pages":pages,"glyphs":glyphs,"kernings":kernings}}

static func _integers(fields: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not fields.has(key) or not str(fields[key]).is_valid_int():return false
		fields[key]=int(fields[key])
	return true

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}
