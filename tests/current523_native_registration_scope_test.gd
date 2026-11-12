extends SceneTree
## Synthetic Class domain and optional reader-scope tests only. Rejected
## reward-graph caching and its former tests are archived outside the checkout.
## No private originals, game saves or image output are used here.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const DATA = preload("res://scripts/resources/current523_item_data.gd")
const DROP = preload("res://scripts/loot/patch523_monster_drops.gd")
var checks: int = 0
var failures: Array[String] = []

class Reader extends RefCounted:
	var key: String = "synthetic:1"
	var generation: int = 0
	var class_rows: Array = []
	var rows_calls: int = 0
	var change_during_rows: bool = false
	var change_key_during_rows: bool = false
	func verified_key() -> String: return key
	func cache_generation() -> int: return generation
	func rows(table: String) -> Array:
		assert(table == "Class")
		rows_calls += 1
		if change_during_rows: generation += 1
		if change_key_during_rows: key += ":changed"
		return class_rows.duplicate(true)

class Inputs extends P.RegisterInputs:
	var source: Dictionary = {"kind":"scope.synthetic.original","source_sha256":"fixture","source_bytes":17}
	func identity() -> Dictionary: return source
	func verified_key() -> String: return "scope.synthetic:17"
	func row_count(_table: String) -> int: return 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func same(a: Variant, b: Variant) -> bool: return var_to_bytes(a) == var_to_bytes(b)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_class_domains()
	_scopes()
	_script_readers()
	print("CURRENT523_NATIVE_REGISTRATION_SCOPE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture":"synthetic_class_and_script_scope_only","original_zip_read":false}))
	quit(0 if failures.is_empty() else 1)

func _old_classes(rows: Array) -> Dictionary:
	var active: Dictionary = {}
	for row: Dictionary in rows:
		var id: Variant = row.get("ID")
		var valid: bool = typeof(id) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(id)) and float(id) == floorf(float(id)) and absf(float(id)) <= 9007199254740991.0
		if valid and int(id)>0 and row.get("CanCreateClient")==true: active[int(id)] = row
	return active

func _class_domains() -> void:
	var reader := Reader.new()
	for id: int in range(1,13): reader.class_rows.append({"ID":float(id),"CanCreateClient":id!=5,"name":"class"+str(id)})
	reader.class_rows.append({"ID":3.0,"CanCreateClient":true,"name":"last duplicate wins"})
	for id: Variant in [0,-1,1.5,"2"]: reader.class_rows.append({"ID":id,"CanCreateClient":true})
	check(reader.class_rows.size()==17,"representative Class domain contains exactly17 rows")
	var baseline: Dictionary = _old_classes(reader.class_rows)
	var scope := P.RegistrationScope.new()
	check(same(scope.active_classes(reader,P._collect_active_classes),baseline),"Class collector preserves legacy values/types/order and duplicate-ID replacement")
	check(scope.classes.keys()==[1,2,3,4,6,7,8,9,10,11,12] and scope.classes[3].name=="last duplicate wins","invalid IDs and noncreatable classes remain excluded in original insertion order")
	for _index: int in 3: check(same(scope.active_classes(reader,P._collect_active_classes),baseline),"same-source Class hit retains serialized output")
	check(reader.rows_calls==1 and scope.builds==1 and scope.hits==3 and scope.classes.is_read_only(),"Class rows build once and subsequent hits use read-only domain")
	reader.generation += 1
	check(same(scope.active_classes(reader,P._collect_active_classes),baseline) and reader.rows_calls==2,"same-key source reset rebuilds Class domain with identical output")
	reader.key = "synthetic:2"
	reader.class_rows[0].name = "new source value"
	check(same(scope.active_classes(reader,P._collect_active_classes),_old_classes(reader.class_rows)) and reader.rows_calls==3,"different verified source key rebuilds Class domain")
	reader.key = ""
	scope.active_classes(reader,P._collect_active_classes); scope.active_classes(reader,P._collect_active_classes)
	check(reader.rows_calls==5 and not scope.ready,"missing verified key is never cached")
	reader.key="synthetic:empty"; reader.class_rows=[]
	scope.active_classes(reader,P._collect_active_classes); scope.active_classes(reader,P._collect_active_classes)
	check(reader.rows_calls==7 and not scope.ready,"empty Class source retries instead of caching absence")
	reader.class_rows=[{"ID":1.0,"CanCreateClient":true}];reader.change_during_rows=true
	scope.active_classes(reader,P._collect_active_classes); scope.active_classes(reader,P._collect_active_classes)
	check(reader.rows_calls==9 and not scope.ready,"reset during Class read cannot publish a stale domain")

	reader.change_during_rows=false;reader.change_key_during_rows=true
	scope.active_classes(reader,P._collect_active_classes);scope.active_classes(reader,P._collect_active_classes)
	check(reader.rows_calls==11 and not scope.ready,"source key change during Class read cannot publish stale domain")

