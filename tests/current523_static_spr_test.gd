extends SceneTree
## New tail binding against held original byte ledgers; not a full SP2 decoder rerun.
const SPR=preload("res://scripts/maps/current523_static_spr.gd")
const SOURCE=preload("res://scripts/maps/current523_source_pack.gd")
const FIELD=preload("res://scripts/maps/current523_source_field.gd")
var failures: Array[String]=[]
var checks: int=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	for key: String in ["source-root","source-sha","sp2-root","declaration","raw-ledger"]:
		if not args.has(key): printerr("Private held original inputs required: "+key);quit(2);return
	var ledger: Variant=JSON.parse_string(FileAccess.get_file_as_string(args["raw-ledger"]))
	check(ledger is Array and ledger.size()==2125,"held independent Aden ledger has2125 records")
	var by_member: Dictionary={}
	for row: Dictionary in ledger:
		if not by_member.has(row.member): by_member[row.member]=[]
		by_member[row.member].append(row)
	var pack=SOURCE.new()
	check(pack.load_pack(args["source-root"],args["source-sha"],"Aden/"),"verified current523 source loads once")
	var examples: Array[Dictionary]=[]
	var declared: Dictionary={}
	var matched: int=0
	for member: String in by_member:
		var original: Dictionary=pack.read_member(member)
		check(not original.is_empty(),"source bytes verified: "+member)
		if original.is_empty():continue
		var parsed: Dictionary=SPR.parse_tail(original.sections.tail,int(pack.source_metadata(member).core_end))
		check(parsed.ok and parsed.records.size()==by_member[member].size(),"tail count matches independent original ledger: "+member)
		if not parsed.ok:continue
		for i: int in parsed.records.size():
			var raw: Dictionary=parsed.records[i];var expected: Dictionary=by_member[member][i]
			check(raw.source_byte_offset==expected.source_byte_offset and raw.sprite_id==expected.sprite_id_u16 and raw.raw_x==expected.raw_x_u16 and raw.raw_y==expected.raw_y_u16 and raw.raw_extra==expected.raw_extra_i32 and raw.raw_bytes.hex_encode()==expected.raw_hex,"literal original record fields/offset/bytes")
			matched+=1
			raw.source_member=member;raw.source_sha256=original.source_sha256
			if examples.size()<3: examples.append(raw)
			if raw.sprite_id==29175 and declared.is_empty():declared=raw
		if by_member[member].size()>0:
			check(not SPR.parse_tail(original.sections.tail.slice(0,3)).ok,"actual truncated tail rejects")
	check(matched==2125 and by_member.size()==184,"all2125 new tail bindings over184 held Aden chunks checked")
	var field=FIELD.new()
	check(field.configure_verified_catalog(pack,args["source-sha"],4),"real Land4 field supplies existing coordinate frame")
	var options: Dictionary={"enabled":true,"source_root":args["sp2-root"],"declaration_path":args.declaration,"group_bit":0,"fps":12}
	var display=SPR.new();root.add_child(display)
	check(display.configure(options,field.coordinates),"exact held SP2 registry and list29 source verified")
	display.set_process(false)
	examples.append(declared)
	display.refresh(examples)
	check(display.metrics().drawn_records>0,"held original pixels reach map draw records")
	var before: Array[Dictionary]=display.displayed_records()
	var saw_declaration: bool=false
	for draw: Dictionary in before:
		check(not draw.source_sp2_sha256.is_empty() and draw.point.is_finite(),"draw retains verified SP2 identity and finite source projection")
		if draw.record.sprite_id==29175:
			saw_declaration=true
			check(draw.frame==14 and draw.sequence_source=="LIST29_ACTION3","original list29 first frame14 overrides guessed storage order")
	check(saw_declaration,"real source29175 is displayed from original declared sequence")
	display._process(4.1/12.0)
	for draw: Dictionary in display.displayed_records():
		if draw.record.sprite_id==29175: check(draw.frame==0,"original duration4 advances14 to0 using explicitly own clock")
	check(display.metrics().unresolved_attachments.has(29175),"clothes attachment remains explicitly unresolved, never silently synthesized")
	check(not display.configure(options,field.coordinates),"active renderer cannot be rebound to another source")
	var missing=SPR.new();check(not missing.configure({"enabled":true,"source_root":"/absent-source"},field.coordinates),"missing source registry rejects");missing.free()
	check(SPR.validate({"enabled":true,"source_root":args["sp2-root"],"fps":NAN}).is_empty(),"nonfinite own clock rejects")
	print("CURRENT523_STATIC_SPR_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"raw_Aden_records":matched,"source_members":by_member.size(),"new_map_binding":true,"native_M_placement_action_clock_or_blend_equivalence":false}))
	display.queue_free();field.close();await process_frame;quit(0 if failures.is_empty() else 1)
