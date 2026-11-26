extends SceneTree
## Awakened polymorph/doll/relic body effect (Effect_AwakenTrans_Lightning_*,
## Effect_Trans_Spell_Sole_*: BuffCardAwakenEffect -> StatusEffectAttr 48).
## The installed 523 bank manifest has no source_action_domains, so the
## awakening selection rejected every awakened card and the body effect never
## appeared. The selection now reads the pinned cooked pack's action domains
## (the same index the source effect selection uses) before the bank manifest.
const AWAKEN = preload("res://scripts/resources/current523_source_awakening_selection.gd")
const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const RULES = "res://data/lineagem_base508/awakening_effects.json"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("AWAKENING_BODY_EFFECT_DOMAIN_FAIL: " + label)

func _initialize() -> void:
	var dir: String = OS.get_cache_dir().path_join("twilight_awakening_body_effect_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("manifest.json")
	# Shape of the installed bank manifest: actors present, no action domains.
	var manifest: Dictionary = {"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","actors":{"sprite:20542":{"0":{},"3":{}}},
		"source_dummy_exclusion_policy":preload("res://scripts/resources/reference_sp2_bank.gd").SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var sha: String = FileAccess.get_sha256(path)
	var options: Dictionary = {"manifest_path":path,"manifest_sha256":sha}
	EFFECT.cooked_domain_index = {}
	var before: Dictionary = AWAKEN._roles(options, 20542)
	check(not before.ok and before.reason == "current523_awakening_original_action_domain_required", "without a cooked index the domain-less bank is still rejected (no invented domain)")
	# The 12 source chains, all with original walk(0) and breath(3) declared in
	# their list_*.spr blocks; the cooked index records exactly those.
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	var domains: Dictionary = {}
	var compiled: Dictionary = {}
	var sprites: Array[int] = []
	for rule: Dictionary in registry.rules:
		sprites.append(int(rule.sprite_id))
		domains["sprite:%d" % int(rule.sprite_id)] = PackedInt32Array([0, 3])
		compiled["sprite:%d" % int(rule.sprite_id)] = PackedInt32Array([0, 3])
	check(sprites.size() == 12 and 20542 in sprites and 20540 in sprites and 20459 in sprites and 24763 in sprites, "polymorph hero/legend/myth/unique lightning chains are in the registry")
	domains["sprite:90001"] = PackedInt32Array([3])
	compiled["sprite:90001"] = PackedInt32Array([3])
	domains["sprite:90002"] = PackedInt32Array([0])
	compiled["sprite:90002"] = PackedInt32Array([0])
	domains["sprite:90003"] = PackedInt32Array([0, 3])
	compiled["sprite:90003"] = PackedInt32Array([0])
	EFFECT.cooked_domain_index = {"format":STORE.EFFECT_INDEX_FORMAT,"manifest_sha256":sha,"domain_basis":STORE.EFFECT_DOMAIN_BASIS,
		"domains":domains,"compiled":compiled,"excluded":{"sprite:90004":{"dummy":true}}}
	for sprite: int in sprites:
		var roles: Dictionary = AWAKEN._roles(options, sprite)
		check(roles.ok and roles.role_actions == {"idle":3} and roles.optional_role_actions == {"walk":0} and roles.walk_status == "source_walk_action_selected", "sprite %d: breath idle + walk from cooked domain" % sprite)
		check(roles.get("source_action_domain",{}).get("action_domain_basis","") == STORE.EFFECT_DOMAIN_BASIS and int(roles.source_action_domain.source_actor_id) == sprite, "sprite %d: domain provenance kept" % sprite)
		check(roles.loop_policy == {"idle":true,"walk":true}, "sprite %d: body effect loops while worn" % sprite)
	var idle_only: Dictionary = AWAKEN._roles(options, 90001)
	check(idle_only.ok and idle_only.optional_role_actions.is_empty() and idle_only.walk_status == "source_walk_action_not_declared", "idle-only source: no walk invented")
	check(AWAKEN._roles(options, 90002).get("reason","") == "current523_awakening_source_idle_action_not_declared", "no breath action: rejected")
	check(AWAKEN._roles(options, 90003).get("reason","") == "current523_awakening_source_idle_inputs_unavailable", "breath without compiled frames: rejected")
	check(AWAKEN._roles(options, 90004).get("reason","") == "current523_awakening_source_declared_dummy", "declared dummy: rejected")
	check(AWAKEN._roles(options, 90005).get("reason","") == "current523_awakening_complete_original_action_domain_missing", "unknown actor: rejected")
	# A cooked index for another bank is not used.
	EFFECT.cooked_domain_index["manifest_sha256"] = "0".repeat(64)
	check(not AWAKEN._roles(options, 20542).ok, "index of a different bank is ignored")
	EFFECT.cooked_domain_index = {}
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	print("AWAKENING_BODY_EFFECT_DOMAIN_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if not failures.is_empty() else 0)
