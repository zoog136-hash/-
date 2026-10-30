extends RefCounted
## Derived state only: the existing card_draw_fusion.owned save remains the
## sole acquisition ledger. Loading old owned cards is silent and idempotent.
const Rules=preload("res://scripts/cards/collection_rules.gd")
const ExistingStats=preload("res://scripts/collections/equipment_collection_stats.gd")
const PATH: String="res://data/cards/normal_collections.json"
var world: Node
var core=Rules.new()
var problem: String=""
var revision: int=0
var rebuild_count: int=0
var totals: Dictionary={}
var _views: Array=[]
var _completed: Dictionary={}
var _announced: Dictionary={}
var _record: Dictionary={}
var _dirty: bool=true
var _has_cache: bool=false
var _owned_hash: int=0

func configure(host: Node) -> bool:
	world=host
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if not data is Dictionary:
		problem="일반 카드 컬렉션 데이터 누락/손상";return false
	if not core.configure(data,world.catalog_db):problem=core.error;return false
	problem="";restore_from_owned();return true

func invalidate() -> void:_dirty=true

func current_revision() -> int:
	_ensure();return revision

func _ensure() -> void:
	if not _dirty or world==null or not problem.is_empty():return
	_dirty=false
	var owned: Dictionary=world.card_draw_fusion.owned
	var signature: int=hash(owned)
	if _has_cache and signature==_owned_hash:return
	_owned_hash=signature;_has_cache=true
	var derived: Dictionary=core.derive({"owned":owned})
	_views=derived.rows;totals=derived.totals;_completed=derived.completed
	_record=ExistingStats.record(totals)
	if not _record.is_empty():
		_record.erase("_equipment_collection_bonus")
		_record["_card_collection_bonus"]=true
	revision+=1;rebuild_count+=1

func restore_from_owned() -> void:
	_dirty=true;_has_cache=false;_ensure()
	# An old save already owned these cards. Rebuilding progress must neither
	# grant cards nor announce every achievement again after each reload.
	_announced=_completed.duplicate()

func reconcile() -> Array[String]:
	_ensure()
	var newly_completed: Array[String]=[]
	for identity: String in _completed:
		if not _announced.has(identity):newly_completed.append(identity)
		_announced[identity]=true
	return newly_completed

func snapshot(category: String="",card_id: String="") -> Array:
	_ensure()
	var rows: Array=[]
	for row: Dictionary in _views:
		if not category.is_empty() and str(row.category)!=category:continue
		if not card_id.is_empty() and not row.requirements.any(func(requirement: Dictionary) -> bool:return str(requirement.id)==card_id and str(requirement.category)==category):continue
		rows.append(row.duplicate(true))
	return rows

func bonus(code: String) -> float:
	_ensure();return float(totals.get(code,0.0))

func catalog_bonus(key: String) -> int:
	_ensure()
	var extra: Dictionary={"potionHealFlat":"potion_heal:flat","potionHealPct":"potion_heal:percent"}
	return int(totals.get(extra[key],0)) if extra.has(key) else ExistingStats.catalog_bonus(totals,key)

func stat_record() -> Dictionary:
	_ensure();return _record
