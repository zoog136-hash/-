extends SceneTree
## Checks the exact renderer worker output (lanes, bins, decoration clipping
## and tail). Optional private originals are hash-pinned, never redistributed.
const R=preload("res://scripts/maps/current523_aden_play_renderer.gd")
const SOURCE_PACK=preload("res://scripts/maps/current523_source_pack.gd")
const F=preload("res://tests/current523_aden_play_renderer_test.gd")
const CASES={
	"80007ffd.s32":["205151df70367f79f5c757e6e22bb21646bf1c7b60a6a1b367f4c8ab8ec1cdc9",68411,125261],
	"7fff7fff.s32":["738895a4c30fcdfaadacbbf82a8b74de7d153c88fc3b535cd52f1706c80ef0e0",82294,138510],
	"7ffd7ffd.s32":["7fa0dc46a57549b12e96c142337bc0f1b41945000a4a4e91dd1f90e5ce19f78f",34635,87764]}
var checks:=0;var failures: Array[String]=[];var timings: Dictionary={}
func ck(ok: bool, why: String)->void:
	checks+=1
	if not ok:failures.append(why);printerr("DIRECT_FLOOR_FAIL ",why)
func _initialize()->void:run.call_deferred()
func opts(origin: Vector2i,overlap: Dictionary)->Dictionary:
	return {"member":"synthetic","core_end":0,"origin":origin,"grid_origin":Vector2i(32610,32723),"overlap":overlap,"generic":true,"valid":true,"basis_x":Vector2(24,-12),"basis_y":Vector2(24,12),"shift":Vector2(0,768)}
func view(d: Dictionary)->Array:return [d.packed,d.bins,d.tail,d.clipped,d.off_floor]
func run()->void:
	var decoded: Dictionary=F.FakeChunkSources.new().read_member("test")
	for origin: Vector2i in [Vector2i.ZERO,Vector2i(-128,192),Vector2i(32640,32768),Vector2i(3,13)]:
		var cover: Vector2i=Vector2i(floori(origin.x/64.0)*64,floori(origin.y/64.0)*64)
		for overlap: bool in [true,false]:
			for alternate: bool in [false,true]:
				var p:=opts(origin,{cover:true} if overlap else {})
				if alternate:p.basis_x=Vector2(23.125,-11.75);p.basis_y=Vector2(-9.75,4.75);p.shift=Vector2(-727.25,57.16)
				ck(var_to_bytes(view(R._decode_chunk(p,decoded)))==var_to_bytes(view(R._decode_chunk_with_floor(p,decoded,false))),"same guarded source coords, cover, refs, order and block bins")
		var invalid: Dictionary={"valid":false,"core_end":0}
		var result:=R._decode_chunk(invalid,decoded)
		ck(not result.has("packed") and result.halves.size()>=8192,"invalid projection keeps complete raw fallback")
	var dir:=OS.get_environment("TWILIGHT_S32_FLOOR_ORIGINALS")
	if not dir.is_empty():
		for member: String in CASES:
			var values: Array=CASES[member];var file:=dir.path_join(member)
			if FileAccess.get_sha256(file)!=values[0]:ck(false,"exact source "+member);continue
			var bytes:=FileAccess.get_file_as_bytes(file);var core: int=values[2]
			var record: Dictionary={"source_sha256":values[0],"source_bytes":bytes.size(),"sections":{"floor":bytes.slice(0,32768),"covers":bytes.slice(32768,32770),"objects":bytes.slice(49154,49154+int(values[1])),"tail":bytes.slice(core)}}
			var origin: Vector2i=SOURCE_PACK.candidate_origin("Map/303/"+member)
			var p:=opts(origin,{origin:true})
			p.member=member;p.core_end=core
			var sample: Array=[[],[]];var baseline:=PackedByteArray()
			for round_id: int in 13:
				for arm: int in ([0,1] if round_id%2==0 else [1,0]):
					var start:=Time.get_ticks_usec()
					var out: Dictionary=R._decode_chunk(p,record) if arm else R._decode_chunk_with_floor(p,record,false)
					var elapsed:=Time.get_ticks_usec()-start
					var exact:=var_to_bytes(view(out))
					if baseline.is_empty():baseline=exact
					ck(exact==baseline,"same original complete worker results "+member)
					if round_id>0:sample[arm].append(elapsed)
			timings[member]=sample
	print("CURRENT523_DIRECT_FLOOR_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"complete_worker_usec_old_new":timings}))
	quit(0 if failures.is_empty() else 1)
