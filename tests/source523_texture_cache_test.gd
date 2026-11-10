extends SceneTree
## Unit check of the image pack's texture cache helper alone (no pack, no
## original data, no user:// access). Textures are synthetic 2x2 images and the
## byte costs are the numbers passed to remember(). Run:
##   godot --headless --path <repo> --script res://tests/source523_texture_cache_test.gd
const CACHE = preload("res://scripts/resources/source523_texture_cache.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		if failures.size() < 20: failures.append(label)
		printerr("FAIL: " + label)

func tex() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))

func _initialize() -> void:
	_defaults()
	_lru_order_and_byte_budget()
	_oversize_and_zero_budget()
	_entry_cap()
	_weak_reuse_and_release()
	_trim_keeps_budget()
	_clear_modes()
	_metrics_snapshot()
	_replace_and_rejects()
	_bounded_under_churn()
	print("SOURCE523_TEXTURE_CACHE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,
		"scope":"helper_only_synthetic_textures"}))
	quit(0 if failures.is_empty() else 1)

func _defaults() -> void:
	var cache: RefCounted = CACHE.new()
	var metrics: Dictionary = cache.metrics()
	check(metrics.budget_bytes == 32 * 1024 * 1024 and metrics.max_entries == 4096, "package defaults are 32 MiB and 4096 entries")
	check(metrics.resident_entries == 0 and metrics.tracked_entries == 0 and metrics.misses == 0, "a new cache is empty")
	check(cache.lookup("nothing") == null and cache.metrics().misses == 1, "an unknown key is a miss")

func _lru_order_and_byte_budget() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(32, 10)
	var a: Texture2D = tex()
	var b: Texture2D = tex()
	var d: Texture2D = tex()
	cache.remember("a", a, 16)
	cache.remember("b", b, 16)
	check(cache.metrics().resident_decoded_bytes_estimate == 32 and cache.metrics().resident_entries == 2, "two entries fill the budget")
	check(cache.lookup("a") == a, "a resident hit returns the same texture")
	check(cache.metrics().resident_hits == 1, "resident hit counted")
	cache.remember("d", d, 16)
	check(cache._resident.has("a") and cache._resident.has("d") and not cache._resident.has("b"), "the least recently used entry (b) is evicted, the touched one (a) stays")
	check(cache.metrics().resident_decoded_bytes_estimate == 32 and cache.metrics().evictions == 1, "resident bytes stay within the budget")
	# b is no longer resident; this test still owns it, so it is found again.
	check(cache.lookup("b") == b and cache.metrics().weak_hits == 1, "an evicted texture that is still owned is reused")
	check(cache._resident.has("b") and cache._resident.has("d") and not cache._resident.has("a"), "re-admission evicts the oldest resident (a)")
	check(cache._resident_lru == ["d", "b"], "resident order is oldest first")
	cache.configure(16, 10)
	check(cache._resident.has("b") and cache.metrics().resident_entries == 1 and cache.metrics().resident_decoded_bytes_estimate == 16, "a smaller budget evicts at once, oldest first")
	check(cache.metrics().tracked_entries == 3, "eviction keeps weak tracking of owned textures")

func _oversize_and_zero_budget() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(32, 10)
	var small: Texture2D = tex()
	var big: Texture2D = tex()
	cache.remember("small", small, 16)
	cache.remember("big", big, 64)
	check(cache.metrics().resident_entries == 1 and cache.metrics().resident_decoded_bytes_estimate == 16, "an entry larger than the budget is not held and evicts nothing")
	check(cache.lookup("big") == big and cache.metrics().resident_entries == 1, "the oversize entry is still reused while owned")
	cache.configure(0, 10)
	check(cache.metrics().resident_entries == 0 and cache.metrics().resident_decoded_bytes_estimate == 0, "budget 0 holds nothing")
	cache.remember("zero", small, 16)
	check(cache.metrics().resident_entries == 0 and cache.lookup("zero") == small, "budget 0 still reuses owned textures")
	cache.configure(-5, -5)
	check(cache.metrics().budget_bytes == 0 and cache.metrics().max_entries == 0 and cache.metrics().tracked_entries == 0, "negative limits become 0")
	cache.remember("none", small, 16)
	check(cache.lookup("none") == null and cache.metrics().tracked_entries == 0, "entry cap 0 remembers nothing")

