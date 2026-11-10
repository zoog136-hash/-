extends SceneTree
## Standalone, synthetic (no original): the monster book cold projection that
## reads one column plus the selected rows of every referenced table must
## equal the former whole-table build (kept verbatim below as LEGACY: only
## Definitions -> legacy_source, _integer -> Catalog._integer and _fail(x) ->
## a returned reason) in payload bytes and SHA256, evidence, issues (every
## entry, in order) and failure reason, for the normal projection and every
## rejection, and must never read a referenced table with rows(). The fake
## source mirrors current523_definition_rows' reader API (table_metadata /
## rows / row_count / row_at / column), including column-packed tables,
## row-store tables and JSON float numbers.

const Catalog = preload("res://scripts/monsterbook/monsterbook523.gd")
const WHOLE := ["MonsterBook","MonsterBookLevel","MonsterBookLevelBonus","MonsterBookLevelReward"]
var failures: Array[String] = []
var checks: int = 0
var legacy_source: FakeRows

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

## Reader double. Uniform tables (every row has the same keys) behave like
## the packed column store, others like its "rows" fallback store.
class FakeRows extends RefCounted:
	var tables: Dictionary = {}
	var metadata: Dictionary = {}
	var full_reads: Dictionary = {}
	var row_reads: Dictionary = {}
	func add(table: String, rows: Array) -> void:
		tables[table] = rows
		metadata[table] = {"path":"content/"+table+".json","version":523.0,"bytes":float(1000+rows.size()*37),"sha256":(table+"|").sha256_text(),"row_count":float(rows.size())}
	func table_metadata(table: String) -> Dictionary:
		return (metadata.get(table, {}) as Dictionary).duplicate(true)
	func _uniform(rows: Array) -> bool:
		if rows.is_empty(): return true
		var keys: Array = (rows[0] as Dictionary).keys()
		for row: Dictionary in rows:
			if row.size() != keys.size(): return false
			for key: Variant in keys: if not row.has(key): return false
		return true
	func rows(table: String) -> Array[Dictionary]:
		full_reads[table] = int(full_reads.get(table, 0)) + 1
		var result: Array[Dictionary] = []
		for row: Dictionary in tables.get(table, []): result.append(row.duplicate(true))
		return result
	func row_count(table: String) -> int: return (tables.get(table, []) as Array).size()
	func row_at(table: String, index: int) -> Dictionary:
		row_reads[table] = int(row_reads.get(table, 0)) + 1
		var rows: Array = tables.get(table, [])
		return (rows[index] as Dictionary).duplicate(true) if index >= 0 and index < rows.size() else {}
	func column(table: String, field: String) -> Variant:
		var rows: Array = tables.get(table, [])
		if rows.is_empty() or (_uniform(rows) and not (rows[0] as Dictionary).has(field)): return []
		var values: Array = []
		for row: Dictionary in rows:
			if not row.has(field): return []
			values.append(row[field])
		if not _uniform(rows): return values
		var floats := true
		var texts := true
		for value: Variant in values:
			if typeof(value) != TYPE_FLOAT: floats = false
			if typeof(value) != TYPE_STRING: texts = false
		if floats: return PackedFloat64Array(values)
		if texts: return PackedStringArray(values)
		return values

## ---- LEGACY (frozen former cold build of monsterbook523.gd) ----
func legacy_source_rows(table: String, cache: Dictionary, evidence: Dictionary, issues: Array[String]) -> Array:
	if cache.has(table): return cache[table]
	var metadata: Dictionary = legacy_source.table_metadata(table)
	var sha: Variant = metadata.get("sha256")
	if metadata.get("path") != "content/"+table+".json" or metadata.get("version") != 523 or not Catalog._integer(metadata.get("bytes")) or not Catalog._integer(metadata.get("row_count")) or not sha is String:
		issues.append("source_table_identity:"+table)
		return []
	if sha.length()!=64 or not sha.is_valid_hex_number(false):
		issues.append("source_table_digest:"+table)
		return []
	var values: Array = legacy_source.rows(table)
	if values.size()!=int(metadata.row_count):
		issues.append("source_table_rows:"+table)
		return []
	cache[table] = values
	evidence[table] = {"bytes":metadata.bytes,"sha256":sha,"rows":values.size()}
	return values

