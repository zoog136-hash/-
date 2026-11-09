extends RefCounted
## M82 (C07/C08) and M83 (C13/C14). DESIGN_NOT_RECOVERED_API.
## M82: the selected native FE metadata reader reads the palette WORDs then the mask at the
## cursor (byte4 for palette1). The byte8 "alternate alignment" is an ANNOTATION ONLY and is kept
## in a separate field; it never changes what the native reader returns.
## M83: PNG failure leaves the Image fields that were already written (no rollback); Texture
## init copies the filename before its size guard.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")

# ---------------------------------------------------------------- M82
## Selected normal FE metadata path (035F7E10). Only the empty-mask specialisation is modelled;
## a nonzero mask means native direction scanning, which this DESIGN does not reproduce.
static func native_fe_metadata(data: PackedByteArray) -> Dictionary:
	var out := {"design_status": V.DESIGN, "evidence": V.CONFIRMED, "accepted": false, "palette": [], "mask": null, "cursor": 0, "directions": []}
	if data.size() < 1:
		out["status"] = V.REJECTED_UNDEFENDED
		return out
	if data[0] != 0xFE:
		out["reason"] = "non-FE marker: false (no alternate non-FE branch in this function)"
		return out
	if data.size() < 2:
		out["status"] = V.REJECTED_UNDEFENDED
		return out
	var count: int = data[1]
	if count == 0:
		count = 256  # 035F7F7C mov eax,0x100 / 035F7F81 cmove
	var cursor: int = 2
	if data.size() < cursor + 2 * count + 1:
		out["status"] = V.REJECTED_UNDEFENDED
		return out
	var palette: Array = []
	for i: int in count:
		palette.append(data.decode_u16(cursor + 2 * i))
	cursor += 2 * count
	var mask: int = data[cursor]
	cursor += 1
	out["palette"] = palette
	out["palette_count"] = count
	out["mask_at"] = cursor - 1
	out["mask"] = mask
	out["cursor"] = cursor
	out["accepted"] = true
	if mask != 0:
		out["evidence"] = V.UNKNOWN
		out["note"] = "nonzero mask: native per-direction scan is outside this DESIGN; not modelled"
	return out

## Alternate byte8 alignment: annotation only (never native success, frame or format support).
static func alternate_alignment_annotation(data: PackedByteArray) -> Dictionary:
	var out := {"annotation_only": true, "native_success": false, "valid": false, "directions": [], "records": 0}
	if data.size() < 9 or data.slice(0, 8).hex_encode() != "fe01000000000000":
		return out
	var mask: int = data[8]
	var cursor: int = 9
	var records: int = 0
	var inverted: int = 0
	for d: int in 8:
		if (mask & (1 << d)) == 0:
			continue
		if cursor + 1 > data.size():
			return out
		var fc: int = V.i8(data[cursor])
		cursor += 1
		if fc < 0:
			return out
		for f: int in fc:
			if cursor + 10 > data.size():
				return out
			var l: int = V.i16(data.decode_u16(cursor))
			var t: int = V.i16(data.decode_u16(cursor + 2))
			var r: int = V.i16(data.decode_u16(cursor + 4))
			var b: int = V.i16(data.decode_u16(cursor + 6))
			var frags: int = data.decode_u16(cursor + 8)
			if frags != 0:
				return out
			if r < l or b < t:
				inverted += 1
			records += 1
			cursor += 10
		if cursor + 4 > data.size():
			return out
		if data.decode_s32(cursor) != 0:
			return out
		cursor += 4
		(out.directions as Array).append({"direction": d, "frames": fc})
	out["mask_at"] = 8
	out["mask"] = mask
	out["records"] = records
	out["inverted_bounds"] = inverted
	out["end"] = cursor
	out["valid"] = cursor == data.size()
	return out

## The exact rejected non-FE candidate: "an old direction stream with the FE header removed".
static func forced_frame_stream_candidate(data: PackedByteArray) -> Dictionary:
	if data.size() < 11:
		return {"status": V.REJECTED_UNDEFENDED}
	var fc: int = V.i8(data[0])
	var bbox: Array = [V.i16(data.decode_u16(1)), V.i16(data.decode_u16(3)), V.i16(data.decode_u16(5)), V.i16(data.decode_u16(7))]
	var frags: int = data.decode_u16(9)
	var required: int = 1 + 8 + 2 + 5 * frags
	return {"frame_count": fc, "bbox": bbox, "fragments": frags, "required_end": required, "rejected_candidate_only": required > data.size(),
		"note": "rejects this one candidate; not a proof that no legacy format exists. Keep unsupported."}

