extends SceneTree
## Synthetic merge/atomic extension storage guards; not a source or Main audit.
const Store = preload("res://scripts/equipment523/pack_store.gd")
const C = preload("res://scripts/equipment523/common.gd")
const BASE_SHA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	var base: Dictionary = {"tables":{"BuffClass":[{"ID":11,"Name":"synthetic"}]},"bonuses":{},"_indexes":{"stale":true}}
	var extension: Dictionary = {"schema":Store.EFFECT_SCHEMA,"base_sha256":BASE_SHA,"source_sha256":C.SOURCE_SHA,"tables":{"BuffClass":[{"ID":11,"Name":"synthetic"},{"ID":12,"Name":"new synthetic"}],"BonusApplicationType":[{"ID":0,"Name":"Character"}]},"bonuses":{},"audit":{"scope":"synthetic merge guards"}}
	var before: String = JSON.stringify(base)
	var merged: Dictionary = Store.merge_effects(base,BASE_SHA,extension)
	check(merged.get("ok",false) and merged.pack.tables.BuffClass.size() == 2,"exact same-ID input is retained once and a new effect row is added")
	check(not merged.pack.has("_indexes") and JSON.stringify(base) == before,"merge clears transient indexes and preserves the original base object")
	check(merged.pack.tables.BonusApplicationType[0].ID == 0,"original definition ID0 is preserved in its own namespace")
	for field: String in ["schema","base_sha256","source_sha256"]:
		var bad: Dictionary = extension.duplicate(true)
		bad[field] = "wrong"
		check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"incorrect envelope "+field+" is refused")
	var bad: Dictionary = extension.duplicate(true)
	bad.tables.ItemSet = [{"ID":12}]
	check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"an effect extension cannot alter equipment membership or activation rules")
	bad = extension.duplicate(true)
	bad.tables.BuffClass[0].Name = "changed"
	check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"a conflicting original row is refused")
	bad = extension.duplicate(true)
	bad.tables.BuffClass.append(bad.tables.BuffClass[1].duplicate(true))
	check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"duplicate row IDs are refused")
	for identity: Variant in [0,-1,1.5,"12",true]:
		bad = extension.duplicate(true)
		bad.tables.BuffClass[1].ID = identity
		check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"active effect IDs cannot be coerced, fractional or zero")
	bad = extension.duplicate(true)
	bad.bonuses["44"] = {"raw":{"ID":45},"type":{"Name":"synthetic"}}
	check(not Store.merge_effects(base,BASE_SHA,bad).get("ok",false),"bonus keys must match the typed raw Bonus namespace")
	var store = Store.new()
	store.base_pack = base
	store.pack = base
	var fixture_path: String = "user://synthetic-base.json"
	var fixture_file: FileAccess = FileAccess.open(fixture_path,FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify(base))
	fixture_file.close()
	var live_sha: String = FileAccess.get_sha256(fixture_path)
	extension.base_sha256 = live_sha
	store.sha256 = live_sha
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Store.ROOT+"/"+live_sha))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(fixture_path),ProjectSettings.globalize_path(Store.ROOT+"/"+live_sha+"/rules.json"))
	fixture_file = FileAccess.open(Store.POINTER,FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify({"sha256":live_sha}))
	fixture_file.close()
	var path: String = "user://synthetic-effect-extension.json"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(extension))
	file.close()
	var digest: String = FileAccess.get_sha256(path)
	check(store.install(path,digest).get("ok",false),"the existing installation API recognizes an effect extension")
	check(store.sha256 == live_sha and store.effects_sha256 == digest and JSON.stringify(base) == before,"install preserves the existing cache identity and raw base")
	var saved: String = FileAccess.get_sha256(Store.ROOT+"/"+live_sha+"/effects-active.json")
	var reopened = Store.new()
	reopened.base_pack = base
	reopened.pack = base
	reopened.sha256 = live_sha
	reopened._load_installed_effects()
	check(reopened.effects_sha256 == digest and reopened.pack.tables.BuffClass.size() == 2,"reopened storage restores the installed effect file through its own pointer")
	bad = extension.duplicate(true)
	bad.base_sha256 = "wrong"
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	check(not store.install(path,FileAccess.get_sha256(path)).get("ok",false) and store.effects_sha256 == digest,"a failed replacement retains the loaded valid extension")
	check(FileAccess.get_sha256(Store.ROOT+"/"+live_sha+"/effects-active.json") == saved,"failed validation does not rewrite the durable activation pointer")
	print("EQUIPMENT523_EFFECT_STORE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_EXTENSION_STORAGE_GUARDS"}))
	quit(0 if failures.is_empty() else 1)
