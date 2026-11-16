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
	# Default: exact RGBA8 pages (zstd). Measured on the v2 trial: RGBA8+zstd
	# files are smaller than ASTC+zstd (sprite pages are mostly transparent;
	# block data barely compresses) and pixels stay identical to the runtime.
	# --block enables the ASTC 4x4 hybrid for GPU memory instead.
	var lossless: bool = not "--block" in OS.get_cmdline_user_args()
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
	var jobs: Array = build_jobs(kinds, context, bank_options, base)
	report["job_counts"] = _job_counts(jobs)
	report["job_filters"] = _filters
	report["effect_selection_rejections"] = _effect_reasons
	report["effect_domain_index"] = _effect_index_stats
	if shard == 0 and not _effect_index.is_empty():
		STORE.write_effect_index(out.path_join(FORMAT.FORMAT_TAG).path_join(STORE.EFFECT_INDEX), _effect_index)
	var only: String = argument("--actors=", "")
	if not only.is_empty():
		var wanted: PackedStringArray = only.split(",")
		jobs = jobs.filter(func(job: Dictionary) -> bool: return str(job.sprite) in wanted)
	# One bundle file per consumer body sprite: its entries share frames.
	var bundles: Dictionary = {}
	for job: Dictionary in jobs:
		var file: String = STORE.file_for(job.inputs)
		if not bundles.has(file): bundles[file] = []
		bundles[file].append(job)
	var files: Array = bundles.keys()
	var mine: Array = []
	for index: int in range(files.size()):
		if index % shards == shard: mine.append(files[index])
	if limit > 0 and mine.size() > limit:
		# A trial samples every kind: evenly spaced bundles of this shard.
		var sampled: Array = []
		for index: int in range(limit): sampled.append(mine[int(float(index) * mine.size() / limit)])
		mine = sampled
	report["jobs_total"] = jobs.size()
	report["bundles_total"] = files.size()
	report["bundles_in_shard"] = mine.size()
	var compress: int = -1 if lossless else Image.COMPRESS_ASTC
	var verification: Dictionary = {"entries":0,"failed":0,"steps":0,"items":0,"exact_items":0,"etc2_items":0,"etc2_max_error":0,"etc2_psnr_db_min":99.0}
	var totals: Dictionary = {"bundles":0,"entries":0,"failed_entries":0,"failed_bundles":0,"bytes":0,"gpu_bytes":0,"states":0,"images":0,"etc2_cells":0,"rgba8_cells":0,"etc2_rejected_psnr":0,"etc2_rejected_alpha":0,"etc2_psnr_min":99.0,"etc2_max_error":0}
	var by_kind: Dictionary = {}
	var verified_kinds: Dictionary = {}
	var failures: Dictionary = {}
	var host := Node2D.new()
	root.add_child(host)
	var count: int = 0
	for file: String in mine:
		count += 1
		var group: Array = bundles[file]
		var kind: String = group[0].kind
		var bundle_started: int = Time.get_ticks_msec()
		var verify_it: bool = int(verified_kinds.get(kind, 0)) < verify_count
		var result: Dictionary = cook_bundle(host, group, lossless, compress, out.path_join(FORMAT.FORMAT_TAG).path_join(file), verify_it)
		if verify_it: verified_kinds[kind] = int(verified_kinds.get(kind, 0)) + 1
		result["msec"] = Time.get_ticks_msec() - bundle_started
		result["kind"] = kind
		report.actors[file] = result
		var kind_totals: Dictionary = by_kind.get(kind, {"bundles":0,"entries":0,"failed_entries":0,"bytes":0,"gpu_bytes":0,"msec":0})
		kind_totals.msec += result.msec
		for problem: String in result.get("failures", {}):
			failures[problem] = int(failures.get(problem, 0)) + int(result.failures[problem])
		totals.failed_entries += int(result.get("failed_entries", 0))
		kind_totals.failed_entries += int(result.get("failed_entries", 0))
		for check: Dictionary in result.get("verify", []):
			verification.entries += 1
			for field: String in ["steps","items","exact_items","etc2_items"]: verification[field] += int(check.get(field, 0))
			verification.etc2_max_error = maxi(verification.etc2_max_error, int(check.get("etc2_max_error", 0)))
			verification.etc2_psnr_db_min = minf(verification.etc2_psnr_db_min, float(check.get("etc2_psnr_db", 99.0)))
			if not check.ok: verification.failed += 1
		if result.ok:
			totals.bundles += 1
			totals.entries += int(result.entries)
			kind_totals.bundles += 1
			kind_totals.entries += int(result.entries)
			kind_totals.bytes += int(result.bytes)
			kind_totals.gpu_bytes += int(result.gpu_bytes)
			for field: String in ["bytes","gpu_bytes"]: totals[field] += int(result[field])
			for field: String in ["states","images","etc2_cells","rgba8_cells","etc2_rejected_psnr","etc2_rejected_alpha"]: totals[field] += int(result.stats.get(field, 0))
			totals.etc2_psnr_min = minf(totals.etc2_psnr_min, float(result.stats.get("etc2_psnr_min", 99.0)))
			totals.etc2_max_error = maxi(totals.etc2_max_error, int(result.stats.get("etc2_max_error", 0)))
		else:
			totals.failed_bundles += 1
		by_kind[kind] = kind_totals
		# Bounded process memory across thousands of actors.
		ASSETS.reset_for_tests()
		COMPOSITES.reset_for_tests()
		PREPARED.clear()
		if count % 25 == 0:
			BANK.forget_member_meta()
			print("COOK_PROGRESS %d/%d bundles=%d failed=%d bytes=%d msec=%d" % [count, mine.size(), totals.bundles, totals.failed_entries, totals.bytes, Time.get_ticks_msec() - started])
		await process_frame
	report["by_kind"] = by_kind
	report["totals"] = totals
	report["failure_reasons"] = failures
	report["failure_examples"] = _failed_examples
	report["verification"] = verification
	report["msec"] = Time.get_ticks_msec() - started
	finish(report, report_path, 0)