# ---------------------------------------------------------------- M83
## PNG colour type -> Image+30 format (other values leave the field unchanged).
const PNG_COLOR_TO_FORMAT := {0: 6, 2: 3, 4: 7, 6: 2}

static func make_image() -> Dictionary:
	## ctor 00308350 values. Padding is not claimed to be initialised.
	return {"data": null, "length": 0, "width": 0, "height": 0, "mipmap_owned": 0, "file_format": 10, "render_format": -1, "mip_count": 0, "premultiplied": 0, "filename": ""}

## Image state after the PNG wrapper stops at `stage`. Fields written before the stop stay.
## stages: signature, read_struct_null, info_struct_null, read_info_error, transform_error,
## pixel_malloc_null, read_image_error, read_end_error, success.
static func png_decode(entry: Dictionary, stage: String, w: int, h: int, color: int, rowbytes: int, premultiply_global: int = 1) -> Dictionary:
	var img: Dictionary = entry.duplicate(true)
	var r := {"image": img, "ok": false, "row_table_allocated": false, "row_table_freed_by_wrapper": false, "rollback": false, "design_status": V.DESIGN}
	if stage in ["signature", "read_struct_null", "info_struct_null", "read_info_error"]:
		return r
	img["width"] = w
	img["height"] = h
	if stage == "transform_error":
		return r
	if PNG_COLOR_TO_FORMAT.has(color):
		img["render_format"] = PNG_COLOR_TO_FORMAT[color]
	r["row_table_allocated"] = true
	img["length"] = V.mul_u64(h, rowbytes)  # sign-extended H times 64-bit stride, low64 kept
	if stage == "pixel_malloc_null":
		r["row_table_freed_by_wrapper"] = true  # only R nonnull is freed; W/H/F/N stay
		r["note"] = "P=null with N>0 is left in the Image: no metadata rollback"
		return r
	img["data"] = "pixels"
	if stage in ["read_image_error", "read_end_error"]:
		r["note"] = "common exit has no R free and no Image rollback; false is conditional"
		r["evidence"] = V.CONDITIONAL
		return r
	if premultiply_global != 0 and color == 6:
		img["premultiplied"] = 1
	r["row_table_freed_by_wrapper"] = true
	r["ok"] = true
	return r

## The row loop uses a 16-bit counter compared zero-extended with H. H>=65536 cannot terminate;
## the DESIGN refuses to run it instead of inventing a bound.
static func row_loop_terminates(h: int) -> Dictionary:
	if h > 0xFFFF:
		return {"terminates": false, "status": V.REJECTED_UNDEFENDED}
	return {"terminates": true}

## IO callback bound check: end = sign_extend32(low32(offset+request)) vs signed64 length.
static func io_callback_check(offset: int, request: int, input_length: int) -> Dictionary:
	var end: int = V.i32(V.i32(offset) + request)
	if end > input_length:
		return {"error_callback": true}
	var r := {"error_callback": false, "copy_from": V.i32(offset), "copy_length": request, "new_offset": V.i32(offset + V.u32(request))}
	if end < 0 or V.i32(offset) + request > input_length:
		r["status"] = V.REJECTED_UNDEFENDED
		r["note"] = "passes the original signed32 check but would read past the input; the DESIGN does not copy"
	return r

## Texture init 00341D34 after an addImage miss. Filename copy and Texture+58 store happen BEFORE
## the size check, which rejects only signed W>max or H>max (0/negative not rejected directly).
static func texture_init(image: Variant, max_size: int) -> Dictionary:
	var events: Array = []
	if image == null:
		return {"ok": false, "events": events}
	var img: Dictionary = image
	events.append("read_width_height")
	events.append("copy_filename")
	events.append("store_texture_58")
	events.append("query_configuration_max")
	if int(img.width) > max_size or int(img.height) > max_size:
		events.append("size_reject")
		return {"ok": false, "events": events, "filename_already_written": true}
	events.append("read_pixels_format_length_mipcount")
	return {"ok": true, "events": events, "note": "continuation; conversion/GL/cache success not claimed", "render_status": V.NOT_OBSERVED}
