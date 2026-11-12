extends RefCounted
## Original 523 item sources ("재료 아이템 출처", Production_Popup_Source) read
## from the installed original definition ZIP (current523_definition_rows).
## Only what the rows state is shown; every rule the tables do not hold is
## listed in docs/acquisition_emblem523_missing_rules.md.
##
##  - ItemAcquisition / ItemAcquisitionSubCategory / ItemAcquisitionCategory:
##    the item's ItemCategoryID -> acquisition sub category -> category (Etc /
##    Scroll). The tables hold only these English names (no DescID, no place):
##    they classify, they do not say where an item comes from.
##  - Monster drops: NpcItemDropView (ItemClassID) whose NpcClass is not a
##    TestNPC and whose NpcCategory has IsShowDropInfo. 획득 장소:
##    NpcSpawnPackNpcClassView (IsSpawn 1) -> NpcSpawnPackTerritory ->
##    Territories with ShowInSourceList, named by DescID.
##  - 획득 방법 (no drop list): ItemCraftInputSource (DescID text, SourceOrder),
##    ItemClass.GettablePlaceID -> TooltipMarketDisplayCategory ->
##    MarketDisplayCategoryType (상점 탭 이름), ItemDropBySpecialDungeonView
##    (SpecialDungeon -> LandTeleport -> LandTeleportTerritories -> Territories).
##  - Crafts: ItemCraftOutputView rows whose ItemClassID is the item; the game
##    connects only those whose recipe exists in world.crafting
##    ("patch523:<ItemCraftID>").
## Without the archive sources() returns ok=false and nothing is shown.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
## Rows the popup lists at most (the original ListView limit is not in the
## tables; counts are always reported in full).
const MAX_DROP_ROWS: int = 80
const MAX_CRAFT_ROWS: int = 40

static var _text_cache: Dictionary = {}

static func reset_cache() -> void:
	_text_cache.clear()

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func text(id: int) -> String:
	if id<=0: return ""
	if _text_cache.has(id): return _text_cache[id]
	var matches: Array[Dictionary] = SOURCE.related("DescData_Korean","ID",id)
	var value: String = "" if matches.is_empty() else str(matches[-1].get("Description",""))
	if _text_cache.size()>4096: _text_cache.clear()
	_text_cache[id] = value
	return value