const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const OVERLAY_LOOPS := {"spell":false,"invoke":false,"item":false,"global":false,"death":false,"ammo_flight":true,"ammo_explosion":false}

func _job_counts(jobs: Array) -> Dictionary:
	var out: Dictionary = {}
	for job: Dictionary in jobs: out[job.kind] = int(out.get(job.kind, 0)) + 1
	return out

var _filters: Dictionary = {}
var _effect_index: Dictionary = {}
var _effect_index_stats: Dictionary = {}
var _failed_examples: Dictionary = {}

func _filtered(reason: String) -> void:
	_filters[reason] = int(_filters.get(reason, 0)) + 1

## Every runtime request the cooked pack answers, in a fixed order. Only
## identities the game can reach are cooked: NPCs of spawn rows the existing
## spawn admission accepts (IsSpawn 1, ServerLimitSetID 0), class bodies of
## the Class table, transform bodies reachable from non-test transform cards,
## and the effect sprites of the effect callers. A combination whose actions
## the bank does not contain (the runtime would reject it the same way) is
## left out and counted in job_filters.
## selection jobs: exactly what _configure_selected_roles receives;
## request jobs: exactly what _configure_reference_bank receives.
func build_jobs(kinds: PackedStringArray, context: Dictionary, options: Dictionary, base: String) -> Array:
	var jobs: Array = []
	var seen: Dictionary = {}
	var add := func(job: Dictionary) -> void:
		var key: String = var_to_str(job.inputs)
		if seen.has(key): return
		seen[key] = true
		jobs.append(job)
	_bank_manifest(options)
	if "npc" in kinds:
		var npc_ids: Dictionary = {}
		for row: Dictionary in SOURCE.table_rows("NpcSpawnPackNpcClassView") if not DEF.table_metadata("NpcSpawnPackNpcClassView").is_empty() else []:
			if int(row.get("IsSpawn", 0)) == 1 and int(row.get("ServerLimitSetID", 0)) == 0: npc_ids[int(row.get("NpcClassID", -1))] = true
		_effect_index_stats["admitted_spawn_npc_classes"] = npc_ids.size()
		var sprites: Dictionary = {}
		for row: Dictionary in SOURCE.table_rows("NpcClass"):
			if row.get("TestNPC") != false or not BANK.integer(row.get("Sprite"), 1): continue
			if not npc_ids.is_empty() and not npc_ids.has(int(row.ID)):
				_filtered("npc_class_not_in_admitted_spawn_rows")
				continue
			sprites[int(row.Sprite)] = true
		var ids: Array = sprites.keys()
		ids.sort()
		for sprite: int in ids:
			if not _actor_usable(sprite, SELECTION.CORE_ACTIONS.values()):
				_filtered("npc_core_action_absent_in_bank")
				continue
			var selected: Dictionary = SELECTION.cook_selection(sprite, context)
			if selected.ok: add.call({"kind":"npc","sprite":sprite,"label":"npc:%d" % sprite,"selected":selected,"inputs":STORE.selection_inputs(selected)})
	if "class" in kinds:
		SOURCE.source_tables(context, ["Class","Gender"])
		for row: Dictionary in SOURCE.table_rows("Class"):
			if not BANK.integer(row.get("ID"), 1): continue
			for gender: int in [1, 2]:
				var field: String = "MaleSpriteID" if gender == 1 else "FemaleSpriteID"
				if not BANK.integer(row.get(field), 1):
					_filtered("class_gender_without_sprite")
					continue
				for weapon: int in SOURCE.PRIMARY_ACTIONS.keys():
					if not _actor_usable(int(row[field]), SOURCE.PRIMARY_ACTIONS[weapon].values()):
						_filtered("class_weapon_actions_absent_in_bank")
						continue
					var class_context: Dictionary = context.duplicate(true)
					class_context.merge({"class_id":int(row.ID),"gender_id":gender,"source_weapon_type":weapon})
					var selected: Dictionary = SOURCE.select_class(class_context)
					if selected.get("ok", false): add.call({"kind":"class","sprite":int(selected.sprite_id),"label":"class:%d:%d:%d" % [int(row.ID), gender, weapon],"selected":selected,"inputs":STORE.selection_inputs(selected)})
					else: _filtered("class_selection:" + str(selected.get("reason", "")))
	if "transform" in kinds:
		var sprites: Dictionary = transform_sprites()
		var ids: Array = sprites.keys()
		ids.sort()
		_effect_index_stats["transform_bodies_reachable"] = ids.size()
		for sprite: int in ids:
			for weapon: int in SOURCE.PRIMARY_ACTIONS.keys():
				if not _actor_usable(sprite, SOURCE.PRIMARY_ACTIONS[weapon].values()):
					_filtered("transform_weapon_actions_absent_in_bank")
					continue
				var selected: Dictionary = SOURCE.card_visual_selection("transform", sprite, weapon, options)
				if selected.ok: add.call({"kind":"transform","sprite":sprite,"label":"transform:%d:%d" % [sprite, weapon],"selected":selected,"inputs":STORE.selection_inputs(selected)})
	if "effect" in kinds:
		_effect_index = effect_domain_index(base.path_join("bank"), options)
		EFFECT.cooked_domain_index = _effect_index
		var effect_reasons: Dictionary = {}
		for pair: Array in effect_sprites(context):
			# The runtime effect selection itself (sole/declared action in the
			# action domain, compiled inputs present); what it rejects is never
			# shown at runtime either, so it is not cooked.
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

