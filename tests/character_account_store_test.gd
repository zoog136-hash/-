extends SceneTree

const STORE = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const WAREHOUSE = preload("res://scripts/warehouse/local_warehouse.gd")
var checks: int = 0
var failures: Array[String] = []
var base: String

class FakeCatalog extends RefCounted:
	var problem: String = ""
	func profile(id: int, gender: int) -> Dictionary:
		if not STORE.JOBS.has(id) or gender not in [1,2]: return {}
		return {"name":STORE.JOBS[id],"stats":{"str":16,"dex":11,"con":16,"int":8,"wis":7,"cha":8},"source":{"ID":id}}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CHARACTER_ACCOUNT_FAIL ", label)

func same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left))==JSON.parse_string(JSON.stringify(right))

func read(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func fresh(suffix: String) -> RefCounted:
	var store = STORE.new()
	store.path = base + suffix + ".json"
	check(store.open().get("ok",false),suffix+": open empty")
	return store

func commit(path: String, data: Dictionary, label: String) -> bool:
	var before: String = JSON.stringify(data,"",true,true)
	var staged: Dictionary = STORE.stage_save(path,data)
	check(JSON.stringify(data,"",true,true)==before,label+": stage does not mutate input")
	check(staged.get("ok",false),label+": stage accepts")
	if not staged.get("ok",false):
		printerr("STAGE_REASON ",staged.get("problem"))
		return false
	check(WRITER.write(path,staged.payload)==OK,label+": atomic write")
	return true

func run() -> void:
	base = "user://account-test-"+str(Time.get_ticks_usec())+"-"
	var catalog = FakeCatalog.new()
	var slots = fresh("slots")
	var ids: Array[String] = []
	for index: int in 13:
		var result: Dictionary = slots.create_character("캐릭터%02d"%index,1,1,catalog)
		check(result.get("ok",false),"create slot %d with repeated same class"%(index+1))
		if result.get("ok",false): ids.append(result.id)
	check(slots.open().get("characters",[]).size()==13,"13 slots stored independently of 13 class definitions")
	var hash_before: String = FileAccess.get_sha256(slots.path)
	check(not slots.create_character("초과캐릭터",2,2,catalog).get("ok",true),"14th character rejected")
	check(FileAccess.get_sha256(slots.path)==hash_before,"slot cap does not modify save")
	for bad: String in ["가"," 이름","이름 ","이/름","이\\름","이\n름","1234567890123"]:
		check(not STORE.name_problem(bad).is_empty(),"invalid name rejected: "+bad.c_escape())
	check(STORE.name_problem("한글이름").is_empty(),"Unicode character name allowed")
	var duplicate = fresh("names")
	check(duplicate.create_character("Alpha",1,1,catalog).ok,"first named character")
	check(not duplicate.create_character("alpha",1,1,catalog).ok,"case-insensitive duplicate name rejected")
	check(not duplicate.create_character("잘못직업",99,1,catalog).ok,"unavailable class rejected")
	check(not duplicate.create_character("잘못성별",1,0,catalog).ok,"unavailable gender rejected")
	catalog.problem="missing source"
	check(not duplicate.create_character("원문없음",1,1,catalog).ok,"unavailable source rejected")
	catalog.problem=""
	var all_jobs = fresh("jobs")
	for id: int in STORE.JOBS:
		check(all_jobs.create_character("직업%d"%id,id,1,catalog).ok,"native class ID creates independently: %d"%id)
	check(all_jobs.open().characters.size()==13,"all 13 native class IDs fit 13 independent slots")
	# First selection, save full private/shared state, then switch to a new body.
	var store = fresh("sharing")
	var first: Dictionary=store.create_character("첫캐릭터",1,1,catalog)
	var second: Dictionary=store.create_character("둘캐릭터",2,2,catalog)
	check(first.ok and second.ok,"two different class/gender characters")
	if first.ok and second.ok:
		check(store.select_character(first.id).ok,"select first")
		var payload: Dictionary=read(store.path)
		payload.merge({"level":30,"gold":777,"inventory":{"개인검":1},"item_instances":{"100":{"name":"개인검","enchant":7}},"original_skill_state":{"learned":[42]},"quickslots":["기사기술"],"equipped_catalog":{"변신":{"id":123}},"warehouse":{"stacks":{"창고검":1},"instances":{"101":{"name":"창고검","enchant":5}}},"card_draw_fusion":{"owned":{"변신":{"card1":true}}},"equipment_collections":{"completed":[4]},"growth":{"nodes":[5]},"card_skill_awakening":{"cards":{"card1":{"level":2}}},"next_item_instance_id":102,"card_option_awakening":{"cards":{"변신":{"card1":{"awakened":true}}},"native_subslot_identity":"first-only","native_doll_unlock":{"marker":1}},"consumable_state":{"elixirs_used":3,"source_skill_book_receipts":{"book-first":1},"source_native_stack_uses":{"physical101":{"remaining":7}}}},true)
		if commit(store.path,payload,"first progress"):
			check(store.open().ok,"reload after world save")
			var switched: Dictionary=store.select_character(second.id)
			check(switched.ok,"select second with shared warehouse/proof journal")
			if not switched.ok: printerr("SELECT_REASON ",switched.get("problem"))
			if switched.ok:
				var other: Dictionary=read(store.path)
				for key: String in ["gold","level","inventory","item_instances","original_skill_state","quickslots","equipped_catalog"]:
					check(not other.has(key),"new character does not inherit private "+key)
				for key: String in ["warehouse","card_draw_fusion","equipment_collections","growth","card_skill_awakening","next_item_instance_id"]:
					check(same(other.get(key),payload.get(key)),"shared "+key)
				check(same(other.get("consumable_state",{}).get("source_native_stack_uses"),payload.consumable_state.source_native_stack_uses),"physical ownership journal follows warehouse")
				check(not other.get("consumable_state",{}).has("source_skill_book_receipts") and not other.get("consumable_state",{}).has("elixirs_used"),"skill learning and permanent consumable stats stay private")
				check(not other.get("card_option_awakening",{}).has("native_subslot_identity") and not other.get("card_option_awakening",{}).has("native_doll_unlock"),"secondary equipped card/unlock remain private")
				other["gold"]=9;other["level"]=2;other["inventory"]={"둘개인검":1};other["item_instances"]={"102":{"name":"둘개인검"}};other["next_item_instance_id"]=103
				other.warehouse.stacks["공유물약"]=4
				if commit(store.path,other,"second progress"):
					store.open()
					check(store.select_character(first.id).ok,"return first")
					var restored: Dictionary=read(store.path)
					for key: String in ["gold","level","inventory","item_instances","original_skill_state","quickslots","equipped_catalog"]:
						check(same(restored.get(key),payload.get(key)),"restore first private "+key)
					check(restored.warehouse.stacks.get("공유물약")==4 and restored.next_item_instance_id==103,"later shared update visible without reviving old allocator")
					check(restored.card_option_awakening.native_subslot_identity=="first-only","restore first secondary card")
					var warehouse = WAREHOUSE.new();warehouse.restore(restored.warehouse)
					var deposited: Dictionary=warehouse.store("개인검",1,"100",restored.inventory,restored.item_instances,{},true)
					check(deposited.ok,"actual warehouse owner deposits first physical item")
					restored.warehouse=warehouse.snapshot()
					if deposited.ok and commit(store.path,restored,"warehouse deposit"):
						store.open();check(store.select_character(second.id).ok,"second enters shared warehouse")
						var receiver: Dictionary=read(store.path)
						warehouse.restore(receiver.warehouse)
						var withdrawn: Dictionary=warehouse.retrieve("개인검",1,"100",receiver.inventory,receiver.item_instances,true,0,1000,1)
						check(withdrawn.ok,"actual warehouse owner retrieves on different character")
						check(receiver.item_instances.get("100",{}).get("enchant")==7,"enhancement stays on original physical ID across characters")
						receiver.warehouse=warehouse.snapshot()
						if withdrawn.ok and commit(store.path,receiver,"warehouse withdrawal"):
							store.open();check(store.select_character(first.id).ok,"first returns after item transfer")
							var sender: Dictionary=read(store.path)
							check(not sender.item_instances.has("100") and not sender.warehouse.instances.has("100"),"cross-character transfer cannot resurrect original physical item")
	# Stale observer and failed atomic writes cannot consume a slot or switch.
	var stale = STORE.new();stale.path=duplicate.path
	check(stale.open().ok,"stale observer opens")
	check(duplicate.create_character("Beta",2,2,catalog).ok,"current observer creates second")
	hash_before=FileAccess.get_sha256(duplicate.path)
	check(not stale.create_character("Stale",1,1,catalog).ok,"stale observer rejected")
	check(FileAccess.get_sha256(duplicate.path)==hash_before,"stale write preserves disk")
	duplicate.test_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_CANT_CREATE
	check(not duplicate.create_character("Failed",1,1,catalog).ok,"write failure propagates")
	check(FileAccess.get_sha256(duplicate.path)==hash_before,"failed write preserves old bytes")
	check(duplicate.open().characters.size()==2,"failed create did not consume slot")
	var uncertain = fresh("lost-response")
	uncertain.test_writer=func(target: String,candidate: Dictionary) -> Error:
		WRITER.write(target,candidate)
		return ERR_CANT_CREATE
	var durable:Dictionary=uncertain.create_character("응답유실",1,1,catalog)
	check(durable.ok,"lost writer response succeeds only after exact durable bytes verified")
	var listed:Dictionary=uncertain.open()
	check(listed.ok and listed.characters.size()==1 and listed.characters[0].id==durable.get("id"),"lost response retains exactly one acknowledged character")
	check(not uncertain.create_character("응답유실",1,1,catalog).ok,"retry cannot duplicate character after lost response")
	check(uncertain.open().characters.size()==1,"retry leaves one slot")
	var gender_store = fresh("legacy-gender")
	check(WRITER.write(gender_store.path,{"job_class":"기사","gold":456,"original_skill_state":{"learned":[77]}})==OK,"write gender-unknown legacy")
	check(gender_store.open().legacy and gender_store.migrate_legacy().ok,"legacy without gender safely migrates to unknown gender")
	var gender_id:String=gender_store.open().characters[0].id
	hash_before=FileAccess.get_sha256(gender_store.path)
	check(not gender_store.complete_legacy_gender(gender_id,0,catalog).ok,"unknown gender cannot complete without valid source profile")
	check(FileAccess.get_sha256(gender_store.path)==hash_before,"invalid gender choice preserves file")
	check(gender_store.complete_legacy_gender(gender_id,2,catalog).ok,"one-time valid source gender completes")
	var after_gender:Dictionary=read(gender_store.path)
	check(after_gender.job_class=="기사" and after_gender.gold==456 and same(after_gender.original_skill_state,{"learned":[77]}),"gender completion preserves job and progress")
	check(after_gender.source_visual_context.gender_id==2 and after_gender[STORE.KEY].characters[0].gender_id==2,"gender metadata and active body match")
	hash_before=FileAccess.get_sha256(gender_store.path)
	check(not gender_store.complete_legacy_gender(gender_id,1,catalog).ok,"completed gender cannot be changed again")
	check(FileAccess.get_sha256(gender_store.path)==hash_before,"repeated gender selection does not write")
	# Migration preserves original bytes and unknown namespaces.
	var legacy = fresh("legacy")
	var original: String="{\n  \"job_class\":\"기사\",\"gold\":123,\"unknown_future\":{\"untouched\":true},\"source_visual_context\":{\"snapshot\":\"base508\",\"gender_id\":1}\n}\n"
	var f:=FileAccess.open(legacy.path,FileAccess.WRITE);f.store_string(original);f.close()
	var original_hash: String=FileAccess.get_sha256(legacy.path)
	check(legacy.open().legacy,"legacy detected")
	var migrated: Dictionary=legacy.migrate_legacy()
	check(migrated.ok,"legacy migrated")
	if not migrated.ok: printerr("MIGRATE_REASON ",migrated.get("problem"))
	if migrated.ok:
		check(FileAccess.get_file_as_string(migrated.backup)==original and FileAccess.get_sha256(migrated.backup)==original_hash,"legacy SHA backup exact bytes")
		var saved: Dictionary=read(legacy.path)
		check(saved.unknown_future.untouched and saved.gold==123,"legacy unknown/private data preserved")
		check(STORE.validate(saved).is_empty(),"migrated envelope validates")
		var invalid: Dictionary=saved.duplicate(true);invalid[STORE.KEY].schema="future"
		check(not STORE.validate(invalid).is_empty(),"unknown schema rejected")
		invalid=saved.duplicate(true);invalid[STORE.KEY].selected="absent"
		check(not STORE.validate(invalid).is_empty(),"missing selection rejected")
		invalid=saved.duplicate(true);invalid[STORE.KEY].characters.append(invalid[STORE.KEY].characters[0].duplicate(true))
		check(not STORE.validate(invalid).is_empty(),"duplicate character ID rejected")
		invalid=saved.duplicate(true);invalid[STORE.KEY].characters[0].state.gold=999
		check(not STORE.validate(invalid).is_empty(),"flat/state projection mismatch rejected")
		invalid=saved.duplicate(true);invalid.item_instances={"same":{"name":"검"}};invalid.warehouse={"instances":{"same":{"name":"검"}}};invalid[STORE.KEY].characters[0].state=STORE.private_fields(invalid)
		check(not STORE.validate(invalid).is_empty(),"warehouse/body duplicate physical ID rejected")
		invalid=saved.duplicate(true)
		var shadow: Dictionary=invalid[STORE.KEY].characters[0].duplicate(true)
		shadow.id=Crypto.new().generate_random_bytes(16).hex_encode();shadow.name="손상캐릭터";shadow.state.consumable_state=[]
		invalid[STORE.KEY].characters.append(shadow)
		check(not STORE.validate(invalid).is_empty(),"malformed inactive character nested state rejected")
		invalid=saved.duplicate(true)
		invalid.item_instances={"dup":{"name":"검"}}
		invalid[STORE.KEY].characters[0].state=STORE.private_fields(invalid)
		shadow=invalid[STORE.KEY].characters[0].duplicate(true)
		shadow.id=Crypto.new().generate_random_bytes(16).hex_encode();shadow.name="중복캐릭터"
		invalid[STORE.KEY].characters.append(shadow)
		check(not STORE.validate(invalid).is_empty(),"physical ID duplicated between two characters rejected")
		STORE.session={"path":legacy.path,"id":"wrong"}
		check(not STORE.stage_save(legacy.path,saved).ok,"different session character cannot save")
		STORE.session={}
		check(not STORE.stage_save(legacy.path,saved).ok,"account payload cannot save without session")
		var stripped: Dictionary=saved.duplicate(true);stripped.erase(STORE.KEY)
		check(not STORE.stage_save(legacy.path,stripped).ok,"missing account envelope cannot erase existing account without session")
	var protected = fresh("backup-collision")
	check(WRITER.write(protected.path,{"job_class":"기사","gold":88})==OK,"write backup collision legacy")
	protected.open()
	var backup_path: String=protected.path+".pre-character-account-"+FileAccess.get_sha256(protected.path)
	check(WRITER.write_text(backup_path,"different backup")==OK,"write conflicting backup")
	hash_before=FileAccess.get_sha256(protected.path)
	check(not protected.migrate_legacy().ok,"conflicting existing backup blocks migration")
	check(FileAccess.get_sha256(protected.path)==hash_before,"backup failure preserves legacy bytes")
	var corrupt=fresh("corrupt")
	f=FileAccess.open(corrupt.path,FileAccess.WRITE);f.store_string("{broken");f.close()
	hash_before=FileAccess.get_sha256(corrupt.path)
	check(not corrupt.open().ok,"malformed JSON rejected without crash")
	check(FileAccess.get_sha256(corrupt.path)==hash_before,"malformed file preserved")
	STORE.session={}
	run_v2_regressions(catalog)
	print("CHARACTER_ACCOUNT_STORE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func old_account_fixture(source: Dictionary) -> Dictionary:
	var data: Dictionary=source.duplicate(true)
	data[STORE.KEY].schema=STORE.LEGACY_SCHEMA
	data[STORE.KEY].erase("shared")
	for record: Dictionary in data[STORE.KEY].characters:
		if record.state.get("card_option_awakening") is Dictionary:
			record.state.card_option_awakening.erase("native_relic_summon_time")
	# v1 selected state is partitioned by the ORIGINAL four private keys.
	for record: Dictionary in data[STORE.KEY].characters:
		if record.id==data[STORE.KEY].selected:
			record.state=STORE._private_fields(data,STORE.LEGACY_PRIVATE_OPTION)
	return data

func run_v2_regressions(catalog: RefCounted) -> void:
	var account = fresh("v2-canonical")
	var first: Dictionary=account.create_character("정본첫째",1,1,catalog)
	var second: Dictionary=account.create_character("정본둘째",2,2,catalog)
	check(first.ok and second.ok and account.select_character(first.id).ok,"v2: two canonical account characters")
	var data: Dictionary=read(account.path)
	check(data[STORE.KEY].schema==STORE.SCHEMA and data[STORE.KEY].shared is Dictionary,"v2: canonical shared namespace stored inside account")
	data["growth"]={"nodes":[77]};data["gold"]=4321
	data["unknown_future"]={"preserve":"first"}
	check(commit(account.path,data,"v2 canonical progress"),"v2: trusted owner snapshot seals")
	data=read(account.path)
	check(same(data[STORE.KEY].shared.growth,data.growth),"v2: top-level shared state is exact canonical projection")
	check(not data[STORE.KEY].characters[0].state.has("growth") and data[STORE.KEY].characters[0].state.gold==4321,"v2: private state and shared namespace are disjoint")
	var broken: Dictionary=data.duplicate(true);broken.growth.nodes=[78]
	check(not STORE.validate(broken).is_empty(),"v2: flat shared mutation cannot bypass canonical state")
	broken=data.duplicate(true);broken[STORE.KEY].shared.growth.nodes=[79]
	check(not STORE.validate(broken).is_empty(),"v2: canonical shared mutation cannot bypass compatibility projection")
	broken=data.duplicate(true);broken.gold=1
	check(not STORE.validate(broken).is_empty(),"v2: flat private mutation cannot bypass selected snapshot")
	# Unknown future shared namespaces retain canonical ownership and identity.
	data[STORE.KEY].shared["future_account_namespace"]={"untouched":true}
	data["future_account_namespace"]={"untouched":true}
	check(STORE.validate(data).is_empty(),"v2: unknown canonical shared namespace remains readable")
	check(WRITER.write(account.path,data)==OK and account.open().ok and account.select_character(second.id).ok,"v2: future shared state survives character selection")
	data=read(account.path)
	check(data.future_account_namespace.untouched and data[STORE.KEY].shared.future_account_namespace.untouched,"v2: future shared state preserved in projection and account")
	check(not data.has("unknown_future"),"v2: original unknown private field does not leak to second character")
	check(account.select_character(first.id).ok and read(account.path).unknown_future.preserve=="first","v2: original unknown private field restored")
	broken=data.duplicate(true)
	broken[STORE.KEY].shared["inventory"]={"incorrectly_shared":1}
	broken["inventory"]={"incorrectly_shared":1}
	broken[STORE.KEY].characters[0].state.erase("inventory")
	check(not STORE.validate(broken).is_empty() and not STORE.seal_payload(broken).ok,"v2: known private inventory cannot masquerade as future shared namespace")
	for field: String in ["card_option_awakening","consumable_state","source_visual_context"]:
		var malformed_legacy = fresh("legacy-shape-"+field)
		var malformed_payload: Dictionary={"job_class":"기사"}
		malformed_payload[field]=[]
		check(WRITER.write(malformed_legacy.path,malformed_payload)==OK and malformed_legacy.open().legacy,"legacy malformed shape: "+field+" fixture opens read-only")
		var shape_sha: String=FileAccess.get_sha256(malformed_legacy.path)
		check(not malformed_legacy.migrate_legacy().ok and FileAccess.get_sha256(malformed_legacy.path)==shape_sha,"legacy malformed shape: "+field+" rejects without runtime error or overwrite")
	# Build an exact v1 fixture with the historical global timer placement.
	data=read(account.path)
	var relic_a: String="source:m523:98:22182"
	var relic_b: String="source:m523:98:20548"
	var timer: Dictionary={"schema":1,"item_class_id":365758,"slot_index":11,"identity":relic_a,"expires_utc":1234567890,"source_duration_seconds":1800,"source_auto_overlap_ms":5000,"source_infinite_amount":true,"future_timer_metadata":{"preserve":7}}
	data["card_option_awakening"]={"native_relic_subslot_identity":relic_a,"native_relic_unlock":{"preserve":"A"},"native_relic_summon_time":timer,"cards":{"shared":true}}
	data=old_account_fixture(data)
	data[STORE.KEY]["future_metadata"]={"preserve":true}
	for record: Dictionary in data[STORE.KEY].characters:
		if record.id==second.id: record.state["card_option_awakening"]={"native_relic_subslot_identity":relic_b,"native_relic_unlock":{"preserve":"B"}}
	check(STORE.validate(data).is_empty(),"v1: original four-field private partition validates before upgrade")
	check(WRITER.write(account.path,data)==OK,"v1: write historical account fixture")
	var v1_sha: String=FileAccess.get_sha256(account.path)
	var opened: Dictionary=account.open()
	check(opened.ok and opened.upgrade and not opened.legacy,"v1: explicit upgrade flag with readable roster")
	check(FileAccess.get_sha256(account.path)==v1_sha,"v1: open is read-only")
	check(not account.create_character("차단생성",1,1,catalog).ok and not account.select_character(second.id).ok,"v1: create and select blocked until explicit upgrade")
	STORE.session={"path":account.path,"id":first.id,"initialized":true}
	check(not STORE.stage_save(account.path,data).ok and FileAccess.get_sha256(account.path)==v1_sha,"v1: World cannot silently rewrite old account")
	var upgraded: Dictionary=account.upgrade_account()
	check(upgraded.ok and upgraded.get("unresolved_timers")==1,"v1: explicit upgrade succeeds with one unresolved inactive timer")
	if upgraded.ok:
		check(FileAccess.get_sha256(upgraded.backup)==v1_sha,"v1: exact pre-upgrade byte backup retained")
		data=read(account.path)
		check(STORE.validate(data).is_empty() and data[STORE.KEY].schema==STORE.SCHEMA,"v1: upgraded v2 projection validates")
		check(same(data.card_option_awakening.native_relic_summon_time,timer),"v1: matching selected timer retains exact expiry and all metadata")
		check(not data[STORE.KEY].shared.card_option_awakening.has("native_relic_summon_time"),"v1: timer removed from account-shared effects")
		check(same(data[STORE.KEY].legacy_relic_timer_migration.historical_timer,timer) and data[STORE.KEY].future_metadata.preserve,"v1: historical timer and unknown account metadata archived exactly")
		check(account.select_character(second.id).ok,"v1: unresolved inactive character remains selectable")
		var other: Dictionary=read(account.path)
		var unresolved: Dictionary=other.card_option_awakening.native_relic_summon_time
		check(unresolved.identity==relic_b and unresolved.expires_utc==0 and unresolved.legacy_deadline_unresolved==true,"v1: inactive expiry explicitly unresolved and effects fail closed")
		check(other.card_option_awakening.native_relic_unlock.preserve=="B","v1: unresolved migration preserves original unlock and selection")
		check(account.select_character(first.id).ok and same(read(account.path).card_option_awakening.native_relic_summon_time,timer),"v1: second character cannot replace first timer")
	# Genuine untimed v1 selections are not assigned a fabricated deadline.
	var untimed = fresh("v1-untimed")
	data.erase("card_option_awakening")
	data=old_account_fixture(data)
	for record: Dictionary in data[STORE.KEY].characters:
		record.state["card_option_awakening"]={"native_relic_subslot_identity":relic_a}
	data["card_option_awakening"]={"native_relic_subslot_identity":relic_a}
	for record: Dictionary in data[STORE.KEY].characters:
		if record.id==data[STORE.KEY].selected: record.state=STORE._private_fields(data,STORE.LEGACY_PRIVATE_OPTION)
	check(WRITER.write(untimed.path,data)==OK and untimed.open().get("upgrade",false),"untimed v1: fixture opens for explicit upgrade")
	var untimed_upgrade: Dictionary=untimed.upgrade_account()
	check(untimed_upgrade.ok and untimed_upgrade.get("unresolved_timers")==0,"untimed v1: no inferred timed mode")
	if untimed_upgrade.ok:
		for record: Dictionary in read(untimed.path)[STORE.KEY].characters:
			check(not record.state.card_option_awakening.has("native_relic_summon_time"),"untimed v1: original untimed selection preserved")
	# Validate v1's old partition before attempting to redistribute fields.
	var malformed = fresh("v1-bad-partition")
	var bad: Dictionary=data.duplicate(true)
	bad[STORE.KEY].characters[1].state.card_option_awakening["native_relic_summon_time"]=timer.duplicate(true)
	check(WRITER.write(malformed.path,bad)==OK,"v1 malformed: write isolated invalid old partition")
	var malformed_sha: String=FileAccess.get_sha256(malformed.path)
	check(not malformed.open().ok and not malformed.upgrade_account().ok and FileAccess.get_sha256(malformed.path)==malformed_sha,"v1 malformed: private timer cannot be accepted as valid old state or rewritten")
	var bad_timer = fresh("v1-bad-timer")
	bad=data.duplicate(true);bad.card_option_awakening["native_relic_summon_time"]=timer.duplicate(true);bad.card_option_awakening.native_relic_summon_time.slot_index=12
	for record: Dictionary in bad[STORE.KEY].characters:
		if record.id==bad[STORE.KEY].selected: record.state=STORE._private_fields(bad,STORE.LEGACY_PRIVATE_OPTION)
	check(WRITER.write(bad_timer.path,bad)==OK and bad_timer.open().get("upgrade",false),"v1 malformed timer: old structural account remains read-only")
	malformed_sha=FileAccess.get_sha256(bad_timer.path)
	check(not bad_timer.upgrade_account().ok and FileAccess.get_sha256(bad_timer.path)==malformed_sha,"v1 malformed timer: refuse invented repairs and preserve bytes")
	# Identity mismatch cannot lend a selected timer to another character.
	var mismatched = fresh("v1-mismatched-timer")
	bad=data.duplicate(true);bad.card_option_awakening["native_relic_summon_time"]=timer.duplicate(true);bad.card_option_awakening.native_relic_summon_time.identity=relic_b
	for record: Dictionary in bad[STORE.KEY].characters:
		if record.id==bad[STORE.KEY].selected: record.state=STORE._private_fields(bad,STORE.LEGACY_PRIVATE_OPTION)
	check(WRITER.write(mismatched.path,bad)==OK and mismatched.open().get("upgrade",false),"v1 mismatched timer: old account remains explicitly upgradeable")
	var mismatch_result: Dictionary=mismatched.upgrade_account()
	check(mismatch_result.ok and mismatch_result.get("unresolved_timers")==2,"v1 mismatched timer: neither character receives an invented historical expiry")
	if mismatch_result.ok:
		var mismatch_payload: Dictionary=read(mismatched.path)
		check(mismatch_payload.card_option_awakening.native_relic_summon_time.identity==relic_a and mismatch_payload.card_option_awakening.native_relic_summon_time.expires_utc==0,"v1 mismatched timer: selected identity retained with inactive unresolved time")
		check(mismatch_payload[STORE.KEY].legacy_relic_timer_migration.historical_timer.identity==relic_b,"v1 mismatched timer: unmatched exact historical identity archived")
	var backup_collision = fresh("v1-backup-collision")
	check(WRITER.write(backup_collision.path,data)==OK and backup_collision.open().get("upgrade",false),"v1 backup collision: fixture ready")
	var upgrade_sha: String=FileAccess.get_sha256(backup_collision.path)
	check(WRITER.write_text(backup_collision.path+".pre-character-account-v2-"+upgrade_sha,"different original backup")==OK,"v1 backup collision: conflicting destination exists")
	check(not backup_collision.upgrade_account().ok and FileAccess.get_sha256(backup_collision.path)==upgrade_sha,"v1 backup collision: old account preserved without replacing existing backup")
	var stale_upgrade = fresh("v1-stale-upgrade")
	check(WRITER.write(stale_upgrade.path,data)==OK and stale_upgrade.open().get("upgrade",false),"v1 stale upgrade: observer opens")
	bad=data.duplicate(true);bad[STORE.KEY].revision=int(bad[STORE.KEY].revision)+1
	check(WRITER.write(stale_upgrade.path,bad)==OK,"v1 stale upgrade: another observer replaces valid account")
	upgrade_sha=FileAccess.get_sha256(stale_upgrade.path)
	check(not stale_upgrade.upgrade_account().ok and FileAccess.get_sha256(stale_upgrade.path)==upgrade_sha,"v1 stale upgrade: external replacement is never overwritten")
	var lost_upgrade = fresh("v1-lost-response")
	check(WRITER.write(lost_upgrade.path,data)==OK and lost_upgrade.open().get("upgrade",false),"v1 lost response: fixture ready")
	upgrade_sha=FileAccess.get_sha256(lost_upgrade.path)
	lost_upgrade.test_writer=func(target: String,candidate: Dictionary) -> Error:
		WRITER.write(target,candidate)
		return ERR_CANT_CREATE
	var lost_result: Dictionary=lost_upgrade.upgrade_account()
	check(lost_result.ok and FileAccess.get_sha256(lost_result.get("backup",""))==upgrade_sha,"v1 lost response: exact durable v2 bytes acknowledge one successful upgrade")
	check(lost_upgrade.open().ok and not lost_upgrade.open().get("upgrade",true),"v1 lost response: next open is canonical v2")
	check(not lost_upgrade.upgrade_account().ok,"v1 lost response: retry cannot create a second upgrade")
	run_cursor_regressions(catalog)
	run_allocator_regressions(catalog)
	STORE.session={}

func run_cursor_regressions(catalog: RefCounted) -> void:
	const OPTIONS=preload("res://scripts/maps/current523_aden_play_options.gd")
	var had_config: bool=FileAccess.file_exists(OPTIONS.PATH)
	var prior_config: String=FileAccess.get_file_as_string(OPTIONS.PATH) if had_config else ""
	# Pure configuration syntax fixture; no source media or original map claim.
	var cfg: Dictionary=OPTIONS.defaults()
	cfg.merge({"enabled":true,"navigation_profile":OPTIONS.GENERIC,"raw_root":"/unloaded-test/raw","tile_root":"/unloaded-test/tiles","source_manifest_sha256":"a".repeat(64),"tile_manifest_sha256":"b".repeat(64),"native_land_id":81,"source_position":[32700.25,32000.5]},true)
	check(OPTIONS.write(cfg)==OK,"legacy cursor: isolated valid config writes")
	for mode: String in ["missing","empty","existing"]:
		var store = fresh("cursor-"+mode)
		var original: Dictionary={"job_class":"기사","character_name":"원래이름","gold":321,"unknown_future":{"kept":true},"source_visual_context":{"snapshot":"base508","gender_id":1}}
		if mode=="empty": original["character_source_cursor"]={}
		if mode=="existing": original["character_source_cursor"]={"native_land_id":52,"source_position":[100.5,101.25]}
		check(OPTIONS.write(cfg)==OK and WRITER.write(store.path,original)==OK and store.open().legacy,"legacy cursor: "+mode+" fixture ready")
		var migrated: Dictionary=store.migrate_legacy()
		check(migrated.ok,"legacy cursor: "+mode+" migrated before second character")
		if not migrated.ok: continue
		var first: String=store.open().characters[0].id
		var expected: Dictionary=original.get("character_source_cursor",{})
		if expected.is_empty(): expected={"native_land_id":81,"source_position":cfg.source_position}
		check(same(read(store.path).character_source_cursor,expected),"legacy cursor: "+mode+" original native location captured or preserved")
		check(store.open().characters[0].name=="원래이름","legacy cursor: valid existing roster name preserved")
		var second: Dictionary=store.create_character("커서둘째",2,2,catalog)
		check(second.ok and store.select_character(second.id).ok,"legacy cursor: second enters before first World load")
		var other_cfg: Dictionary=cfg.duplicate(true);other_cfg.native_land_id=4;other_cfg.source_position=[33100.5,33500.5]
		check(OPTIONS.write(other_cfg)==OK and store.select_character(first).ok,"legacy cursor: second checkpoint then first selected")
		var saved: Dictionary=read(store.path)
		var restored: Dictionary=OPTIONS.read();restored.merge(saved.character_source_cursor,true)
		check(int(restored.native_land_id)==int(expected.native_land_id) and same(restored.source_position,expected.source_position),"legacy cursor: first does not inherit second device checkpoint")
		check(saved.gold==321 and saved.unknown_future.kept and saved.character_source_cursor.size()==2,"legacy cursor: progress preserved without private pack paths")
	var no_cfg = fresh("cursor-no-config")
	DirAccess.remove_absolute(OPTIONS.PATH)
	check(WRITER.write(no_cfg.path,{"job_class":"기사"})==OK and no_cfg.open().legacy and no_cfg.migrate_legacy().ok,"legacy cursor: missing config still migrates safely")
	check(same(read(no_cfg.path).character_source_cursor,{"native_land_id":4,"source_position":[]}),"legacy cursor: explicit default cannot inherit future device point")
	if had_config: WRITER.write_text(OPTIONS.PATH,prior_config)
	elif FileAccess.file_exists(OPTIONS.PATH): DirAccess.remove_absolute(OPTIONS.PATH)

func run_allocator_regressions(catalog: RefCounted) -> void:
	for mode: String in ["missing","stale","ahead"]:
		var store = fresh("allocator-"+mode)
		var legacy: Dictionary={"job_class":"기사","item_instances":{"100":{"name":"보존검"}},"inventory":{"보존검":1},"ground_drops":[{"physical_item":{"id":"200","data":{"name":"보존바닥"}}}],"death_recovery523":{"records":[{"item":{"id":"300"}}]},"warehouse":{"stacks":{},"instances":{"400":{"name":"보존창고"}}},"equipment_collections":{"receipts":{"500":{"preserved":true}}}}
		if mode=="stale":legacy["next_item_instance_id"]=1
		if mode=="ahead":legacy["next_item_instance_id"]=900
		check(WRITER.write(store.path,legacy)==OK and store.open().legacy and store.migrate_legacy().ok,"allocator: "+mode+" legacy migrates")
		var data: Dictionary=read(store.path)
		var expected: int=900 if mode=="ahead" else 501
		check(int(data.next_item_instance_id)==expected and int(data[STORE.KEY].shared.next_item_instance_id)==expected,"allocator: all legacy bag/floor/death/warehouse/collection IDs reserve shared sequence")
		var second: Dictionary=store.create_character("할당둘째",2,2,catalog)
		check(second.ok and store.select_character(second.id).ok,"allocator: alternate character selected before first World loads")
		data=read(store.path)
		check(int(data.next_item_instance_id)==expected,"allocator: inactive first character reservation retained")
		# A newly received high numeric ID is included before the trusted owner save.
		data["item_instances"]={"700":{"name":"새개체"}}
		data["inventory"]={"새개체":1}
		check(commit(store.path,data,"allocator new owner"),"allocator: selected candidate seals new physical ID")
		data=read(store.path)
		check(int(data.next_item_instance_id)>=701 and int(data[STORE.KEY].shared.next_item_instance_id)>=701,"allocator: staged owner allocation advances canonical counter")
