extends RefCounted
## Original 523 item grade presentation, read from the tables only:
## - name color: Grade.ColorID -> ColorTable (Type 1 = RGB888 hex), e.g.
##   Grade6 "신화" ColorID 412 -> ColorTable 412 "Grade6" ffde00;
## - floor drop effect: UIItemDropEffect (per ItemClassID) before
##   Grade.DropItemEffectSpriteID (Grade3..Grade7 -> 23195/23197/23200/23203/23206,
##   SPR "Effect_Drop_Item_{Rare,Hero,Legend,Myth,Sole}_upper_sc", action 3 "breath");
##   ItemDropEffectInvisible lists items that show none.
## Nothing is returned when a row is absent: callers keep their own state and
## never substitute another color or effect for a missing original.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
static var _identity: Dictionary = {}
static var _by_label: Dictionary = {}
static var _rows: Dictionary = {}

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func _ready() -> bool:
	var identity: Dictionary = SOURCE.identity() if not SOURCE.not_installed() else {}
	if identity.is_empty(): return false
	if identity == _identity: return true
	_identity = identity.duplicate(true); _by_label.clear(); _rows.clear()
	for index: int in range(SOURCE.row_count("Grade")):
		var row: Dictionary = SOURCE.row_at("Grade",index)
		if not _int(row.get("ID")) or not SOURCE.declared_exclusion("Grade",row).is_empty(): continue
		_rows[int(row.ID)] = row
		var label: String = str(SOURCE.row("DescData_Korean",int(row.get("DescID",0))).get("Description","")).strip_edges()
		# One label can name two rows ("일반" is None and Grade1): the row shown
		# in item information (IsItemInfoVisible) is the item grade.
		if label.is_empty() or (_by_label.has(label) and row.get("IsItemInfoVisible")!=true): continue
		_by_label[label] = int(row.ID)
	return true

## Grade row of a native record (source_grade_id) or of a grade label.
static func grade_id(record_or_label: Variant) -> int:
	if not _ready(): return -1
	if record_or_label is Dictionary:
		var record: Dictionary = record_or_label
		var value: Variant = record.get("source_grade_id")
		if _int(value) and _rows.has(int(value)): return int(value)
		return int(_by_label.get(str(record.get("grade","")),-1))
	return int(_by_label.get(str(record_or_label),-1))

static func row(id: int) -> Dictionary:
	return _rows.get(id,{}) if _ready() else {}

## {"ok":true,"color":Color,"hex","grade_id","color_table_id","color_table_name"} or ok false.
static func color_info(record_or_label: Variant) -> Dictionary:
	var id: int = grade_id(record_or_label)
	var grade: Dictionary = row(id)
	if grade.is_empty() or not _int(grade.get("ColorID")): return {"ok":false,"reason":"source_grade_row_missing"}
	var table: Dictionary = SOURCE.row("ColorTable",int(grade.ColorID))
	var hex: String = str(table.get("Value",""))
	if table.is_empty() or not _int(table.get("Type")) or int(table.Type)!=1 or hex.length()!=6 or not Color.html_is_valid("#"+hex): return {"ok":false,"reason":"source_grade_color_unresolved","grade_id":id}
	return {"ok":true,"color":Color("#"+hex),"hex":hex.to_lower(),"grade_id":id,"color_table_id":int(table.ID),"color_table_name":str(table.get("Name",""))}

## The original grade color, or `fallback` when the 523 tables give none.
static func color(record_or_label: Variant, fallback: Color) -> Color:
	var info: Dictionary = color_info(record_or_label)
	return info.color if info.ok else fallback

## Floor drop effect of an ItemClass row: {"ok":true,"sprite_id","basis"} or ok false.
static func drop_effect(original_item: Dictionary) -> Dictionary:
	if not _ready() or not _int(original_item.get("ID")) or not _int(original_item.get("GradeID")): return {"ok":false,"reason":"source_item_required"}
	var item: int = int(original_item.ID)
	for link: Dictionary in SOURCE.related("ItemDropEffectInvisible","ItemClassID",item):
		if SOURCE.declared_exclusion("ItemDropEffectInvisible",link).is_empty(): return {"ok":false,"reason":"source_drop_effect_invisible","basis":"ItemDropEffectInvisible"}
	var own: Array = []
	for link: Dictionary in SOURCE.related("UIItemDropEffect","ItemClassID",item):
		if SOURCE.declared_exclusion("UIItemDropEffect",link).is_empty() and _int(link.get("DropEffectSpriteID")): own.append(int(link.DropEffectSpriteID))
	if own.size()==1 and int(own[0])>0: return {"ok":true,"sprite_id":int(own[0]),"basis":"UIItemDropEffect","grade_id":int(original_item.GradeID)}
	if own.size()>1: return {"ok":false,"reason":"source_drop_effect_ambiguous"}
	var grade: Dictionary = row(int(original_item.GradeID))
	if grade.is_empty() or not _int(grade.get("DropItemEffectSpriteID")): return {"ok":false,"reason":"source_grade_row_missing"}
	if int(grade.DropItemEffectSpriteID)<=0: return {"ok":false,"reason":"source_grade_has_no_drop_effect","grade_id":int(grade.ID)}
	return {"ok":true,"sprite_id":int(grade.DropItemEffectSpriteID),"basis":"Grade.DropItemEffectSpriteID","grade_id":int(grade.ID)}
