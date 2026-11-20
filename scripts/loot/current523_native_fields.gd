extends RefCounted
## Item template access for registered native records (Lineage M style).
##
## Registered native records keep their light identity fields in the catalog;
## the heavy, read-mostly fields below stay in the baked item template and are
## read back by ItemClass ID when a record is actually used or shown. full()
## returns exactly the record registration produced: template key order, the
## record's own current values for every key it holds (later edits such as
## grade sync win), the template's values for the heavy fields it left out.
## Records without the marker (non-native, saved, edited) are returned as is.

## Heavy or rarely read registration fields. Readers go through full().
## The second group is read only by a few item checks and detail views; each
## key costs ~2.4 MB resident across the 30,310 registered records.
const HEAVY: Array[String] = ["source_use_spec","source_original_item","source_unhandled_bonuses","source_mapped_bonuses",
	"source_acquisition_policy","source_catalog_eligible","source_category_is_activatable","source_equip_slots","source_icon_id",
	"source_sprite_animation_id","source_unhandled_bonus_ids","source_weapon_type_name","source_effect_scope",
	"source_is_deletable","source_is_droppable","source_is_trash","source_label_status","source_max_level_limit_max",
	"source_max_level_limit_min","source_weight_unit","source_is_storable","source_effect_status","source_equipment_status",
	"source_unresolved_class_ids","source_is_tradable","source_is_consumable","source_category_id","source_class_names",
	# Third group: identity/condition fields read only on use, equip, craft
	# checks, detail views and messages, never per frame. Readers use field()/
	# has_field() (one key) or full(). Identity keys (source_item_class_id,
	# source_m_native_item, source_snapshot, source_definition_archive,
	# source_bless_raw), per-frame UI keys (source_sprite_id, source_grade_id)
	# and generic inventory keys (droppable, storable) stay resident.
	"source_image_status","source_condition_pending","source_weight","source_class_ids","source_equip_slot_ids",
	"source_level_limit_min","source_level_limit_max","source_delete_time_raw","source_is_stackable","tradable",
	"deletable","source_display_name","source_category_name"]
const MARK := "twilight_lazy_native_fields"
## Item templates kept in memory (~4 KB each). 128 was smaller than one
## inventory pass: about 100 items are checked every frame, so with more items
## than this each frame read ~10 templates from disk again (523.699 trace:
## native item record reads ~1.1 ms per frame on a PC, ~4 ms on the phone).
const CACHE_LIMIT := 512

static var _store: Object = null
static var _cache: Dictionary = {}
static var _order: Array[String] = []
static var _weight_store_exact: bool = false
static var _weight_script: Script = null
const WEIGHT_FIELDS: Array[String] = ["source_weight_unit","source_original_item","source_weight"]

static func bind(store: Object, weight_script: Script = null) -> void:
	_store = store
	_weight_script = weight_script
	# Only the private producer supplies its exact nested Script. Default/public
	# binding never opts a generic provider into this optimization. No reverse
	# load dependency from this shared adapter to the entire item producer.
	_weight_store_exact = store != null and weight_script != null and store.get_script() == weight_script and weight_script.get_base_script() == null and store.has_method("_weight_fields_for_binding")
	_cache.clear()
	_order.clear()

static func lazy(record: Variant) -> bool:
	return record is Dictionary and (record as Dictionary).get(MARK) == true

