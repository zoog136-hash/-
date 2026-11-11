extends RefCounted
## Saved roster of original 523 NPC production units (NpcClassID -> count)
## and the last attempts. World saves it under KEY; a damaged value blocks
## saving instead of being replaced.
const KEY: String = "npc_production523"
const SCHEMA: int = 1
const HISTORY: int = 20
const MAX_COUNT: int = 1000000
var state: Dictionary = fresh()
var save_blocked: bool = false

static func fresh() -> Dictionary:
	return {"schema":SCHEMA,"units":{},"history":[]}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "NPC 생산 저장 형식 오류"
	if not _integer(value.get("schema")) or int(value.schema)!=SCHEMA: return "NPC 생산 저장 버전 불일치"
	if not value.get("units") is Dictionary or not value.get("history") is Array: return "NPC 생산 저장 형식 오류"
	for key: Variant in value.units:
		var text: String = str(key)
		if not text.is_valid_int() or int(text)<=0 or str(int(text))!=text: return "NPC 생산 유닛 ID 형식 오류"
		var count: Variant = value.units[key]
		if not _integer(count) or int(count)<1 or int(count)>MAX_COUNT: return "NPC 생산 유닛 수량 형식 오류"
	if value.history.size()>HISTORY: return "NPC 생산 기록 길이 오류"
	for entry: Variant in value.history:
		if not entry is Dictionary or not str(entry.get("kind","")) in ["summon","combination"]: return "NPC 생산 기록 형식 오류"
	return ""

## Loaded JSON numbers are floats; the roster keeps whole numbers as int.
static func _whole(value: Variant) -> Variant:
	if value is float and is_finite(value) and value==floorf(value) and absf(value)<=9007199254740991.0: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _whole(value[key])
		return result
	if value is Array:
		var items: Array = []
		for item: Variant in value: items.append(_whole(item))
		return items
	return value

func accept(value: Dictionary) -> void:
	state = _whole(value)
	save_blocked = false

func export_state() -> Dictionary:
	return state.duplicate(true)

func count(npc_class_id: int) -> int:
	return int(state.units.get(str(npc_class_id),0))

## A copy of `base` with unit deltas applied and `entry` appended to history.
static func staged(base: Dictionary, deltas: Dictionary, entry: Dictionary) -> Dictionary:
	var next: Dictionary = base.duplicate(true)
	for key: Variant in deltas:
		var id: String = str(key)
		var amount: int = int(next.units.get(id,0))+int(deltas[key])
		if amount>0: next.units[id] = amount
		else: next.units.erase(id)
	next.history.append(entry.duplicate(true))
	while next.history.size()>HISTORY: next.history.pop_front()
	return next
