extends SceneTree
## Craft window first open: the 523 craft item index reads one lazy item
## template per item (~30,000). NATIVE_FIELDS.prefetch_templates decodes a
## block of them on worker threads with their own read handles; the reads it
## serves must be exactly the ordinary store.record() values, and the index
## must be byte-identical with and without it. A synthetic template file
## always runs; with the original definition ZIP the real index is compared
## in actual Main.
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const PATH := "user://craft_index_template_prefetch_test.bin"
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT_INDEX_PREFETCH_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func synthetic() -> void:
	var previous_store: Object = FIELDS._store
	var previous_script: Script = FIELDS._weight_script
	FIELDS.end_prefetch()
	check(FIELDS.prefetch_templates(PackedStringArray(["1"])) == 0, "a short block is read the ordinary way")
	# Below the processor floor nothing is read ahead; the checks lower it.
	evidence["processors"] = OS.get_processor_count()
	FIELDS.prefetch_min_processors = 2
	var writer := FileAccess.open(PATH, FileAccess.WRITE)
	var offsets: Dictionary = {}
	var ids := PackedStringArray()
	for id: int in range(1000, 1600):
		var key: String = str(id)
		offsets[key] = writer.get_position()
		writer.store_var({"name":"item %d" % id,"source_item_class_id":id})
		writer.store_var({"keys":["name","source_item_class_id","source_original_item","source_use_spec"],"fields":{"source_original_item":{"ID":id,"Name":"원본 %d" % id,"Rows":[id,id+1]},"source_use_spec":{"kind":"k%d" % (id % 7)}}})
		ids.append(key)
	ids.append("999999") # no template: the ordinary read decides it
	writer.close()
	var store: Object = PROJECTION.TemplateStore.new()
	store.file = FileAccess.open(PATH, FileAccess.READ)
	store.offsets = offsets
	store.interning = false
	FIELDS.bind(store, PROJECTION.TemplateStore)
	var expected: Dictionary = {}
	for id: String in ids: expected[id] = store.record(id)
	var held: int = FIELDS.prefetch_templates(ids)
	evidence["synthetic_held"] = held
	check(OS.get_processor_count() < 2 or held == 600, "600 templates decoded ahead (%d)" % held)
	var same: bool = true
	for id: String in ids:
		var lazy: Dictionary = {"source_item_class_id":int(id),FIELDS.MARK:true}
		var original: Variant = expected[id].get("source_original_item") if expected[id] is Dictionary else null
		if var_to_bytes(FIELDS.field(lazy,"source_original_item")) != var_to_bytes(original): same = false
		if var_to_bytes(FIELDS.full(lazy)) != var_to_bytes(FIELDS._merge_full(lazy, expected[id] if expected[id] is Dictionary else {})): same = false
	check(same, "every prefetched read equals store.record()")
	FIELDS.end_prefetch()
	check(FIELDS._prefetched.is_empty(), "end_prefetch drops the block")
	store.interning = true
	check(FIELDS.prefetch_templates(ids) == 0, "an interning store is not read ahead")
	FIELDS.prefetch_min_processors = 1000
	store.interning = false
	check(FIELDS.prefetch_templates(ids) == 0, "below the processor floor nothing is read ahead")
	FIELDS.prefetch_min_processors = 2
	FIELDS.bind(previous_store, previous_script)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	FIELDS.prefetch_enabled = false
	world.patch523_craft_item_cache = {}
	var started: int = Time.get_ticks_usec()
	var plain: Dictionary = world._patch523_craft_item_index()
	var plain_ms: int = (Time.get_ticks_usec() - started) / 1000
	FIELDS.prefetch_enabled = true
	world.patch523_craft_item_cache = {}
	started = Time.get_ticks_usec()
	var fast: Dictionary = world._patch523_craft_item_index()
	var fast_ms: int = (Time.get_ticks_usec() - started) / 1000
	# Main-thread share once decoding is fully off the main thread: each block
	# is decoded ahead first (not timed), then only its indexing is timed.
	var rest: Dictionary = world._craft_item_index().duplicate()
	var ids: Array = (world.patch523_equipment.data.get("items",{}) as Dictionary).keys()
	var main_us: int = 0
	for start: int in range(0, ids.size(), 1024):
		var block := PackedStringArray(ids.slice(start, start + 1024))
		FIELDS.prefetch_templates(block)
		var block_started: int = Time.get_ticks_usec()
		for id: String in block: world._patch523_craft_index_item(rest, id)
		main_us += Time.get_ticks_usec() - block_started
	FIELDS.end_prefetch()
	check(var_to_bytes(rest) == var_to_bytes(plain), "block-wise indexing gives the same index")
	evidence["index"] = {"entries":fast.size(),"ordinary_ms":plain_ms,"prefetch_ms":fast_ms,"main_thread_ms_without_decoding":main_us/1000,"cpus":OS.get_processor_count()}
	check(fast.size() > 30000, "original craft item index built (%d)" % fast.size())
	check(var_to_bytes(fast) == var_to_bytes(plain) and fast.keys() == plain.keys(), "the index is byte-identical with read-ahead")
	check(FIELDS._prefetched.is_empty(), "no template is held after the index")
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed(): await actual_main()
	print("CRAFT_INDEX_PREFETCH_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
