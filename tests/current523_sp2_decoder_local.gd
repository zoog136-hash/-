extends SceneTree
## Manual local audit. No private originals are required by automatic CI.
## godot --headless --path . --script tests/current523_sp2_decoder_local.gd -- --pack=/private/989actual.zip
## Alternative: --source-root=/private/installed-pack ; optional --render-all --report=/tmp/audit.json
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const REGISTRY = "results/all989_actual_current_M_SP2_registry.json"
var failures: Array[String] = []
var checks: int = 0
var source_stats: Dictionary = {"files":0,"records":0,"nonempty":0,"empty":0,"samples":0,"index0_samples":0,"rendered":0,"masks":{}}

func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)

func _initialize() -> void: call_deferred("run")

func _u16(bytes: PackedByteArray,value: int) -> void:
	bytes.append(value & 255)
	bytes.append((value >> 8) & 255)

func _u32(bytes: PackedByteArray,value: int) -> void:
	_u16(bytes,value)
	_u16(bytes,value >> 16)

func _block(commands: Array,indices: Array,x: int = 0,y: int = 0) -> Dictionary:
	return {"x":x,"y":y,"commands":commands,"indices":indices}

func _ref(index: int = 0,a: int = 0,b: int = 0,type: int = 22) -> Dictionary:
	return {"a":a,"b":b,"type":type,"index":index}

func _group(bounds: Array,refs: Array,blocks: Array) -> Dictionary:
	return {"frames":[{"bounds":bounds,"refs":refs}],"blocks":blocks}

func _fixture(palette: Array,mask: int,groups: Array,marker: int = -1) -> PackedByteArray:
	var bytes := PackedByteArray([254,(palette.size() & 255) if marker < 0 else marker])
	for color: int in palette: _u16(bytes,color)
	bytes.append(mask)
	for group: Dictionary in groups:
		bytes.append(group.frames.size())
		for frame: Dictionary in group.frames:
			for bound: int in frame.bounds: _u16(bytes,bound)
			_u16(bytes,frame.refs.size())
			for field: String in ["a","b","type"]:
				for ref: Dictionary in frame.refs: bytes.append(int(ref[field]) & 255)
			var last: int = 0
			for index: int in range(frame.refs.size()):
				var value: int = frame.refs[index].index
				_u16(bytes,value if index == 0 else ((value - last - 1) & 65535))
				last = value
		_u32(bytes,group.blocks.size())
		for block: Dictionary in group.blocks:
			bytes.append(block.x)
			bytes.append(block.y)
			bytes.append(block.commands.size())
			for command: int in block.commands: _u16(bytes,command)
	for group: Dictionary in groups:
		for block: Dictionary in group.blocks:
			for sample: int in block.indices: bytes.append(sample)
	return bytes

