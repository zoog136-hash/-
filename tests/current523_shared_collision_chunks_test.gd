extends SceneTree
## Authored bytes only, but uses production verification, chunk worker and
## renderer publication. No original resource, visual or phone claim.
const FIXTURE = preload("res://tests/current523_source_pack_test.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const RENDER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const ROOT: String = "user://shared_s32_fixture"
const ASSET: String = "fixture_shared/"
const PIN: String = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const START := Vector2i(32768,32768)
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("SHARED_S32_FAIL ",label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var pack = FIXTURE.FixturePack.new()
	var field = FIELD.new()
	field._raw=pack
	field.loaded=true
	field.catalog_root=ROOT
	field.catalog_sha256=PIN
	field.source_asset=ASSET
	field.set_meta("current523_generic_field",true)
	field._configure_policy({})
	field.width=64*12
	field.height=64
	field.coordinates.configure([START.x,START.y],[field.width,field.height])
	var members: Array[String]=[]
	for i: int in range(12):
		var origin: Vector2i=START+Vector2i(64*i,0)
		var member: String="Map/"+ASSET+"%04x%04x.s32" % [origin.x,origin.y]
		members.append(member)
		pack.prepare_fixture(ROOT,ASSET,member)
		field._source_chunks[origin]=member
		field.source_origins[member]=origin
	var renderer = RENDER.new()
	renderer.field=field
	renderer._raw_sources=pack
	renderer._member_origins=field.source_origins.duplicate()
	var first: String=members[0]
	var job: Dictionary=renderer._chunk_params(first)
	job.merge({"field_id":field.get_instance_id(),"catalog_root":ROOT,"catalog_pin":PIN,"asset_path":ASSET})
	var task: int=WorkerThreadPool.add_task(RENDER._chunk_job.bind(job))
	WorkerThreadPool.wait_for_task_completion(task)
	check(job.has("verified_collision") and not job.has("problem"),"production worker verifies fixture sections")
	if not job.has("verified_collision"):
		renderer.free()
		_finish()
		return
	check(not field.offer_renderer_collision(first,ROOT,"wrong",ASSET,job.verified_collision),"wrong catalog pin denied")
	check(not field.offer_renderer_collision(first,ROOT,PIN,"foreign/",job.verified_collision),"wrong asset denied")
	var stale: Dictionary=job.duplicate()
	stale.field_id=0
	renderer._install_chunk(first,stale)
	check(field.shared_chunk_metrics().renderer_collision_waiting==0,"stale field ID cannot publish")
	var wrong_hash: Dictionary=job.verified_collision.duplicate()
	wrong_hash.source_sha256="0".repeat(64)
	check(not field.offer_renderer_collision(first,ROOT,PIN,ASSET,wrong_hash),"wrong source member digest rejected")
	renderer._install_chunk(first,job)
	check(field.shared_chunk_metrics().renderer_collision_waiting==1 and field.cache_metrics().raw_reads==0,
		"completed worker publishes without touching the active gameplay LRU")
	check(not field.walkable(field.cell_to_world(Vector2i.ZERO)) and field.walkable(field.cell_to_world(Vector2i(1,0))),
		"collision consumes original sentinel and passable cell identically")
	check(field.cache_metrics().raw_reads==0 and field.shared_chunk_metrics().renderer_to_nav==1,
		"worker-first route does not reopen file")
	check(field.verified_navigation_chunk_for_renderer(first,ROOT,PIN,ASSET).is_empty(),"collision-only row is not a renderer input")
	var second: String=members[1]
	check(field.walkable(field.cell_to_world(Vector2i(65,0))) and field.cache_metrics().raw_reads==1,"cold navigation retains verified fallback")
	var for_renderer: Dictionary=field.verified_navigation_chunk_for_renderer(second,ROOT,PIN,ASSET)
	check(for_renderer.get("sections",{}).has("tail") and field.shared_chunk_metrics().nav_to_renderer==1,
		"renderer can borrow a full verified navigation read")
	var from_nav_job: Dictionary=renderer._chunk_params(second)
	from_nav_job["verified_navigation"]=for_renderer
	RENDER._chunk_job(from_nav_job)
	check(from_nav_job.has("packed") and not from_nav_job.has("problem"),"production renderer projects the shared full payload")
	var direct_job: Dictionary=renderer._chunk_params(second)
	RENDER._chunk_job(direct_job)
	check(from_nav_job.get("packed")==direct_job.get("packed") and from_nav_job.get("tail")==direct_job.get("tail"),
		"shared and re-read renderer outputs are identical")
	var bad: String=members[2]
	var bad_path: String=ROOT.path_join(pack.source_metadata(bad).path)
	var file := FileAccess.open(bad_path,FileAccess.READ_WRITE)
	file.store_8(42)
	file.close()
	var rejected: Dictionary=renderer._chunk_params(bad)
	rejected.merge({"field_id":field.get_instance_id(),"catalog_root":ROOT,"catalog_pin":PIN,"asset_path":ASSET})
	RENDER._chunk_job(rejected)
	check(rejected.has("problem") and not rejected.has("verified_collision"),"invalid on-disk digest can never publish")
	pack.prepare_fixture(ROOT,ASSET,bad)
	for i: int in range(2,12):
		var m: String=members[i]
		check(field.offer_renderer_collision(m,ROOT,PIN,ASSET,pack.read_member(m)),"fixture verified member accepted "+str(i))
	check(field.shared_chunk_metrics().renderer_collision_waiting==FIELD.RENDER_COLLISION_LIMIT
		and field.cache_metrics().cached_chunks==2,"mailbox is bounded and cannot evict active gameplay chunks")
	renderer.free()
	field.close()
	check(field.shared_chunk_metrics().renderer_collision_waiting==0 and not field.loaded,"field close drops unpublished collision data")
	_finish()

func _finish() -> void:
	print("CURRENT523_SHARED_COLLISION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