func _entry_cap() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(1024, 3)
	var owned: Array[Texture2D] = []
	for index: int in 5:
		owned.append(tex())
		cache.remember("k%d" % index, owned[index], 16)
	check(cache.metrics().tracked_entries == 3 and cache.metrics().resident_entries == 3, "the entry cap bounds tracked and resident entries")
	check(cache.metrics().resident_decoded_bytes_estimate == 48, "bytes follow the forgotten entries")
	var misses: int = cache.metrics().misses
	# Documented cost of the cap: an owned texture whose key was forgotten is
	# not found, so its caller decodes again.
	check(cache.lookup("k0") == null and cache.lookup("k1") == null and cache.metrics().misses == misses + 2, "the oldest keys are forgotten")
	check(cache.lookup("k2") == owned[2] and cache.lookup("k4") == owned[4], "the newest keys remain")
	cache.configure(1024, 1)
	check(cache.metrics().tracked_entries == 1 and cache.metrics().resident_entries == 1, "a smaller cap forgets at once")
	check(cache.lookup("k4") == owned[4], "the most recently used key survives the smaller cap")

func _weak_reuse_and_release() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(16, 8)
	var held: Texture2D = tex()
	var witness: WeakRef = weakref(held)
	cache.remember("held", held, 16)
	cache.remember("next", tex(), 16)
	check(not cache._resident.has("held") and witness.get_ref() != null, "an evicted texture lives on with its outside owner")
	check(cache.lookup("held") == held and cache.metrics().weak_hits == 1, "it is reused instead of decoded again")
	check(cache._resident.has("held") and not cache._resident.has("next"), "reuse makes it resident again")
	check(cache.lookup("next") == null, "an evicted texture nobody owns is gone")
	cache.remember("other", tex(), 16)
	held = null
	check(witness.get_ref() == null, "eviction plus the last outside release frees the texture")
	var tracked: int = cache.metrics().tracked_entries
	check(cache.lookup("held") == null, "a freed texture is never returned")
	check(cache.metrics().tracked_entries == tracked - 1, "its dead tracking entry is dropped on lookup")

func _trim_keeps_budget() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(64, 10)
	var owned: Array[Texture2D] = []
	for index: int in 4:
		owned.append(tex())
		cache.remember("k%d" % index, owned[index], 16)
	check(cache.metrics().resident_decoded_bytes_estimate == 64, "four entries resident")
	cache.trim_to(16)
	var metrics: Dictionary = cache.metrics()
	check(metrics.resident_decoded_bytes_estimate == 16 and metrics.resident_entries == 1 and cache._resident.has("k3"), "trim keeps only the newest within the target")
	check(metrics.budget_bytes == 64 and metrics.max_entries == 10, "trim does not change the configured limits")
	check(metrics.tracked_entries == 4, "trim keeps weak tracking")
	for index: int in 4: check(owned[index].get_width() == 2, "trim leaves owned textures usable")
	check(cache.lookup("k0") == owned[0] and cache.metrics().resident_entries == 2, "after a trim the budget admits entries again")
	cache.trim_to(-100)
	check(cache.metrics().resident_entries == 0 and cache.metrics().budget_bytes == 64, "a negative trim target means 0")
	cache.trim_to(1 << 30)
	check(cache.metrics().resident_entries == 0, "a trim never admits anything")