const DEF = preload("res://scripts/resources/current523_definition_rows.gd")

## Transform bodies of every non-test transform card's typed entity chain
## (BuffClass -> PolymorphSet -> PolymorphEntity, sub-slot buffs and the
## card's sprite customizing options), the same walk select_card makes.
func transform_sprites() -> Dictionary:
	var out: Dictionary = {}
	var cards: int = 0
	for card: Dictionary in SOURCE.table_rows("BuffCard"):
		if int(card.get("BuffCardDeckID", -1)) != SOURCE.DECKS.transform or bool(card.get("IsTest", false)): continue
		cards += 1
		var chains: Array = []
		SOURCE._walk_buff(int(card.get("BuffClassID", -1)), [], [], chains)
		for option: Dictionary in SOURCE.table_where("BuffCardSpriteCustomizingOption", "BuffCardID", int(card.ID)):
			var unit: Dictionary = SOURCE.table_row("Unit", int(option.get("UnitID", -1)))
			if unit.get("Name", "") == "PolymorphSetID": SOURCE._add_set(int(option.get("Value", -1)), [], chains)
		for chain: Dictionary in chains: out[int(chain.sprite_id)] = true
	_effect_index_stats["transform_cards"] = cards
	return out

## Cook-time action domains for the effect selection (see
## cooked_actor_store.gd EFFECT_DOMAIN_BASIS): every effective SPR action the
## pack's own evidence lists per actor, compiled or blocked.
func effect_domain_index(bank: String, options: Dictionary) -> Dictionary:
	var domains: Dictionary = {}
	var lines: int = 0
	for file: String in ["action-outcomes.jsonl.gz", "source-family-scan-failures.jsonl.gz"]:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.path_join(file))
		if bytes.is_empty(): return {}
		var text: String = bytes.decompress_dynamic(512 * 1024 * 1024, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
		for line: String in text.split("\n", false):
			var row: Variant = JSON.parse_string(line)
			if not row is Dictionary: continue
			var actor: int = -1
			var action: int = -1
			if (row.get("actor_id") is float or row.get("actor_id") is int) and (row.get("action_id") is float or row.get("action_id") is int):
				actor = int(row.actor_id)
				action = int(row.action_id)
			else:
				var match: RegExMatch = _failure_key().search(str(row.get("failure_key", "")))
				if match == null: continue
				actor = int(match.get_string(1))
				action = int(match.get_string(2))
			lines += 1
			var key: String = "sprite:%d" % actor
			if not domains.has(key): domains[key] = {}
			domains[key][action] = true
	var packed_domains: Dictionary = {}
	for key: String in domains:
		var ids: Array = domains[key].keys()
		ids.sort()
		packed_domains[key] = PackedInt32Array(ids)
	var compiled: Dictionary = {}
	for key: String in _bank_actors:
		var ids: Array = []
		for action: String in _bank_actors[key]: ids.append(int(action))
		ids.sort()
		compiled[key] = PackedInt32Array(ids)
	_effect_index_stats["domain_actors"] = packed_domains.size()
	_effect_index_stats["domain_actions"] = lines
	return {"format":STORE.EFFECT_INDEX_FORMAT,"manifest_sha256":str(options.manifest_sha256).to_lower(),"domain_basis":STORE.EFFECT_DOMAIN_BASIS,
		"domains":packed_domains,"compiled":compiled,"excluded":_bank_excluded.duplicate(true)}

var _failure_regex: RegEx = null
func _failure_key() -> RegEx:
	if _failure_regex == null:
		_failure_regex = RegEx.new()
		_failure_regex.compile("^sprite:(\\d+)/action:(\\d+)$")
	return _failure_regex

const POLICY = preload("res://scripts/animation/source_playback_policy.gd")

var _bank_actors: Dictionary = {}
var _bank_excluded: Dictionary = {}
var _effect_reasons: Dictionary = {}

func _bank_manifest(options: Dictionary) -> void:
	if not _bank_actors.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(options.manifest_path)))
	if not parsed is Dictionary: return
	_bank_actors = parsed.get("actors", {})
	_bank_excluded = parsed.get("excluded_source_actors", {})

