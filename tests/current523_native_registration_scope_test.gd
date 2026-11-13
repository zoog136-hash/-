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
	_binding_digests()
	_native_market_scope()
	_market_warmup_scopes()
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
	isolated = isolated and P._skill_row_digest('{"skills":{"worker":{"spell_id":7,"row_sha256":"worker"}}}',7)=="worker" and worker.binding_builds==1
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

func _binding_digests() -> void:
	var text: String = JSON.stringify({"skills":{"a":{"spell_id":17.0,"row_sha256":"one"},"b":{"spell_id":17,"row_sha256":"one"},"c":{"spell_id":18,"row_sha256":"two"}}})
	var prior: P.RegistrationScope = P._swap_registration_scope(null)
	var baseline: String = P._skill_row_digest(text,17)
	var outer := P.RegistrationScope.new()
	P._swap_registration_scope(outer)
	check(baseline=="one" and P._skill_row_digest(text,17)==baseline and P._skill_row_digest(text,18)=="two", "scoped binding scan matches public scan and numeric IDs")
	check(outer.binding_builds==1 and outer.binding_hits==1, "binding JSON parses once across different books")
	for id: int in [0,17,18,19,9007199254740991]:
		var mixed: String=JSON.stringify({"skills":{"a":{"spell_id":float(id),"row_sha256":"x"},"b":{"spell_id":null,"row_sha256":"z"},"c":false,"d":{"spell_id":9007199254740992.0,"row_sha256":"big"},"e":{"spell_id":-0.0,"row_sha256":"zero"}}})
		check(P._skill_row_digest(mixed,id)==_frozen_binding_digest(mixed,id), "parsed memo retains frozen scan numeric/null/precision behavior")
	# Resume the original byte-change counter sequence in a fresh scope.
	outer = P.RegistrationScope.new(); P._swap_registration_scope(outer)
	P._skill_row_digest(text,17)
	var changed: String = text.replace("one","new")
	check(P._skill_row_digest(changed,17)=="new" and outer.binding_builds==2, "same-length binding byte edits reparse document")
	var ambiguous: String = JSON.stringify({"skills":{"a":{"spell_id":17,"row_sha256":"a"},"b":{"spell_id":17,"row_sha256":"b"}}})
	check(P._skill_row_digest(ambiguous,17)=="", "ambiguous binding hashes remain unavailable")
	check(P._skill_row_digest("{}",17)=="" and P._skill_row_digest("[]",17)=="", "missing binding structure and non-object input clear prior hashes")
	var inner := P.RegistrationScope.new()
	P._swap_registration_scope(inner)
	check(P._skill_row_digest(text,17)==baseline and inner.binding_builds==1 and outer.binding_text=="[]", "nested binding scopes own separate documents")
	P._swap_registration_scope(outer)
	check(P._skill_row_digest(text,17)==baseline and outer.binding_builds==6, "outer scope restores and rebuilds after bytes change")
	P.SOURCE.reset()
	check(P._skill_row_digest(changed,17)=="new", "source reset never retains stale changed binding bytes")
	P._swap_registration_scope(null)
	check(P._skill_row_digest(text,17)==baseline and outer.binding_text==changed, "scope exit restores public uncached behavior")
	P._swap_registration_scope(prior)

func _native_market_scope() -> void:
	var detail: Dictionary={"bonus":{"Value":17.0},"type":{"Name":"MarketPurchaseID"},"unit":{"Name":"MarketPurchaseID"},"link":{"ID":1.0}}
	var blockers: Array[String]=[]
	var public_ref: Dictionary=DATA._typed_reference(detail,blockers)
	check(public_ref.has("market_gotcha") and public_ref.market_gotcha.get("kind")=="twilight.current523.market-gotcha-data.v1", "default typed Market reference still builds complete public graph")
	check(DATA._typed_reference(detail,blockers,false).is_empty(), "internal projection omits only unused Market graph")
	var nonmarket: Dictionary={"bonus":{"Value":17.0},"type":{"Name":"Unknown"},"unit":{"Name":"Unknown"},"link":{"ID":1.0}}
	check(same(DATA._typed_reference(nonmarket,blockers),DATA._typed_reference(nonmarket,blockers,false)), "projection leaves non-Market reference behavior unchanged")
	check(same(DATA.describe(-1),DATA._describe_native_registration(-1)), "missing-source native projection preserves describe rejection")
	var prior: P.RegistrationScope=P._swap_registration_scope(null)
	check(same(DROP._describe_item(-1,true),DROP._describe_item(-1)), "projection request outside verified registration keeps public reader path")
	P._swap_registration_scope(prior)

