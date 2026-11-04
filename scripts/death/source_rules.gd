extends RefCounted
## Reads the pinned, private original archive. No original rows are vendored.
const SHA: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PATH: String = "user://source_rules/death523.zip"
var fallback_loss_percent: float = 5.0
var fallback_cost_factor: int = 12
var experience: Dictionary = {}
var items: Dictionary = {}
var item_names: Dictionary = {}
var attributes: Array = []
var territories: Dictionary = {}
var ready: bool = false
var problem: String = "원본523 미설치 · TWILIGHT 추정 정책"

func load_pack(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SHA: return false
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return false
	var tables: Dictionary = {}
	for table: String in ["Experience","ItemClass","LandAttribute","Territories","DescData_Korean"]:
		var parser := JSON.new()
		if parser.parse(archive.read_file("content/"+table+".json").get_string_from_utf8()) != OK or not parser.data is Dictionary or not parser.data.get("rows") is Array:
			archive.close(); return false
		tables[table] = parser.data.rows
	archive.close()
	if tables.Experience.size() != 160 or tables.ItemClass.size() != 34743: return false
	var next_exp: Dictionary = {}
	for row: Dictionary in tables.Experience: next_exp[int(row.Level)] = row
	var descriptions: Dictionary = {}
	for row: Dictionary in tables.DescData_Korean: descriptions[int(row.ID)] = str(row.Description)
	var next_items: Dictionary = {}
	var next_names: Dictionary = {}
	for row: Dictionary in tables.ItemClass:
		var id: String = str(int(row.ID))
		next_items[id] = row
		next_names[id] = [str(descriptions.get(int(row.DescID),"")),str(descriptions.get(int(row.IdentifiedDescID),""))]
	var next_territories: Dictionary = {}
	for row: Dictionary in tables.Territories: next_territories[int(row.ID)] = row
	experience = next_exp; items = next_items; item_names = next_names; territories = next_territories
	attributes = tables.LandAttribute
	ready = true; problem = "최신523 원본 규칙 · 로컬 투영/추정 정책 별도"
	return true

func install(path: String) -> String:
	var candidate = get_script().new()
	if not candidate.load_pack(path): return "원본523 ZIP의 SHA 또는 정의표가 다릅니다"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir())) != OK: return "규칙 폴더 생성 실패"
	var temporary: String = PATH+".tmp"
	if DirAccess.copy_absolute(path,temporary) != OK or FileAccess.get_sha256(temporary) != SHA: return "규칙 복사 실패 · 이전 팩 보존"
	if DirAccess.rename_absolute(temporary,PATH) != OK: return "규칙 설치 실패 · 이전 팩 보존"
	if not load_pack(): return "규칙 재확인 실패"
	return ""

func matches_item(record: Dictionary, id: String) -> bool:
	# Inven/community and native IDs are never joined by number alone. Keep
	# blessing/variant words intact; missing or differing names are ineligible.
	return ready and items.has(id) and str(record.get("sourceId","")) == id and not str(record.get("name","")).is_empty() and item_names.get(id,[]).has(str(record.name))

func row(level: int) -> Dictionary:
	return experience.get(level,{})

func exp_loss(level: int, current: int, need: int) -> int:
	if level < 30: return 0
	var source: Dictionary = row(level)
	if source.is_empty(): return mini(current,maxi(0,int(floor(need*fallback_loss_percent/100.0))))
	var previous: Dictionary = row(level-1)
	var span: int = int(source.CumulativeExperience)-int(previous.get("CumulativeExperience",0))
	if span <= 0: return 0
	# Fractional projection onto TWILIGHT's existing curve; no level rollback.
	return mini(current,maxi(0,int(floor(float(need)*int(source.ExperienceLossOnDie)/span))))

func cost(level: int) -> int:
	return maxi(0,int(row(level).get("RestorationCost",level*level*fallback_cost_factor)))

func land_policy(land_id: int, source_position: Vector2) -> Dictionary:
	var out: Dictionary = {"no_exp":false,"no_item":false,"no_penalty":false,"npc_penalty":false,"full_revive":false,"source":false}
	if not ready or land_id < 0: return out
	for raw: Dictionary in attributes:
		if int(raw.LandID) != land_id: continue
		var kind: int = int(raw.LandAttributeTypeID)
		if kind not in [3,4,494,878,1122]: continue
		var territory_id: int = int(raw.TerritoryID)
		if territory_id != 0:
			if not source_position.is_finite() or not territories.has(territory_id): continue
			var t: Dictionary = territories[territory_id]
			if int(t.LandID) != land_id or source_position.x < mini(int(t.StartX),int(t.EndX)) or source_position.x > maxi(int(t.StartX),int(t.EndX)) or source_position.y < mini(int(t.StartY),int(t.EndY)) or source_position.y > maxi(int(t.StartY),int(t.EndY)): continue
		out.source = true
		if kind == 3: out.no_item = bool(raw.Value)
		if kind == 4: out.no_exp = bool(raw.Value)
		if kind == 494: out.npc_penalty = bool(raw.Value)
		if kind == 878: out.full_revive = bool(raw.Value)
		if kind == 1122: out.no_penalty = bool(raw.Value)
	return out
