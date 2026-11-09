extends "res://tests/original_client_test_base.gd"
## C09 / C10 acceptance tests.
const LAYERS = preload("res://scripts/original_client/actor_visual_layers.gd")
const CACHE = preload("res://scripts/original_client/sprite_cache.gd")

func run() -> void:
	var base: Dictionary = LAYERS.make("body_a", 11, ["c1", "c2"], "actor1")
	var kept: Dictionary = LAYERS.change_main(base, "body_b", false, true, 0, [null])
	check("C09-T01", kept.main == "body_b" and kept.shadow == 11 and kept.clothes == ["c1", "c2"], "refresh_aux=false must keep shadow and clothes")
	check("C09-T01", kept.log == ["shadow_kept", "clothes_kept"], "keep must be logged as an explicit operation")
	var walked: Dictionary = LAYERS.change_main(base, "body_b", true, true, 7, ["v1", null, "v3"])
	check("C09-T02", walked.clothes == ["v1"], "clothes [valid, missing, valid] keeps only the first prefix element")
	check("C09-T02", (walked.log as Array).has("clothes_walk_stopped_at_first_null"), "the walk must stop at the first null")
	var animated: Dictionary = LAYERS.change_main(base, "body_b", true, true, 0, [])
	var static_path: Dictionary = LAYERS.change_main(base, "body_b", true, false, 0, [])
	check("C09-T03", animated.shadow == null and static_path.shadow == 11, "animated shadow 0 clears, static shadow 0 keeps")
	var requests: Dictionary = LAYERS.aux_requests(27255, [100, 200], {27255: 23095})
	check("C09-T03", requests.shadow.mapped_id == 23095 and requests.clothes[0].mapped_id == 100, "each file request gets its own single whole remap")
	check("C09-T03", LAYERS.aux_selection({"low16": 8, "picture_u8": 3}).independent_action == false, "aux layers never get an independent SPR action")
	var ordered: Array = LAYERS.draw_order([{"id": "clothes_first", "depth": 5}, {"id": "body", "depth": 1}, {"id": "clothes_second", "depth": 5}])
	check("C09-T03", ordered[0].id == "body" and ordered[1].id == "clothes_first" and ordered[2].id == "clothes_second", "z comes from piece depth with a stable tie, not from collection order")

	var cache := CACHE.new()
	var loader: Callable = func(file_key: int) -> Variant:
		return null if file_key == 27255 else "sheet_%d" % file_key
	var first: Dictionary = cache.request(27255, loader)
	check("C10-T01", first.value_state == "null" and first.failure_state == "load_failed", "first request fails and is cached as null")
	cache.add_remap(27255, 23095)
	var second: Dictionary = cache.request(27255, loader)
	check("C10-T01", second.value_state == "null" and second.file_key == 27255 and cache.loads == 1, "a remap added later must not retry the cached null request")
	var fresh := CACHE.new()
	fresh.add_remap(27255, 23095)
	var remapped: Dictionary = fresh.request(27255, loader)
	check("C10-T01", remapped.value_state == "loaded" and remapped.request_key == 27255 and remapped.file_key == 23095, "request key and mapped file key stay separate")
	var generation_before: int = cache.generation
	var reload: Dictionary = cache.hot_reload()
	check("C10-T01", reload.generation == generation_before + 1 and cache.request_cache.is_empty() and reload.design_addition != "", "hot reload is a new generation, recorded as a design addition")
	var switched: Dictionary = cache.switch_mode(0)
	check("C10-T02", switched.mode == 0 and switched.manager_retained == true and switched.manager_deleted_by_switch == false, "mode 1 -> 0 keeps the manager; retained state and mode are separate")
	check("C10-T02", CACHE.REQUEST_LIMIT == 450 and CACHE.SELECTED_BYTE_LIMIT == 64 * 1024 * 1024, "approved limits are recorded as constants")
	finish("ORIGINAL_CLIENT_P2_LAYERS_CACHE_RESULT")
