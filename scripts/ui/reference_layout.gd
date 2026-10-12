extends RefCounted

# Measured from the official Korean guide screenshots, normalized to 1280x720.
# See docs/ui-rebuild-20261012/REFERENCES.md for image sizes and uncertainty.
const BASE = Vector2(1280,720)
const SHELF = Rect2(890,82,378,508)
const CHARACTER = Rect2(12,82,378,610)
const SLOT = Vector2(72,72)
const BAG_COLUMNS = 4
const QUICK_GROUP_SIZE = 5
const QUICK_PAGE_COUNT = 5
const QUICK_CAPACITY = 50
const QUICK_Y = 612.0
const QUICK_SIZE = 62.0
const QUICK_GAP = 5.0
const MOUSE_DRAG_DISTANCE = 8.0
const TOUCH_SCROLL_DISTANCE = 10.0
const TOUCH_HOLD_SECONDS = 0.30
const AUTO_DISTANCE = 28.0
const QUICK_PAGE_SWIPE_DISTANCE = 42.0
const TOUCH_PREVIEW_OFFSET = Vector2(0,-62)

static func quick_index(visible_index: int, pages: Array) -> int:
	var group: int = visible_index / QUICK_GROUP_SIZE
	return clampi(int(pages[group]),0,QUICK_PAGE_COUNT-1)*10+visible_index

static func quick_x(index: int) -> float:
	return (456.0 if index < 5 else 928.0)+(index%5)*(QUICK_SIZE+QUICK_GAP)
