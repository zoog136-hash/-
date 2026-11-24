extends SceneTree
const Bytes = preload("res://scripts/io/verified_source_bytes.gd")
const Runtime = preload("res://scripts/shop/source523_shop_runtime.gd")
const Tickets = preload("res://scripts/shop/source523_inventory_tickets.gd")
const NpcDefinitions = preload("res://scripts/shop/source523_npc_definitions.gd")
const Equipment = preload("res://scripts/quests/quest_equipment523.gd")
const PATH := "user://verified-source-bytes-test.json"

class FixtureCatalog extends RefCounted:
	var loaded_sha256 := "a".repeat(64)
	func label(_id: int) -> String: return "원본 티켓"
	func record(table: String, _id: int) -> Dictionary:
		if table == "ItemClass": return {"DescID":1,"TestItem":false}
		if table == "MarketProduct": return {"UnitID":35,"ID":11,"ClassID":22,"Amount":1}
		return {}
	func _related(table: String, _id: int) -> Array:
		return [{"MarketProductID":11}] if table == "MarketPurchaseProduct" else []

class FixtureRuntime extends RefCounted:
	const Catalog = Runtime.Catalog
	var catalog := FixtureCatalog.new()
	func integer(value: Variant) -> bool: return Runtime.Catalog._integer(value)

var count := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	count += 1
	if not condition:
		failures.append(label)
		printerr("FAIL " + label)

func put(text: String) -> String:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_buffer(text.to_utf8_buffer())
	file.close()
	return FileAccess.get_sha256(PATH)

func _initialize() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var raw := "\ufeff{\"name\":\"가호\U01f47e\"}\r\n"
	var sha := put(raw)
	var file := FileAccess.open(PATH,FileAccess.READ)
	var bytes := Bytes.read(file,128)
	check(Bytes.sha256(bytes) == sha and bytes == raw.to_utf8_buffer(),"BOM/Korean/emoji/CRLF byte hash equals FileAccess")
	check(bytes.get_string_from_utf8() == FileAccess.get_file_as_string(PATH),"legacy UTF-8 decode equivalent")
	file.seek(0)
	check(Bytes.read(file,4).is_empty() and file.get_position()==0,"limit rejects before reading")
	check(Bytes.read(null,128).is_empty() and Bytes.sha256(PackedByteArray()).is_empty(),"missing/empty inputs cannot authenticate")
	file.close()
	var shop := Runtime.new()
	shop.catalog = FixtureCatalog.new()
	var policy := "\ufeff"+JSON.stringify({"schema":"twilight.source523.shop-policy.v1","pack_sha256":shop.catalog.loaded_sha256,"server_context":{"world_no":27,"region":"한국"}})+"\r\n"
	sha = put(policy)
	check(shop.load_policy(PATH,sha.to_upper()).ok and shop.policy_sha256==sha and shop.server_context.region=="한국","real policy loader accepts BOM and binds exact UTF-8/CRLF digest")
	put(policy+" ")
	check(not shop.load_policy(PATH,sha).ok and shop.policy_sha256==sha,"policy tamper preserves prior activation")
	check(not shop.load_policy(PATH,put("{broken")).ok,"authenticated malformed policy is rejected")
	check(not shop.load_policy(PATH,put(" ".repeat(1024*1024+1))).ok,"oversize policy is rejected")
	var runtime := FixtureRuntime.new()
	var tickets := Tickets.new()
	tickets.owner_ref = weakref(runtime)
	var body := {"schema":Tickets.SCHEMAS[1],"source_sha256":Runtime.Catalog.SOURCE_SHA256,
		"owned_use_policy":"twilight_one_owned_ticket_for_linked_products","redeem_owned_when_market_not_on_sale":false,
		"tickets":{"33":{"item_id":33,"name":"원본 티켓","market_id":44,"grants":[{"product_id":11,"pool_id":22,"count":1}]}},
		"pools":{"22":[{"card_id":99,"grade_id":2,"weight":1000000}]}}
	var valid := JSON.stringify(body)+"\r\n"
	sha = put(valid)
	check(tickets.load_pack(PATH,sha.to_upper()) and tickets.loaded_sha == sha and tickets.document.tickets["33"].name=="원본 티켓","real ticket pack loader accepts exact UTF-8 / mixed-case digest")
	var identity: Dictionary = tickets.model_input_identity.duplicate(true)
	put(valid+" ")
	check(not tickets.load_pack(PATH,sha) and tickets.model_input_identity == identity,"valid JSON tamper cannot replace model identity")
	check(not tickets.load_pack(PATH,put("{broken")) and tickets.problem.contains("JSON"),"authenticated malformed ticket fails before model replacement")
	check(not tickets.load_pack(PATH,put(" ".repeat(2*1024*1024+1))) and tickets.problem.contains("크기"),"oversize ticket rejected without parsing")
	DirAccess.remove_absolute(PATH)
	check(not tickets.load_pack(PATH,sha) and tickets.model_input_identity == identity,"missing ticket input fails")
	var npc := NpcDefinitions.new()
	var npc_body := JSON.stringify({"schema":"twilight.source523.npc-definitions.v1","patch":523,
		"source_zip_sha256":Runtime.Catalog.SOURCE_SHA256,"shop_pack_sha256":runtime.catalog.loaded_sha256,
		"merchants":[{"merchant_id":13,"goods_ids":[19],"object_links":[]}],"source_semantics":{"fixture":"한국"}})+"\r\n"
	sha = put(npc_body)
	check(npc.load_pack(PATH,sha.to_upper(),runtime.catalog.loaded_sha256) and npc.records.has("13") and npc.loaded_sha256==sha,"real NPC loader accepts verified model")
	put(npc_body+" ")
	check(not npc.load_pack(PATH,sha,runtime.catalog.loaded_sha256) and npc.loaded_sha256==sha and npc.records.has("13"),"NPC tamper keeps previous model but reports failure")
	check(not npc.load_pack(PATH,put("{broken"),runtime.catalog.loaded_sha256),"verified malformed NPC body rejected")
	check(not npc.load_pack(PATH,put(" ".repeat(NpcDefinitions.MAX_INPUT_BYTES+1)),runtime.catalog.loaded_sha256),"oversized NPC body rejected")
	npc.configure(runtime.catalog)
	check(not npc.problem.is_empty() and not npc.load_original(runtime.catalog) and npc.problem.contains("우회하지"),"bad explicit NPC input never falls through to original")
	var equipment := Equipment.new()
	equipment.configure(null)
	check(equipment.data.is_empty() and equipment.problem=="정확한 장비 규칙 SHA 필요","real quest command-line route fails on missing/tampered pinned input")
	print("VERIFIED_SOURCE_BYTES ", JSON.stringify({"checks":count,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
