extends SceneTree
## Cooks 523 NPC actors from an extracted original 523 resource pack into the
## cooked actor format (scripts/resources/cooked_actor_format.gd).
##
## Runs in CI only (zoog136-hash/Twm .github/workflows/cook-actors.yml) with
## the official Godot 4.7.2 editor binary, never on the phone:
##   godot --headless --path <game repo> --script res://tools/cook/cook_actors.gd -- \
##     --pack=<dir with source523_pack.json> --out=<dir> [--shard=I --shards=N]
##     [--limit=K] [--actors=1,2] [--lossless]
## Writes <out>/<FORMAT_TAG>/actors/npc_<sprite>.twca and <out>/report-<I>.json.
##
## Pixels come from the existing runtime renderer (original_source_preview.gd
## + reference_sp2_bank.gd) on the Android copy-free path, so originals are
## verified here once: the bank manifest pin, the tables pin and every SP2
## member's SHA-256 as the runtime bank checks them. Nothing original is
## written except the cooked derivative, which goes only to the private Twm
## release and to the phone's user:// storage.
const PACK = preload("res://scripts/boot/source523_pack.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const SELECTION = preload("res://scripts/monsters/current523_source_bank_selection.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const COOKER = preload("res://scripts/resources/cooked_actor_cooker.gd")
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const GPU_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const COMPOSITES = preload("res://scripts/resources/actor_frame_composite_cache.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")

func _initialize() -> void: call_deferred("run")

func argument(prefix: String, fallback: String) -> String:
	for item: String in OS.get_cmdline_user_args():
		if item.begins_with(prefix): return item.trim_prefix(prefix)
	return fallback

func finish(report: Dictionary, path: String, code: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t", true))
		file.close()
	var summary: Dictionary = report.duplicate()
	summary.erase("actors")
	print("COOK_ACTORS_RESULT " + JSON.stringify(summary))
	quit(code)

func run() -> void:
	var started: int = Time.get_ticks_msec()
	var base: String = argument("--pack=", "")
	var out: String = argument("--out=", "")
	var shard: int = int(argument("--shard=", "0"))
	var shards: int = maxi(1, int(argument("--shards=", "1")))
	var limit: int = int(argument("--limit=", "0"))
	var lossless: bool = "--lossless" in OS.get_cmdline_user_args()
	var verify_count: int = int(argument("--verify=", "25"))
	var report: Dictionary = {"format":FORMAT.FORMAT,"shard":shard,"shards":shards,"lossless":lossless,"engine":Engine.get_version_info().string,"actors":{},"failures":[]}
	var report_path: String = out.path_join("report-%d.json" % shard)
	if base.is_empty() or out.is_empty():
		report.failures.append("usage: --pack=<dir> --out=<dir>")
		finish(report, "user://cook_report.json", 2)
		return
	# The phone's path: no screen copy, uncompressed runtime layer textures,
	# and never a cooked actor as input.
	STORE.disabled = true
	COMPOSITOR.screen_copy_available = false
	GPU_TEXTURE.enabled = false
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	if not read.ok:
		report.failures.append("descriptor: " + str(read.reason))
		finish(report, report_path, 2)
		return
	var selected_pack: Dictionary = PACK.selections(base, read.descriptor)
	var bank_options: Dictionary = selected_pack.bank
	# The phone's reader configuration (source523_pack.gd apply()): the shared
	# column-packed definition rows read the same pinned tables ZIP.
	for key: String in selected_pack.environment: OS.set_environment(key, str(selected_pack.environment[key]))
	# Cook-time verification of the originals' pins (members are verified by
	# the bank on every render below).
	var manifest_sha: String = FileAccess.get_sha256(str(bank_options.manifest_path))
	var tables_sha: String = FileAccess.get_sha256(str(bank_options.tables_zip))
	report["source_pack_id"] = read.descriptor.pack_id
	report["bank_manifest_sha256"] = manifest_sha
	report["tables_sha256"] = tables_sha
	if manifest_sha != str(bank_options.manifest_sha256) or tables_sha != SOURCE.TABLES_SHA:
		report.failures.append("original pins differ: manifest=%s tables=%s" % [manifest_sha, tables_sha])
		finish(report, report_path, 3)
		return
	var context: Dictionary = {"current523_source_bank":bank_options}
	var tables: Dictionary = SOURCE.source_tables(context)
	if not tables.ok:
		report.failures.append("tables: " + str(tables.get("reason", "")))
		finish(report, report_path, 3)
		return
	var kinds: PackedStringArray = argument("--kinds=", "npc,class,transform,effect").split(",")
	var jobs: Array = build_jobs(kinds, context, bank_options)
	report["job_counts"] = _job_counts(jobs)
	report["effect_selection_rejections"] = _effect_reasons
	var only: String = argument("--actors=", "")
	if not only.is_empty():
		var wanted: PackedStringArray = only.split(",")
		jobs = jobs.filter(func(job: Dictionary) -> bool: return str(job.sprite) in wanted)
	var mine: Array = []
	for index: int in range(jobs.size()):
		if index % shards == shard: mine.append(jobs[index])
	if limit > 0 and mine.size() > limit:
		# A trial samples every kind: evenly spaced jobs of this shard.
		var sampled: Array = []
		for index: int in range(limit): sampled.append(mine[int(float(index) * mine.size() / limit)])
		mine = sampled
	report["jobs_total"] = jobs.size()
	report["jobs_in_shard"] = mine.size()
	var compress: int = -1 if lossless else Image.COMPRESS_ETC2
	var verification: Dictionary = {"actors":0,"failed":0,"steps":0,"items":0,"exact_items":0,"etc2_items":0,"etc2_max_error":0,"etc2_psnr_db_min":99.0}
	var totals: Dictionary = {"cooked":0,"failed":0,"bytes":0,"gpu_bytes":0,"states":0,"images":0,"samples":0,"resampled_child_tracks":0}
	var by_kind: Dictionary = {}
	var verified_kinds: Dictionary = {}
	var host := Node2D.new()
	root.add_child(host)
	var count: int = 0
	for job: Dictionary in mine:
		count += 1
		var actor_started: int = Time.get_ticks_msec()
		var entry: Dictionary = cook_job(host, job, lossless, compress, out, int(verified_kinds.get(job.kind, 0)) < verify_count)
		if entry.has("verify"): verified_kinds[job.kind] = int(verified_kinds.get(job.kind, 0)) + 1
		entry["msec"] = Time.get_ticks_msec() - actor_started
		entry["kind"] = job.kind
		report.actors[job.label] = entry
		var kind_totals: Dictionary = by_kind.get(job.kind, {"cooked":0,"failed":0,"bytes":0,"gpu_bytes":0,"msec":0})
		kind_totals.msec += entry.msec
		if entry.has("verify"):
			verification.actors += 1
			for field: String in ["steps","items","exact_items","etc2_items"]: verification[field] += int(entry.verify.get(field, 0))
			verification.etc2_max_error = maxi(verification.etc2_max_error, int(entry.verify.get("etc2_max_error", 0)))
			verification.etc2_psnr_db_min = minf(verification.etc2_psnr_db_min, float(entry.verify.get("etc2_psnr_db", 99.0)))
			if not entry.verify.ok: verification.failed += 1
		if entry.ok:
			totals.cooked += 1
			kind_totals.cooked += 1
			kind_totals.bytes += int(entry.bytes)
			kind_totals.gpu_bytes += int(entry.gpu_bytes)
			for field: String in ["bytes","gpu_bytes","states","images","samples","resampled_child_tracks"]: totals[field] += int(entry.get(field, 0))
		else:
			totals.failed += 1
			kind_totals.failed += 1
		by_kind[job.kind] = kind_totals
		# Bounded process memory across thousands of actors.
		ASSETS.reset_for_tests()
		COMPOSITES.reset_for_tests()
		PREPARED.clear()
		if count % 50 == 0:
			BANK.forget_member_meta()
			print("COOK_PROGRESS %d/%d cooked=%d failed=%d bytes=%d msec=%d" % [count, mine.size(), totals.cooked, totals.failed, totals.bytes, Time.get_ticks_msec() - started])
		await process_frame
	report["by_kind"] = by_kind
	report["totals"] = totals
	report["verification"] = verification
	report["msec"] = Time.get_ticks_msec() - started
	finish(report, report_path, 0)

const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const OVERLAY_LOOPS := {"spell":false,"invoke":false,"item":false,"global":false,"death":false,"ammo_flight":true,"ammo_explosion":false}

func _job_counts(jobs: Array) -> Dictionary:
	var out: Dictionary = {}
	for job: Dictionary in jobs: out[job.kind] = int(out.get(job.kind, 0)) + 1
	return out

## Every runtime request the cooked pack answers, in a fixed order.
## selection jobs: exactly what _configure_selected_roles receives;
## request jobs: exactly what _configure_reference_bank receives.
func build_jobs(kinds: PackedStringArray, context: Dictionary, options: Dictionary) -> Array:
	var jobs: Array = []
	var seen: Dictionary = {}
	var add := func(job: Dictionary) -> void:
		var key: String = var_to_str(job.inputs)
		if seen.has(key): return
		seen[key] = true
		jobs.append(job)
	print("COOK_JOBS before npc %d msec=%d" % [jobs.size(), Time.get_ticks_msec()])
	if "npc" in kinds:
		var sprites: Dictionary = {}
		for row: Dictionary in SOURCE.table_rows("NpcClass"):
			if row.get("TestNPC") == false and BANK.integer(row.get("Sprite"), 1): sprites[int(row.Sprite)] = true
		var ids: Array = sprites.keys()
		ids.sort()
		for sprite: int in ids:
			var selected: Dictionary = SELECTION.cook_selection(sprite, context)
			if selected.ok: add.call({"kind":"npc","sprite":sprite,"label":"npc:%d" % sprite,"selected":selected,"inputs":STORE.selection_inputs(selected)})
	print("COOK_JOBS before class %d msec=%d" % [jobs.size(), Time.get_ticks_msec()])
	if "class" in kinds:
		SOURCE.source_tables(context, ["Class","Gender"])
		for row: Dictionary in SOURCE.table_rows("Class"):
			if not BANK.integer(row.get("ID"), 1): continue
			for gender: int in [1, 2]:
				for weapon: int in SOURCE.PRIMARY_ACTIONS.keys():
					var class_context: Dictionary = context.duplicate(true)
					class_context.merge({"class_id":int(row.ID),"gender_id":gender,"source_weapon_type":weapon})
					var selected: Dictionary = SOURCE.select_class(class_context)
					if selected.get("ok", false): add.call({"kind":"class","sprite":int(selected.sprite_id),"label":"class:%d:%d:%d" % [int(row.ID), gender, weapon],"selected":selected,"inputs":STORE.selection_inputs(selected)})
	print("COOK_JOBS before transform %d msec=%d" % [jobs.size(), Time.get_ticks_msec()])
	if "transform" in kinds:
		var sprites: Dictionary = {}
		for row: Dictionary in SOURCE.table_rows("PolymorphEntity"):
			if BANK.integer(row.get("SpriteID"), 1): sprites[int(row.SpriteID)] = true
		var ids: Array = sprites.keys()
		ids.sort()
		for sprite: int in ids:
			for weapon: int in SOURCE.PRIMARY_ACTIONS.keys():
				if not _actor_has(options, sprite, SOURCE.PRIMARY_ACTIONS[weapon].values()): continue
				var selected: Dictionary = SOURCE.card_visual_selection("transform", sprite, weapon, options)
				if selected.ok: add.call({"kind":"transform","sprite":sprite,"label":"transform:%d:%d" % [sprite, weapon],"selected":selected,"inputs":STORE.selection_inputs(selected)})
	print("COOK_JOBS before effect %d msec=%d" % [jobs.size(), Time.get_ticks_msec()])
	if "effect" in kinds:
		var effect_reasons: Dictionary = {}
		for pair: Array in effect_sprites(context):
			# The runtime effect selection itself (sole/declared action in the
			# bank's complete original action domain); what it rejects is
			# never shown at runtime either, so it is not cooked.
			var action: Dictionary = EFFECT._action(options, int(pair[1]), int(pair[2]))
			if not action.get("ok", false):
				effect_reasons[str(action.get("reason", ""))] = int(effect_reasons.get(str(action.get("reason", "")), 0)) + 1
				continue
			var bindings: Dictionary = {"idle":int(action.action_id)}
			var loops: Dictionary = {"idle":bool(OVERLAY_LOOPS.get(pair[0], false))}
			var mode_override: String = POLICY.mode(str(options.manifest_path).get_base_dir()) if str(pair[0]).begins_with("ammo") else ""
			add.call({"kind":"effect","sprite":int(pair[1]),"label":"effect:%s:%d:%d" % [pair[0], int(pair[1]), int(action.action_id)],
				"request":{"manifest_path":options.manifest_path,"sha":options.manifest_sha256,"sprite":int(pair[1]),"bindings":bindings,"loops":loops,"consumer":"overlay","override":mode_override},
				"inputs":STORE.request_inputs(str(options.manifest_path), str(options.manifest_sha256), int(pair[1]), bindings, loops, "overlay", {}, mode_override)})
		_effect_reasons = effect_reasons
	print("COOK_JOBS done %d msec=%d" % [jobs.size(), Time.get_ticks_msec()])
	return jobs

const POLICY = preload("res://scripts/animation/source_playback_policy.gd")

var _bank_actors: Dictionary = {}
var _effect_reasons: Dictionary = {}

func _actor_has(options: Dictionary, sprite: int, actions: Array) -> bool:
	if _bank_actors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(options.manifest_path)))
		_bank_actors = parsed.get("actors", {}) if parsed is Dictionary else {}
	var entries: Variant = _bank_actors.get("sprite:%d" % sprite)
	if not entries is Dictionary: return false
	for action: Variant in actions:
		if not entries.has(str(int(action))): return false
	return true

