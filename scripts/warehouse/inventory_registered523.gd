extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Read the already-approved PR238 application payload into the existing item
## encyclopedia. This never grants ownership, installs data or widens loot pools.
const SHA = "bec901d26a7766f2c77e9781ce636f17c14e7ba1b33617840eb5a5d5123bafd3"
const BYTES: int = 1806317
const INSTALLED = "user://lineagem_patch523_drops/"+SHA+"/monster_drops.bin"
var document: Dictionary = {}
var problem: String = "검증된523 드랍·아이템 적용팩 미설치"
var report: Dictionary = {}

func load_existing() -> bool:
	var paths: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-drop-root="): paths.append(arg.trim_prefix("--patch523-drop-root=").path_join("monster_drops.bin"))
	paths.append(INSTALLED)
	for path: String in paths:
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length() != BYTES or FileAccess.get_sha256(path) != SHA: continue
		var packed: PackedByteArray = file.get_buffer(BYTES)
		var raw: PackedByteArray = packed.decompress_dynamic(32*1024*1024,FileAccess.COMPRESSION_GZIP)
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if not parsed is Dictionary or parsed.get("kind") != "patch523_monster_drop_membership" or parsed.get("source_snapshot") != "patch523" or int(parsed.get("schema",0)) not in [1,2]: continue
		document = parsed
		problem = ""
		return true
	return false

func attach(catalog: Dictionary, rules) -> Dictionary:
	if document.is_empty(): load_existing()
	var records: Array = catalog.get("아이템",[])
	var source_ids: Dictionary = {}
	var names: Dictionary = {}
	for record: Dictionary in records:
		var source: String = str(record.get("sourceId",""))
		if not source_ids.has(source): source_ids[source] = []
		source_ids[source].append(record)
		var name_: String = str(record.get("name",""))
		if not names.has(name_): names[name_] = []
		names[name_].append(record)
	var approved: Array = document.get("native_item_ids",[]).duplicate()
	for id: String in document.get("native_reward_item_ids",[]):
		if not approved.has(id): approved.append(id)
	var states: Dictionary = {}
	for rows: Array in document.get("drops",{}).values():
		for row: Dictionary in rows:
			var id: String = str(int(row.ItemClassID))
			if not rules.document.get("items",{}).has(id): continue
			if not states.has(id): states[id] = {1:true}
			states[id][int(row.Bless)] = true
	for definition: Dictionary in document.get("item_definitions",{}).values():
		var spec: Dictionary = NATIVE_FIELDS.full(definition.get("native_record",{})).get("source_use_spec",{})
		if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"] or spec.get("activation_status") != "unrestricted": continue
		for row: Dictionary in spec.get("rewards",[]):
			var id: String = str(int(row.item_class_id))
			if not rules.document.get("items",{}).has(id): continue
			if not states.has(id): states[id] = {1:true}
			states[id][int(row.bless_raw)] = true
	var added: int = 0
	var collisions: Array[String] = []
	for id: String in approved:
		var rule: Dictionary = rules.definition(id)
		if rule.is_empty() or rule.virtual or rule.test_item or rule.currency or rule.equipment: continue
		var original: Dictionary = document.get("item_definitions",{}).get(id,{}).get("native_record",{})
		if original.get("sourceId") != "m523:item:"+id or int(original.get("source_item_class_id",0)) != int(id) or original.get("source_display_name") != rule.label or original.get("grade") != rule.grade: continue
		for state: int in states.get(id,{1:true}):
			if state not in [1,2,3]: continue
			var item: Dictionary = original.duplicate(true)
			item["source_bless_raw"] = state
			if state != 1:
				item["name"] = str(item.name)+(" · 축복" if state == 2 else " · 저주")
				item["sourceId"] = str(item.sourceId)+":bless:"+str(state)
			if rules.resolve(item).is_empty(): continue
			var registered: Array = source_ids.get(str(item.sourceId),[])
			if not registered.is_empty():
				if registered.size() != 1 or JSON.stringify(rules._canonical_identity(registered[0])) != JSON.stringify(rules._canonical_identity(item)): collisions.append(str(item.sourceId))
				continue
			if names.has(str(item.name)):
				collisions.append(str(item.sourceId))
				continue
			item["source_automation_catalog_only"] = true
			records.append(item)
			source_ids[item.sourceId] = [item]
			names[item.name] = [item]
			added += 1
	catalog["아이템"] = records
	report = {"added":added,"collisions":collisions,"payload_sha":SHA if not document.is_empty() else "","problem":problem}
	return report