func _clear_modes() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(64, 10)
	var a: Texture2D = tex()
	var b: Texture2D = tex()
	cache.remember("a", a, 16)
	cache.remember("b", b, 16)
	cache.remember("unowned", tex(), 16)
	cache.clear(false)
	var metrics: Dictionary = cache.metrics()
	check(metrics.resident_entries == 0 and metrics.resident_decoded_bytes_estimate == 0, "clear(false) drops every strong reference")
	check(metrics.tracked_entries == 2, "clear(false) keeps tracking owned textures and drops the freed one")
	check(metrics.budget_bytes == 64 and metrics.max_entries == 10, "clear does not change the configured limits")
	check(a.get_width() == 2 and b.get_width() == 2, "clear(false) leaves owned textures usable")
	check(cache.lookup("a") == a and cache.metrics().weak_hits == 1 and cache.metrics().resident_entries == 1, "after clear(false) an owned texture is reused and resident again")
	cache.clear(true)
	metrics = cache.metrics()
	check(metrics.resident_entries == 0 and metrics.tracked_entries == 0, "clear(true) drops strong references and tracking")
	check(a.get_width() == 2 and b.get_width() == 2, "clear(true) leaves owned textures usable")
	var misses: int = metrics.misses
	check(cache.lookup("a") == null and cache.lookup("b") == null and cache.metrics().misses == misses + 2, "after clear(true) owned textures are no longer found")
	check(cache._weak.is_empty() and cache._cost.is_empty() and cache._tracked_lru.is_empty() and cache._resident_lru.is_empty(), "clear(true) leaves no bookkeeping")

func _metrics_snapshot() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(16, 10)
	var a: Texture2D = tex()
	cache.remember("a", a, 16)
	cache.remember("dead", tex(), 16) # evicts a; then "dead" is the resident
	cache.lookup("a") # weak hit; evicts and frees "dead", whose tracking stays
	var first: Dictionary = cache.metrics()
	check(first.tracked_entries == 2, "a dead tracking entry is present before the snapshot")
	check(first == cache.metrics() and first == cache.metrics(), "reading metrics changes nothing (no prune, no counters)")
	var expected: Dictionary = first.duplicate(true)
	for key: Variant in first.keys(): first[key] = 999
	first["extra"] = true
	check(cache.metrics() == expected, "changing a snapshot does not change the cache")
	check(cache.lookup("a") == a and cache.metrics().budget_bytes == 16, "the cache still works with its own limits")
	check(str(expected.accounting) == "decoded_image_payload_only_not_gpu_or_rss", "the snapshot states what the bytes are")
	for field: String in ["budget_bytes","max_entries","resident_decoded_bytes_estimate","resident_entries","tracked_entries","resident_hits","weak_hits","misses","evictions"]:
		check(expected.get(field) is int, "metric is a number: " + field)

func _replace_and_rejects() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(64, 10)
	var a: Texture2D = tex()
	var replacement: Texture2D = tex()
	cache.remember("a", a, 16)
	cache.remember("a", replacement, 32)
	check(cache.lookup("a") == replacement and cache.metrics().resident_decoded_bytes_estimate == 32 and cache.metrics().tracked_entries == 1, "remembering a key again replaces it without double counting")
	cache.remember("null", null, 16)
	cache.remember("free", a, 0)
	cache.remember("negative", a, -16)
	check(cache.metrics().tracked_entries == 1 and cache.lookup("null") == null and cache.lookup("free") == null and cache.lookup("negative") == null, "a missing texture or a cost of 0 or less is not remembered")

func _bounded_under_churn() -> void:
	var cache: RefCounted = CACHE.new()
	cache.configure(48, 5)
	var owned: Array[Texture2D] = []
	var within: bool = true
	for index: int in 300:
		var texture: Texture2D = tex()
		if index % 3 == 0: owned.append(texture)
		cache.remember("k%d" % index, texture, 16)
		if index % 7 == 0: cache.lookup("k%d" % (index / 2))
		var metrics: Dictionary = cache.metrics()
		if metrics.resident_decoded_bytes_estimate > 48 or metrics.tracked_entries > 5 or metrics.resident_entries > 3: within = false
		if cache._resident.size() != cache._resident_lru.size() or cache._weak.size() != cache._tracked_lru.size() or cache._weak.size() != cache._cost.size(): within = false
	check(within, "limits and bookkeeping hold after every one of 300 insertions")
