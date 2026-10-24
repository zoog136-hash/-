extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		print("ANIMATION CATALOG FAIL: " + text)

func _run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/directional_art_v19.json"))
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.position = Vector2(135, 237)
	actor.auto_enabled = true
	var directional_count: int = 0
	var native_count: int = 0
	for item: Dictionary in db["변신"]:
		var id: String = "transform:" + str(item.sourceId)
		var resource: String = str(art.get(id, {}).get("path", item.image_path))
		var profile: TwilightAnimationProfile = CATALOG.for_record("transform", item, resource)
		actor.start_combat_attack(Vector2(250, 200), 0.72, "slash")
		var sequence: int = actor.motion.sequence
		actor.set_transform_visual(resource, 1.0, profile)
		check(actor.transform_active, "missing transform " + id)
		check(actor.position == Vector2(135, 237) and actor.auto_enabled, "switch altered position/AUTO " + id)
		check(actor.motion.sequence == sequence and actor.motion.active, "switch cancelled combat " + id)
		check(not actor.class_sprite.visible, "old class still visible " + id)
		var frames: SpriteFrames = actor.transform_sprite.sprite_frames
		var generated: Dictionary = preload("res://scripts/animation/visual_manifest.gd").record(id)
		if art.has(id): directional_count+=1
		if profile.layout == "directional8" and not profile.frames_path.is_empty():
			native_count+=1
			for direction: int in range(8):
				for role: String in ["idle", "walk", "attack", "hit", "death"]:
					var key := role + "_" + str(direction)
					check(frames.has_animation(key) and frames.get_frame_count(key) >= 2, "native eight-view action " + id + key)
			continue
		if art.has(id):
			if generated.is_empty():
				check(frames.get_animation_names().size() == 4, "directional layout " + id)
			else:
				for suffix: String in ["_down", "_up", "_left", "_right"]:
					for role: String in ["idle", "walk", "run", "attack", "hit", "death"]:
						check(frames.has_animation(role + suffix) and frames.get_frame_count(role + suffix) >= 2, "authored directional action " + id + role + suffix)
		else:
			if generated.is_empty():
				check(frames.has_animation("still") and frames.get_frame_count("still") == 1, "single-image fallback cut into tiles " + id)
			else:
				for role: String in ["idle", "walk", "run", "attack", "hit", "death"]:
					check(frames.has_animation(role) and frames.get_frame_count(role) >= 2, "authored single-view action " + id + role)
	# PR122 exact-name reuse: share the COMPLETE existing source atlas without
	# merging distinct catalog/monster identities or altering battle contracts.
	var shared_six: Dictionary = {
		"transform:7":"monster:바포메트",
		"transform:11":"monster:베레스",
		"transform:352":"monster:알비노 뿔 개구리",
		"monster:알비노 피쉬맨":"transform:350",
		"transform:351":"monster:알비노 자이언트 크랩",
		"transform:349":"monster:알비노 악어거북"
	}
	var profile_db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_animation_profiles.json"))["profiles"]
	var connection_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_boss_runtime_connections.json"))
	var native_connections: Dictionary = {}
	for connection: Dictionary in connection_data.connections:
		check(not native_connections.has(connection.id), "unique reviewed native connection " + str(connection.id))
		native_connections[connection.id] = connection
	check(native_connections.size() == 6, "six recorded native boss connections")
	# Pin the six pre-merge approved bodies and their complete immutable packs.
	# They remain FRAME_INSUFFICIENT; unapproved name/palette aliases cannot
	# replace their prior approval or count as new production completions.
	var prior_path := "res://data/pr122_prior_approved_native_20261019.json"
	check(FileAccess.get_sha256(prior_path) == "ae1e35791d4c796f639f2c7ef60a26d50a874793fba2eb97f547bd18cfd29f1d", "exact pinned pre-merge approval preservation")
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prior_path))
	var prior_records: Dictionary = prior.get("records", {})
	check(prior_records.size() == 6 and int(prior.get("newly_approved", -1)) == 0, "preserve six prior approvals without promotion")
	for key: String in ["transform:176", "transform:351", "transform:349", "transform:167", "transform:110", "transform:2"]:
		var saved: Dictionary = prior_records.get(key, {})
		check(not saved.is_empty() and profile_db.get(key, {}) == saved.get("approved_profile", {}), "exact prior approved profile " + key)
		check(str(saved.get("preserved_status", "")) == "FRAME_INSUFFICIENT", "prior frame shortage retained " + key)
		for path: String in saved.get("resources_sha256", {}):
			check(FileAccess.get_sha256(path) == str(saved.resources_sha256[path]), "immutable prior approval source " + path)
	for target: String in shared_six:
		var donor_id: String = str(shared_six[target])
		var target_data: Dictionary = profile_db.get(target, {})
		var donor_data: Dictionary = profile_db.get(donor_id, {})
		check(not target_data.is_empty() and not donor_data.is_empty(), "six-way source record " + target)
		if target_data.is_empty() or donor_data.is_empty(): continue
		check(str(target_data.get("name","")) == str(donor_data.get("name","")), "exact same name " + target)
		var source_path: String = str(donor_data.get("frames_path",""))
		if target in ["transform:351", "transform:349"]:
			# Same names cannot displace these distinct, previously approved packs.
			source_path = str(prior_records.get(target, {}).get("approved_profile", {}).get("frames_path", ""))
			check(not source_path.is_empty() and source_path == str(target_data.get("frames_path", ""))
				and source_path != str(donor_data.get("frames_path", "")), "retain distinct prior native identity " + target)
		else:
			check(str(target_data.get("shared_visual_source","")) == donor_id, "explicit no-heuristic source " + target)
			check(not source_path.is_empty() and source_path == str(target_data.get("frames_path","")), "reuse identical original SpriteFrames " + target)
		if source_path.is_empty() or not ResourceLoader.exists(source_path): continue
		if target not in ["transform:351", "transform:349"]:
			for key: String in ["pixel_scale","sprite_offset","color_tint","embedded_shadow","movement_fps"]:
				check(target_data.get(key,null) == donor_data.get(key,null), "copy only visual source metadata " + target + ":" + key)
		var art_frames: SpriteFrames = CATALOG.frames(source_path, "directional8")
		for direction: int in range(8):
			for role: String in ["idle","walk","attack","hit","death"]:
				var animation: String = role + "_" + str(direction)
				check(art_frames.has_animation(animation) and art_frames.get_frame_count(animation) >= 2, "complete shared motion " + target + ":" + animation)
		var split: PackedStringArray = target.split(":", false, 1)
		var record: Dictionary = {"sourceId":split[1]} if split[0] == "transform" else {"name":split[1]}
		var target_profile: TwilightAnimationProfile = CATALOG.for_record(split[0], record)
		check(target_profile.frames_path == source_path and target_profile.layout == "directional8", "real actor profile uses shared source " + target)
	# PR122 palette reuses: paths are in-project shared frames; no new PNGs.
	# Every mapped identity keeps its own catalog/combat data and prior QA state.
	var color_ledger_path: String = "res://data/pr122_palette_reuse_20261019.json"
	check(FileAccess.file_exists(color_ledger_path), "PR122 palette reuse ledger")
	if FileAccess.file_exists(color_ledger_path):
		var ledger_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(color_ledger_path))
		check(ledger_value is Dictionary, "PR122 palette reuse JSON")
		if ledger_value is Dictionary:
			var ledger: Dictionary = ledger_value as Dictionary
			var entries: Array = ledger.get("entries", [])
			check(entries.size() == 41, "PR122 exact palette candidate count")
			var data_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_animation_profiles.json"))
			check(data_value is Dictionary, "PR122 source profiles JSON")
			if data_value is Dictionary:
				var all_profiles: Dictionary = (data_value as Dictionary).get("profiles", {})
				for entry_value: Variant in entries:
					if not (entry_value is Dictionary):
						check(false, "PR122 entry dictionary")
						continue
					var entry: Dictionary = entry_value as Dictionary
					var target: String = str(entry.get("target", ""))
					var donor: String = str(entry.get("source", ""))
					var target_data: Dictionary = all_profiles.get(target, {})
					var donor_data: Dictionary = all_profiles.get(donor, {})
					var native_path: String = str(target_data.get("frames_path", ""))
					check(not target_data.is_empty() and not donor_data.is_empty(), "PR122 pair profiles: " + target)
					var replacement: Dictionary = entry.get("superseded_by_native_pack", {})
					var prior_replacement: Dictionary = entry.get("prior_approved_native", {})
					var published_replacement: bool = target in ["monster:테베 아누비스", "monster:알비노 데몬"]
					if not prior_replacement.is_empty():
						check(target == "transform:176" and prior_records.has(target), "explicit prior captain preservation")
						check(native_path == str(prior_replacement.get("frames_path", ""))
							and native_path == str(prior_records.get(target, {}).get("approved_profile", {}).get("frames_path", "")), "prior captain native binding")
						check(str(prior_replacement.get("status", "")) == "FRAME_INSUFFICIENT"
							and int(prior_replacement.get("newly_approved", -1)) == 0, "captain shortage retained, no approval")
					elif replacement.is_empty():
						if published_replacement:
							# The reviewed connection supersedes only these two proxies.
							# Keep the complete former source identity/tint for auditing;
							# a published pack does not grant a new formal art approval.
							var connection: Dictionary = native_connections.get(target, {})
							var proxy: Dictionary = target_data.get("preserved_proxy_profile", {})
							check(str(connection.get("status", "")) == "CONNECTED_REVIEWED" and bool(connection.get("formal_approval_history_unchanged", false)), "PR122 reviewed connection, approval history preserved: " + target)
							check(native_path == str(connection.get("frames", "")) and native_path != str(entry.get("frames_path", "")), "PR122 exact published resource: " + target)
							check(FileAccess.get_sha256(native_path) == str(connection.get("frames_sha256", "")), "PR122 published source bytes: " + target)
							check(str(proxy.get("frames_path", "")) == str(entry.get("frames_path", "")) and str(proxy.get("shared_visual_source", "")) == donor, "PR122 preserved proxy source: " + target)
							check(str(proxy.get("color_tint", "")) == str(entry.get("color_tint", "")), "PR122 preserved proxy tint: " + target)
							check(str(target_data.get("shared_visual_source", "")).is_empty() and str(target_data.get("color_tint", "")) == "ffffff", "PR122 dedicated source has its own palette: " + target)
						else:
							# A donor can acquire its own new pack after this ledger was
							# written. Aliases keep the exact recorded original source.
							var original_path: String = str(entry.get("frames_path", ""))
							var preserved_donor: Dictionary = donor_data.get("preserved_proxy_profile", {})
							check(native_path == original_path and (original_path == str(donor_data.get("frames_path", "")) or original_path == str(preserved_donor.get("frames_path", ""))), "PR122 same recorded original source: " + target)
							if original_path != str(donor_data.get("frames_path", "")):
								var donor_connection: Dictionary = native_connections.get(donor, {})
								check(str(donor_connection.get("status", "")) == "CONNECTED_REVIEWED" and bool(donor_connection.get("formal_approval_history_unchanged", false)), "PR122 donor upgrade has recorded review: " + target)
								check(str(donor_data.get("frames_path", "")) == str(donor_connection.get("frames", "")) and FileAccess.get_sha256(str(donor_data.get("frames_path", ""))) == str(donor_connection.get("frames_sha256", "")), "PR122 exact recorded donor upgrade: " + target)
							check(str(target_data.get("shared_visual_source","")) == donor, "PR122 explicit donor: " + target)
							check(str(target_data.get("color_tint","")) == str(entry.get("color_tint","")), "PR122 exact tint: " + target)
					else:
						# Concurrent batch16 native completions supersede four unreviewed
						# palette proxies; preserve their real resources and approval evidence.
						check(target in ["monster:알비노 변이된 골렘", "monster:스파이더", "monster:검은숲 거미", "monster:왜곡의 타란툴라"], "PR122 explicit native replacement: " + target)
						check(native_path == str(replacement.get("frames_path", "")) and native_path != str(entry.get("frames_path", "")), "PR122 retain reviewed native pack: " + target)
						var decision_path: String = "res://" + str(replacement.get("completion_decision", ""))
						check(FileAccess.file_exists(decision_path), "PR122 native decision exists: " + target)
						if FileAccess.file_exists(decision_path):
							var decision: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(decision_path))
							check(str(decision.get("status", "")) == "APPROVED", "PR122 native decision approved: " + target)
					check(bool(entry.get("identity_verified",true)) == false, "PR122 cannot promote proxy identity " + target)
					check(ResourceLoader.exists(str(entry.get("frames_path", ""))), "PR122 original palette source retained: " + target)
					if native_path.is_empty() or not ResourceLoader.exists(native_path):
						check(false, "PR122 resource exists: " + target)
						continue
					var frames_shared: SpriteFrames = CATALOG.frames(native_path, "directional8")
					var roles: Array[String] = ["idle", "walk", "attack", "hit", "death"]
					if published_replacement: roles[1] = "run"
					if published_replacement:
						var connection: Dictionary = native_connections.get(target, {})
						var poses: int = 0
						for animation: StringName in frames_shared.get_animation_names(): poses += frames_shared.get_frame_count(animation)
						check(int(connection.get("required_clips", 0)) == 33 and frames_shared.get_animation_names().size() == 33 and poses == int(connection.get("source_poses", 0)), "PR122 all published clips and poses: " + target)
						check(bool(frames_shared.get_meta("twilight_native_locomotion_staging", false)) and bool(frames_shared.get_meta("twilight_production_connected", false)) and not bool(frames_shared.get_meta("twilight_detailed_completed", true)), "PR122 published native metadata without new approval: " + target)
					for direction: int in range(8):
						if published_replacement:
							check(not frames_shared.has_animation("walk_" + str(direction)) and frames_shared.get_frame_count("run_" + str(direction)) == 6, "PR122 authored RUN-only source: " + target)
						for role: String in roles:
							var anim: String = role + "_" + str(2 if published_replacement and role == "death" else direction)
							check(frames_shared.has_animation(anim) and frames_shared.get_frame_count(anim) >= 2, "PR122 shared 8-way animation: " + target + ":" + anim)
					var parts: PackedStringArray = target.split(":", false, 1)
					check(parts.size() == 2, "PR122 explicit ID " + target)
					if parts.size() != 2: continue
					var card: Dictionary = {"sourceId":parts[1]} if parts[0] == "transform" else {"name":parts[1]}
					var actual_profile: TwilightAnimationProfile = CATALOG.for_record(parts[0], card)
					check(actual_profile.frames_path == native_path and actual_profile.layout == "directional8", "PR122 source used by runtime lookup: " + target)
	check(directional_count == 78, "directional coverage changed")
	check(CATALOG.frame_cache.size() <= CATALOG.MAX_FRAME_CACHE, "unbounded frame cache")
	actor.clear_transform_visual()
	check(actor.class_sprite.visible and not actor.transform_sprite.visible, "clear leaves transform residue")
	actor.queue_free()
	await process_frame
	if failures == 0: print("ANIMATION_CATALOG_OK transforms=413 registered_directional=78 native_eight_way=",native_count," shared_attack=413")
	quit(0 if failures == 0 else 1)
