extends SceneTree
## Read-only comparison of native resolver quotes to independently selected
## original rows. Generate the matrix with patch523_enhancement_family_matrix.py
## --cover-items, then pass the pinned ZIP, matrix and private JSONL after --.
const Source = preload("res://scripts/resources/current523_definition_rows.gd")
const Drops = preload("res://scripts/loot/patch523_monster_drops.gd")
const Book = preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const Enhance = preload("res://scripts/crafting/patch523_enhancement.gd")
const Outcomes = {"success":"success","destroy":"destroy","remain":"no_change","side":"decrease"}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or FileAccess.get_sha256(args[0]) != Source.SOURCE_SHA:
		printerr("A pinned definition ZIP, full item matrix and private output path are required")
		quit(1)
		return
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", args[0])
	Source.reset()
	var matrix: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var output := FileAccess.open(args[2], FileAccess.WRITE)
	if not matrix is Dictionary or matrix.is_empty() or output == null:
		quit(2)
		return
	var counts := {}
	var items := {}
	for key: String in matrix:
		for fixture: Dictionary in matrix[key]:
			var result := compare(int(key), fixture)
			counts[result] = int(counts.get(result, 0)) + 1
			items[int(fixture.target)] = true
			items[int(fixture.scroll)] = true
			output.store_line(JSON.stringify({"group":int(key), "target":int(fixture.target), "scroll":int(fixture.scroll),
				"level":int(fixture.level), "target_bless":int(fixture.target_bless), "scroll_bless":int(fixture.scroll_bless), "result":result}))
	output.close()
	print("ENHANCEMENT_PAIRS_RESULT ", JSON.stringify({"groups":matrix.size(), "distinct_items":items.size(), "quotes":counts}))
	quit(1 if counts.has("numeric_difference") else 0)

func compare(group: int, fixture: Dictionary) -> String:
	var target_id := str(int(fixture.target))
	var scroll_id := str(int(fixture.scroll))
	var target: Dictionary = Drops.definition_id(target_id).get("native_record", {})
	var scroll: Dictionary = Drops.definition_id(scroll_id).get("native_record", {})
	if target.is_empty() or scroll.is_empty():
		return "record_unavailable"
	if int(fixture.scroll_bless) == 2:
		scroll = Drops.variant_item(scroll, 2)
	var book := Book.new()
	if not Book.declares_scroll(scroll) or not book.bind(target, target_id, scroll, scroll_id, null):
		return "binding_refused"
	var quote := Enhance.rule(book, target, scroll_id, int(fixture.level), int(fixture.target_bless), int(fixture.scroll_bless))
	if not quote.has("group"):
		return "quote_unavailable"
	if int(quote.group) != group or int(quote.get("cost", -1)) != int(fixture.cost) or int(quote.get("count", -1)) != int(fixture.count):
		return "numeric_difference"
	for name: String in Outcomes:
		if not is_equal_approx(float(quote.get(Outcomes[name], -1)), float(fixture[name]) / 10000.0):
			return "numeric_difference"
	return "quote_matches_source"
