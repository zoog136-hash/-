extends SceneTree
## The account save keeps the selected character's state once (user
## 2026-11-19 "쓸데없이 비용만 차지하는 데이터 다 삭제"): the flat body is that
## state, so characters[selected].state is a marker on disk and expand()
## restores private_fields(body) before validate(). Older full files still
## open; a tampered marker is rejected; the lobby store reads, writes and
## switches characters with the same states as before.
const STORE = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeCatalog extends RefCounted:
	var problem: String = ""
	func profile(id: int, gender: int) -> Dictionary:
		return {"name":STORE.JOBS[id],"stats":{"str":16,"dex":13,"con":16,"int":8,"wis":7,"cha":8},"source":{"ID":id}} if STORE.JOBS.has(id) and gender in [1,2] else {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ACCOUNT_SELECTED_STATE_ONCE_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func parse(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func run() -> void:
	var base: String = "user://account-once-test-" + str(Time.get_ticks_usec())
	var store = STORE.new(); store.path = base + ".json"
	check(store.open().get("ok",false), "empty account opens")
	var catalog := FakeCatalog.new()
	var first: Dictionary = store.create_character("한번첫째",1,1,catalog)
	var second: Dictionary = store.create_character("한번둘째",3,2,catalog)
	check(first.get("ok",false) and second.get("ok",false) and store.select_character(first.id).get("ok",false), "two characters, first selected")
	# A big selected bag, as after a long hunt.
	var body: Dictionary = parse(store.path); STORE.expand(body)
	var items: Dictionary = {}
	for index: int in 200: items["%032x" % index] = {"name":"가죽","level":0,"record":{"name":"가죽","slot":"material","note":"x".repeat(40)}}
	body.item_instances = items; body.gold = 777; body.inventory = {"가죽":200}
	var staged: Dictionary = STORE.stage_save(store.path, body)
	check(staged.get("ok",false), "a selected-character save seals: %s" % str(staged.get("problem","")))
	if not staged.get("ok",false):
		finish(base); return
	var full_text: String = JSON.stringify(staged.payload,"",true,true)
	var compact: Dictionary = STORE.compact(staged.payload)
	check(compact != staged.payload and STORE.validate(staged.payload).is_empty(), "compact() returns a copy; the input stays valid")
	var compact_text: String = JSON.stringify(compact,"",true,true)
	evidence["bytes"] = {"full":full_text.length(),"compact":compact_text.length()}
	check(compact_text.length()*10 < full_text.length()*6, "the file loses the second copy of the selected state (%s)" % str(evidence.bytes))
	var selected_on_disk: Dictionary = {}
	for record: Dictionary in compact[STORE.KEY].characters:
		if record.id == compact[STORE.KEY].selected: selected_on_disk = record
	check(selected_on_disk.state == {STORE.SELECTED_IN_BODY:true}, "only a marker in the selected record")
	var reread: Dictionary = JSON.parse_string(compact_text)
	STORE.expand(reread)
	check(STORE.validate(reread).is_empty(), "expanded file validates")
	check(JSON.stringify(reread,"",true,true) == JSON.stringify(JSON.parse_string(full_text),"",true,true), "expand(compact) is exactly the sealed payload")
	check(STORE.dormant_items(reread).is_empty() and reread.gold == 777, "dormant items exclude the selected bag; body unchanged")
	var old_full: Dictionary = JSON.parse_string(full_text); STORE.expand(old_full)
	check(STORE.validate(old_full).is_empty(), "an older full file still validates (expand is a no-op)")
	var tampered: Dictionary = JSON.parse_string(compact_text)
	for record: Dictionary in tampered[STORE.KEY].characters:
		if record.id == tampered[STORE.KEY].selected: record.state = {STORE.SELECTED_IN_BODY:true,"gold":1}
	STORE.expand(tampered)
	check(not STORE.validate(tampered).is_empty(), "a marker with extra fields is not trusted")
	var unexpanded: Dictionary = JSON.parse_string(compact_text)
	check(not STORE.validate(unexpanded).is_empty(), "an unexpanded compact file is never accepted as is")
	# Durable store round trip: write the compact form, then lobby reads/switches.
	check(WRITER.write(store.path, compact) == OK, "compact file written")
	var listed: Dictionary = store.open()
	check(listed.get("ok",false) and listed.get("characters",[]).size() == 2, "lobby lists both characters from the compact file")
	check(store.select_character(second.id).get("ok",false), "switch to the second character")
	var switched: Dictionary = parse(store.path)
	var first_record: Dictionary = {}
	for record: Dictionary in switched[STORE.KEY].characters:
		if record.id == first.id: first_record = record
	check(first_record.get("state",{}).get("item_instances",{}).size() == 200 and int(first_record.state.get("gold",0)) == 777, "the first character's bag is kept in its record after switching")
	check(switched[STORE.KEY].characters.filter(func(r: Dictionary) -> bool: return r.id == second.id)[0].state == {STORE.SELECTED_IN_BODY:true}, "the new selection is stored once")
	STORE.expand(switched)
	check(STORE.validate(switched).is_empty() and switched.get("item_instances",{}).size() == 0, "switched file validates; body is the second character")
	check(store.select_character(first.id).get("ok",false), "switch back")
	var back: Dictionary = parse(store.path); STORE.expand(back)
	check(STORE.validate(back).is_empty() and back.item_instances.size() == 200 and back.gold == 777 and back.inventory == {"가죽":200}, "switching back restores the same bag, gold and counts")
	finish(base)

func finish(base: String) -> void:
	STORE.session.clear()
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with(base.get_file()): DirAccess.remove_absolute(directory.path_join(name))
	print("ACCOUNT_SELECTED_STATE_ONCE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
