extends SceneTree
## Standalone synthetic check of scripts/resources/bounded_weak_lru.gd (no Main,
## no original data, no files). Run:
##   godot --headless --path <repo> --script res://tests/bounded_weak_lru_test.gd
const LRU = preload("res://scripts/resources/bounded_weak_lru.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("BOUNDED_WEAK_LRU_FAIL: " + label)

func tex() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_order_and_bounds()
	_weak_reuse()
	_values_without_weak_form()
	_cost_bound()
	_trim_and_clear()
	_churn()
	print("BOUNDED_WEAK_LRU_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _order_and_bounds() -> void:
	var cache: RefCounted = LRU.new(2)
	var a: Texture2D = tex()
	var b: Texture2D = tex()
	var c: Texture2D = tex()
	cache.store("a", a)
	cache.store("b", b)
	check(cache.lookup("a") == a, "strong hit returns the stored instance")
	cache.store("c", c)
	check(cache.strong_size() == 2 and cache._strong.has("a") and cache._strong.has("c") and not cache._strong.has("b"), "least recently used entry is evicted first")
	check(cache.lookup("b") == b and cache.metrics().weak_hits == 1, "an evicted value still owned elsewhere comes back through the weak side")
	check(cache.strong_size() == 2, "a weak hit is re-admitted within the bound")
	check(cache.lookup("missing") == null and cache.metrics().misses == 1, "an unknown key misses")

func _weak_reuse() -> void:
	var cache: RefCounted = LRU.new(0)
	var owner: Array = [tex()]
	var id: int = (owner[0] as Object).get_instance_id()
	cache.store("k", owner[0])
	check(cache.strong_size() == 0 and cache.tracked_size() == 1, "max_entries 0 keeps a weak handle only")
	check(cache.lookup("k") != null and (cache.lookup("k") as Object).get_instance_id() == id, "weak-only lookup returns the exact live instance")
	owner.clear()
	check(cache.lookup("k") == null, "the cache never keeps a value alive once its last owner drops it")
	check(cache.tracked_size() == 0, "a dead weak entry is forgotten")

func _values_without_weak_form() -> void:
	var cache: RefCounted = LRU.new(1)
	var first: Dictionary = {"x":1}
	cache.store("d1", first)
	check(cache.lookup("d1") == first and is_same(cache.lookup("d1"), first), "dictionary hit is the stored instance")
	cache.store("d2", {"x":2})
	check(cache.lookup("d1") == null and cache.tracked_size() == 0, "an evicted dictionary is gone (no weak form) and leaves no metadata")
	check(cache.lookup("d2").x == 2, "newest dictionary stays")

func _cost_bound() -> void:
	var cache: RefCounted = LRU.new(10, 100)
	var held: Array = []
	for index: int in 5:
		var value: Texture2D = tex()
		held.append(value)
		cache.store(index, value, 40)
	check(cache.strong_cost() <= 100 and cache.strong_size() == 2, "cost bound holds (2 x 40 <= 100)")
	check(cache._strong.has(3) and cache._strong.has(4), "newest entries are kept under the cost bound")
	var big: Texture2D = tex()
	cache.store("big", big, 500)
	check(not cache._strong.has("big") and cache.lookup("big") == big, "an entry larger than the whole bound is only weakly tracked")
	cache.store(4, held[4], 60)
	check(cache.strong_cost() == 100 and cache.strong_size() == 2, "re-storing a key replaces its cost without double counting")

func _trim_and_clear() -> void:
	var cache: RefCounted = LRU.new(8)
	var held: Array = []
	for index: int in 6:
		held.append(tex())
		cache.store("t%d" % index, held[index])
	cache.trim(2)
	check(cache.strong_size() == 2 and cache._strong.has("t4") and cache._strong.has("t5"), "trim keeps the most recent reserve")
	check(cache.lookup("t0") == held[0], "trim drops only the cache's own reference")
	cache.clear()
	check(cache.strong_size() == 0 and cache.strong_cost() == 0 and cache.lookup("t1") == held[1], "clear keeps weak reuse while owners live")
	cache.clear(true)
	check(cache.tracked_size() == 0 and cache.lookup("t1") == null, "clear(true) forgets everything")
	cache.store("bad", null)
	check(cache.tracked_size() == 0 and not cache.has("bad"), "null is never stored")

func _churn() -> void:
	var cache: RefCounted = LRU.new(5, 64)
	var owned: Array = []
	var within: bool = true
	for index: int in 300:
		var value: Texture2D = tex()
		if index % 3 == 0: owned.append(value)
		cache.store("k%d" % index, value, 16)
		if index % 7 == 0: cache.lookup("k%d" % (index / 2))
		if cache.strong_size() > 4 or cache.strong_cost() > 64 or cache._order.size() != cache._strong.size(): within = false
		var total: int = 0
		for key: Variant in cache._strong: total += int(cache._cost[key])
		if total != cache.strong_cost(): within = false
	check(within, "bounds and bookkeeping hold after each of 300 insertions")
	var live: bool = true
	for index: int in range(0, 300, 3):
		var found: Variant = cache.lookup("k%d" % index)
		if found != null and not is_same(found, owned[index / 3]): live = false
	check(live, "any weak hit under churn is the owner's exact instance")
