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
const COOKED_PREVIEW = preload("res://scripts/animation/cooked_actor_preview.gd")

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
	var verify_count: int = int(argument("--verify=", "40"))
	var report: Dictionary = {"format":FORMAT.FORMAT,"shard":shard,"shards":shards,"lossless":lossless,"engine":Engine.get_version_info().string,"actors":{},"failures":[]}
	var report_path: String = out.path_join("report-%d.json" % shard)
	if base.is_empty() or out.is_empty():
		report.failures.append("usage: --pack=<dir> --out=<dir>")
		finish(report, "user://cook_report.json", 2)
		return
	# The phone's path: no screen copy, uncompressed runtime layer textures.
	COMPOSITOR.screen_copy_available = false
	GPU_TEXTURE.enabled = false
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	if not read.ok:
		report.failures.append("descriptor: " + str(read.reason))
		finish(report, report_path, 2)
		return
	var selected_pack: Dictionary = PACK.selections(base, read.descriptor)
	var bank_options: Dictionary = selected_pack.bank
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
	var sprites: Dictionary = {}
	for row: Dictionary in SOURCE.table_rows("NpcClass"):
		if row.get("TestNPC") == false and BANK.integer(row.get("Sprite"), 1): sprites[int(row.Sprite)] = true
	var ids: Array = sprites.keys()
	ids.sort()
	var only: String = argument("--actors=", "")
	if not only.is_empty():
		ids = []
		for part: String in only.split(","): ids.append(int(part))
	var mine: Array = []
	for index: int in range(ids.size()):
		if index % shards == shard: mine.append(ids[index])
	if limit > 0: mine = mine.slice(0, limit)
	report["npc_sprites_total"] = ids.size()
	report["npc_sprites_in_shard"] = mine.size()
	var compress: int = -1 if lossless else Image.COMPRESS_ETC2
	var verification: Dictionary = {"actors":0,"failed":0,"steps":0,"items":0,"exact_items":0,"etc2_items":0,"etc2_max_error":0,"etc2_psnr_db_min":99.0}
	var totals: Dictionary = {"cooked":0,"failed":0,"bytes":0,"gpu_bytes":0,"states":0,"images":0,"samples":0,"resampled_child_tracks":0}
	var host := Node2D.new()
	root.add_child(host)
	var count: int = 0
	for sprite: int in mine:
		count += 1
		var actor_started: int = Time.get_ticks_msec()
		var entry: Dictionary = {}
		var selected: Dictionary = SELECTION.cook_selection(sprite, context)
		if not selected.ok:
			entry = {"ok":false,"error":str(selected.get("reason", ""))}
		else:
			var inputs: Dictionary = STORE.inputs(selected)
			var selected_copy: Dictionary = selected.duplicate(true)
			var preview: Node2D = PREVIEW.new()
			preview.cached_frames = true
			host.add_child(preview)
			if not preview._configure_selected_roles(selected, "idle"):
				entry = {"ok":false,"error":"configure:" + str(preview.reference_bank_status.get("error", ""))}
			else:
				var resolved: Dictionary = {}
				for field: String in ["role_actions","loop_policy","role_actor_ids","run_status","optional_role_status"]:
					if selected.has(field): resolved[field] = selected[field]
				var cooked: Dictionary = COOKER.cook_preview(preview, inputs, lossless, resolved)
				if not cooked.ok:
					entry = {"ok":false,"error":str(cooked.error)}
				else:
					var path: String = out.path_join(FORMAT.FORMAT_TAG).path_join(FORMAT.actor_file(inputs.key))
					var written: Dictionary = COOKER.write_cooked(path, cooked, compress)
					if not written.ok:
						entry = {"ok":false,"error":str(written.error)}
					else:
						entry = {"ok":true,"bytes":written.bytes,"gpu_bytes":written.gpu_bytes,"roles":cooked.index.tracks.keys()}
						entry.merge(cooked.index.stats)
						if verification.actors < verify_count:
							entry["verify"] = verify_written(host, selected_copy, path, cooked.index.tracks.keys(), sprite)
							verification.actors += 1
							for field: String in ["steps","items","exact_items","etc2_items"]: verification[field] += int(entry.verify.get(field, 0))
							verification.etc2_max_error = maxi(verification.etc2_max_error, int(entry.verify.get("etc2_max_error", 0)))
							verification.etc2_psnr_db_min = minf(verification.etc2_psnr_db_min, float(entry.verify.get("etc2_psnr_db", 99.0)))
							if not entry.verify.ok:
								verification.failed += 1
								entry.ok = false
								entry["error"] = "verify:" + str(entry.verify.problems)
								DirAccess.remove_absolute(path)
			preview.free()
		entry["msec"] = Time.get_ticks_msec() - actor_started
		report.actors[str(sprite)] = entry
		if entry.ok:
			totals.cooked += 1
			for field: String in ["bytes","gpu_bytes","states","images","samples","resampled_child_tracks"]: totals[field] += int(entry.get(field, 0))
		else:
			totals.failed += 1
		# Bounded process memory across thousands of actors.
		ASSETS.reset_for_tests()
		COMPOSITES.reset_for_tests()
		PREPARED.clear()
		if count % 25 == 0:
			BANK.forget_member_meta()
			print("COOK_PROGRESS %d/%d cooked=%d failed=%d bytes=%d msec=%d" % [count, mine.size(), totals.cooked, totals.failed, totals.bytes, Time.get_ticks_msec() - started])
		await process_frame
	report["totals"] = totals
	report["verification"] = verification
	if verification.failed > 0: report.failures.append("verification failed for %d actors" % verification.failed)
	report["msec"] = Time.get_ticks_msec() - started
	finish(report, report_path, 0)

func verify_written(host: Node, selected: Dictionary, path: String, roles: Array, sprite: int) -> Dictionary:
	var loaded: Dictionary = STORE.load_actor(path)
	if not loaded.ok: return {"ok":false,"problems":["load:" + str(loaded.error)]}
	var runtime: Node2D = PREVIEW.new()
	runtime.cached_frames = true
	host.add_child(runtime)
	var result: Dictionary = {}
	if not runtime._configure_selected_roles(selected, "idle"):
		result = {"ok":false,"problems":["runtime configure"]}
	else:
		var cooked: Node2D = COOKED_PREVIEW.new()
		host.add_child(cooked)
		cooked.configure_cooked(loaded.actor, "idle")
		result = COOKER.verify(runtime, cooked, COOKER.verify_steps(roles, sprite))
		cooked.free()
	runtime.free()
	return result