func _scopes() -> void:
	var prior: P.RegistrationScope=P._swap_registration_scope(null)
	check(P.registration_item_reader()==null and P.registration_profile_scope()==null,"outside registration no reader or profiling scope is active")
	var outer := P.RegistrationScope.new();var inner := P.RegistrationScope.new()
	outer.describe_reader=DescribeReader
	check(P._swap_registration_scope(outer)==null and P._swap_registration_scope(inner)==outer,"nested registration scope installs and returns its exact predecessor")
	check(P._swap_registration_scope(outer)==inner and P.registration_item_reader()==DescribeReader,"nested success restores the exact outer scope and reader")
	check(P.registration_profile_scope()==null,"default registration performs no profiling clocks")
	outer.profile=true
	check(P.registration_profile_scope()==outer,"explicit profiling resolves only the owning current scope")
	var old_inputs: P.RegisterInputs=P.register_inputs;var inputs := Inputs.new();P.register_inputs=inputs
	var catalog: Dictionary={"아이템":[{"source_m_native_item":true,"source_definition_archive":inputs.source}],"patch523_crafting_catalog_contract":{"mode":"current_original_native_projection","source_definition_archive":inputs.source,"registered_definition_ids":["1"],"pending":{}}}
	var document: Dictionary={"native_item_ids":["1"],"current_registration_pending":{},"current_native_registered_count":1}
	check(P.register(get_script(),catalog,document).get("reused_registration",false),"successful nested registration takes the unchanged verified reuse path")
	check(P._swap_registration_scope(outer)==outer and P.registration_item_reader()==DescribeReader and P.registration_profile_scope()==outer,"successful register wrapper restores caller scope, reader and profiling owner")
	inputs.source={}
	check(not P.register(get_script(),{},{}).get("ok",true),"failed nested registration returns the original input rejection")
	check(P._swap_registration_scope(outer)==outer and P.registration_item_reader()==DescribeReader and P.registration_profile_scope()==outer,"failed register wrapper restores caller scope, reader and profiling owner")
	P.register_inputs=old_inputs
	var thread := Thread.new();var launched: Error=thread.start(_thread_scopes)
	check(launched==OK,"scope isolation worker starts")
	if launched==OK:check(bool(thread.wait_to_finish()),"worker Class, reader and profiling scopes remain isolated from main-thread scope")
	check(P._swap_registration_scope(prior)==outer,"worker completion and nested failures leave the main outer scope intact")

func _thread_scopes() -> bool:
	var before: P.RegistrationScope=P._swap_registration_scope(null)
	var worker := P.RegistrationScope.new();worker.describe_reader=DATA;worker.profile=true
	var outside: bool=P.registration_item_reader()==null and P.registration_profile_scope()==null
	var installed: bool=P._swap_registration_scope(worker)==null
	var isolated: bool=P.registration_item_reader()==DATA and P.registration_profile_scope()==worker
	return before==null and outside and installed and isolated and P._swap_registration_scope(null)==worker

class DescribeReader extends RefCounted:
	static func describe(id: int, descriptions: bool=false) -> Dictionary:
		return {"fixture":"positive_script_reader","id":id,"descriptions":descriptions}

func _script_readers() -> void:
	var previous: P.RegistrationScope=P._swap_registration_scope(null)
	check(P.registration_item_reader()==null,"outside registration no describe script is cached")
	var outer := P.RegistrationScope.new();outer.describe_reader=DescribeReader
	P._swap_registration_scope(outer)
	check(P.registration_item_reader()==DescribeReader and DROP._describe_item(17)=={"fixture":"positive_script_reader","id":17,"descriptions":false},"positive describe Script API is reused only inside its owning registration scope")
	var inner := P.RegistrationScope.new();inner.describe_reader=DATA
	check(P._swap_registration_scope(inner)==outer and P.registration_item_reader()==DATA,"nested scope selects its own positive describe Script")
	check(P._swap_registration_scope(outer)==inner and P.registration_item_reader()==DescribeReader,"ending nested scope restores the exact prior describe Script")
	P._swap_registration_scope(null)
	var had_env: bool=OS.has_environment("TWILIGHT_PATCH523_CONTENT")
	var saved_env: String=OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT","");P.SOURCE.reset()
	var actual: Dictionary=DROP._describe_item(17)
	var expected: Dictionary=DATA.describe(17,false)
	check(P.registration_item_reader()==null and same(actual,expected) and expected.get("ok")==false,"outside registration drop description retains its original optional-reader path and missing-source behavior")
	P.SOURCE.reset()
	if had_env:OS.set_environment("TWILIGHT_PATCH523_CONTENT",saved_env)
	else:OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	P._swap_registration_scope(previous)