## One row by ID without touching the reader's shared problem text.
static func _row(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",id)
	return matches[0] if matches.size()==1 else {}

static func available() -> bool:
	return not SOURCE.identity().is_empty()

## The acquisition classification of an ItemCategoryID (empty when the
## category has no ItemAcquisition row).
static func classification(item_category_id: int) -> Dictionary:
	var rows: Array[Dictionary] = SOURCE.rows_matching("ItemAcquisition","ItemCategoryID",{item_category_id:true})
	if rows.size()!=1 or not _integer(rows[0].get("ItemAcquisitionSubCategoryID")): return {}
	var sub: Dictionary = _row("ItemAcquisitionSubCategory",int(rows[0].ItemAcquisitionSubCategoryID))
	if sub.is_empty() or not _integer(sub.get("ItemAcquisitionCategoryID")): return {}
	var category: Dictionary = _row("ItemAcquisitionCategory",int(sub.ItemAcquisitionCategoryID))
	if category.is_empty(): return {}
	return {"acquisition_id":int(rows[0].ID),"sub_category_id":int(sub.ID),"sub_category":str(sub.get("Name","")),
		"category_id":int(category.ID),"category":str(category.get("Name",""))}

static func _territory_name(id: int) -> String:
	var territory: Dictionary = _row("Territories",id)
	if territory.is_empty() or territory.get("ShowInSourceList")!=true: return ""
	return text(int(territory.get("DescID",0)))

## Shown places of one NpcClass, in table order, without repeats.
static func npc_places(npc_class_id: int) -> Array[String]:
	var places: Array[String] = []
	for spawn: Dictionary in SOURCE.related("NpcSpawnPackNpcClassView","NpcClassID",npc_class_id):
		if int(spawn.get("IsSpawn",0))!=1: continue
		for link: Dictionary in SOURCE.related("NpcSpawnPackTerritory","NpcSpawnPackID",int(spawn.NpcSpawnPackID)):
			var name: String = _territory_name(int(link.get("TerritoriesID",0)))
			if not name.is_empty() and name not in places: places.append(name)
	return places

static func _shown_npc(npc_class_id: int) -> Dictionary:
	var npc: Dictionary = _row("NpcClass",npc_class_id)
	if npc.is_empty() or npc.get("TestNPC")==true: return {}
	var category: Dictionary = _row("NpcCategory",int(npc.get("Category",0)))
	if category.get("IsShowDropInfo")!=true: return {}
	return npc

static func _special_dungeon_name(dungeon_id: int) -> String:
	var dungeon: Dictionary = _row("SpecialDungeon",dungeon_id)
	if dungeon.is_empty(): return ""
	for link: Dictionary in SOURCE.related("LandTeleportTerritories","LandTeleportID",int(dungeon.get("LandTeleportID",0))):
		var territory: Dictionary = _row("Territories",int(link.get("TerritoryID",0)))
		var name: String = text(int(territory.get("DescID",0)))
		if not name.is_empty(): return name
	return ""

## {"ok", item_class_id, name, classification, drops:[{npc, location}],
##  drop_monsters, drop_rows_total, acquirements:[{text, kind, destination}],
##  crafts:[{craft_id, item_class_id, name}], mode} or {"ok":false,"problem"}.
## mode: "drop" (몬스터/획득 장소 list), "acquirement" (획득 방법 list),
## "craft" (제작 list) or "none".
static func sources(item_class_id: int) -> Dictionary:
	if not available(): return {"ok":false,"problem":"원본523 정의 ZIP 미설치: "+SOURCE.problem()}
	var item: Dictionary = _row("ItemClass",item_class_id)
	if item.is_empty(): return {"ok":false,"problem":"ItemClass #%d 없음" % item_class_id}
	var result: Dictionary = {"ok":true,"item_class_id":item_class_id,"name":text(int(item.get("DescID",0))),
		"classification":classification(int(item.get("CategoryID",0))),"drops":[],"acquirements":[],"crafts":[]}
	# Monster drops (one row per monster name and shown place).
	var seen: Dictionary = {}
	var monsters: Dictionary = {}
	var total: int = 0
	for drop: Dictionary in SOURCE.rows_matching("NpcItemDropView","ItemClassID",{item_class_id:true}):
		var npc: Dictionary = _shown_npc(int(drop.get("NpcClassID",0)))
		if npc.is_empty(): continue
		var npc_name: String = text(int(npc.get("DescId",0)))
		if npc_name.is_empty(): npc_name = str(npc.get("Name",""))
		monsters[npc_name] = true
		var places: Array[String] = npc_places(int(npc.ID))
		if places.is_empty(): places = [""]
		for place: String in places:
			var key: String = npc_name+"\n"+place
			if seen.has(key): continue
			seen[key] = true
			total += 1
			if (result.drops as Array).size()<MAX_DROP_ROWS: result.drops.append({"npc":npc_name,"npc_class_id":int(npc.ID),"location":place})
	result["drop_monsters"] = monsters.size()
	result["drop_rows_total"] = total
	# Non-drop sources.
	var inputs: Array[Dictionary] = SOURCE.rows_matching("ItemCraftInputSource","ItemClassID",{item_class_id:true})
	inputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("SourceOrder",0))<int(b.get("SourceOrder",0)))
	for row: Dictionary in inputs:
		var line: String = text(int(row.get("DescID",0)))
		if not line.is_empty(): result.acquirements.append({"text":line,"kind":"craft_input_source","row_id":int(row.ID),"destination":""})
	var place_id: int = int(item.get("GettablePlaceID",0))
	if place_id>0:
		for link: Dictionary in SOURCE.rows_matching("TooltipMarketDisplayCategory","GettablePlaceID",{place_id:true}):
			var market: Dictionary = _row("MarketDisplayCategoryType",int(link.get("MarketDisplayCategoryType",0)))
			var tab: String = text(int(market.get("DescID",0)))
			if not tab.is_empty(): result.acquirements.append({"text":"상점 · "+tab.replace(" ",""),"kind":"market","market_display_category":int(market.ID),"destination":"shop"})
	var dungeons: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemDropBySpecialDungeonView","ItemClassID",{item_class_id:true}):
		var dungeon: int = int(row.get("DungeonID",0))
		if dungeons.has(dungeon): continue
		dungeons[dungeon] = true
		var name: String = _special_dungeon_name(dungeon)
		if not name.is_empty(): result.acquirements.append({"text":"던전 · "+name,"kind":"special_dungeon","special_dungeon_id":dungeon,"destination":"source_dungeons"})
	# Crafts producing the item.
	var crafts: Dictionary = {}
	for output: Dictionary in SOURCE.rows_matching("ItemCraftOutputView","ItemClassID",{item_class_id:true}):
		var craft: int = int(output.get("ItemCraftID",0))
		if craft<=0 or crafts.has(craft): continue
		crafts[craft] = true
		if (result.crafts as Array).size()<MAX_CRAFT_ROWS: result.crafts.append({"craft_id":craft,"recipe_id":"patch523:"+str(craft),"output_type":int(output.get("ItemCraftOutputTypeID",-1))})
	result["crafts_total"] = crafts.size()
	var authored: bool = false
	for row: Dictionary in result.acquirements:
		if row.kind=="craft_input_source": authored = true
	result["mode"] = "acquirement" if authored else "drop" if not (result.drops as Array).is_empty() else ("acquirement" if not (result.acquirements as Array).is_empty() else ("craft" if not (result.crafts as Array).is_empty() else "none"))
	return result

## Plain lines for the renewal detail panel (no original UI pack).
static func summary_lines(data: Dictionary, limit: int = 6) -> PackedStringArray:
	var lines := PackedStringArray()
	if not data.get("ok",false): return lines
	var info: Dictionary = data.get("classification",{})
	if not info.is_empty(): lines.append("원본 획득 분류  %s · %s" % [info.category,info.sub_category])
	var drops: Array = data.get("drops",[])
	for index: int in mini(limit,drops.size()):
		var row: Dictionary = drops[index]
		lines.append("몬스터  %s%s" % [row.npc," · "+str(row.location) if not str(row.location).is_empty() else ""])
	if int(data.get("drop_rows_total",0))>limit: lines.append("… 몬스터 %d종 / %d곳" % [int(data.drop_monsters),int(data.drop_rows_total)])
	for row: Dictionary in data.get("acquirements",[]): lines.append("획득 방법  "+str(row.text))
	if int(data.get("crafts_total",0))>0: lines.append("제작  원본 제작식 %d개" % int(data.crafts_total))
	return lines
