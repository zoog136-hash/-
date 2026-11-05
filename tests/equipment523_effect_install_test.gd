extends SceneTree
## Opt-in actual private files. Run each phase in the same isolated XDG profile.
const Store = preload("res://scripts/equipment523/pack_store.gd")
const BASE_SHA = "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
const PROOF = "user://equipment523-effects-install-proof.json"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var store = Store.new()
	if "--effects-reload" in OS.get_cmdline_user_args():
		var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
		check(proof is Dictionary,"previous isolated installation proof exists")
		if not proof is Dictionary:
			finish("FRESH_PROCESS_PRIVATE_EFFECT_INSTALL")
			return
		check(store.startup().get("ok",false),"new process loads the installed base pointer")
		check(store.sha256 == BASE_SHA and store.effects_sha256 == proof.effects_sha256,"new process loads both private files without cache CLI paths")
		check(store.base_pack.tables.BuffClass.size() == 1 and store.pack.tables.BuffClass.size() == 14 and store.pack.tables.BuffBonus.size() == 38,"new process reconstructs every missing buff without changing the base")
		check(FileAccess.get_sha256(Store.ROOT+"/"+BASE_SHA+"/rules.json") == BASE_SHA,"durable original base cache bytes are preserved")
		finish("FRESH_PROCESS_PRIVATE_EFFECT_INSTALL")
		return
	var base_path: String = ""
	var effects_path: String = ""
	var effects_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): base_path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-effects="): effects_path = arg.trim_prefix("--equipment523-effects=")
		if arg.begins_with("--equipment523-effects-sha256="): effects_sha = arg.trim_prefix("--equipment523-effects-sha256=")
	check(store.load_verified(base_path,BASE_SHA).get("ok",false),"original transferred cache loads unchanged")
	if store.pack.is_empty():
		finish("PRIVATE_FILES_INSTALL")
		return
	check(not store.install(effects_path,effects_sha).get("ok",false),"read-only base loading cannot masquerade as durable base installation")
	check(store.install(base_path,BASE_SHA).get("ok",false),"original base installs through the production store")
	check(store.install(effects_path,effects_sha).get("ok",false),"scoped effect graph installs against the matching base")
	check(store.sha256 == BASE_SHA and store.effects_sha256 == effects_sha,"original base identity is kept alongside the supplement")
	check(store.pack.tables.ItemInvokeReplacementBonus.size() == 974 and store.pack.tables.ItemSetBonus.size() == 228,"original selection and set tables retain their complete row counts")
	check(store.base_pack.tables.BuffClass.size() == 1 and store.pack.tables.BuffClass.size() == 14 and store.pack.tables.BuffBonus.size() == 38,"missing gameplay rows are appended only to the runtime view")
	check(FileAccess.get_sha256(base_path) == BASE_SHA and FileAccess.get_sha256(Store.ROOT+"/"+BASE_SHA+"/rules.json") == BASE_SHA,"source and installed base bytes remain exactly unchanged")
	check(FileAccess.get_sha256(Store.ROOT+"/"+BASE_SHA+"/effects/"+effects_sha+".json") == effects_sha,"durable supplement bytes match their independently supplied hash")
	var file: FileAccess = FileAccess.open(PROOF,FileAccess.WRITE)
	check(file != null,"isolated proof opens")
	if file != null:
		file.store_string(JSON.stringify({"base_sha256":BASE_SHA,"effects_sha256":effects_sha}))
		file.close()
	finish("PRIVATE_FILES_INSTALL")

func finish(scope: String) -> void:
	print("EQUIPMENT523_EFFECT_INSTALL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":scope}))
	quit(0 if failures.is_empty() else 1)