## The bank holds every action and the actor is not a declared dummy.
func _actor_usable(sprite: int, actions: Array) -> bool:
	var key: String = "sprite:%d" % sprite
	if _bank_excluded.has(key): return false
	var entries: Variant = _bank_actors.get(key)
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

func _configure(preview: Node2D, job: Dictionary, resolved: Dictionary) -> bool:
	if job.has("selected"):
		var selected: Dictionary = job.selected.duplicate(true)
		var configured: bool = preview._configure_selected_roles(selected, "idle")
		for field: String in ["role_actions","loop_policy","role_actor_ids","run_status","optional_role_status"]:
			if selected.has(field): resolved[field] = selected[field]
		return configured
	var request: Dictionary = job.request
	preview.playback_mode_override = str(request.override)
	return preview._configure_reference_bank(str(request.manifest_path), str(request.sha), int(request.sprite), request.bindings, request.loops, "idle", str(request.consumer))

## Failure classes for the report (the runtime fails the same way).
static func classify(error: String) -> String:
	if error.contains("Invalid raw member identity"): return "original_member_identity_differs (pack member bytes/size vs bank manifest)"
	if error.contains("palette marker") or error.contains("SP2 sample extent"): return "original_sp2_layout_unsupported_by_decoder"
	if error.contains("dummy actor"): return "source_declared_dummy"
	if error.contains("absent or unsafe") or error.contains("actor ID is absent"): return "bank_action_absent"
	return error.left(120)

