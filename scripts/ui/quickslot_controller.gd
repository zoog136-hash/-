extends RefCounted

const BANKS := 2
const PAGES := 3
const SLOTS := 4
const CAPACITY := BANKS * PAGES * SLOTS
const PATH := "user://twilight_ui_settings.cfg"
var pages: Array[int] = [0, 0]

func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for bank: int in BANKS:
			pages[bank] = clampi(int(cfg.get_value("quickslots", str(bank), 0)), 0, PAGES - 1)

# Interleaving preserves every old 8-slot save in the first visible pair.
func index_for(visible: int) -> int:
	var bank: int = visible / SLOTS
	return pages[bank] * (BANKS * SLOTS) + visible

func change_page(bank: int, direction: int) -> void:
	pages[bank] = posmod(pages[bank] + direction, PAGES)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for index: int in BANKS: cfg.set_value("quickslots", str(index), pages[index])
	if cfg.save(PATH) != OK: push_warning("Quickslot page settings could not be saved")

static func label_for(index: int) -> String:
	return "%s %d-%d" % ["왼쪽" if index % 8 < 4 else "오른쪽", index / 8 + 1, index % 4 + 1]
