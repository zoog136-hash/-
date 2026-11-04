extends RefCounted
## Private 523 source evidence. No legacy-name joins or inferred server formulas.
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const MAX_BYTES = 16 * 1024 * 1024
var content: Dictionary = {}
var error: String = ""
var indexes: Dictionary = {}

func load_pack(manifest_path: String, expected_sha: String) -> bool:
	content = {}; indexes = {}; error = ""
	if expected_sha.length() != 64 or not FileAccess.file_exists(manifest_path):
		error = "manifest_sha_mismatch"; return false
	var manifest_file: FileAccess = FileAccess.open(manifest_path,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() > 65536:
		error = "manifest_too_large"; return false
	if FileAccess.get_sha256(manifest_path) != expected_sha:
		error = "manifest_sha_mismatch"; return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("kind") != "patch523_npc_spell_pack" or int(manifest.get("schema", 0)) != 1 or manifest.get("source_archive_sha256") != SOURCE_SHA:
		error = "manifest_contract_mismatch"; return false
	if manifest.get("catalog_file") != "npc_spells.json":
		error = "catalog_path_rejected"; return false
	var path: String = manifest_path.get_base_dir().path_join("npc_spells.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_BYTES or file.get_length() != int(manifest.get("catalog_bytes", -1)):
		error = "catalog_size_mismatch"; return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if FileAccess.get_sha256(path) != manifest.get("catalog_sha256"):
		error = "catalog_sha_mismatch"; return false
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("kind") != "patch523_npc_spell_catalog" or value.get("source_snapshot") != "patch523" or int(value.get("schema", 0)) != 1 or value.get("source_archive_sha256") != SOURCE_SHA:
		error = "catalog_contract_mismatch"; return false
	if not value.get("tables") is Dictionary or not value.get("boss_npc_ids") is Array:
		error = "catalog_tables_missing"; return false
	for table: String in value.tables:
		if not value.tables[table] is Dictionary or value.tables[table].size() != int(manifest.get("table_counts", {}).get(table, -1)):
			error = "table_count_mismatch"; return false
		for key: String in value.tables[table]:
			var entry: Variant = value.tables[table][key]
			if not entry is Dictionary or not entry.get("row") is Dictionary or int(entry.get("source_row_1based", 0)) <= 0:
				error = "source_row_missing"; return false
			if entry.row.has("ID") and str(int(entry.row.ID)) != key:
				error = "source_id_mismatch"; return false
	content = value
	for pair: Array in [["NpcAttack", "NpcClassID"], ["SpellBonus", "SpellClassID"], ["BuffBonus", "BuffClassID"], ["StatusEffectAttr", "StatusEffectID"], ["LandAttribute", "LandID"]]:
		var index: Dictionary = {}
		for entry: Dictionary in content.tables.get(pair[0], {}).values():
			var owner: String = str(int(entry.row.get(pair[1], -1)))
			if not index.has(owner): index[owner] = []
			index[owner].append(entry.row)
		indexes[pair[0]] = index
	return true

func row(table: String, id: int) -> Dictionary:
	return content.get("tables", {}).get(table, {}).get(str(id), {}).get("row", {})

func owned(table: String, id: int) -> Array:
	return indexes.get(table, {}).get(str(id), [])

func bonuses(table: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in owned(table, id):
		var bonus: Dictionary = row("Bonus", int(link.BonusID))
		var type: Dictionary = row("BonusType", int(bonus.get("BonusTypeID", -1)))
		result.append({"link":link,"bonus":bonus,"type":type,"unit":row("Unit",int(type.get("UnitID",-1)))})
	return result

func values(table: String, id: int, name: String, unit: String = "") -> Array:
	var result: Array = []
	for detail: Dictionary in bonuses(table, id):
		# Conditions are retained in bonuses(), never collapsed into unconditional values.
		if detail.type.get("Name") != name or int(detail.bonus.get("BonusApplicationTypeID",-1)) != 0 or int(detail.bonus.get("BonusApplicationTargetID",-1)) != 0: continue
		if int(detail.link.get("MinSpellLevel",0)) != 0 or int(detail.link.get("CharacterLevel",0)) != 0 or int(detail.link.get("CharacterClass",0)) != 0: continue
		if not unit.is_empty() and detail.unit.get("Name") != unit: continue
		result.append(detail.bonus.Value)
	return result

func scalar(table: String, id: int, name: String, unit: String = "", fallback: float = 0.0) -> float:
	var found: Array = values(table,id,name,unit)
	return float(found[0]) if found.size() == 1 else fallback

func spell_chain(id: int, visited: Array = []) -> Dictionary:
	if visited.has(id) or visited.size() >= 32: return {"id":id,"pending":"cycle_or_depth_limit"}
	var source: Dictionary = row("SpellClass",id)
	if source.is_empty(): return {"id":id,"pending":"missing_spell"}
	var next_seen: Array = visited.duplicate(); next_seen.append(id)
	var next: Array = []
	for detail: Dictionary in bonuses("SpellBonus",id):
		if detail.type.get("Name") == "NextSpellClassID" and detail.unit.get("Name") == "SpellClassID":
			next.append({"edge":detail,"spell":spell_chain(int(detail.bonus.Value),next_seen)})
	return {"source":source,"bonuses":bonuses("SpellBonus",id),"next":next}

func buff_details(id: int) -> Dictionary:
	var source: Dictionary = row("BuffClass",id)
	var statuses: Array = []; var invokes: Array = []
	for detail: Dictionary in bonuses("BuffBonus",id):
		if detail.type.get("Name") == "StatusEffectID":
			statuses.append({"id":int(detail.bonus.Value),"attributes":owned("StatusEffectAttr",int(detail.bonus.Value))})
		if detail.type.get("Name") == "InvokeOption":
			# Invoke target is ApplicationTargetID, not probability Value.
			invokes.append({"edge":detail,"source":row("InvokeOption",int(detail.bonus.get("BonusApplicationTargetID",0)))})
	return {"source":source,"group":row("BuffGroup",int(source.get("BuffGroupID",0))),"bonuses":bonuses("BuffBonus",id),"statuses":statuses,"invokes":invokes}

func duration(id: int) -> Vector2:
	var fixed: Array = values("SpellBonus",id,"SpellBuffDuration","Seconds")
	if fixed.size() == 1: return Vector2(float(fixed[0]),float(fixed[0]))
	var low: Array = values("SpellBonus",id,"SpellDebuffMinDuration","Seconds")
	var high: Array = values("SpellBonus",id,"SpellDebuffMaxDuration","Seconds")
	return Vector2(float(low[0]),float(high[0])) if low.size() == 1 and high.size() == 1 else Vector2.ZERO

func environment_buffs(land_id: int) -> Array:
	var result: Array = []
	for attribute: Dictionary in owned("LandAttribute",land_id):
		var type: Dictionary = row("LandAttributeType",int(attribute.LandAttributeTypeID))
		if type.get("Name") != "NpcBuff": continue
		result.append({"attribute":attribute,"territory":row("Territories",int(attribute.TerritoryID)),"buff":buff_details(int(attribute.Value)),"application":"requires_verified_position_and_environment_lifecycle"})
	return result