func _synthetic() -> void:
	var basic: PackedByteArray = _fixture([16904],1,[_group([0,0,1,1],[_ref()],[_block([32],[0])])])
	var parsed: Dictionary = DECODER.parse(basic)
	check(parsed.ok,"marker1 one-word layout")
	if parsed.ok:
		check(parsed.palette.size() == 1 and parsed.raw == basic and parsed.body == basic,"raw source and palette retained")
		var result: Dictionary = DECODER.render(parsed,0,0)
		check(result.ok and result.estimated and not result.empty and result.offset == Vector2i.ZERO,"estimated render metadata")
		if result.ok:
			check(result.image.get_pixel(0,0).is_equal_approx(Color8(66,65,66,255)),"covered index0 opaque with RGB565 bit replication")
		var transparent: Dictionary = DECODER.render(parsed,0,0,{"alpha_policy":"index0_transparent"})
		check(transparent.ok and transparent.image.get_pixel(0,0).a == 0.0,"explicit estimated index0 transparency")
		var linear: Dictionary = DECODER.render(parsed,0,0,{"rgb_policy":"linear"})
		check(linear.ok and linear.image.get_pixel(0,0).is_equal_approx(Color8(65,64,65,255)),"explicit estimated linear RGB")
		check(not DECODER.render(parsed,-1,0).ok and not DECODER.render(parsed,0,1).ok,"invalid render addresses return errors")
		check(not DECODER.render(parsed,0,0,{"alpha_policy":"type_opacity"}).ok,"unknown opacity policy rejected")
		check(not DECODER.render(parsed,0,0,{"rgb_policy":"invented"}).ok,"unknown RGB policy rejected")
	var palette3: Dictionary = DECODER.parse(_fixture([16904,0,65535],1,[_group([0,0,1,1],[_ref()],[_block([32],[2])])],1))
	check(palette3.ok and palette3.palette.size() == 3,"marker1 three-word unique EOF layout")
	var palette256: Array = []
	palette256.resize(256)
	palette256.fill(0)
	var full_palette: Dictionary = DECODER.parse(_fixture(palette256,1,[_group([0,0,1,1],[_ref()],[_block([32],[255])])]))
	check(full_palette.ok and full_palette.palette.size() == 256,"marker0 means256 and sample255 retained")
	var multiple: Array = [_group([0,0,1,1],[_ref()],[_block([32],[0])]),_group([24,12,25,13],[_ref(0,0,1)],[_block([32],[1])])]
	var mask3: Dictionary = DECODER.parse(_fixture([0,65535],3,multiple))
	check(mask3.ok and mask3.groups.size() == 2 and mask3.groups[0].bit == 0 and mask3.groups[1].bit == 1,"mask3 is two groups with all metadata before samples")
	var mask5: Dictionary = DECODER.parse(_fixture([0,65535],5,multiple))
	check(mask5.ok and mask5.groups[1].bit == 2,"stored group bits retained without compass labels")
	var stepped: Dictionary = DECODER.parse(_fixture([0,65535],1,[_group([0,0,2,4],[_ref()],[_block([32,1056,2080,32],[0,1,1,0])])]))
	check(stepped.ok,"every command draws before its own row step")
	if stepped.ok:
		var image: Image = DECODER.render(stepped,0,0).image
		check(image.get_pixel(0,0).a == 1.0 and image.get_pixel(1,0).a == 1.0 and image.get_pixel(0,1).a == 1.0 and image.get_pixel(0,2).a == 0.0 and image.get_pixel(0,3).a == 1.0,"commandwise row coverage and absent coverage")
	var command1024: Dictionary = DECODER.parse(_fixture([0,65535],1,[_group([0,1,1,2],[_ref()],[_block([1024,32],[0])])]))
	check(command1024.ok and command1024.groups[0].blocks[0].commands[0] == 1024 and command1024.sample_count == 1,"command1024 is zero draw plus rowstep1")
	var negative: Dictionary = DECODER.parse(_fixture([0,65535],1,[_group([3,17,4,18],[_ref(0,-1,0)],[_block([32],[1],3,5)])]))
	check(negative.ok and DECODER.render(negative,0,0).offset == Vector2i(3,17),"negative odd reference uses floor-half placement and full source offset")
	var ordered: Dictionary = DECODER.parse(_fixture([0,65535],1,[_group([0,0,1,1],[_ref(0,0,0,0),_ref(1,0,0,255)],[_block([32],[1]),_block([32],[0])])]))
	check(ordered.ok and DECODER.render(ordered,0,0).image.get_pixel(0,0).is_equal_approx(Color.BLACK),"reference-order covered-zero overwrite independent of type")
	if ordered.ok:
		check(ordered.groups[0].frames[0].refs[1].type == 255 and ordered.groups[0].frames[0].raw_bounds == PackedInt32Array([0,0,1,1]),"type and four raw i16 fields retained")
	var blank: Dictionary = DECODER.parse(_fixture([0,65535],1,[_group([-32768,32767,32767,-32768],[],[])]))
	check(blank.ok,"empty source records preserve uninterpreted extreme bounds")
	if blank.ok:
		var empty: Dictionary = DECODER.render(blank,0,0)
		check(empty.ok and empty.empty and empty.image.get_size() == Vector2i.ONE and empty.image.get_pixel(0,0).a == 0.0 and empty.offset == Vector2i(-32768,32767),"empty transparent marker never invents visible pixels")
	print("CURRENT523_SP2_SYNTHETIC reference-wrap fixture")
	var wrap_bytes: PackedByteArray = _fixture([0,65535],1,[_group([0,0,1,1],[_ref(65535),_ref(0),_ref(65535)],[])])
	wrap_bytes.encode_u32(wrap_bytes.size() - 4,65536)
	var block_start: int = wrap_bytes.size()
	wrap_bytes.resize(block_start + 65536 * 3 + 4)
	wrap_bytes[block_start + 2] = 1
	wrap_bytes.encode_u16(block_start + 3,32)
	var last_block: int = block_start + 5 + 65534 * 3
	wrap_bytes[last_block + 2] = 1
	wrap_bytes.encode_u16(last_block + 3,32)
	wrap_bytes.append_array(PackedByteArray([0,1]))
	print("CURRENT523_SP2_SYNTHETIC reference-wrap parse")
	var wrapping: Dictionary = DECODER.parse(wrap_bytes)
	check(wrapping.ok,"first reference is unsigned u16 and subsequent references wrap")
	if wrapping.ok:
		var refs: Array = wrapping.groups[0].frames[0].refs
		check(refs[0].index == 65535 and refs[1].index == 0 and refs[2].index == 65535 and refs[0].raw_reference_word == 65535 and refs[1].raw_reference_word == 0 and refs[2].raw_reference_word == 65534,"reference high word and signed wrap source words retained")
	var trailing: PackedByteArray = basic.duplicate()
	trailing.append(0)
	check(not DECODER.parse(trailing).ok,"trailing uncompressed bytes rejected")
	check(not DECODER.parse(basic.slice(0,basic.size() - 1)).ok,"truncated sample rejected")
	check(not DECODER.parse(_fixture([0,65535],1,[_group([0,0,2,1],[_ref()],[_block([32],[0])])])).ok,"nonempty native half-open bbox mismatch rejected")
	check(not DECODER.parse(_fixture([0,65535],1,[_group([0,0,1,1],[_ref(1)],[_block([32],[0])])])).ok,"out-of-range block reference rejected")
	check(not DECODER.parse(_fixture([0,65535],1,[_group([0,0,1,1],[_ref()],[_block([32],[2])])])).ok,"out-of-range sample index rejected")
	check(not DECODER.parse(_fixture([0,65535],0,[])).ok,"empty mask rejected")
	check(not DECODER.parse(PackedByteArray()).ok,"empty input rejected")
	var errors_enabled: bool = Engine.print_error_messages
	print("CURRENT523_SP2_SYNTHETIC malformed Brotli")
	check(not DECODER.parse(PackedByteArray([0,0,0])).ok and Engine.print_error_messages == errors_enabled,"invalid Brotli returns error and restores error reporting")
	# Synthetic standard Brotli stream expands to 32MiB+1 bytes (FE, then zeros).
	var bomb: PackedByteArray = "cbffff3f00a400fce3b24070efffe2ffff1f001200715800baf77ffcffff034002200e0b40f7fe8fffff7f004800c46101e8deff0100200003".hex_decode()
	check(not DECODER.parse(bomb).ok and Engine.print_error_messages == errors_enabled,"decoded body cap rejects32MiB+1 synthetic expansion")
	var wide_commands: Array = []
	var wide_indices: Array = []
	wide_commands.resize(162)
	wide_commands.fill(992)
	wide_indices.resize(5022)
	wide_indices.fill(0)
	check(not DECODER.parse(_fixture([0,65535],1,[_group([0,0,5022,1],[_ref()],[_block(wide_commands,wide_indices)])])).ok,"nonempty canvas dimension cap enforced")
	var oversized := PackedByteArray()
	oversized.resize(DECODER.MAX_INPUT_BYTES + 1)
	check(not DECODER.parse(oversized).ok,"oversized input rejected before decompression")
	check(not DECODER.render({"ok":false},0,0).ok,"invalid parse never renders")