func cook_bundle(host: Node, group: Array, lossless: bool, compress: int, path: String, verify_it: bool) -> Dictionary:
	var session := COOKER.Session.new()
	var entries: Array = []
	var cooked_jobs: Array = []
	var failures: Dictionary = {}
	for job: Dictionary in group:
		var preview: Node2D = PREVIEW.new()
		preview.cached_frames = true
		host.add_child(preview)
		var resolved: Dictionary = {}
		if not _configure(preview, job, resolved):
			var reason: String = classify(str(preview.reference_bank_status.get("error", "")))
			failures[reason] = int(failures.get(reason, 0)) + 1
			_failed_examples[reason] = job.label
			preview.free()
			continue
		var cooked: Dictionary = COOKER.cook_preview(preview, job.inputs, lossless, resolved, session)
		preview.free()
		if not cooked.ok:
			var reason: String = classify(str(cooked.error))
			failures[reason] = int(failures.get(reason, 0)) + 1
			continue
		entries.append(cooked.entry)
		cooked_jobs.append(job)
	var failed: int = group.size() - entries.size()
	if entries.is_empty(): return {"ok":false,"entries":0,"failed_entries":failed,"failures":failures}
	var written: Dictionary = COOKER.write_cooked(path, session, entries, compress)
	if not written.ok: return {"ok":false,"entries":0,"failed_entries":group.size(),"failures":{"write:" + str(written.error):1}}
	var result: Dictionary = {"ok":true,"entries":entries.size(),"failed_entries":failed,"failures":failures,"bytes":written.bytes,"gpu_bytes":written.gpu_bytes,"stats":written.stats}
	if verify_it:
		var checks: Array = []
		# The first entry and the last one (weapon variants share frames).
		for job: Dictionary in ([cooked_jobs[0]] if cooked_jobs.size() == 1 else [cooked_jobs[0], cooked_jobs[-1]]):
			checks.append(verify_written(host, job, path))
		result["verify"] = checks
	return result

func verify_written(host: Node, job: Dictionary, path: String) -> Dictionary:
	var loaded: Dictionary = STORE.load_actor(path)
	if not loaded.ok: return {"ok":false,"problems":["load:" + str(loaded.error)]}
	var entry: Variant = loaded.actor.entries.get(STORE.entry_key(job.inputs))
	if not entry is Dictionary: return {"ok":false,"problems":["entry missing"]}
	var runtime: Node2D = PREVIEW.new()
	runtime.cached_frames = true
	host.add_child(runtime)
	var result: Dictionary = {}
	if not _configure(runtime, job, {}):
		result = {"ok":false,"problems":["runtime configure"]}
	else:
		var cooked: Node2D = PREVIEW.new()
		host.add_child(cooked)
		var manifest_path: String = str(job.get("selected", job.get("request", {})).get("manifest_path", ""))
		var ok: bool = cooked._configure_cooked({"actor":loaded.actor,"entry":entry}, manifest_path, "idle", "overlay", int(job.sprite))
		if ok and job.has("request"): cooked._is_overlay = false
		result = COOKER.verify(runtime, cooked, COOKER.verify_steps(entry.runtime_tracks.keys(), int(job.sprite))) if ok else {"ok":false,"problems":["cooked configure"]}
		cooked.free()
	runtime.free()
	return result
