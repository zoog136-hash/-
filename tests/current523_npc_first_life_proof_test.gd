extends SceneTree
## Cold first and subsequent admitted NPCs through the production owner and
## full typed closure. The source reader is filled with synthetic table data in
## a disposable test profile; no original archive or phone timings are inferred.
const ROWS=preload("res://scripts/resources/current523_definition_rows.gd")
const Catalog=preload("res://scripts/monsters/patch523_npc_catalog.gd")
const PATH: String="user://npc-first-life-proof-fixture.zip"
var failed: Array[String]=[]
var checks: int=0
var attacks: Array[Dictionary]=[]
var spells: Array[Dictionary]=[]
var links: Array[Dictionary]=[]
var bonuses: Array[Dictionary]=[]
var names: Array[int]=[73681,73682]

func _initialize() -> void:_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failed.append(label);printerr("NPC_FIRST_LIFE_PROOF_FAIL ",label)

func _source(npc_id: int) -> Dictionary:
	return {"ID":npc_id,"Sprite":4576,"DescId":7,"Category":1,"TestNPC":false,"HP":81,"MP":9,"AC":-12,"MR":11,"Exp":25,"Str":9,"Dex":8,"Con":7,"Wis":6,"Cha":5,"Int":4,
		"FireResistance":13,"WaterResistance":12,"EarthResistance":11,"AirResistance":10}

func _host(npc_id: int) -> Dictionary:
	return {"source_m_npc_id":npc_id,"source_m_original":{"ID":npc_id,"Sprite":4576,"DescId":7,"host":[1,2]},"source_m_spawn_npc_level":19,"attack_range":211.0,"fear_resistance":17,"drop":[{"name":"same item"}]}

func _table(table: String, values: Array) -> void:
	ROWS._tables[table]=ROWS._pack(values)

func _prepare() -> bool:
	ROWS.reset()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",PATH)
	var writer:=ZIPPacker.new()
	if writer.open(PATH)!=OK:return false
	writer.start_file("test-fixture.txt")
	writer.write_file("synthetic admission test".to_utf8_buffer())
	writer.close_file()
	writer.close()
	ROWS._archive=ZIPReader.new()
	if ROWS._archive.open(PATH)!=OK:return false
	ROWS._archive_path=PATH
	ROWS._verified_sha=Catalog.SOURCE_SHA
	ROWS._verified_bytes=FileAccess.open(PATH,FileAccess.READ).get_length()
	for who: int in range(names.size()):
		for spell: int in range(24):
			var id: int=1000+who*24+spell
			spells.append({"ID":id,"TestSpell":false})
			attacks.append({"ID":id,"NpcClassID":names[who],"Range":2,"IsSpell":true,"SpellID":id})
			for link: int in range(12):
				links.append({"ID":id*100+link,"SpellClassID":id,"BonusID":1+link})
	for id: int in range(1,1001):
		bonuses.append({"ID":id,"BonusTypeID":1,"BonusApplicationTypeID":0,"Value":id})
	var tables: Dictionary={"NpcClass":[_source(names[0]),_source(names[1])],"NpcCategory":[{"ID":1,"Name":"Npc","IsAttackable":true}],
		"NpcAttack":attacks,"NpcAttribute":[],"NpcRace":[],
		"NpcSpecialResistance":[{"ID":11,"NpcClassID":names[0],"SpecialResistanceTypeID":1,"Value":26},{"ID":12,"NpcClassID":names[1],"SpecialResistanceTypeID":1,"Value":27}],
		"SpecialResistanceType":[{"ID":1,"Name":"Stun"}],"SpellClass":spells,"SpellBonus":links,"Bonus":bonuses,"BonusType":[{"ID":1,"UnitID":1,"Name":"Fixture"}],
		"Unit":[{"ID":1,"Name":"Value"}],"BonusApplicationType":[{"ID":0,"Name":"None"}],"UIUnit":[{"UnitID":1}],
		"BuffGroup":[{"ID":1}],"ElementalType":[{"ID":1}],"AttackType":[{"ID":1}]}
	for table: String in tables:_table(table,tables[table])
	return true

func _measure(use_cache: bool) -> Dictionary:
	ROWS._relations.clear()
	var catalog=Catalog.new()
	catalog._original_input.id_proof_reuse_enabled=use_cache
	var actors: Array=[]
	var cold_us: int=0
	var reads: Array[int]=[]
	var hits: Array[int]=[]
	for npc: int in names:
		var started: int=Time.get_ticks_usec()
		var result: Dictionary=catalog.project_actor_record(_host(npc))
		cold_us+=Time.get_ticks_usec()-started
		actors.append(result)
		reads.append(catalog._original_input.growth_id_reads)
		hits.append(catalog._original_input.growth_id_hits)
	var repeat_started: int=Time.get_ticks_usec()
	for sample: int in range(20):actors.append(catalog.project_actor_record(_host(names[sample%2])))
	var repeat_us: float=(Time.get_ticks_usec()-repeat_started)/20.0
	check(catalog.admitted_source_identities.size()==2 and actors[0].hp==81 and actors[1].get("stun_resistance")==27,"both exact first-life source owners admit and project")
	check(actors[0].attack_range==116.0 and actors[0].source_m_spawn_npc_level==19 and actors[0].drop==_host(names[0]).drop,"range is exact; spawn level and loot input remain untouched")
	return {"cold_us":cold_us,"repeat_avg_us":repeat_us,"reads":reads,"hits":hits,"bytes":var_to_bytes([actors,catalog.content,catalog.source_model_sha256,catalog.admitted_source_identities])}

func _run() -> void:
	if not _prepare():
		check(false,"disposable source fixture prepares")
		quit(1);return
	var cold: Dictionary={"false":[],"true":[]}
	var repeated: Dictionary={"false":[],"true":[]}
	var sample: Dictionary={}
	var expected:=PackedByteArray()
	for arm: bool in [false,true,true,false,false,true,true,false]:
		var row: Dictionary=_measure(arm)
		if expected.is_empty():expected=row.bytes
		check(row.bytes==expected,"first/repeated actors, full closure, identity and provenance match byte-for-byte")
		check((row.hits[0]>0 and row.hits[1]>0 and row.reads[0]<100 and row.reads[1]<100) if arm else (row.hits==[0,0] and row.reads[0]>800 and row.reads[1]>800),"only the repeated globally-proved ID reads are omitted")
		cold[str(arm)].append(row.cold_us)
		repeated[str(arm)].append(row.repeat_avg_us)
		sample[str(arm)]={"reads":row.reads,"hits":row.hits}
	# A colliding, otherwise equal Bonus ID must fail before any proof is cached.
	var duplicate: Array=bonuses.duplicate()
	duplicate.append(bonuses[0].duplicate())
	_table("Bonus",duplicate)
	ROWS._relations.clear()
	var reject=Catalog.new()
	var host: Dictionary=_host(names[0])
	var got: Dictionary=reject.project_actor_record(host)
	check(got==host and reject.admitted_source_identities.is_empty() and reject.error=="source_reference_missing_or_ambiguous:Bonus:1","duplicate typed Bonus still blocks first admission")
	_table("Bonus",bonuses)
	ROWS._relations.clear()
	check(reject.project_actor_record(host).hp==81,"failed growth proofs are cleared; the verified retry admits")
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	ROWS.reset()
	print("NPC_FIRST_LIFE_PROOF_RESULT ",JSON.stringify({"checks":checks,"failures":failed,"cold":cold,"repeat":repeated,"samples":sample}))
	quit(0 if failed.is_empty() else 1)