func _source(archive: String,source_root: String,render_all: bool) -> void:
	var zip := ZIPReader.new()
	var text: String = ""
	if not archive.is_empty():
		if zip.open(archive) != OK:
			check(false,"authorized source ZIP opens")
			return
		text = zip.read_file(REGISTRY).get_string_from_utf8()
	else:
		if not FileAccess.file_exists(source_root.path_join(REGISTRY)):
			check(false,"installed source registry exists")
			return
		text = FileAccess.get_file_as_string(source_root.path_join(REGISTRY))
	var rows: Variant = JSON.parse_string(text)
	if not rows is Array:
		check(false,"source registry parses")
		return
	check(rows.size() == 989,"989 actual source records supplied")
	for row: Dictionary in rows:
		var member: String = str(row.canonical_package_member)
		var bytes: PackedByteArray = zip.read_file(member) if not archive.is_empty() else FileAccess.get_file_as_bytes(source_root.path_join(member))
		var hash_context := HashingContext.new()
		hash_context.start(HashingContext.HASH_SHA256)
		hash_context.update(bytes)
		check(bytes.size() == int(row.bytes) and hash_context.finish().hex_encode() == row.sha256,"source identity: " + member)
		var parsed: Dictionary = DECODER.parse(bytes)
		check(parsed.ok,"source parse: " + member + (": " + str(parsed.error) if not parsed.ok else ""))
		if not parsed.ok: continue
		source_stats.files += 1
		source_stats.records += parsed.frame_count
		source_stats.nonempty += parsed.nonempty_count
		source_stats.empty += int(parsed.frame_count) - int(parsed.nonempty_count)
		source_stats.samples += parsed.sample_count
		var mask: String = str(parsed.mask)
		source_stats.masks[mask] = int(source_stats.masks.get(mask,0)) + 1
		for group_index: int in range(parsed.groups.size()):
			for block: Dictionary in parsed.groups[group_index].blocks:
				source_stats.index0_samples += block.indices.count(0)
			var frames: Array = parsed.groups[group_index].frames
			for frame_index: int in range(frames.size() if render_all else mini(1,frames.size())):
				var result: Dictionary = DECODER.render(parsed,group_index,frame_index)
				check(result.ok and result.estimated,"source estimated render: %s group%d frame%d" % [member,group_index,frame_index])
				if result.ok:
					source_stats.rendered += 1
					check(result.bounds == frames[frame_index].bounds and result.offset == result.bounds.position,"source bounds and offset retained")
		if int(source_stats.files) % 100 == 0:
			print("CURRENT523_SP2_PROGRESS ",source_stats.files,"/989")
			await process_frame
	zip.close()
	check(source_stats.files == 989 and source_stats.records == 17115 and source_stats.nonempty == 17054 and source_stats.empty == 61,"all989 exact EOF and native nonempty extents match handoff")
	check(source_stats.samples == 150790654 and source_stats.index0_samples == 12224853 and source_stats.masks == {"1":981,"3":2,"255":6},"all source samples including covered index0 and stored masks retained")

func run() -> void:
	var archive: String = ""
	var source_root: String = ""
	var report_path: String = ""
	var render_all: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): archive = argument.trim_prefix("--pack=")
		if argument.begins_with("--source-root="): source_root = argument.trim_prefix("--source-root=")
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument == "--render-all": render_all = true
	_synthetic()
	if not archive.is_empty() or not source_root.is_empty(): await _source(archive,source_root,render_all)
	var report: Dictionary = {"checks":checks,"failures":failures,"source":source_stats,"estimated":true,"render_all":render_all,"godot":Engine.get_version_info().string,"private_source_required_by_ci":false}
	if not report_path.is_empty():
		var output := FileAccess.open(report_path,FileAccess.WRITE)
		if output == null: check(false,"audit report writable")
		else: output.store_string(JSON.stringify(report,"\t") + "\n")
	print("CURRENT523_SP2_DECODER_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
