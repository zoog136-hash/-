extends SceneTree
## Direct private pack recovery/decoder checks; no network or personal-save access.
const PACK = preload("res://scripts/resources/current523_identity_pack.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): path = argument.trim_prefix("--pack=")
	if path.is_empty(): printerr("Authorized --pack and isolated XDG profile required"); quit(2); return
	var source_sha: String = FileAccess.get_sha256(path)
	var installer := PACK.new()
	root.add_child(installer)
	var result: Dictionary = await installer.install_zip(path)
	check(result.ok,"officially received exact ZIP installs in fresh consumer profile")
	if not result.ok: finish(); return
	var options: Dictionary = PACK.options()
	options.root = result.root
	options.enabled = true
	check(PACK.save_options(options).ok,"fresh consumer activates hash-verified identity subset")
	var manifest: Dictionary = PACK.manifest_at(str(result.root))
	check(manifest.members.size() == 328 and manifest.actors.size() == 26 and manifest.cards.size() == 26,"final subset counts")
	var sampled: int = 0
	var source_records: int = 0
	for member: String in manifest.members:
		var spec: Dictionary = manifest.members[member]
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(str(result.root).path_join(str(spec.path)))
		check(bytes.size() == int(spec.bytes) and preload("res://scripts/resources/current523_pack.gd").digest(bytes) == spec.sha256,"actual installed original hash " + member)
		var parsed: Dictionary = DECODER.parse(bytes)
		check(parsed.ok,"bounded Godot parse of every required source " + member)
		if not parsed.ok: continue
		for group_index: int in range(parsed.groups.size()):
			var group: Dictionary = parsed.groups[group_index]
			source_records += group.frames.size()
			if group.frames.is_empty(): continue
			var indices: Array = [0] if group.frames.size() == 1 else [0,group.frames.size()-1]
			for index: int in indices:
				var layer: Dictionary = {"member":member,"group_bit":int(group.bit),"frame_index":index}
				var shown: Dictionary = PACK.render_layer(layer,options)
				check(shown.ok,"first/last stored source frame renders " + member + "/" + str(group.bit) + "/" + str(index))
				if shown.ok:
					check(shown.image != null and not shown.image.is_empty() and shown.offset == group.frames[index].bounds.position,"source frame bounds/origin preserved " + member)
				sampled += 1
		await process_frame
	var profiles: int = 0
	for key: String in manifest.cards:
		var selected: Dictionary = PACK.load_actor(key,{"class_id":1,"gender_id":1,"source_weapon_type":0})
		check(selected.ok,"actual canonical card ID selects pinned source root " + key)
		if not selected.ok: continue
		var raw_actor: Dictionary = manifest.actors["sprite:" + str(int(selected.actor.source_sprite_id))]
		for weapon: String in raw_actor.get("weapon_profiles",{}):
			var loaded: Dictionary = PACK.load_actor(key,{"class_id":1,"gender_id":1,"source_weapon_type":int(weapon)})
			check(loaded.ok and int(loaded.actor.get("source_weapon_type",-1)) == int(weapon),"exact weapon context expands " + key + "/" + weapon)
			if loaded.ok: check(PACK.validate_actor_files(loaded.actor).ok,"every expanded selected member is present " + key + "/" + weapon)
			profiles += 1
		check(not PACK.load_actor(key,{"class_id":1,"gender_id":1,"source_weapon_type":3}).ok,"unproved bow alter-mode never borrows generic/sword bank " + key)
	check(profiles == 304,"all304 supported compact weapon profiles consumed")
	check(not PACK.load_actor("transform:m508:1:999999",{}).ok,"foreign card cannot reuse similar numbered source")
	check(not PACK.load_actor("doll:m508:2:161",{}).ok,"other consumer namespace cannot reuse transformation")
	var before: Dictionary = PACK.options()
	var missing: Dictionary = before.duplicate(true)
	missing.root = "user://current523_identity_versions/pack-missing"
	check(not PACK.save_options(missing).ok and PACK.options() == before,"missing pack selection preserves previous active root")
	check(FileAccess.get_sha256(path) == source_sha,"consumption preserves original Drive ZIP bytes")
	print("CURRENT523_IDENTITY_PACK_COVERAGE ",JSON.stringify({"members":manifest.members.size(),"source_records":source_records,"sampled_first_last_records":sampled,"weapon_profiles":profiles,"installed_root":result.root}))
	installer.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("CURRENT523_IDENTITY_PACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"REAL328_RAW_FILES_STRUCTURAL_PARSE_FIRST_LAST_RENDER_AND304_WEAPON_PROFILES; NOT_ALL_FRAME_VISUAL_EQUIVALENCE"}))
	quit(0 if failures.is_empty() else 1)
