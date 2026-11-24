extends SceneTree
const TICKETS = preload("res://scripts/shop/source523_inventory_tickets.gd")

class FakeCatalog extends RefCounted:
	var reads: int = 0
	func record(table: String, id: int) -> Dictionary:
		if table != "BuffCard" or id != 101: return {}
		reads += 1
		return {"GradeID":2,"BuffCardDeckID":1,"IsNoMergeOut":false,"IsNoSwapOut":false,
			"ServerLimitSetID":0,"StartDateTimeID":0,"EndDateTimeID":0}

class FakeWorld extends RefCounted:
	var card_draw_fusion: Dictionary = {"known_ids":{"변신":{}}}
	var catalog_db: Dictionary = {"변신":[]}

class FakeRuntime extends RefCounted:
	var catalog := FakeCatalog.new()
	var world := FakeWorld.new()
	var allow_server: bool = true
	func fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
	func _server(_sets: Array) -> Dictionary: return {"ok":true} if allow_server else fail("server gate")

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var runtime := FakeRuntime.new()
	var tickets = TICKETS.new()
	tickets.owner_ref = weakref(runtime)
	tickets.document = {"pools":{"1":[{"card_id":101,"grade_id":2,"weight":1000000}]}}
	var grants: Array = [{"pool_id":1,"count":11}]
	var card: Dictionary = {"name":"Fixture","source":"lineagem_patch523","source_card_id":101,
		"source_grade_id":2,"source_deck_id":1,"sourceId":"m523:1:101","nested":{"n":7}}
	var id: String = TICKETS.CardEngine.card_id(card)
	runtime.world.catalog_db["변신"].append(card)
	runtime.world.card_draw_fusion.known_ids["변신"][id] = true
	var preflight: Dictionary = tickets._candidates(grants,false)
	var drawable: Dictionary = tickets._candidates(grants)
	check(preflight.ok and preflight.pools.is_empty() and preflight.count == 11 and preflight.category == "변신",
		"preflight validates metadata without building drawable copies")
	check(drawable.ok and drawable.category == preflight.category and drawable.count == preflight.count
		and drawable.pools["1"][0].weight == 1000000 and drawable.pools["1"][0].entry.id == id,
		"final preparation retains exact ID, order, quantity and weight")
	check(runtime.catalog.reads == 2, "one original card-row lookup per preflight or materialization")
	drawable.pools["1"][0].entry.record.nested.n = 8
	check(card.nested.n == 7, "final drawable records do not alias the catalog")
	runtime.allow_server = false
	check(tickets._candidates(grants,false) == tickets._candidates(grants), "preflight does not skip the server rule")
	runtime.allow_server = true
	runtime.world.catalog_db["변신"].clear()
	var missing: Dictionary = tickets._candidates(grants,false)
	check(not missing.ok and missing.missing_card_ids == [101] and missing == tickets._candidates(grants),
		"missing positive-weight candidate still refuses the entire pool")
	print("SOURCE523_TICKET_POOL_PREFLIGHT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
