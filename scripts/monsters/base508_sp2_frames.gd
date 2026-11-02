extends RefCounted
## Portable source-frame decoder for validated FE-SP2 packets. The packet keeps
## the unchanged decompressed source bytes and disambiguated palette length.
const PACKET_BUDGET_BYTES: int = 64 * 1024 * 1024
static var _packets: Dictionary = {}
static var _order: Array[String] = []
static var _costs: Dictionary = {}
static var _bytes: int = 0
class Reader extends RefCounted:
	var data: PackedByteArray
	var pos: int = 0
	var valid: bool = true
	func _init(raw: PackedByteArray) -> void: data = raw
	func u8() -> int:
		if pos + 1 > data.size(): valid = false; return 0
		var value: int = int(data[pos]); pos += 1; return value
	func s8() -> int:
		var value: int = u8(); return value - 256 if value >= 128 else value
	func u16() -> int:
		if pos + 2 > data.size(): valid = false; return 0
		var value: int = data.decode_u16(pos); pos += 2; return value
	func s16() -> int:
		var value: int = u16(); return value - 65536 if value >= 32768 else value
	func s32() -> int:
		if pos + 4 > data.size(): valid = false; return -1
		var value: int = data.decode_s32(pos); pos += 4; return value
static func _decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 9 or bytes.slice(0,5).get_string_from_ascii() != "LMSP1": return {}
	var entries: int = bytes.decode_u16(5)
	if entries < 1 or entries > 256: return {}
	var reader := Reader.new(bytes.slice(7))
	if reader.u8() != 254: return {}
	reader.u8() # The source palette marker is retained; validated entries resolves marker1.
	var palette: Array = []
	for index: int in range(entries):
		var p: int = reader.u16()
		palette.append(int((p >> 11) * 255 / 31) | (int(((p >> 5) & 63) * 255 / 63) << 8) | (int((p & 31) * 255 / 31) << 16) | (255 << 24))
	var mask: int = reader.u8()
	if mask <= 0: return {}
	var directions: Dictionary = {}
	for bit: int in range(8):
		if not (mask & (1 << bit)): continue
		var frames: Array = []
		var frame_count: int = reader.u8()
		for f: int in range(frame_count):
			var bounds: Array = []
			for axis: int in range(4): bounds.append(reader.s16())
			var count: int = reader.u16()
			if count >= 10000 or not reader.valid: return {}
			var aa: Array = []; var bb: Array = []; var types: Array = []; var refs: Array = []
			for i: int in range(count): aa.append(reader.s8())
			for i: int in range(count): bb.append(reader.s8())
			for i: int in range(count): types.append(reader.u8())
			var last: int = 0
			for i: int in range(count):
				var delta: int = reader.s16()
				last = (delta & 65535) if i == 0 else ((last + delta + 1) & 65535)
				refs.append([aa[i],bb[i],types[i],last])
			frames.append({"bounds":bounds,"refs":refs})
		var block_count: int = reader.s32()
		if block_count < 0 or block_count >= 1000000 or not reader.valid: return {}
		var blocks: Array = []
		for i: int in range(block_count):
			var bx: int = reader.u8(); var by: int = reader.u8(); var count: int = reader.u8()
			var values := PackedInt32Array()
			for n: int in range(count): values.append(reader.u16())
			blocks.append({"bx":bx,"by":by,"values":values,"points":PackedInt32Array(),"image":null})
		for frame: Dictionary in frames:
			for ref: Array in frame.refs:
				if int(ref[3]) >= blocks.size(): return {}
		directions[bit] = {"frames":frames,"blocks":blocks}
	var cost: int = bytes.size()
	for direction: Dictionary in directions.values():
		for block: Dictionary in direction.blocks:
			var values: PackedInt32Array = block.values
			var points := PackedInt32Array()
			var i: int = 0; var y: int = 0
			while i < values.size():
				var value: int = values[i]
				var blank: int = int(value / 1024) - 1 if value > 2048 else 0
				var group: int = 1
				if value > 1024: value %= 1024
				else:
					if i != values.size() - 1: group += 1
					var k: int = 0
					while k < 10 and i + k + 1 < values.size() and i + k != values.size() - 1:
						if i + k + 1 == values.size() - 1 or values[i + k + 1] > 1024: break
						group += 1; k += 1
				var x: int = 0
				for g: int in range(group):
					if i >= values.size(): return {}
					if g > 0: value = values[i] % 1024
					x += value % 32
					for n: int in range(int(value / 32)):
						var color: int = reader.u8()
						if color >= entries or not reader.valid: return {}
						points.append(x); points.append(y); points.append(color); x += 1
					i += 1
				y += 1 + blank
			block.points = points
			block.erase("values")
			cost += points.size() * 4
	if not reader.valid or reader.pos != reader.data.size(): return {}
	return {"palette":palette,"mask":mask,"directions":directions,"cost":cost}
