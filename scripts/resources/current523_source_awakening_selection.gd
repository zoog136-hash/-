extends RefCounted
## Presentation selection for an awakening already enabled by its existing caller.
## Only the existing twelve complete source chains are admitted; Type48 is not
## treated as a general status-effect enum or an awakening activation rule.
const BASE = preload("res://scripts/lineagem_base508.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const RULES_PATH = "res://data/lineagem_base508/awakening_effects.json"
const RENDER_SEMANTICS = "exact12chain_allowlist_only_Type48_global_enum_unverified"
const ACTIVATION = "explicit_existing_native_card_awakened_state_and_ownership_required"
const CATEGORY_CONSUMERS = {"변신":"transform","마법인형":"doll","성물":"relic","transform":"transform","doll":"doll","relic":"relic"}
static var _manifest_path: String = ""
static var _manifest_sha: String = ""
static var _manifest: Dictionary = {}

static func fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok":false,"enabled":true,"status":"selection_pending","reason":reason,"consumer":"awakening","source_snapshot":"patch523","source_reference":detail}

static func _known_rule(legacy_rule: Dictionary) -> bool:
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not registry is Dictionary or registry.get("source_snapshot") != "base508" or not registry.get("rules") is Array or registry.rules.size() != 12: return false
	if legacy_rule.get("render_semantics") != RENDER_SEMANTICS or legacy_rule.get("activation") != ACTIVATION: return false
	# Match the whole existing rule, including its raw attributes and source
	# declaration, rather than admitting a new status chain with the same sprite.
	return legacy_rule in registry.rules

static func _bank(options: Dictionary) -> Dictionary:
	var path: String = str(options.get("manifest_path",""))
	var expected: String = str(options.get("manifest_sha256",""))
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > BANK.MAX_MANIFEST_JSON or not BANK.valid_sha(expected): return fail("current523_awakening_bank_missing_or_oversized")
	file.close()
	# Ordinary production pin admission; this does not launch an asset audit.
	if FileAccess.get_sha256(path) != expected: return fail("current523_awakening_bank_pin_changed")
	if path == _manifest_path and expected == _manifest_sha and not _manifest.is_empty(): return {"ok":true,"manifest":_manifest}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("kind") != "current523_reference_sp2_action_bank" or value.get("source_snapshot") != "patch523" or not value.get("actors") is Dictionary or not value.get("source_action_domains") is Dictionary: return fail("current523_awakening_original_action_domain_required")
	if value.get("source_dummy_exclusion_policy") != BANK.SOURCE_DUMMY_EXCLUSION_POLICY or not value.get("excluded_source_actors") is Dictionary: return fail("current523_awakening_source_dummy_policy_required")
	_manifest_path = path
	_manifest_sha = expected
	_manifest = value
	return {"ok":true,"manifest":value}

static func _roles(options: Dictionary, sprite: int) -> Dictionary:
	var loaded: Dictionary = _bank(options)
	if not loaded.ok: return loaded
	var index: Dictionary = loaded.manifest
	var key: String = "sprite:" + str(sprite)
	if index.excluded_source_actors.has(key): return fail("current523_awakening_source_declared_dummy",index.excluded_source_actors[key])
	var domain: Variant = index.source_action_domains.get(key)
	if not domain is Dictionary or domain.get("source_snapshot") != "patch523" or domain.get("source_actor_id") != sprite or domain.get("action_domain_basis") != "all_effective_original_SPR_actions_not_only_compiled_entries" or not domain.get("action_ids") is Array: return fail("current523_awakening_complete_original_action_domain_missing")
	var ids: Array[int] = []
	for action: Variant in domain.action_ids:
		if not BANK.integer(action): return fail("current523_awakening_original_action_domain_invalid")
		ids.append(int(action))
	# These two roles come from the existing awakening consumer contract. There
	# is no sole-action/default-action inference and no idle-for-motion fallback.
	if not ids.has(3): return fail("current523_awakening_source_idle_action_not_declared")
	var entries: Variant = index.actors.get(key)
	if not entries is Dictionary or not entries.has("3"): return fail("current523_awakening_source_idle_inputs_unavailable")
	var optional: Dictionary = {}
	var walk_status: String = "source_walk_action_not_declared"
	if ids.has(0):
		walk_status = "source_walk_inputs_unavailable"
		if entries.has("0"):
			optional["walk"] = 0
			walk_status = "source_walk_action_selected"
	return {"ok":true,"role_actions":{"idle":3},"optional_role_actions":optional,"loop_policy":{"idle":true,"walk":true},"walk_status":walk_status,"source_action_domain":domain.duplicate(true)}

static func select(category: String, record: Dictionary, legacy_rule: Dictionary, context: Dictionary = {}) -> Dictionary:
	var consumer: String = str(CATEGORY_CONSUMERS.get(category,""))
	if not SOURCE.DECKS.has(consumer) or not BASE.native(record) or not _known_rule(legacy_rule): return fail("current523_existing_awakening_chain_required")
	var source_id: String = str(record.get("sourceId",""))
	if not source_id.begins_with("m508:") and not source_id.begins_with("m523:"): return fail("current523_awakening_namespaced_card_required")
	# Resolve the persisted identity in the actual catalog. An arbitrary supplied
	# row cannot become a new card merely by declaring a source namespace.
	var canonical: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	if canonical.get("sourceId","") != source_id or not canonical.get("source_original_card") is Dictionary: return fail("current523_awakening_canonical_card_required")
	var supplied: Dictionary = SOURCE.source_tables(context)
	if not supplied.ok: return supplied
	var native: Dictionary = SOURCE.table_row("BuffCard",int(canonical.get("source_card_id",-1)))
	if native.is_empty() or native != canonical.source_original_card or int(native.get("BuffCardDeckID",-1)) != SOURCE.DECKS[consumer] or int(canonical.get("source_deck_id",-1)) != int(native.BuffCardDeckID) or source_id != "%s:%d:%d" % [source_id.get_slice(":",0),int(native.BuffCardDeckID),int(native.ID)]: return fail("current523_awakening_complete_typed_card_differs")
	if bool(native.get("IsTest",false)): return fail("current523_awakening_test_card_not_admitted")
	var deck: Dictionary = SOURCE.table_row("BuffCardDeck",int(native.BuffCardDeckID))
	if deck.get("Name") != SOURCE.DECK_NAMES[consumer]: return fail("current523_awakening_typed_card_deck_differs")
	var matches: Array[Dictionary] = []
	for row: Dictionary in SOURCE.table_rows("BuffCardAwakenEffect"):
		if row.get("BuffCardDeckID") == native.BuffCardDeckID and row.get("GradeID") == native.get("GradeID"): matches.append(row)
	if matches.size() != 1 or matches[0] != legacy_rule.get("effect_row"): return fail("current523_awakening_complete_effect_row_differs")
	var effect: Dictionary = matches[0]
	var attrs: Array[Dictionary] = []
	for row: Dictionary in SOURCE.table_rows("StatusEffectAttr"):
		if row.get("StatusEffectID") == effect.get("StatusEffectID"): attrs.append(row.duplicate(true))
	if attrs != legacy_rule.get("status_attributes"): return fail("current523_awakening_complete_status_attributes_differ")
	var references: Array[Dictionary] = []
	var uninterpreted: Array[Dictionary] = []
	for attr: Dictionary in attrs:
		if attr.get("StatusEffectAttrType") == 48 and attr.get("GenderID") == 0: references.append(attr)
		else: uninterpreted.append(attr.duplicate(true))
	if references.size() != 1: return fail("current523_awakening_existing_gender0_reference_not_unique")
	var reference: Dictionary = references[0]
	if reference.get("ID") != legacy_rule.get("attr48_reference_id") or reference.get("Value") != legacy_rule.get("sprite_id") or not BANK.integer(reference.get("Value"),1): return fail("current523_awakening_existing_sprite_reference_differs")
	var sprite: int = int(reference.Value)
	var roles: Dictionary = _roles(supplied.options,sprite)
	if not roles.ok: return roles
	return {"ok":true,"enabled":true,"status":"selected","consumer":"awakening","source_snapshot":"patch523",
		"request_key":"awakening:" + category + ":" + source_id,"source_id":source_id,"sprite_id":sprite,
		"role_actions":roles.role_actions,"optional_role_actions":roles.optional_role_actions,"loop_policy":roles.loop_policy,
		"walk_status":roles.walk_status,"source_action_domain":roles.source_action_domain,
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_tables_sha256":supplied.source_tables_sha256,
		"source_reference":{"table":"BuffCardAwakenEffect","row":effect.duplicate(true),"card":native.duplicate(true),"card_deck":deck.duplicate(true),
			"status_attributes":attrs,"scoped_sprite_attribute":reference.duplicate(true),"uninterpreted_attributes":uninterpreted,
			"existing_allowlist_rule":legacy_rule.duplicate(true),"activation":"existing_enabled_argument_and_source_status_owner_only; no_new_state_or_bonus",
			"card_conditions":"preserved_in_complete_source_card; no_server_date_or_status_interpretation"},
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"host_policy":"existing_native_card_visual_anchor_compatibility; own_source_action_clock_and_loop; native_placement_blend_and_attr48_global_enum_unverified"}
