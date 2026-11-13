extends "res://tests/reference_sp2_load_memo_test.gd"
const PREPARED=preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const POLICY=preload("res://scripts/animation/source_playback_policy.gd")
const PREVIEW=preload("res://scripts/animation/original_source_preview.gd")
const LEGACY=preload("res://tests/qa_unshared_reference_preview.gd")
const NATIVE=preload("res://tests/source_native_attachment_bank_test.gd")
const ATTRIBUTES=preload("res://tests/reference_sp2_attribute_memo_test.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")

func shared(bank: RefCounted, data: Dictionary, bindings: Dictionary=BINDINGS, loops: Dictionary=LOOPS, scope: String="npc", actors: Dictionary={}) -> Dictionary:
	return bank.load_shared_bank(data.path,data.sha,ACTOR,bindings,loops,scope,actors)

func frozen(value: Variant) -> bool:
	if value is Dictionary:
		if not value.is_read_only(): return false
		for child: Variant in value.values():
			if not frozen(child): return false
	elif value is Array:
		if not value.is_read_only(): return false
		for child: Variant in value:
			if not frozen(child): return false
	return true

func run() -> void:
	var directory: String="user://prepared_bank_test_%d" % OS.get_process_id()
	var data: Dictionary=fixture(directory)
	PREPARED.clear()
	var oracle:=BANK.new()
	var expected: Dictionary=oracle.load_bank(data.path,data.sha,ACTOR,BINDINGS,LOOPS,"npc")
	var a:=BANK.new()
	var b:=BANK.new()
	var first: Dictionary=shared(a,data)
	HITCH._counters.clear()
	var second: Dictionary=shared(b,data)
	check(first.ok and second.ok and var_to_bytes(expected)==var_to_bytes(first) and var_to_bytes(first)==var_to_bytes(second),"full bank bytes equal mutable validation oracle")
	check(HITCH._counters.get("sp2.prepared_hit")==1 and not HITCH._counters.has("sp2.layer_validate"),"reuse skips repeated validation")
	check(is_same(first,second) and a._prepared_snapshot==b._prepared_snapshot,"live banks share one snapshot")
	check(frozen(first),"all shared nested arrays/dictionaries read-only")
	check(is_same(first.tracks.idle.directions[0][0].layers[0].source_attribute_projection,first.tracks.idle.directions[1][0].layers[0].source_attribute_projection),"prepared occurrences share one immutable action proof")
	check(not is_same(expected.tracks.idle.directions[0][0].layers[0].source_attribute_projection,expected.tracks.idle.directions[1][0].layers[0].source_attribute_projection),"mutable occurrences retain independent proofs")
	check(not expected.is_read_only() and not expected.tracks.idle.directions[0][0].layers.is_read_only(),"ordinary API stays mutable")
	var layer: Dictionary=second.tracks.idle.directions[0][0].layers[0]
	check(b.render_layer(layer).ok,"hit bank restores pins/index and draws exact source")
	var x: Dictionary=POLICY.tracks_from_prepared(first.record,"npc","compatible")
	var y: Dictionary=POLICY.tracks_from_prepared(second.record,"npc","strict")
	check(var_to_bytes(x)==var_to_bytes(POLICY.tracks(expected.record,"npc","compatible")),"compatible policy matches prior deep-copy output")
	check(var_to_bytes(y)==var_to_bytes(POLICY.tracks(expected.record,"npc","strict")),"strict policy matches prior deep-copy output")
	check(not is_same(x,y) and not is_same(x.idle,y.idle) and not is_same(x.idle.directions[0][0],y.idle.directions[0][0]),"timing containers remain per-view")
	check(is_same(x.idle.directions[0][0].layers,y.idle.directions[0][0].layers),"immutable layers shared across timing policies")
	x.idle.directions[0][0].duration=999.0
	x.erase("attack")
	check(y.has("attack") and y.idle.directions[0][0].duration!=999.0 and first.tracks.idle.directions[0][0].duration!=999.0,"private timing edits cannot leak")
	# Same actor is not sufficient: caller roles, loops, order, consumer, path
	# and role-actor maps are all part of the exact request identity.
	for request: Array in [[{"rest":0,"attack":3},{"rest":true,"attack":false},"npc",{}],[BINDINGS,{"idle":false,"attack":false},"npc",{}],[BINDINGS,LOOPS,"overlay",{}],[BINDINGS,LOOPS,"npc",{"idle":ACTOR}],[{"attack":3,"idle":0},{"attack":false,"idle":true},"npc",{}]]:
		var other:=BANK.new()
		var value: Dictionary=shared(other,data,request[0],request[1],request[2],request[3])
		var full: Dictionary=BANK.new().load_bank(data.path,data.sha,ACTOR,request[0],request[1],request[2],request[3])
		check(value.ok and not is_same(value,first) and var_to_bytes(value)==var_to_bytes(full),"request domains remain independent")
	var other_data: Dictionary=fixture(directory+"_other")
	check(not is_same(shared(BANK.new(),other_data),first),"same manifest bytes at another path cannot cross-reuse")
	# The actual preview boundary owns clocks, events, nodes and timing edits.
	var old:=LEGACY.new()
	var one:=PREVIEW.new()
	var two:=PREVIEW.new()
	for view: Node in [old,one,two]:
		check(view._configure_reference_bank(data.path,data.sha,ACTOR,BINDINGS,LOOPS,"idle","npc"),"NPC view prepares")
		check(view.advance_reference_source(0.0,"idle",0),"NPC initial frame draws")
	check(is_same(one._record,two._record) and not is_same(old._record,one._record),"preview uses shared validated record")
	check(var_to_bytes(old._playback_tracks)==var_to_bytes(one._playback_tracks),"actual preview tracks unchanged")
	for direction: int in range(8):
		for role: String in BINDINGS:
			for view: Node in [old,one]:
				check(view.restart_reference_source(role,17) and view.advance_reference_source(0.125,role,direction),"role/direction playback valid")
			check(var_to_bytes(old.reference_source_frame_status())==var_to_bytes(one.reference_source_frame_status()),"role/direction provenance unchanged")
			for index: int in old._layers.size():
				var left: Sprite2D=old._layers[index]
				var right: Sprite2D=one._layers[index]
				check(left.visible==right.visible and left.position==right.position,"sprite placement/visibility unchanged")
				if left.visible: check(left.texture.get_image().get_data()==right.texture.get_image().get_data(),"exact decoded initial/body pixels")
	check(two._clock==0.0 and two._sequence==-1,"other actor clock/sequence isolated")
	one.clear()
	check(two.installed() and two.advance_reference_source(0.1,"idle",2),"retiring one view cannot clear another")
	old.free();one.free();two.free()
	# Invalid requests cannot obtain a valid entry under a related key.
	for request: Array in [[{},{}],[{"idle":0},{"idle":1}],[{"idle":-1},{"idle":true}]]:
		check(not shared(BANK.new(),data,request[0],request[1]).ok,"invalid role request rejected")
	# Changed/missing originals are checked even when a live snapshot exists.
	var raw: PackedByteArray=FileAccess.get_file_as_bytes(data.raw)
	write_bytes(data.raw,raw+PackedByteArray([0]))
	check(not shared(BANK.new(),data).ok,"changed member size rejects hit")
	write_bytes(data.raw,raw)
	var restored:=BANK.new()
	check(shared(restored,data).ok,"restored member rebuilds")
	DirAccess.rename_absolute(data.raw,data.raw+".held")
	check(not shared(BANK.new(),data).ok,"missing member rejects hit")
	DirAccess.rename_absolute(data.raw+".held",data.raw)
	var pinned:=BANK.new()
	check(shared(pinned,data).ok,"member restored before pin test")
	var action_path: String=data.path.get_base_dir().path_join("actors/%d/action-0.json" % ACTOR)
	var action: PackedByteArray=FileAccess.get_file_as_bytes(action_path)
	write_bytes(action_path,action+PackedByteArray([32]))
	check(not shared(BANK.new(),data).ok,"changed action SHA rejects hit")
	write_bytes(action_path,action)
	var before_forget:=BANK.new()
	check(shared(before_forget,data).ok,"action restored")
	BANK.forget_verified_members()
	HITCH._counters.clear()
	check(shared(BANK.new(),data).ok and HITCH._counters.get("sp2.prepared_miss")==1,"explicit forget also invalidates prepared index")
	# Same-size rewrites are rejected once the approved size/mtime stamp changes.
	var same_size:=BANK.new()
	check(shared(same_size,data).ok,"prime equal-size rewrite")
	var stamp: int=int(FileAccess.get_modified_time(data.raw))
	var altered: PackedByteArray=raw.duplicate()
	altered[altered.size()-1]^=1
	var deadline: int=Time.get_ticks_msec()+5000
	while int(FileAccess.get_modified_time(data.raw))==stamp and Time.get_ticks_msec()<deadline:
		await create_timer(0.05).timeout
		write_bytes(data.raw,altered)
	check(int(FileAccess.get_modified_time(data.raw))!=stamp,"rewrite has observable mtime")
	check(not shared(BANK.new(),data).ok,"equal-size changed member is rehashed and rejected")
	write_bytes(data.raw,raw)
	var manifest_bytes: PackedByteArray=FileAccess.get_file_as_bytes(data.path)
	var manifest_owner:=BANK.new()
	check(shared(manifest_owner,data).ok,"prime manifest pin")
	write_bytes(data.path,manifest_bytes+PackedByteArray([32]))
	check(not shared(BANK.new(),data).ok,"changed manifest pin rejects hit")
	write_bytes(data.path,manifest_bytes)
	# Received CRC/receipt provenance stays nullable SHA, with no freezing of
	# the separately shared manifest record as a side effect.
	var received: Dictionary=fixture(directory+"_received")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(received.path))
	var member: String="Sprite/%d-0.sp2" % ACTOR
	var spec: Dictionary=manifest.members[member]
	spec.sha256=null
	spec.stage="received_not_additionally_validated"
	spec.crc32=BANK.crc32(FileAccess.get_file_as_bytes(received.raw))
	spec.source_receipt_id=member
	spec.source_identity={"source_snapshot":"patch523","basis":"supplied_exact_current523_member_archive_bytes_crc_domain","archive":"synthetic.zip","source_manifest_reference":"synthetic","whole_current523_manifest_match":true}
	received.sha=write_json(received.path,manifest)
	var receipt_owner:=BANK.new()
	var receipt_result: Dictionary=shared(receipt_owner,received)
	check(receipt_result.ok,"received member accepted")
	var receipt_layer: Dictionary=receipt_result.tracks.idle.directions[0][0].layers[0]
	check(receipt_layer.frame_provenance.raw_sha256==null and receipt_layer.frame_provenance.source_stage=="received_not_additionally_validated","received identity is not promoted to SHA")
	check(not receipt_owner._index.lookup("members",member).source_identity.is_read_only(),"shared manifest identity not frozen by snapshot")
	check(receipt_owner.render_layer(receipt_layer).ok,"received shared result draws")
	# Native ordered occurrences and exclusion failures use the same oracle.
	var native_fixture:=NATIVE.new()
	for mutation: String in ["","alias_whitespace","wrong_instance","wrong_body_owner","duplicate_binding"]:
		var native: Dictionary=native_fixture.native_fixture(directory+"_native_"+mutation,mutation)
		var native_owner:=BANK.new()
		var compiled: Dictionary=native_owner.load_shared_bank(native.path,native.sha,NATIVE.REQUEST,{"selected":3},{"selected":true},"npc")
		var full: Dictionary=BANK.new().load_bank(native.path,native.sha,NATIVE.REQUEST,{"selected":3},{"selected":true},"npc")
		check(var_to_bytes(compiled)==var_to_bytes(full),"native occurrence validation/output: "+mutation)
		if compiled.ok:
			check(frozen(compiled),"native occurrence metadata frozen")
			check(is_same(BANK.new().load_shared_bank(native.path,native.sha,NATIVE.REQUEST,{"selected":3},{"selected":true},"npc"),compiled),"native metadata hit")
	native_fixture.free()
	var attribute_fixture:=ATTRIBUTES.new()
	var excluded: Dictionary=attribute_fixture.fixture(directory+"_excluded","excluded_child")
	check(not shared(BANK.new(),excluded,ATTRIBUTES.CORE_BINDINGS,ATTRIBUTES.CORE_LOOPS).ok,"excluded source graph is never admitted by reuse")
	attribute_fixture.free()
	# A bounded weak index owns no idle snapshot. Eviction leaves live owners.
	PREPARED.clear()
	var holders: Array=[]
	for index: int in PREPARED.MAX_KEYS+5:
		var value:=PREPARED.new()
		holders.append(value)
		PREPARED.remember(str(index),value)
	check(PREPARED.size()==PREPARED.MAX_KEYS and PREPARED.lookup("0")==null and is_instance_valid(holders[0]),"weak keys bounded without revoking live owner")
	holders.clear()
	check(PREPARED.size()==0,"last owner releases all weak snapshots")
	# Root source declarations are still enforced before any snapshot is stored.
	var bad: Dictionary=fixture(directory+"_bad","wrong_attributes")
	check(not shared(BANK.new(),bad).ok,"invalid proof never cached")
	print("REFERENCE_SP2_PREPARED_BANK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