## The light catalog form of a full registered record.
static func slim(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in record:
		if not key in HEAVY: result[key] = record[key]
	result[MARK] = true
	return result

static func full(record: Variant) -> Variant:
	if not lazy(record): return record
	var template: Dictionary = _template(str(int((record as Dictionary).get("source_item_class_id", 0))))
	return _merge_full(record,template)

static func _merge_full(record: Dictionary, template: Dictionary) -> Dictionary:
	if template.is_empty():
		var bare: Dictionary = (record as Dictionary).duplicate(false)
		bare.erase(MARK)
		return bare
	var result: Dictionary = {}
	for key: Variant in template:
		if (record as Dictionary).has(key): result[key] = record[key]
		elif key in HEAVY: result[key] = _copy(template[key])
	for key: Variant in record:
		if key != MARK and not result.has(key): result[key] = record[key]
	return result

## Internal compiler-only expansion. An already cached template, a generic
## store or an unavailable fast path retains full() and its snapshot/cache
## behavior. Public full()/field()/has_field() and their copy contracts stay
## unchanged. A successful real-store expansion holds at most one full item.
static func _full_for_binding(record: Variant) -> Variant:
	if not lazy(record) or _store == null: return full(record)
	var id: String = str(int((record as Dictionary).get("source_item_class_id",0)))
	if _cache.has(id) or not _store.has_method("_expanded_for_binding"): return full(record)
	var expanded: Variant = _store.call("_expanded_for_binding",id,record)
	return expanded if expanded is Dictionary else full(record)

## Private cold compiler: a separate read handle and cache/order snapshot.
## Its worker never touches this adapter's live provider/cache or Source state.
class BindingReader extends RefCounted:
	var provider: Object
	var merge: Callable
	var read_error: int=OK
	var cache: Dictionary={}
	var order: Array[String]=[]
	func full_for_binding(record: Variant) -> Variant:
		if not record is Dictionary or record.get(MARK)!=true:return record
		var id: String=str(int(record.get("source_item_class_id",0)))
		if not cache.has(id):
			var expanded: Variant=provider.call("_expanded_for_binding",id,record)
			var error: int=provider.file.get_error()
			if error!=OK:read_error=error
			if expanded is Dictionary:return expanded
			var value: Variant=provider.call("record",id)
			error=provider.file.get_error()
			if error!=OK:read_error=error
			cache[id]=value if value is Dictionary else {}
			order.append(id)
			if order.size()>CACHE_LIMIT:cache.erase(order.pop_front())
		return merge.call(record,cache[id])

static func _binding_reader(provider: Object) -> BindingReader:
	if not _weight_store_exact or _store==null or _store.get_script()!=_weight_script or provider==null or provider.get_script()!=_weight_script:return null
	var reader:=BindingReader.new();reader.provider=provider;reader.merge=_merge_full;reader.cache=_cache.duplicate(false);reader.order=_order.duplicate()
	return reader

static func _selected_for_binding(record: Variant, fields: Array[String]) -> Variant:
	if not record is Dictionary:return _full_for_binding(record)
	if _weight_store_exact and _store!=null and _store.get_script()==_weight_script and lazy(record):
		var id: String=str(int(record.get("source_item_class_id",0)))
		if not _cache.has(id):
			var selected: Variant=_store.call("_selected_for_binding",id,record,fields)
			if selected is Dictionary:return selected
	var full_record: Variant=_full_for_binding(record)
	if not full_record is Dictionary:return full_record
	var selected: Dictionary={}
	for key: String in fields:
		if full_record.has(key):selected[key]=full_record[key]
	return selected

## Weight validation reads exactly these three fields. Only the exact real,
## uncached, non-interning store may avoid assembling unrelated detail fields.
## Generic/subclass/cached reads keep the prior full expansion and call count.
static func _weight_fields_for_binding(record: Dictionary) -> Dictionary:
	if _weight_store_exact and _store != null and _store.get_script() == _weight_script and lazy(record):
		var id: String = str(int(record.get("source_item_class_id",0)))
		if not _cache.has(id):
			var projected: Variant = _store.call("_weight_fields_for_binding",id,record)
			if projected is Dictionary: return projected
			return _weight_projection(full(record))
	return _weight_projection(_full_for_binding(record))

static func _weight_projection(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in WEIGHT_FIELDS:
		if record.has(key): result[key] = record[key]
	return result

## One key of full(record), without building the whole record: the record's
## own value when it holds the key, the template's value for a heavy key it
## left out, otherwise `default`. Same value (and copy semantics) as
## full(record).get(key, default).
static func field(record: Variant, key: String, default: Variant = null) -> Variant:
	if not record is Dictionary: return default
	var own: Dictionary = record
	if own.has(key): return own[key] if key != MARK or own.get(MARK) != true else default
	if own.get(MARK) != true or not key in HEAVY: return default
	var template: Dictionary = _template(str(int(own.get("source_item_class_id", 0))))
	return _copy(template[key]) if template.has(key) else default

## field() without its copy, for read-only comparisons over many records
## (the craft item index). Never mutate or store the result.
static func field_view(record: Variant, key: String, default: Variant = null) -> Variant:
	if not record is Dictionary: return default
	var own: Dictionary = record
	if own.has(key): return own[key] if key != MARK or own.get(MARK) != true else default
	if own.get(MARK) != true or not key in HEAVY: return default
	var template: Dictionary = _template(str(int(own.get("source_item_class_id", 0))))
	return template[key] if template.has(key) else default

## full(record).has(key) without building the whole record.
static func has_field(record: Variant, key: String) -> bool:
	if not record is Dictionary: return false
	var own: Dictionary = record
	if own.has(key): return key != MARK or own.get(MARK) != true
	if own.get(MARK) != true or not key in HEAVY: return false
	return _template(str(int(own.get("source_item_class_id", 0)))).has(key)

## full() for every record in an array (other values unchanged).
static func full_all(records: Array) -> Array:
	var result: Array = []
	for record: Variant in records: result.append(full(record))
	return result

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _template(id: String) -> Dictionary:
	if _cache.has(id): return _cache[id]
	if _prefetched.has(id): return _prefetched[id]
	if _store == null: return {}
	var value: Variant = _store.call("record", id)
	var template: Dictionary = value if value is Dictionary else {}
	_cache[id] = template
	_order.append(id)
	if _order.size() > CACHE_LIMIT: _cache.erase(_order.pop_front())
	return template

## Bulk read-ahead for one pass over many records (the craft item index reads
## one template per ~30,000 items, ~0.15-0.3 ms each). Worker threads decode
## the next block of templates through their own read handles while the
## caller works on the current one; _template() then serves those exact
## store.record() values instead of reading them one by one. Only the real
## template store (no subclass/provider substitution, string interning off)
## is read ahead; otherwise every read stays the ordinary one.
static var _prefetched: Dictionary = {}
## Test switch: false reads every template the ordinary way.
static var prefetch_enabled: bool = true
## Read-ahead runs only with this many processors: on a 2-core device a
## decoding worker competes with the main thread (measured slower), on a
## phone's 8 cores up to PREFETCH_WORKERS decode beside it.
static var prefetch_min_processors: int = 4
const PREFETCH_MIN := 256
const PREFETCH_WORKERS := 4

class TemplatePrefetch extends RefCounted:
	var fork: Object
	var ids: PackedStringArray
	var result: Dictionary = {}
	func run() -> void:
		for id: String in ids:
			var value: Variant = fork.call("record", id)
			if value is Dictionary: result[id] = value

## A started read-ahead of one block: {"jobs","threads"}, or {} (not read ahead).
static func prefetch_begin(ids: PackedStringArray) -> Dictionary:
	if not prefetch_enabled or ids.size() < PREFETCH_MIN or OS.get_processor_count() < maxi(2, prefetch_min_processors) or OS.get_thread_caller_id() != OS.get_main_thread_id(): return {}
	if _store == null or not _weight_store_exact or _store.get_script() != _weight_script or _weight_script.get_base_script() != null: return {}
	if _store.get("interning") != false or not _store.get("file") is FileAccess or not _store.get("offsets") is Dictionary: return {}
	var path: String = (_store.file as FileAccess).get_path_absolute()
	var length: int = (_store.file as FileAccess).get_length()
	var count: int = mini(PREFETCH_WORKERS, maxi(1, OS.get_processor_count() - 1))
	var jobs: Array[TemplatePrefetch] = []
	for index: int in count:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != length: return {}
		var fork: Object = _weight_script.new()
		fork.set("file", file)
		fork.set("offsets", (_store.offsets as Dictionary).duplicate(false))
		fork.set("interning", false)
		var job := TemplatePrefetch.new()
		job.fork = fork
		for position: int in range(index, ids.size(), count):
			if not _cache.has(ids[position]): job.ids.append(ids[position])
		jobs.append(job)
	var threads: Array[Thread] = []
	for job: TemplatePrefetch in jobs:
		var thread := Thread.new()
		if thread.start(job.run) != OK: job.run()
		else: threads.append(thread)
	return {"jobs":jobs,"threads":threads}

## Waits for a started block and serves it (the previous block is dropped).
static func prefetch_install(started: Dictionary) -> int:
	_prefetched.clear()
	if started.is_empty(): return 0
	for thread: Thread in started.threads: thread.wait_to_finish()
	for job: TemplatePrefetch in started.jobs:
		_prefetched.merge(job.result)
		job.fork = null
	started.clear()
	return _prefetched.size()

## Reads one block ahead now; returns how many templates are held.
static func prefetch_templates(ids: PackedStringArray) -> int:
	_prefetched.clear()
	return prefetch_install(prefetch_begin(ids))

static func end_prefetch() -> void:
	_prefetched.clear()
