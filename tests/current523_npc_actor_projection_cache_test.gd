extends SceneTree
## Exercises the production projection against synthetic read-only source
## rows (not imported original assets), including repeat initializations.
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
const PATH := "user://npc-projection-cache-fixture.zip"
const NPC := 17
var row_count: int = 12000
const SPECIAL := CATALOG.SPECIAL_PROJECTION_KEY
const RANGE := CATALOG.RANGE_PROJECTION_KEY
var checks: int = 0
var failures: Array[String] = []
var source: Dictionary = {"ID":NPC,"Sprite":88,"DescId":7,"TestNPC":false,"Category":1,
	"HP":999,"MP":7,"AC":-8,"MR":41,"Exp":5,"Str":3,"Dex":4,"Con":5,"Wis":6,"Cha":7,"Int":8,
	"FireResistance":8,"WaterResistance":11,"EarthResistance":13,"AirResistance":17}
var attacks: Array[Dictionary] = []
var special: Array[Dictionary] = [{"ID":3,"NpcClassID":NPC,"SpecialResistanceTypeID":1,"Value":26},
	{"ID":4,"NpcClassID":NPC,"SpecialResistanceTypeID":2,"Value":27},
	{"ID":5,"NpcClassID":NPC,"SpecialResistanceTypeID":2,"Value":29}]

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("NPC_ACTOR_PROJECTION_CACHE_FAIL " + label)

func _entry(value: Dictionary) -> Dictionary:
	return {"row":value,"source_row_1based":int(value.ID)+1}

func _fixture() -> void:
	ROWS.reset()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",PATH)
	var writer := ZIPPacker.new()
	check(writer.open(PATH)==OK,"isolated fixture zip")
	writer.start_file("test-fixture.txt")
	writer.write_file("synthetic projection fixture".to_utf8_buffer())
	writer.close_file()
	writer.close()
	ROWS._archive=ZIPReader.new()
	check(ROWS._archive.open(PATH)==OK,"isolated fixture handle")
	ROWS._archive_path=PATH
	# Test-only injection in isolated user://; no production pin change.
	ROWS._verified_sha=CATALOG.SOURCE_SHA
	ROWS._verified_bytes=FileAccess.open(PATH,FileAccess.READ).get_length()
	if attacks.is_empty():
		for index: int in row_count:
			var owner: int = index+1000 if index>=2 else NPC
			attacks.append({"ID":index+80,"NpcClassID":owner,"Range":2})
	for row_set: Array in [["NpcClass",[source]],["NpcCategory",[{"ID":1,"Name":"Npc","IsAttackable":true}]],
			["NpcAttack",attacks],["NpcSpecialResistance",special],
			["SpecialResistanceType",[{"ID":1,"Name":"Stun"},{"ID":2,"Name":"Fear"}]]]:
		ROWS._tables[row_set[0]] = ROWS._pack(row_set[1])

func _catalog(cache: bool):
	var catalog = CATALOG.new()
	catalog.actor_projection_cache_enabled = cache
	catalog.source_identity = ROWS.identity()
	var attack_entries: Dictionary = {}
	var resistance_entries: Dictionary = {}
	for row: Dictionary in attacks: attack_entries[str(row.ID)] = _entry(row)
	for row: Dictionary in special: resistance_entries[str(row.ID)] = _entry(row)
	catalog._publish_original({"kind":"patch523_npc_spell_catalog","input_kind":"twilight.current523.npc-input.v1",
		"source_snapshot":"patch523","schema":1,"source_archive_sha256":CATALOG.SOURCE_SHA,
		"tables":{"NpcClass":{str(NPC):_entry(source)},"NpcAttack":attack_entries,"NpcSpecialResistance":resistance_entries,
			"SpecialResistanceType":{"1":_entry({"ID":1,"Name":"Stun"}),"2":_entry({"ID":2,"Name":"Fear"})}}})
	catalog.admitted_source_identities[str(NPC)]={"npc_class_id":NPC,"sprite":88,"desc_id":7,
		"source_archive_sha256":CATALOG.SOURCE_SHA}
	return catalog