## [stage, sprite, explicit action or -1] of every original effect field the
## existing effect callers read (current523_source_effect_selection.gd).
func effect_sprites(context: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var push := func(stage: String, sprite: int, action: int) -> void:
		if sprite <= 0: return
		var key: String = "%s:%d:%d" % [stage, sprite, action]
		if seen.has(key): return
		seen[key] = true
		out.append([stage, sprite, action])
	SOURCE.source_tables(context, ["InvokeOption","ItemClass","ItemBonus","WeaponType","Class","Gender"])
	for row: Dictionary in SOURCE.table_rows("SpellClass"):
		if row.get("TestSpell") != false: continue
		for stage: String in EFFECT.STAGES:
			var field: String = EFFECT.STAGES[stage]
			var sprite: int = EFFECT._source_integer(row.get(field))
			push.call("spell", sprite, EFFECT._source_integer(row.get("EffectSpriteActionNo")) if field == "EffectSpriteID" else -1)
	for row: Dictionary in SOURCE.table_rows("InvokeOption"):
		if EFFECT._source_integer(row.get("InvokeOptionTypeID")) == 34: continue
		for field: String in ["TargetEffectSpriteID","AttackerEffectSpriteID"]: push.call("invoke", EFFECT._source_integer(row.get(field)), -1)
	for row: Dictionary in SOURCE.table_rows("ConstantData"):
		if row.get("Name") in EFFECT.GLOBALS.values(): push.call("global", EFFECT._source_integer(row.get("Value")), -1)
	for kind: Dictionary in SOURCE.table_rows("BonusType"):
		var name: String = str(kind.get("Name", ""))
		var stage: String = {"ItemConsumeEffectSpriteID":"item","AmmoEffectSpriteIDByWeapon":"ammo_flight","AmmoEffectSpriteID":"ammo_flight","AmmoExplosionSpriteID":"ammo_explosion"}.get(name, "")
		if stage.is_empty(): continue
		for bonus: Dictionary in SOURCE.table_where("Bonus", "BonusTypeID", int(kind.ID)): push.call(stage, EFFECT._source_integer(bonus.get("Value")), -1)
	for row: Dictionary in SOURCE.table_rows("WeaponType"):
		push.call("ammo_flight", EFFECT._source_integer(row.get("DefaultAmmoEffectSpriteID")), -1)
		push.call("ammo_explosion", EFFECT._source_integer(row.get("DefaultAmmoExplosionSpriteID")), -1)
	# Player death pose: the unique canonical death action on each class body.
	var death: Array = []
	for row: Dictionary in SOURCE.table_rows("ListSprAction"):
		if row.get("MotionType") == 5 and row.get("WeaponType") == 0 and row.get("WeaponAlterType") == 0: death.append(int(row.ID))
	if death.size() == 1:
		for row: Dictionary in SOURCE.table_rows("Class"):
			for field: String in ["MaleSpriteID","FemaleSpriteID"]: push.call("death", EFFECT._source_integer(row.get(field)), int(death[0]))
	return out

func cook_job(host: Node, job: Dictionary, lossless: bool, compress: int, out: String, verify_it: bool) -> Dictionary:
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = true
	host.add_child(preview)
	var entry: Dictionary = {}
	var configured: bool = false
	var resolved: Dictionary = {}
	if job.has("selected"):
		var selected: Dictionary = job.selected.duplicate(true)
		configured = preview._configure_selected_roles(selected, "idle")
		for field: String in ["role_actions","loop_policy","role_actor_ids","run_status","optional_role_status"]:
			if selected.has(field): resolved[field] = selected[field]
	else:
		var request: Dictionary = job.request
		preview.playback_mode_override = str(request.override)
		configured = preview._configure_reference_bank(str(request.manifest_path), str(request.sha), int(request.sprite), request.bindings, request.loops, "idle", str(request.consumer))
	if not configured:
		entry = {"ok":false,"error":"configure:" + str(preview.reference_bank_status.get("error", ""))}
		preview.free()
		return entry
	var cooked: Dictionary = COOKER.cook_preview(preview, job.inputs, lossless, resolved)
	preview.free()
	if not cooked.ok: return {"ok":false,"error":str(cooked.error)}
	var path: String = out.path_join(FORMAT.FORMAT_TAG).path_join(STORE.file_for(job.inputs))
	var written: Dictionary = COOKER.write_cooked(path, cooked, compress)
	if not written.ok: return {"ok":false,"error":str(written.error)}
	entry = {"ok":true,"bytes":written.bytes,"gpu_bytes":written.gpu_bytes,"roles":cooked.index.tracks.keys(),"file":STORE.file_for(job.inputs)}
	entry.merge(cooked.index.stats)
	if verify_it:
		entry["verify"] = verify_written(host, job, path, cooked.index.tracks.keys())
		if not entry.verify.ok:
			entry.ok = false
			entry["error"] = "verify:" + str(entry.verify.problems)
			DirAccess.remove_absolute(path)
	return entry

func verify_written(host: Node, job: Dictionary, path: String, roles: Array) -> Dictionary:
	var loaded: Dictionary = STORE.load_actor(path)
	if not loaded.ok: return {"ok":false,"problems":["load:" + str(loaded.error)]}
	var runtime: Node2D = PREVIEW.new()
	runtime.cached_frames = true
	host.add_child(runtime)
	var configured: bool = false
	if job.has("selected"):
		configured = runtime._configure_selected_roles(job.selected.duplicate(true), "idle")
	else:
		var request: Dictionary = job.request
		runtime.playback_mode_override = str(request.override)
		configured = runtime._configure_reference_bank(str(request.manifest_path), str(request.sha), int(request.sprite), request.bindings, request.loops, "idle", str(request.consumer))
	var result: Dictionary = {}
	if not configured:
		result = {"ok":false,"problems":["runtime configure"]}
	else:
		var cooked: Node2D = PREVIEW.new()
		host.add_child(cooked)
		var ok: bool = cooked._configure_cooked(loaded.actor, str(job.get("selected", job.get("request", {})).get("manifest_path", "")), "idle", "overlay", int(job.sprite))
		result = COOKER.verify(runtime, cooked, COOKER.verify_steps(roles, int(job.sprite))) if ok else {"ok":false,"problems":["cooked configure"]}
		cooked.free()
	runtime.free()
	return result