static func packet(path: String, expected_sha256: String) -> Dictionary:
	var key: String = path + ":" + expected_sha256
	if _packets.has(key):
		_order.erase(key); _order.append(key); return _packets[key]
	if expected_sha256.length() != 64 or FileAccess.get_sha256(path) != expected_sha256: return {}
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path).decompress_dynamic(256 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var parsed: Dictionary = _decode(raw)
	if parsed.is_empty(): return {}
	var cost: int = int(parsed.cost)
	while not _order.is_empty() and _bytes + cost > PACKET_BUDGET_BYTES:
		var old: String = _order.pop_front(); _bytes -= int(_costs[old]); _costs.erase(old); _packets.erase(old)
	if cost <= PACKET_BUDGET_BYTES:
		_packets[key] = parsed; _costs[key] = cost; _order.append(key); _bytes += cost
	return parsed
static func render(path: String, expected_sha256: String, bit: int, frame_index: int) -> Dictionary:
	var source: Dictionary = packet(path, expected_sha256)
	var direction: Dictionary = source.get("directions", {}).get(bit, {})
	if direction.is_empty() or frame_index < 0 or frame_index >= direction.frames.size(): return {}
	var placements: Array = []; var first: bool = true; var minimum := Vector2i.ZERO; var maximum := Vector2i.ZERO
	for ref: Array in direction.frames[frame_index].refs:
		var block: Dictionary = direction.blocks[int(ref[3])]
		var points: PackedInt32Array = block.points
		if points.is_empty(): continue
		if block.image == null:
			var lo := Vector2i(points[0],points[1]); var hi: Vector2i = lo
			for p: int in range(0,points.size(),3):
				lo = lo.min(Vector2i(points[p],points[p+1])); hi = hi.max(Vector2i(points[p],points[p+1]))
			var size: Vector2i = hi - lo + Vector2i.ONE
			if size.x <= 0 or size.y <= 0 or size.x >= 4096 or size.y >= 4096: return {}
			var colors := PackedByteArray(); colors.resize(size.x * size.y * 4)
			for p: int in range(0,points.size(),3): colors.encode_u32(((points[p+1]-lo.y)*size.x+points[p]-lo.x)*4, int(source.palette[points[p+2]]))
			block.image = Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,colors)
			block.origin = lo
			var key: String = path + ":" + expected_sha256
			if _packets.has(key):
				var image_cost: int = size.x * size.y * 4
				_costs[key] = int(_costs[key]) + image_cost
				_bytes += image_cost
				while not _order.is_empty() and _bytes > PACKET_BUDGET_BYTES:
					var old: String = _order.pop_front()
					_bytes -= int(_costs[old]); _costs.erase(old); _packets.erase(old)
		var a: int = int(ref[0]); var b: int = int(ref[1]); var half: int = floori(float(a) / 2.0)
		var at: Vector2i = Vector2i(24 * (b+a-half)+int(block.bx),12 * (b-half)+int(block.by)) + block.origin
		var extent: Vector2i = block.image.get_size()
		minimum = at if first else minimum.min(at); maximum = at + extent - Vector2i.ONE if first else maximum.max(at+extent-Vector2i.ONE)
		first = false; placements.append({"image":block.image,"at":at})
	if first: return {"image":Image.create(1,1,false,Image.FORMAT_RGBA8),"offset":[0,0]}
	var size: Vector2i = maximum - minimum + Vector2i.ONE
	if size.x <= 0 or size.y <= 0 or size.x >= 4096 or size.y >= 4096: return {}
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for placement: Dictionary in placements:
		image.blend_rect(placement.image,Rect2i(Vector2i.ZERO,placement.image.get_size()),placement.at-minimum)
	return {"image":image,"offset":[minimum.x,minimum.y]}