func _host() -> Dictionary:
	return {"source_m_npc_id":NPC,"source_m_original":{"ID":NPC,"Sprite":88,"DescId":7,"host_extra":{"unchanged":[1]}},
		"source_m_spawn_npc_level":9,"attack_range":321.0,"fear_resistance":81,"hp":12,
		"owner":{"position":[4,5],"hp":2},"element_resistance":{"custom":31}}

func _median(samples: Array[float]) -> float:
	samples.sort()
	var mid: int=samples.size()/2
	return (samples[mid-1]+samples[mid])/2.0 if samples.size()%2==0 else samples[mid]

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rows="): row_count=clampi(int(argument.trim_prefix("--rows=")),2,24000)
	_fixture()
	var reference = _catalog(false)
	var candidate = _catalog(true)
	var host := _host()
	var initial: Dictionary = reference.project_actor_record(host)
	check(initial.has(SPECIAL) and initial.has(RANGE),"both policy outputs actually run")
	check(initial.get("stun_resistance")==26 and initial.get("fear_resistance")==81 and initial.get("attack_range")==116.0,"only unique and valid source fields replace the host input")
	check(initial.get(SPECIAL,{}).get("fields",{}).get("Fear",{}).get("hold_reason")=="multiple_source_rows_for_status_channel","semantic duplicate channel remains rejected")
	check(initial.get("hp")==999 and initial.get("source_m_spawn_npc_level")==9 and initial.get("element_resistance",{}).get("custom")==31,"stats/level/host-only channels remain")
	check(initial.get(SPECIAL,{}).get("fields",{}).get("Stun",{}).get("prior_present")==false,"missing prior distinguished from zero")
	check(var_to_bytes(candidate.project_actor_record(host))==var_to_bytes(initial),"cold cached path bit-for-bit matches")
	check(var_to_bytes(candidate.project_actor_record(host))==var_to_bytes(initial),"warm cached path bit-for-bit matches")
	for role: String in ["ordinary","variant","boss","pet","dungeon"]:
		var life := host.duplicate(true)
		life["owner"]["role"]=role
		life["owner"]["position"].append(role)
		life["stun_resistance"]=54 if role!="pet" else null
		life["fear_resistance"]=22 if role=="boss" else 0
		life["attack_range"]=85.5 if role=="dungeon" else null
		var expected: Dictionary = reference.project_actor_record(life)
		var actual: Dictionary = candidate.project_actor_record(life)
		check(var_to_bytes(actual)==var_to_bytes(expected),"warm exact output for "+role)
		check(actual.owner==life.owner and actual[RANGE].prior_host_attack_range==life.attack_range and actual[SPECIAL].fields.Stun.prior==life.stun_resistance,"per-life state and evidence preserved for "+role)
		actual.owner.position[0]=-1
		actual[SPECIAL].fields.Stun.source_rows[0].link.Value=99
		actual[RANGE].admitted_attack_ids.append(999)
		check(var_to_bytes(candidate.project_actor_record(life))==var_to_bytes(expected),"returned mutable fields are detached for "+role)
	var incorrect := host.duplicate(true)
	incorrect.source_m_original.Sprite=89
	check(is_same(candidate.project_actor_record(incorrect),incorrect),"prior sprite identity is still checked on a hit")
	var before_registry: String=initial[RANGE].admitted_registry_ids_sha256
	for catalog in [reference,candidate]:
		var next: Dictionary = catalog.content.duplicate(true)
		catalog._publish_original(next)
		catalog._ids_sha_count=-1
		catalog.admitted_source_identities["500"]={}
	var republished: Dictionary = candidate.project_actor_record(host)
	check(var_to_bytes(republished)==var_to_bytes(reference.project_actor_record(host)) and republished[RANGE].admitted_registry_ids_sha256!=before_registry,"registry publication invalidates and updates evidence")
	# Change the policy fingerprint, then present two source rows with one ID:
	# this must hold rather than use the earlier positive cache.
	var policy_file: Dictionary=CATALOG._policy_file(CATALOG.NPC_RANGE_INPUT_POLICY_PATH)
	var changed:=policy_file.duplicate(true)
	changed.sha256="synthetic_test_override"
	changed.policy.raw_attack_range_to_host_length=40.0
	CATALOG._policy_files[CATALOG.NPC_RANGE_INPUT_POLICY_PATH]=changed
	var changed_out: Dictionary=candidate.project_actor_record(host)
	check(var_to_bytes(changed_out)==var_to_bytes(reference.project_actor_record(host)) and changed_out.attack_range==80.0,"policy hash invalidates a warm projection")
	CATALOG._policy_files[CATALOG.NPC_RANGE_INPUT_POLICY_PATH]=policy_file
	special.append(special[0].duplicate(true))
	_fixture() # same pin and size, new read lifetime
	var rejected: Dictionary=candidate.project_actor_record(host)
	check(var_to_bytes(rejected)==var_to_bytes(reference.project_actor_record(host)) and not rejected.has(SPECIAL),"source reader reset invalidates even the same identity and rejects ambiguous duplicated ID")
	special.pop_back()
	_fixture()
	# Compare warm repeat projection in paired ABBA order; timing is informational.
	var cold: Dictionary={}
	var warm: Dictionary={}
	for enabled: bool in [false,true,true,false,false,true,true,false]:
		var label: String = "enabled" if enabled else "disabled"
		var run = _catalog(enabled)
		var start: int=Time.get_ticks_usec()
		var first: Dictionary=run.project_actor_record(host)
		var elapsed: float=float(Time.get_ticks_usec()-start)/1000.0
		check(var_to_bytes(first)==var_to_bytes(initial),"benchmark cold evidence matches "+label)
		if not cold.has(label):cold[label]=[]
		cold[label].append(elapsed)
		for _sample: int in 30:
			start=Time.get_ticks_usec()
			run.project_actor_record(host)
			if not warm.has(label):warm[label]=[]
			warm[label].append(float(Time.get_ticks_usec()-start)/1000.0)
	var cold_p50: Dictionary={}
	for label: String in cold:
		var samples: Array[float]=[]
		samples.assign(cold[label])
		cold_p50[label]=_median(samples)
	var warm_p50: Dictionary={}
	for label: String in warm:
		var samples: Array[float]=[]
		samples.assign(warm[label])
		warm_p50[label]=_median(samples)
	var bounded = CATALOG.new()
	for id: int in CATALOG.ACTOR_PROJECTION_CACHE_LIMIT+1:
		bounded._store_actor_projection({"ID":id},{"sample":id})
	check(bounded._actor_projection_cache.size()==CATALOG.ACTOR_PROJECTION_CACHE_LIMIT and not bounded._actor_projection_cache.has(0),"positive-cache FIFO remains bounded")
	bounded._publish_original({"tables":{}})
	check(bounded._actor_projection_cache.is_empty(),"registry replacement drops all retained entries")
	# A range proof that cannot be completed must keep each prior range;
	# publication of valid evidence later must be retried rather than poisoned.
	var mixed = _catalog(true)
	var varied: Dictionary=mixed.content.duplicate(true)
	varied.tables.NpcAttack["81"].row.Range=5
	mixed.content=varied
	var held: Dictionary=mixed.project_actor_record(host)
	check(not held.has(RANGE) and held.attack_range==host.attack_range,"failed exact attack-row proof retains prior range")
	check(not mixed._actor_projection_cache.get(NPC,{}).has("range"),"missing/failed range proof is not cached")
	mixed.content=candidate.content
	var retried: Dictionary=mixed.project_actor_record(host)
	check(retried.has(RANGE),"valid republished attack proof is retried")
	ROWS.reset()
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	print("NPC_ACTOR_PROJECTION_CACHE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"source":"synthetic_only","admitted_attack_rows":row_count,"cold_ms":cold,"cold_p50_ms":cold_p50,"warm_p50_ms":warm_p50}))
	quit(0 if failures.is_empty() else 1)
