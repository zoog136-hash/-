extends SceneTree

const Data = preload("res://scripts/unconfirmed523/source_ui_data.gd")
const Source = preload("res://scripts/unconfirmed523/source523.gd")
var checks: int = 0
var failures: int = 0

class Tables extends RefCounted:
	var tables: Dictionary = {}
	func row(table: String, id: int) -> Dictionary:
		var matches: Array = find_rows(table,"ID",id)
		return matches[0] if matches.size() == 1 else {}
	func find_rows(table: String, field: String, value: Variant) -> Array:
		var matches: Array = []
		for record: Dictionary in tables.get(table,[]):
			if record.get(field) == value: matches.append(record)
		return matches

func _initialize() -> void: call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var source := Tables.new()
	source.tables = {
		"MainMenuUIButtons":[{"ID":106,"MainMenuTypeID":86,"IsVisible":true,"AssetID":372566},{"ID":116,"MainMenuTypeID":96,"IsVisible":true,"AssetID":372696}],
		"AssetType":[{"ID":101,"Name":"UI_CsbFile","Path":"UI/CsbFile/"},{"ID":143,"Name":"UI_Pass","Path":"Image/Pass/"},{"ID":1,"Name":"UI_Icon","Path":"icon/"}],
		"AssetView":[{"AssetId":372566,"AssetTypeId":101,"FilePath":"MainMenu/MainMenu_Attendance.csb"},{"AssetId":372696,"AssetTypeId":101,"FilePath":"MainMenu/MainMenu_Pass.csb"},{"AssetId":20,"AssetTypeId":143,"FilePath":"fixture.png"},{"AssetId":21,"AssetTypeId":1,"FilePath":"item.png"}],
		"UIDungeonCategory":[{"ID":14,"DungeonCategoryID":21,"RootUITableKey":"ALL_DUNGEON_TRYING_PAGE_ROOT","TitleDescId":1145954}],
		"DungeonCategory":[{"ID":21,"Name":"Challenge","Release":true}],
		"PassSystem":[{"ID":724,"IsActive":true,"PassSystemQuestListID":10,"PassSystemDailyQuestListID":11,"PassBackgroundAssetID":20,"PassNameAssetID":20,"PassRewardAssetID":20,"PassImageNode":"Nd_Img_SeasonPass","DescID":100}],
		"PassSystemLevel":[{"ID":70,"PassSystemID":724,"Level":1}],
		"PassSystemQuest":[{"ID":7,"PassSystemQuestListID":11,"QuestID":6},{"ID":8,"PassSystemQuestListID":12,"QuestID":9}],
		"AttendanceVersion":[{"ID":8,"Version":39,"ServiceRegionCode":"KR"}],
		"AttendanceReward":[{"AttendanceVersionID":8,"RewardIndex":1,"RewardID":30,"ServerLimitSetID":1},{"AttendanceVersionID":8,"RewardIndex":1,"RewardID":31,"ServerLimitSetID":2}],
		"ItemClass":[{"ID":100,"CategoryID":10622,"GradeID":3,"IconID":9,"DescID":101},{"ID":101,"CategoryID":10291,"IconID":9}],
		"ItemCategory":[{"ID":10622,"UIInventoryUseConfirm":true},{"ID":10291,"UIInventoryUseConfirm":false}],
		"Icon":[{"ID":9,"AssetID":21}],"ItemBonus":[],
		"ItemGrace":[{"ID":4,"ItemCategoryID":10622,"GradeID":3}],
		"GotChaEntityView":[{"ID":1,"GotChaClassID":77,"Probability":7},{"ID":2,"GotChaClassID":77,"Probability":11}],
		"Challenge":[{"ID":701,"IsWorking":true,"MiniAssetID":20,"FullAssetID":20,"CutSceneAssetID":372566,"TitleDescID":102}],
		"UIChallengeExtraRewardList":[{"ID":1,"ChallengeID":701,"RewardIconID":21,"ViewOrder":1}]
	}
	var before: String = JSON.stringify(source.tables)
	var attendance: Dictionary = Data.menu_route(source,106)
	check(attendance.get("ok",false) and attendance.focus == "attendance" and attendance.domain == "events","exact attendance menu join")
	check(attendance.asset_refs.AssetID.declared_path == "UI/CsbFile/MainMenu/MainMenu_Attendance.csb","menu preserves native declared CSB reference")
	check(Data.menu_route(source,116).get("focus") == "pass","exact pass menu join")
	check(not Data.menu_route(source,86).get("ok",false),"menu type ID is not a button ID")
	source.tables.MainMenuUIButtons[0].IsVisible = false
	check(not Data.menu_route(source,106).get("ok",false),"hidden source button cannot route")
	source.tables.MainMenuUIButtons[0].IsVisible = true
	source.tables.MainMenuUIButtons[0].AssetID = 372696
	check(not Data.menu_route(source,106).get("ok",false),"menu asset cannot substitute a different menu")
	source.tables.MainMenuUIButtons[0].AssetID = 372566
	var category: Dictionary = Data.category_route(source,Data.CHALLENGE_KEY)
	check(category.get("ok",false) and category.domain == "challenge" and category.source_records.UIDungeonCategory.DungeonCategoryID == 21,"exact ordinary dungeon category route")
	check(not Data.category_route(source,"Challenge").get("ok",false),"feature labels do not route")
	source.tables.DungeonCategory[0].Release = false
	check(not Data.category_route(source,Data.CHALLENGE_KEY).get("ok",false),"unreleased category cannot route")
	source.tables.DungeonCategory[0].Release = true
	var pass_row: Dictionary = {"id":"pass:724","label":"arbitrary label"}
	var pass_data: Dictionary = Data.project(source,"events",pass_row)
	check(pass_data.source_namespace == "PassSystem" and pass_data.source_id == 724 and pass_data.row_id == pass_row.id,"machine namespace and ID select pass metadata")
	check(pass_data.native_fields.PassImageNode == "Nd_Img_SeasonPass" and pass_data.asset_refs.size() == 3,"all pass image refs and explicit node retained")
	check(pass_data.desc_refs["PassSystem:724:DescID"] == 100,"raw description reference retained")
	check(Data.project(source,"events",{"id":"pass:724:70:true"}).source_records.PassSystemLevel.ID == 70,"tier FK validated")
	check(Data.project(source,"events",{"id":"pass:724:999:true"}).source_records.is_empty(),"unrelated or missing pass tier rejected")
	check(Data.project(source,"events",{"id":"pass-quest:724:6"}).source_records.PassSystemQuest.QuestID == 6,"pass daily quest list FK validated")
	check(Data.project(source,"events",{"id":"pass-quest:724:9"}).source_records.is_empty(),"another pass quest list is not joined")
	var daily: Dictionary = Data.project(source,"events",{"id":"attendance:8:39:KR:1"})
	check(daily.source_records.AttendanceReward.size() == 2 and daily.reward_index == 1,"attendance retains every native server alternative")
	check(Data.project(source,"events",{"id":"attendance:8:38:KR:1"}).source_records.is_empty(),"attendance version is part of the machine key")
	check(Data.project(source,"events",{"id":"attendance:8:39:TW:1"}).source_records.is_empty(),"attendance region is part of the machine key")
	var context: Dictionary = {"instances":{"owned:100":{"instance_id":"owned:100","sourceID":100}}}
	var grail: Dictionary = Data.project(source,"jade_grail",{"id":"grail:owned:100","base_prefix_id":24,"absolute_prefix_id":4},context)
	check(grail.source_namespace == "ItemClass" and grail.source_id == 100 and grail.instance_id == "owned:100" and grail.source_records.ItemGrace.ID == 4,"grail physical ID resolves only through context source namespace")
	check(grail.asset_refs.IconID.declared_path == "icon/item.png" and not grail.source_records.has("UIItemGraceIcon"),"item icon preserves mapping while unverified saved prefix does not choose a grace icon")
	check(Data.project(source,"jade_grail",{"id":"grail:100"}).source_records.is_empty(),"physical ID is not an ItemClass ID")
	check(Data.project(source,"jade_grail",{"id":"jade:100"}).source_records.is_empty(),"grail category cannot masquerade as jade")
	check(Data.project(source,"jade_grail",{"id":"jade:101"}).source_id == 101,"native jade item metadata")
	var challenge: Dictionary = Data.project(source,"challenge",{"id":"challenge:701"})
	check(challenge.source_id == 701 and challenge.asset_refs.CutSceneAssetID.asset_id == 372566 and challenge.source_records.UIChallengeExtraRewardList.ViewOrder == 1,"challenge keeps raw art refs and explicit reward ordering")
	check(Data.project(source,"challenge",{"id":"challenge_active","label":"Challenge701"}).source_records.is_empty(),"active run label cannot invent native Challenge ID")
	var active: Dictionary = Data.project(source,"challenge",{"id":"challenge_active"},{"active_challenge_id":701})
	check(active.get("source_id") == 701 and active.row_id == "challenge_active","active Challenge maps only the saved source ID while preserving its machine row")
	check(Data.project(source,"events",{"id":"other","label":"pass:724"}).source_records.is_empty(),"display labels never select a source record")
	var group: Dictionary = Data.project(source,"events",{"id":"pool:77"})
	check(group.source_group == {"table":"GotChaEntityView","field":"GotChaClassID","value":77} and group.source_member_count == 2 and group.source_records.is_empty(),"roulette summary preserves the exact group reference without duplicating its members")
	check(Data.project(source,"events",{"id":"pool-entity:1"}).source_records.GotChaEntityView.Probability == 7,"selected roulette entity preserves its raw source probability")
	pass_data.source_records.PassSystem.PassImageNode = "mutated"
	pass_data.asset_refs.PassBackgroundAssetID.AssetView.FilePath = "mutated"
	check(JSON.stringify(source.tables) == before and pass_row == {"id":"pass:724","label":"arbitrary label"},"projection copies cannot mutate source or backend DTO")
	var real_path: String = OS.get_environment("TWILIGHT_523_SOURCE_DIR")
	if not real_path.is_empty(): _real_source(real_path)
	else: print("UI_DATA523_REAL_SOURCE_SKIPPED: TWILIGHT_523_SOURCE_DIR not set")
	print("UI_DATA523_CHECKS %d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _real_source(directory: String) -> void:
	var source := Source.new()
	var configured: Dictionary = source.configure_directory(directory)
	check(configured.get("ok",false),"real source test directory loads")
	if not configured.get("ok",false): return
	check(Data.menu_route(source,106).get("ok",false) and Data.menu_route(source,116).get("ok",false),"real native attendance and pass menu joins")
	check(Data.category_route(source,Data.CHALLENGE_KEY).get("ok",false),"real ordinary Challenge category join")
	for pass_row: Dictionary in source.rows("PassSystem"):
		var projected: Dictionary = Data.project(source,"events",{"id":"pass:%d" % int(pass_row.ID)})
		check(projected.source_records.PassSystem == pass_row and projected.native_fields.PassImageNode == pass_row.PassImageNode,"real pass source fields preserved %d" % int(pass_row.ID))
		for field: String in ["PassBackgroundAssetID","PassNameAssetID","PassRewardAssetID"]:
			check(projected.asset_refs.has(field) and projected.asset_refs[field].asset_id == pass_row[field],"real pass asset FK %d %s" % [int(pass_row.ID),field])
	for version: Dictionary in source.rows("AttendanceVersion"):
		for reward: Dictionary in source.find_rows("AttendanceReward","AttendanceVersionID",int(version.ID)):
			var key: String = "attendance:%d:%d:%s:%d" % [int(version.ID),int(version.Version),str(version.ServiceRegionCode),int(reward.RewardIndex)]
			var projected: Dictionary = Data.project(source,"events",{"id":key})
			check(projected.get("source_id") == version.ID and projected.reward_index == reward.RewardIndex,"real attendance machine key %s" % key)
	for item: Dictionary in source.find_rows("ItemClass","CategoryID",10622):
		var uid: String = "test-owned:%d" % int(item.ID)
		var context: Dictionary = {"instances":{uid:{"instance_id":uid,"sourceID":int(item.ID)}}}
		var projected: Dictionary = Data.project(source,"jade_grail",{"id":"grail:"+uid},context)
		check(projected.get("source_id") == item.ID and projected.source_records.has("ItemGrace") and projected.asset_refs.has("IconID"),"real owned grail metadata %d" % int(item.ID))
	for challenge: Dictionary in source.find_rows("Challenge","IsWorking",true):
		var projected: Dictionary = Data.project(source,"challenge",{"id":"challenge:%d" % int(challenge.ID)})
		check(projected.source_records.Challenge == challenge and projected.asset_refs.has("MiniAssetID") and projected.asset_refs.has("FullAssetID") and projected.asset_refs.has("CutSceneAssetID"),"real active Challenge native asset refs %d" % int(challenge.ID))