func _frozen_binding_digest(text: String, spell_id: int) -> String:
	var binding_document: Variant=JSON.parse_string(text)
	var row_digests: Array=[]
	if binding_document is Dictionary and binding_document.get("skills") is Dictionary:
		for bound: Variant in binding_document.skills.values():
			if bound is Dictionary and bound.get("spell_id")==spell_id and bound.get("row_sha256") is String and bound.row_sha256 not in row_digests:row_digests.append(bound.row_sha256)
	return str(row_digests[0]) if row_digests.size()==1 else ""

func _market_warmup_scopes() -> void:
	var prior: P.RegistrationScope = P._swap_registration_scope(null)
	check(not P.registration_market_warmup(), "outside registration no Market warmup token exists")
	var outer := P.RegistrationScope.new()
	P._swap_registration_scope(outer)
	var detail: Dictionary = {"bonus":{"Value":17.0},"type":{"Name":"MarketPurchaseID"},"unit":{"Name":"MarketPurchaseID"},"link":{"ID":1.0}}
	var blockers: Array[String] = []
	var expected: Dictionary = DATA._typed_reference(detail,blockers,true,P.registration_market_warmup)
	check(expected.has("market_gotcha") and not outer.market_warmup_taken, "ordinary public Market graph never consumes registration warmup")
	check(DATA._typed_reference(detail,blockers,false).is_empty() and not outer.market_warmup_taken, "private call without callback retains skip behavior")
	for value: Variant in [null,"17",0,-1,1.5,INF]:
		var invalid: Dictionary = detail.duplicate(true); invalid.bonus.Value = value
		check(DATA._typed_reference(invalid,blockers,false,P.registration_market_warmup).is_empty() and not outer.market_warmup_taken, "invalid Market target never consumes first valid graph warmup")
	var unrelated: Dictionary = detail.duplicate(true); unrelated.type.Name = "Unknown"; unrelated.unit.Name = "Unknown"
	check(DATA._typed_reference(unrelated,blockers,false,P.registration_market_warmup).is_empty() and not outer.market_warmup_taken, "non-Market target never consumes Market warmup")
	check(same(DATA._typed_reference(detail,blockers,false,P.registration_market_warmup),expected) and outer.market_warmup_taken, "first valid Market target builds the exact existing public graph")
	check(DATA._typed_reference(detail,blockers,false,P.registration_market_warmup).is_empty(), "second valid Market target skips unused graph")
	var inner := P.RegistrationScope.new()
	P._swap_registration_scope(inner)
	check(P.registration_market_warmup() and not P.registration_market_warmup(), "nested registration receives exactly one independent Market warmup")
	P._swap_registration_scope(outer)
	check(not P.registration_market_warmup(), "restoring outer registration preserves its consumed Market warmup")
	var thread := Thread.new()
	var launched: Error = thread.start(_thread_market_warmup)
	check(launched == OK, "Market warmup isolation worker starts")
	if launched == OK: check(bool(thread.wait_to_finish()), "worker Market warmup is independent and released on exit")
	check(not P.registration_market_warmup(), "worker leaves outer Market warmup consumed")
	P.SOURCE.reset()
	check(P.registration_market_warmup() and not P.registration_market_warmup(), "explicit source reset permits exactly one new graph warmup")
	P._swap_registration_scope(null)
	check(not P.registration_market_warmup() and same(DATA._typed_reference(detail,blockers),expected), "scope exit keeps full public graph behavior and no persistent token")
	P._swap_registration_scope(prior)

func _thread_market_warmup() -> bool:
	var outside: bool = not P.registration_market_warmup()
	var scope := P.RegistrationScope.new()
	var prior: P.RegistrationScope = P._swap_registration_scope(scope)
	var once: bool = P.registration_market_warmup() and not P.registration_market_warmup()
	return outside and prior == null and once and P._swap_registration_scope(null) == scope and not P.registration_market_warmup()