func legacy_source_ids(values: Array, field: String, issues: Array[String], omit_zero: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values:
		if not Catalog._integer(value.get(field)):
			issues.append("source_integer:"+field)
			continue
		var id: int = int(value[field])
		if not omit_zero or id!=0: result[id] = true
	return result

func legacy_source_filter(values: Array, field: String, ids: Dictionary) -> Array:
	var result: Array = []
	for value: Dictionary in values:
		if Catalog._integer(value.get(field)) and ids.has(int(value[field])): result.append(value)
	return result

func legacy_source_select(table: String, ids: Dictionary, cache: Dictionary, evidence: Dictionary, issues: Array[String]) -> Array:
	var values: Array = legacy_source_rows(table,cache,evidence,issues)
	var result: Array = legacy_source_filter(values,"ID",ids)
	if legacy_source_ids(result,"ID",issues).size()!=ids.size(): issues.append("source_missing_reference:"+table)
	return result

func legacy_source_index(values: Array, issues: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values:
		if not Catalog._integer(value.get("ID")):
			issues.append("source_integer:ID")
			continue
		result[int(value.ID)] = value
	return result

func legacy(source: FakeRows) -> Dictionary:
	legacy_source = source
	var cache: Dictionary = {}
	var evidence: Dictionary = {}
	var issues: Array[String] = []
	var tables: Dictionary = {}
	for table: String in ["MonsterBook","MonsterBookLevel","MonsterBookLevelBonus","MonsterBookLevelReward"]:
		tables[table] = legacy_source_rows(table,cache,evidence,issues)
	var books: Array = tables.MonsterBook
	var groups: Dictionary = legacy_source_ids(books,"NpcGroupID",issues,true)
	tables.NpcClassForNpcGroup = legacy_source_filter(legacy_source_rows("NpcClassForNpcGroup",cache,evidence,issues),"NpcGroupID",groups)
	var reward_ids: Dictionary = legacy_source_ids(tables.MonsterBookLevelReward,"RewardID",issues)
	var reward_rows: Array = legacy_source_rows("Reward",cache,evidence,issues)
	var rewards: Dictionary = legacy_source_index(reward_rows,issues)
	var item_ids: Dictionary = {}
	for reward: Dictionary in reward_rows:
		if int(reward.RewardTypeID)==2 and reward_ids.has(int(reward.ID)): item_ids[int(reward.RewardClassID)] = true
	var current_books: Dictionary = legacy_source_ids(legacy_source_filter(books,"NpcGroupID",groups),"ID",issues)
	var current_levels: Array = legacy_source_filter(tables.MonsterBookLevel,"MonsterBookID",current_books)
	var current_level_ids: Dictionary = legacy_source_ids(current_levels,"ID",issues)
	var current_reward_ids: Dictionary = legacy_source_ids(legacy_source_filter(tables.MonsterBookLevelReward,"MonsterBookLevelID",current_level_ids),"RewardID",issues)
	var action_roots: Dictionary = {}
	for id: int in current_reward_ids:
		var reward: Dictionary = rewards.get(id,{})
		if reward.is_empty(): return {"ok":false,"reason":"source_missing_reference:Reward","issues":issues}
		if int(reward.RewardTypeID)==2: action_roots[int(reward.RewardClassID)] = true
	var bonuses: Dictionary = legacy_source_index(legacy_source_rows("Bonus",cache,evidence,issues),issues)
	var types: Dictionary = legacy_source_index(legacy_source_rows("BonusType",cache,evidence,issues),issues)
	var pending: Array = action_roots.keys()
	var visited: Dictionary = {}
	var select_ids: Dictionary = {}
	var market_ids: Dictionary = {}
	var intangible_ids: Dictionary = {}
	while not pending.is_empty():
		var item_id: int = int(pending.pop_back())
		if visited.has(item_id): continue
		visited[item_id] = true
		for link: Dictionary in legacy_source_rows("ItemBonus",cache,evidence,issues):
			if int(link.ItemClassID)!=item_id: continue
			var bonus: Dictionary = bonuses.get(int(link.BonusID),{})
			var type: Dictionary = types.get(int(bonus.get("BonusTypeID",-1)),{})
			if bonus.is_empty() or type.is_empty(): return {"ok":false,"reason":"source_missing_reference:ItemBonus","issues":issues}
			var kind: String = str(type.Name)
			if kind not in ["MarketPurchaseID","IntangibleItemClassID","SelectRewardClassID"]: continue
			if not Catalog._integer(bonus.get("Value")): return {"ok":false,"reason":"source_integer:Bonus.Value","issues":issues}
			var target: int = int(bonus.Value)
			if kind=="MarketPurchaseID": market_ids[target] = true
			elif kind=="IntangibleItemClassID": intangible_ids[target] = true
			else:
				var parent: Dictionary = rewards.get(target,{})
				if parent.is_empty() or int(parent.RewardTypeID)!=111: return {"ok":false,"reason":"source_selection_reward_type","issues":issues}
				reward_ids[int(parent.ID)] = true
				select_ids[int(parent.RewardClassID)] = true
				for entity: Dictionary in legacy_source_rows("SelectRewardEntity",cache,evidence,issues):
					if int(entity.SelectRewardID)!=int(parent.RewardClassID): continue
					var child: Dictionary = rewards.get(int(entity.RewardID),{})
					if child.is_empty(): return {"ok":false,"reason":"source_missing_reference:Reward","issues":issues}
					reward_ids[int(child.ID)] = true
					if int(child.RewardTypeID)==2:
						item_ids[int(child.RewardClassID)] = true
						pending.append(int(child.RewardClassID))
	tables.SelectReward = legacy_source_select("SelectReward",select_ids,cache,evidence,issues)
	tables.SelectRewardEntity = legacy_source_filter(legacy_source_rows("SelectRewardEntity",cache,evidence,issues),"SelectRewardID",select_ids)
	tables.MarketPurchase_Korean = legacy_source_select("MarketPurchase_Korean",market_ids,cache,evidence,issues)
	tables.MarketPurchaseProduct = legacy_source_filter(legacy_source_rows("MarketPurchaseProduct",cache,evidence,issues),"MarketPurchaseID",market_ids)
	var product_ids: Dictionary = legacy_source_ids(tables.MarketPurchaseProduct,"MarketProductID",issues)
	tables.MarketProduct = legacy_source_select("MarketProduct",product_ids,cache,evidence,issues)
	tables.MarketProductAdditional = legacy_source_filter(legacy_source_rows("MarketProductAdditional",cache,evidence,issues),"MarketProductID",product_ids)
	tables.MarketBonusForPurchase = legacy_source_filter(legacy_source_rows("MarketBonusForPurchase",cache,evidence,issues),"MarketPurchaseID",market_ids)
	var gotcha_ids: Dictionary = {}
	for product: Dictionary in tables.MarketProduct:
		if int(product.UnitID)==35: gotcha_ids[int(product.ClassID)] = true
	tables.GotChaEntityView = legacy_source_filter(legacy_source_rows("GotChaEntityView",cache,evidence,issues),"GotChaClassID",gotcha_ids)
	var card_ids: Dictionary = {}
	for entity: Dictionary in tables.GotChaEntityView:
		if int(entity.UnitID)==33: card_ids[int(entity.ClassID)] = true
	tables.BuffCard = legacy_source_select("BuffCard",card_ids,cache,evidence,issues)
	tables.IntangibleItemClass = legacy_source_select("IntangibleItemClass",intangible_ids,cache,evidence,issues)
	tables.ItemBonus = legacy_source_filter(legacy_source_rows("ItemBonus",cache,evidence,issues),"ItemClassID",item_ids)
	var bonus_ids: Dictionary = legacy_source_ids(tables.MonsterBookLevelBonus,"BonusID",issues)
	bonus_ids.merge(legacy_source_ids(tables.ItemBonus,"BonusID",issues),true)
	tables.Bonus = legacy_source_select("Bonus",bonus_ids,cache,evidence,issues)
	tables.BonusType = legacy_source_select("BonusType",legacy_source_ids(tables.Bonus,"BonusTypeID",issues),cache,evidence,issues)
	tables.BonusApplicationType = legacy_source_select("BonusApplicationType",legacy_source_ids(tables.Bonus,"BonusApplicationTypeID",issues),cache,evidence,issues)
	var resistance_ids: Dictionary = {}
	for bonus: Dictionary in tables.Bonus:
		if int(bonus.BonusApplicationTypeID)==2: resistance_ids[int(bonus.BonusApplicationTargetID)] = true
	tables.SpecialResistanceType = legacy_source_select("SpecialResistanceType",resistance_ids,cache,evidence,issues)
	tables.Reward = legacy_source_select("Reward",reward_ids,cache,evidence,issues)
	tables.RewardType = legacy_source_select("RewardType",legacy_source_ids(tables.Reward,"RewardTypeID",issues),cache,evidence,issues)
	var unit_ids: Dictionary = legacy_source_ids(tables.BonusType,"UnitID",issues)
	unit_ids.merge(legacy_source_ids(tables.MarketProduct,"UnitID",issues),true)
	unit_ids.merge(legacy_source_ids(tables.GotChaEntityView,"UnitID",issues),true)
	tables.Unit = legacy_source_select("Unit",unit_ids,cache,evidence,issues)
	tables.UIUnit = legacy_source_filter(legacy_source_rows("UIUnit",cache,evidence,issues),"UnitID",legacy_source_ids(tables.Unit,"ID",issues))
	tables.ItemClass = legacy_source_select("ItemClass",item_ids,cache,evidence,issues)
	tables.ItemCategory = legacy_source_select("ItemCategory",legacy_source_ids(tables.ItemClass,"CategoryID",issues),cache,evidence,issues)
	var grade_ids: Dictionary = legacy_source_ids(tables.ItemClass,"GradeID",issues)
	grade_ids.merge(legacy_source_ids(tables.BuffCard,"GradeID",issues),true)
	tables.Grade = legacy_source_select("Grade",grade_ids,cache,evidence,issues)
	tables.Currency = legacy_source_select("Currency",legacy_source_ids(tables.MonsterBookLevel,"CurrencyID",issues,true),cache,evidence,issues)
	var date_ids: Dictionary = {}
	for field: String in ["StartDateTimeID","CountingEndDateTimeID","EndDateTimeID"]:
		date_ids.merge(legacy_source_ids(books,field,issues,true),true)
	for bonus: Dictionary in tables.Bonus:
		if int(bonus.BonusApplicationTypeID)==298 and int(bonus.BonusApplicationTargetID)!=0: date_ids[int(bonus.BonusApplicationTargetID)] = true
	tables.DateTimes_Korean = legacy_source_select("DateTimes_Korean",date_ids,cache,evidence,issues)
	var desc_ids: Dictionary = {}
	for table: String in ["BonusType","RewardType","Currency","ItemClass","ItemCategory","Grade","SpecialResistanceType","IntangibleItemClass","BuffCard"]:
		for row: Dictionary in tables[table]:
			if row.get("DescID"):
				if not Catalog._integer(row.DescID): return {"ok":false,"reason":"source_integer:DescID","issues":issues}
				desc_ids[int(row.DescID)] = true
	tables.DescData_Korean = legacy_source_select("DescData_Korean",desc_ids,cache,evidence,issues)
	if not issues.is_empty(): return {"ok":false,"reason":issues[0],"issues":issues}
	if current_levels.size()!=97: return {"ok":false,"reason":"source_stage_count","issues":issues}
	return {"ok":true,"evidence":evidence,"tables":tables,"issues":issues}

## ---- end of LEGACY ----

## JSON numbers are floats, exactly as the original tables are read.
func j(value: Variant) -> Array:
	return JSON.parse_string(value if value is String else JSON.stringify(value))

func fixture() -> FakeRows:
	var source := FakeRows.new()
	# Books 1 and 3 are current (NpcGroupID != 0), 2 is not.
	source.add("MonsterBook", j('[{"ID":3,"NpcGroupID":11,"StartDateTimeID":1,"CountingEndDateTimeID":2,"EndDateTimeID":3},{"ID":2,"NpcGroupID":0,"StartDateTimeID":0,"CountingEndDateTimeID":0,"EndDateTimeID":0},{"ID":1,"NpcGroupID":10,"StartDateTimeID":1,"CountingEndDateTimeID":0,"EndDateTimeID":4}]'))
	var levels: Array = []
	var level_bonus: Array = []
	var level_reward: Array = []
	# 97 current stages (books 1 and 3) and 3 stages of the non-current book.
	for index: int in 100:
		var id: int = 1000 + index
		levels.append({"ID":id,"MonsterBookID":2 if index % 34 == 33 or index == 5 else (1 if index % 2 == 0 else 3),"Level":index % 5 + 1,"Amount":10,"CurrencyID":4 if index % 3 == 0 else 0,"CurrencyCost":5})
		level_bonus.append({"ID":index + 1,"MonsterBookLevelID":id,"BonusID":600 + index % 4})
		level_reward.append({"ID":index + 1,"MonsterBookLevelID":id,"RewardID":[20,21,22,23,24,25][index % 6]})
	check(levels.filter(func(row: Dictionary) -> bool: return row.MonsterBookID != 2).size() == 97, "fixture has 97 current stages")
	# Stage 1005 (index 5, RewardID 25) belongs to the non-current book only
	# through this one extra link: reward 26 is projected but is no action root.
	level_reward.append({"ID":200,"MonsterBookLevelID":1005,"RewardID":26})
	source.add("MonsterBookLevel", j(levels))
	source.add("MonsterBookLevelBonus", j(level_bonus))
	source.add("MonsterBookLevelReward", j(level_reward))
	source.add("NpcClassForNpcGroup", j('[{"NpcGroupID":10,"NpcClassID":1,"ServerLimitSetID":0},{"NpcGroupID":12,"NpcClassID":2,"ServerLimitSetID":0},{"NpcGroupID":11,"NpcClassID":3,"ServerLimitSetID":0},{"NpcGroupID":10,"NpcClassID":4,"ServerLimitSetID":0}]'))
	# Out-of-order IDs. 20/22/26: items; 21: exp; 23: item without links;
	# 24/25: items; 40: selection parent (type 111); 41/42/43: its children.
	var rewards: Array = j('[{"ID":43,"RewardTypeID":1,"RewardClassID":0,"Amount":7},{"ID":26,"RewardTypeID":2,"RewardClassID":106,"Amount":1},{"ID":20,"RewardTypeID":2,"RewardClassID":100,"Amount":1},{"ID":99,"RewardTypeID":2,"RewardClassID":555,"Amount":1},{"ID":21,"RewardTypeID":1,"RewardClassID":0,"Amount":50},{"ID":22,"RewardTypeID":2,"RewardClassID":101,"Amount":2},{"ID":23,"RewardTypeID":2,"RewardClassID":102,"Amount":1},{"ID":24,"RewardTypeID":2,"RewardClassID":103,"Amount":1},{"ID":25,"RewardTypeID":2,"RewardClassID":100,"Amount":3},{"ID":40,"RewardTypeID":111,"RewardClassID":70,"Amount":1},{"ID":41,"RewardTypeID":2,"RewardClassID":104,"Amount":1},{"ID":42,"RewardTypeID":2,"RewardClassID":105,"Amount":1},{"ID":44,"RewardTypeID":111,"RewardClassID":71,"Amount":1}]')
	for index: int in 300: rewards.append({"ID":float(5000 + index),"RewardTypeID":2.0,"RewardClassID":float(9000 + index),"Amount":1.0})
	source.add("Reward", rewards)
	# 100: market + stat; 101: intangible; 103: selection 40 -> items 104, 105;
	# 104: selection 44 (no entities); 105: market 81; 106/555/300: not visited.
	var item_bonus: Array = j('[{"ID":1,"ItemClassID":100,"BonusID":700},{"ID":2,"ItemClassID":555,"BonusID":701},{"ID":3,"ItemClassID":100,"BonusID":701},{"ID":4,"ItemClassID":101,"BonusID":702},{"ID":5,"ItemClassID":103,"BonusID":703},{"ID":6,"ItemClassID":104,"BonusID":704},{"ID":7,"ItemClassID":105,"BonusID":705},{"ID":8,"ItemClassID":106,"BonusID":701},{"ID":9,"ItemClassID":300,"BonusID":706},{"ID":10,"ItemClassID":105,"BonusID":700}]')
	for index: int in 300: item_bonus.append({"ID":float(100 + index),"ItemClassID":float(9000 + index),"BonusID":701.0})
	source.add("ItemBonus", item_bonus)
	var bonus: Array = j('[{"ID":706,"BonusTypeID":1,"Value":1,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0},{"ID":700,"BonusTypeID":3,"Value":80,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0},{"ID":701,"BonusTypeID":1,"Value":2.5,"BonusApplicationTypeID":2,"BonusApplicationTargetID":9},{"ID":702,"BonusTypeID":4,"Value":90,"BonusApplicationTypeID":298,"BonusApplicationTargetID":5},{"ID":703,"BonusTypeID":5,"Value":40,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0},{"ID":704,"BonusTypeID":5,"Value":44,"BonusApplicationTypeID":298,"BonusApplicationTargetID":0},{"ID":705,"BonusTypeID":3,"Value":81,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0},{"ID":600,"BonusTypeID":1,"Value":3,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0},{"ID":601,"BonusTypeID":2,"Value":4,"BonusApplicationTypeID":2,"BonusApplicationTargetID":8},{"ID":602,"BonusTypeID":1,"Value":5,"BonusApplicationTypeID":3,"BonusApplicationTargetID":0},{"ID":603,"BonusTypeID":2,"Value":6,"BonusApplicationTypeID":1,"BonusApplicationTargetID":0}]')
	for index: int in 300: bonus.append({"ID":float(8000 + index),"BonusTypeID":1.0,"Value":0.0,"BonusApplicationTypeID":1.0,"BonusApplicationTargetID":0.0})
	source.add("Bonus", bonus)
	source.add("BonusType", j('[{"ID":5,"Name":"SelectRewardClassID","UnitID":3,"DescID":0},{"ID":4,"Name":"IntangibleItemClassID","UnitID":2,"DescID":904},{"ID":3,"Name":"MarketPurchaseID","UnitID":2,"DescID":903},{"ID":2,"Name":"Defense","UnitID":1,"DescID":902},{"ID":1,"Name":"Stat","UnitID":1,"DescID":901},{"ID":9,"Name":"Unused","UnitID":7,"DescID":999}]'))
	source.add("BonusApplicationType", j('[{"ID":298,"Name":"Date"},{"ID":3,"Name":"c"},{"ID":2,"Name":"Resist"},{"ID":1,"Name":"a"},{"ID":7,"Name":"z"}]'))
	source.add("SpecialResistanceType", j('[{"ID":8,"Name":"Stun","DescID":908},{"ID":9,"Name":"Hold","DescID":909},{"ID":10,"Name":"z","DescID":999}]'))
	source.add("SelectReward", j('[{"ID":71,"Name":"second"},{"ID":70,"Name":"first"},{"ID":72,"Name":"unused"}]'))
	source.add("SelectRewardEntity", j('[{"ID":1,"SelectRewardID":70,"RewardID":41},{"ID":2,"SelectRewardID":72,"RewardID":99},{"ID":3,"SelectRewardID":70,"RewardID":42},{"ID":4,"SelectRewardID":70,"RewardID":43}]'))
	source.add("MarketPurchase_Korean", j('[{"ID":81,"Name":"m81"},{"ID":80,"Name":"m80"},{"ID":82,"Name":"unused"}]'))
	source.add("MarketPurchaseProduct", j('[{"ID":1,"MarketPurchaseID":80,"MarketProductID":51},{"ID":2,"MarketPurchaseID":82,"MarketProductID":59},{"ID":3,"MarketPurchaseID":81,"MarketProductID":50},{"ID":4,"MarketPurchaseID":80,"MarketProductID":50}]'))
	source.add("MarketProduct", j('[{"ID":59,"UnitID":35,"ClassID":999},{"ID":50,"UnitID":35,"ClassID":60},{"ID":51,"UnitID":4,"ClassID":100}]'))
	# Row stores (non-uniform keys).
	source.add("MarketProductAdditional", j('[{"ID":1,"MarketProductID":50},{"ID":2},{"ID":3,"MarketProductID":51,"Extra":1},{"ID":4,"MarketProductID":59}]'))
	source.add("MarketBonusForPurchase", j('[{"ID":1,"MarketPurchaseID":80,"BonusID":1},{"ID":2,"MarketPurchaseID":82,"BonusID":1,"Extra":"x"},{"ID":3,"MarketPurchaseID":81,"BonusID":2}]'))
	source.add("GotChaEntityView", j('[{"ID":1,"GotChaClassID":60,"UnitID":33,"ClassID":31},{"ID":2,"GotChaClassID":999,"UnitID":33,"ClassID":39},{"ID":3,"GotChaClassID":60,"UnitID":5,"ClassID":32},{"ID":4,"GotChaClassID":60,"UnitID":33,"ClassID":30}]'))
	source.add("BuffCard", j('[{"ID":39,"GradeID":9,"DescID":999},{"ID":30,"GradeID":2,"DescID":930},{"ID":31,"GradeID":1,"DescID":0}]'))
	source.add("IntangibleItemClass", j('[{"ID":91,"Name":"z","DescID":999},{"ID":90,"Name":"i","DescID":990}]'))
	source.add("RewardType", j('[{"ID":111,"Name":"Select","DescID":911},{"ID":2,"Name":"Item","DescID":0},{"ID":1,"Name":"Exp","DescID":912},{"ID":5,"Name":"z","DescID":999}]'))
	source.add("Unit", j('[{"ID":35,"Name":"gotcha"},{"ID":33,"Name":"card"},{"ID":5,"Name":"e"},{"ID":4,"Name":"d"},{"ID":3,"Name":"c"},{"ID":2,"Name":"b"},{"ID":1,"Name":"a"},{"ID":7,"Name":"z"}]'))
	source.add("UIUnit", j('[{"ID":1,"UnitID":1,"Text":"%"},{"ID":2,"UnitID":7,"Text":"z"},{"ID":3,"UnitID":35,"Text":"g"},{"ID":4,"UnitID":1,"Text":"second"}]'))
	var items: Array = j('[{"ID":106,"Name":"g","CategoryID":1,"GradeID":1,"DescID":0},{"ID":100,"Name":"a","CategoryID":1,"GradeID":1,"DescID":950},{"ID":300,"Name":"z","CategoryID":9,"GradeID":9,"DescID":999},{"ID":101,"Name":"b","CategoryID":2,"GradeID":3,"DescID":951},{"ID":102,"Name":"c","CategoryID":1,"GradeID":1,"DescID":0},{"ID":103,"Name":"d","CategoryID":1,"GradeID":1,"DescID":952},{"ID":104,"Name":"e","CategoryID":2,"GradeID":2,"DescID":0},{"ID":105,"Name":"f","CategoryID":1,"GradeID":1,"DescID":953}]')
	for index: int in 300: items.append({"ID":float(9000 + index),"Name":"filler","CategoryID":9.0,"GradeID":9.0,"DescID":999.0})
	source.add("ItemClass", items)
	source.add("ItemCategory", j('[{"ID":9,"Name":"z","DescID":999},{"ID":2,"Name":"two","DescID":962},{"ID":1,"Name":"one","DescID":961}]'))
	source.add("Grade", j('[{"ID":3,"Name":"g3","DescID":973},{"ID":9,"Name":"z","DescID":999},{"ID":2,"Name":"g2","DescID":0},{"ID":1,"Name":"g1","DescID":971}]'))
	source.add("Currency", j('[{"ID":5,"Name":"z","DescID":999},{"ID":4,"Name":"Gem","DescID":980}]'))
	source.add("DateTimes_Korean", j('[{"ID":5,"Year":2026},{"ID":4,"Year":2025},{"ID":3,"Year":2024},{"ID":2,"Year":2023},{"ID":1,"Year":2022},{"ID":6,"Year":1}]'))
	var descriptions: Array = []
	for id: int in [999,901,902,903,904,908,909,911,912,930,950,951,952,953,961,962,971,973,980,990]: descriptions.append({"ID":id,"Text":"desc %d" % id})
	source.add("DescData_Korean", j(descriptions))
	return source

func sha(data: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	return digest.finish().hex_encode()

func rows_of(source: FakeRows, table: String) -> Array:
	return source.tables[table]

func find_row(source: FakeRows, table: String, id: int) -> Dictionary:
	for row: Dictionary in rows_of(source, table):
		if row.get("ID") is float and int(row.ID) == id: return row
	failures.append("fixture row missing: %s#%d" % [table, id])
	return {}

func drop(source: FakeRows, table: String, id: int) -> void:
	source.add(table, rows_of(source, table).filter(func(row: Dictionary) -> bool: return not (row.get("ID") is float and int(row.ID) == id)))

## Runs LEGACY and the new projection on the same tables and compares them.
## `expected` is "" for an accepted projection or the required failure reason.
func compare(name: String, source: FakeRows, expected: String) -> Dictionary:
	var before: String = JSON.stringify(source.tables, "", false, true)
	var old: Dictionary = legacy(source)
	source.full_reads.clear()
	source.row_reads.clear()
	var catalog := Catalog.new()
	var now: Dictionary = catalog._cold_projection(source)
	var reads: Dictionary = source.full_reads.duplicate()
	check(JSON.stringify(source.tables, "", false, true) == before, name + ": source tables untouched")
	check(bool(now.ok) == bool(old.ok), name + ": same acceptance")
	check(str(now.get("reason", "")) == str(old.get("reason", "")), name + ": same failure reason " + str(old.get("reason", "")) + " / " + str(now.get("reason", "")))
	check((old.issues as Array) == (now.issues as Array), name + ": same issues in the same order " + str(old.issues) + " / " + str(now.issues))
	check(str(old.get("reason", "")) == expected, name + ": legacy result is the intended case (" + expected + ") got " + str(old.get("reason", "")) + " " + str(old.issues))
	if old.ok and now.ok:
		var old_bytes: PackedByteArray = Catalog._payload_bytes(old.evidence, old.tables)
		var now_bytes: PackedByteArray = Catalog._payload_bytes(now.evidence, now.tables)
		check(old_bytes == now_bytes and sha(old_bytes) == sha(now_bytes), name + ": identical payload bytes and sha256")
		check(JSON.stringify(old.evidence, "", false, true) == JSON.stringify(now.evidence, "", false, true), name + ": identical evidence (values and table order)")
		check((old.tables as Dictionary).keys() == (now.tables as Dictionary).keys(), name + ": same table order")
		check(var_to_str(old.tables) == var_to_str(now.tables), name + ": same rows, order and value types")
	for table: String in source.tables:
		if table not in WHOLE: check(not reads.has(table), name + ": no whole-table rows(" + table + ")")
	return now

## The former build stops at the first unresolved look-up when an indexed
## table reads as empty; the table issue is still the first recorded issue.
func table_rejection(table: String, issue: String) -> String:
	if table == "Reward": return "source_missing_reference:Reward"
	if table in ["Bonus","BonusType"]: return "source_missing_reference:ItemBonus"
	return issue + ":" + table

func _initialize() -> void:
	var base := fixture()
	var accepted: Dictionary = compare("normal", base, "")
	if accepted.ok:
		var t: Dictionary = accepted.tables
		check(t.Reward.size() == 12 and t.ItemBonus.size() == 8 and t.Bonus.size() == 10 and t.ItemClass.size() == 7, "fixture selects rewards, links, bonuses and items %d %d %d %d" % [t.Reward.size(), t.ItemBonus.size(), t.Bonus.size(), t.ItemClass.size()])
		check(t.SelectReward.size() == 2 and t.SelectRewardEntity.size() == 3 and t.MarketPurchase_Korean.size() == 2 and t.MarketProduct.size() == 2 and t.GotChaEntityView.size() == 3 and t.BuffCard.size() == 2 and t.IntangibleItemClass.size() == 1, "fixture reaches selections, market, gotcha cards and intangibles")
		check(t.NpcClassForNpcGroup.size() == 3 and t.DateTimes_Korean.size() == 5 and t.SpecialResistanceType.size() == 2 and t.UIUnit.size() == 3 and t.DescData_Korean.size() == 19, "fixture reaches groups, dates, resistances, units and descriptions")
		check((accepted.evidence as Dictionary).size() == base.tables.size(), "evidence covers every table")
		# Bounded: per table only selected rows (plus index look-ups) are built.
		for table: String in ["Reward","ItemBonus","Bonus","ItemClass"]:
			check(int(base.row_reads.get(table, 0)) <= 4 * (t[table] as Array).size() and int(base.row_reads.get(table, 0)) < base.row_count(table) / 4, "normal: bounded row reads of %s (%d of %d)" % [table, int(base.row_reads.get(table, 0)), base.row_count(table)])

	# ---- table identity / digest / row count, for every referenced table ----
	for table: String in base.tables:
		var identity := fixture()
		identity.metadata[table].version = 522.0
		check(not (compare("identity " + table, identity, table_rejection(table, "source_table_identity")).issues as Array).is_empty() and (legacy(identity).issues as Array)[0] == "source_table_identity:" + table, "identity " + table + ": first issue is the table issue")
	for table: String in ["MonsterBook","Reward","ItemBonus","SelectRewardEntity","Bonus","BonusType","UIUnit","DescData_Korean"]:
		var path := fixture()
		path.metadata[table].path = "content/Other.json"
		check(not (compare("path " + table, path, table_rejection(table, "source_table_identity")).issues as Array).is_empty() and (legacy(path).issues as Array)[0] == "source_table_identity:" + table, "path " + table + ": first issue is the table issue")
		var absent := fixture()
		absent.metadata.erase(table)
		check(not (compare("no metadata " + table, absent, table_rejection(table, "source_table_identity")).issues as Array).is_empty() and (legacy(absent).issues as Array)[0] == "source_table_identity:" + table, "no metadata " + table + ": first issue is the table issue")
		var digest := fixture()
		digest.metadata[table].sha256 = "xyz"
		check(not (compare("digest " + table, digest, table_rejection(table, "source_table_digest")).issues as Array).is_empty() and (legacy(digest).issues as Array)[0] == "source_table_digest:" + table, "digest " + table + ": first issue is the table issue")
		var digest_type := fixture()
		digest_type.metadata[table].sha256 = 5.0
		check(not (compare("digest type " + table, digest_type, table_rejection(table, "source_table_identity")).issues as Array).is_empty() and (legacy(digest_type).issues as Array)[0] == "source_table_identity:" + table, "digest type " + table + ": first issue is the table issue")
		var count := fixture()
		count.metadata[table].row_count = float(count.row_count(table) + 1)
		check(not (compare("row count " + table, count, table_rejection(table, "source_table_rows")).issues as Array).is_empty() and (legacy(count).issues as Array)[0] == "source_table_rows:" + table, "row count " + table + ": first issue is the table issue")
		var fraction := fixture()
		fraction.metadata[table].bytes = 10.5
		check(not (compare("bytes " + table, fraction, table_rejection(table, "source_table_identity")).issues as Array).is_empty() and (legacy(fraction).issues as Array)[0] == "source_table_identity:" + table, "bytes " + table + ": first issue is the table issue")
	var two := fixture()
	two.metadata.ItemBonus.version = 1.0
	two.metadata.Bonus.sha256 = "00"
	two.metadata.SelectRewardEntity.row_count = 1.0
	compare("several failing tables", two, "source_table_digest:Bonus")

	# ---- integer checks ----
	var group := fixture()
	rows_of(group, "MonsterBook")[0].NpcGroupID = 11.5
	compare("non-integer NpcGroupID", group, "source_integer:NpcGroupID")
	var negative_group := fixture()
	rows_of(negative_group, "MonsterBook")[1].NpcGroupID = -1.0
	compare("negative NpcGroupID", negative_group, "source_integer:NpcGroupID")
	for pair: Array in [["Reward",5000],["Bonus",8000],["BonusType",9]]:
		var id := fixture()
		find_row(id, pair[0], pair[1]).ID = float(pair[1]) + 0.5
		compare("non-integer unreferenced %s ID" % pair[0], id, "source_integer:ID")
		var text := fixture()
		find_row(text, pair[0], pair[1]).ID = "x%d" % pair[1]
		compare("string unreferenced %s ID" % pair[0], text, "source_integer:ID")
		var minus := fixture()
		find_row(minus, pair[0], pair[1]).ID = -1.0
		compare("negative unreferenced %s ID" % pair[0], minus, "source_integer:ID")
	var many := fixture()
	for id: int in [5000, 5007, 5100]: find_row(many, "Reward", id).ID = float(id) + 0.25
	find_row(many, "Bonus", 8001).ID = 0.5
	compare("several non-integer IDs", many, "source_integer:ID")
	var truncated := fixture()
	# int(20.5) == 20 still marks its item, but the row is not indexed.
	(rows_of(truncated, "Reward") as Array).push_front({"ID":20.5,"RewardTypeID":2.0,"RewardClassID":300.0,"Amount":1.0})
	truncated.metadata.Reward.row_count += 1.0
	compare("fractional Reward ID truncating onto a referenced one", truncated, "source_integer:ID")
	var value := fixture()
	find_row(value, "Bonus", 703).Value = 40.5
	compare("non-integer selection Bonus.Value", value, "source_integer:Bonus.Value")
	var negative_value := fixture()
	find_row(negative_value, "Bonus", 700).Value = -80.0
	compare("negative market Bonus.Value", negative_value, "source_integer:Bonus.Value")
	var ignored_value := fixture()
	find_row(ignored_value, "Bonus", 600).Value = 1.5
	compare("fractional stat value is not a reference", ignored_value, "")
	var desc := fixture()
	find_row(desc, "ItemClass", 103).DescID = 952.5
	compare("non-integer DescID", desc, "source_integer:DescID")
	var bonus_type := fixture()
	find_row(bonus_type, "Bonus", 600).BonusTypeID = 1.5
	compare("non-integer selected BonusTypeID", bonus_type, "source_integer:BonusTypeID")
	var link_bonus := fixture()
	find_row(link_bonus, "ItemBonus", 8).BonusID = 701.5
	compare("non-integer unvisited link BonusID", link_bonus, "source_integer:BonusID")
	var currency := fixture()
	rows_of(currency, "MonsterBookLevel")[0].CurrencyID = 4.5
	compare("non-integer CurrencyID", currency, "source_integer:CurrencyID")

	# ---- missing references ----
	var current_reward := fixture()
	drop(current_reward, "Reward", 22)
	compare("missing current reward", current_reward, "source_missing_reference:Reward")
	var other_reward := fixture()
	drop(other_reward, "Reward", 26)
	compare("missing non-current reward", other_reward, "source_missing_reference:Reward")
	var link_target := fixture()
	drop(link_target, "Bonus", 702)
	compare("missing link bonus", link_target, "source_missing_reference:ItemBonus")
	var link_type := fixture()
	drop(link_type, "BonusType", 4)
	compare("missing link bonus type", link_type, "source_missing_reference:ItemBonus")
	var parent := fixture()
	drop(parent, "Reward", 40)
	compare("missing selection parent", parent, "source_selection_reward_type")
	var parent_type := fixture()
	find_row(parent_type, "Reward", 44).RewardTypeID = 2.0
	compare("selection parent of another type", parent_type, "source_selection_reward_type")
	var child := fixture()
	drop(child, "Reward", 42)
	compare("missing selection child", child, "source_missing_reference:Reward")
	for pair: Array in [["SelectReward",71],["MarketPurchase_Korean",81],["MarketProduct",51],["BuffCard",31],["IntangibleItemClass",90],["Bonus",602],["BonusType",2],["BonusApplicationType",298],["SpecialResistanceType",8],["RewardType",111],["Unit",33],["ItemClass",102],["ItemCategory",2],["Grade",3],["Currency",4],["DateTimes_Korean",5],["DescData_Korean",953]]:
		var missing := fixture()
		drop(missing, pair[0], pair[1])
		compare("missing %s#%d" % pair, missing, "source_missing_reference:" + pair[0])
	var several := fixture()
	drop(several, "Grade", 3)
	drop(several, "Unit", 33)
	drop(several, "DescData_Korean", 953)
	compare("several missing references", several, "source_missing_reference:Unit")
	# A negative class ID is matched by the int() traversal but never selected.
	var negative := fixture()
	find_row(negative, "Reward", 24).RewardClassID = -103.0
	find_row(negative, "ItemBonus", 5).ItemClassID = -103.0
	find_row(negative, "ItemClass", 103).ID = -103.0
	compare("negative item class", negative, "source_missing_reference:ItemClass")
	var negative_link := fixture()
	find_row(negative_link, "ItemBonus", 1).BonusID = -700.0
	compare("negative link bonus", negative_link, "source_missing_reference:ItemBonus")

	# ---- duplicates: the last row of an ID is the indexed one ----
	var duplicate_reward := fixture()
	(rows_of(duplicate_reward, "Reward") as Array).append({"ID":24.0,"RewardTypeID":1.0,"RewardClassID":0.0,"Amount":9.0})
	duplicate_reward.metadata.Reward.row_count += 1.0
	compare("duplicate reward, last is not an item", duplicate_reward, "")
	var duplicate_first := fixture()
	(rows_of(duplicate_first, "Reward") as Array).push_front({"ID":21.0,"RewardTypeID":2.0,"RewardClassID":106.0,"Amount":9.0})
	duplicate_first.metadata.Reward.row_count += 1.0
	compare("duplicate reward, first is an item", duplicate_first, "")
	var duplicate_bonus := fixture()
	(rows_of(duplicate_bonus, "Bonus") as Array).append({"ID":700.0,"BonusTypeID":4.0,"Value":90.0,"BonusApplicationTypeID":1.0,"BonusApplicationTargetID":0.0})
	duplicate_bonus.metadata.Bonus.row_count += 1.0
	compare("duplicate link bonus, last retargets", duplicate_bonus, "")
	var duplicate_type := fixture()
	(rows_of(duplicate_type, "BonusType") as Array).append({"ID":3.0,"Name":"Stat","UnitID":1.0,"DescID":0.0})
	duplicate_type.metadata.BonusType.row_count += 1.0
	compare("duplicate bonus type, last is not a reference", duplicate_type, "")
	var duplicate_item := fixture()
	(rows_of(duplicate_item, "ItemClass") as Array).append({"ID":100.0,"Name":"again","CategoryID":2.0,"GradeID":2.0,"DescID":0.0})
	duplicate_item.metadata.ItemClass.row_count += 1.0
	compare("duplicate selected item", duplicate_item, "")

	# ---- stores and value kinds ----
	var row_store := fixture()
	for table: String in ["Reward","ItemBonus","Bonus","BonusType","SelectRewardEntity","ItemClass","NpcClassForNpcGroup","DescData_Korean"]:
		(rows_of(row_store, table)[1] as Dictionary)["Extra"] = 1.0
	compare("row-store tables", row_store, "")
	var mixed := fixture()
	# A string in a filter column is never an integer reference.
	find_row(mixed, "MarketPurchaseProduct", 4).MarketPurchaseID = "80"
	find_row(mixed, "GotChaEntityView", 3).GotChaClassID = "60"
	find_row(mixed, "UIUnit", 4).UnitID = 1.5
	find_row(mixed, "ItemBonus", 8).ItemClassID = 106.5
	compare("mixed and fractional filter columns", mixed, "")
	var absent_field := fixture()
	for row: Dictionary in rows_of(absent_field, "UIUnit"): row.erase("UnitID")
	for row: Dictionary in rows_of(absent_field, "MarketBonusForPurchase"): row.erase("MarketPurchaseID")
	compare("filter column absent from every row", absent_field, "")
	var no_id := fixture()
	# (The former scan reads ID only of item rewards: keep this one another type.)
	rows_of(no_id, "Reward")[3].RewardTypeID = 1.0
	rows_of(no_id, "Reward")[3].erase("ID")
	rows_of(no_id, "Bonus")[12].erase("ID")
	find_row(no_id, "SelectReward", 72).erase("ID")
	compare("row without ID", no_id, "source_integer:ID")
	var empty := fixture()
	for table: String in ["ItemBonus","SelectReward","SelectRewardEntity","MarketPurchase_Korean","MarketPurchaseProduct","MarketProduct","MarketProductAdditional","MarketBonusForPurchase","GotChaEntityView","BuffCard","IntangibleItemClass"]:
		empty.add(table, [])
	compare("empty link and optional tables", empty, "")
	var no_roots := fixture()
	for row: Dictionary in rows_of(no_roots, "Reward"): row.RewardTypeID = 1.0
	compare("no item rewards", no_roots, "")
	var zero := fixture()
	# Zero IDs: omitted for groups/currency/dates, kept everywhere else.
	find_row(zero, "Bonus", 600).BonusApplicationTypeID = 0.0
	(rows_of(zero, "BonusApplicationType") as Array).append({"ID":0.0,"Name":"zero"})
	zero.metadata.BonusApplicationType.row_count += 1.0
	compare("zero reference", zero, "")

	# ---- stage count ----
	var stages := fixture()
	rows_of(stages, "MonsterBookLevel")[0].MonsterBookID = 2.0
	compare("96 current stages", stages, "source_stage_count")
	var no_books := fixture()
	for row: Dictionary in rows_of(no_books, "MonsterBook"): row.NpcGroupID = 0.0
	compare("no current book", no_books, "source_stage_count")
	var issue_first := fixture()
	rows_of(issue_first, "MonsterBookLevel")[0].MonsterBookID = 2.0
	drop(issue_first, "Grade", 3)
	compare("issue before stage count", issue_first, "source_missing_reference:Grade")

	var result := {"checks": checks, "failures": failures}
	print("MONSTERBOOK523_COLD_SELECTION_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
