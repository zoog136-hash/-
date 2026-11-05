extends SceneTree
const Service = preload("res://scripts/tj/coupon_service.gd")
const Source = preload("res://scripts/tj/source523.gd")
const Runtime = preload("res://scripts/tj/runtime.gd")
var checks := 0
var failures: Array[String]=[]
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:failures.append(message);push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var isolated: String=OS.get_environment("TWILIGHT_TJ_TEST_ROOT")
	check(not isolated.is_empty() and ProjectSettings.globalize_path("user://").begins_with(isolated),"isolated saves required")
	var args: PackedStringArray=OS.get_cmdline_user_args()
	check(args.size()==1,"source ZIP argument")
	var data: Dictionary=Source.load_zip(args[0])
	check(data.size()>0,"verified actual523 source")
	check(data.coupons.size()==139 and data.profiles.size()==10,"all139 entrances and10 profiles")
	var service=Service.new();service.definitions=data
	for id: String in data.coupons:
		var coupon: Dictionary=data.coupons[id]
		var profile: Dictionary=coupon.profile
		var matched:=0
		for history: Dictionary in data.histories:
			if int(history.HistoryType)==int(profile.TJCouponHistoryType):matched+=1;check(int(history.OwnerType)==int(profile.OwnerTypeID),"source owner agreement")
		check(matched==1,"join by history type for every coupon")
		check(service.candidates(id,{},service.clock()).get("events",[]).is_empty(),"catalog never invents failures")
	var fixture: Dictionary={"profiles":{},"coupons":{"900001":{"item":{"Name":"Synthetic test coupon"},"profile":{"TJCouponHistoryType":1,"OwnerTypeID":1,"BuffCardDeckID":1,"ChoiceFailCardCount":0,"BuffCardMinGrade":2},"effects":[{"BonusTypeID":11551,"Value":6},{"BonusTypeID":492,"Value":0,"BonusApplicationTypeID":298,"BonusApplicationTargetID":3}]}},"histories":[{"ID":31,"HistoryType":1,"OwnerType":1,"MinGrade":3}],"mappings":[{"HistoryType":1,"UnitID":31,"Value":1}],"dates":{"1":{"Year":2026,"Month":1,"Day":1},"2":{"Year":2027,"Month":1,"Day":1},"3":{"Year":2027,"Month":2,"Day":1}},"seasons":[{"ID":882,"HistoryType":1,"Season":6,"ServerLimitSetID":9,"StartDateTimeID":1,"EndDateTimeID":2}],"servers":[{"ServerLimitSetID":9,"ServiceRegionCode":"KR","WorldNo":1}],"cards":{"100":{"BuffCardDeckID":1,"GradeID":4},"101":{"BuffCardDeckID":1,"GradeID":3}}}
	service.definitions=fixture
	var context: Dictionary={"service_region_code":"KR","world_no":1}
	var now: int=Time.get_unix_time_from_datetime_string("2026-11-04T12:00:00")
	check(service.resolve("900001",context,now).window.ID==882,"season number is not row ID")
	check(not service.resolve("900001",{"service_region_code":"JP","world_no":1},now).ok,"region/world tuple required")
	service.state.coupons["900001"]=1
	var event: Dictionary={"adapter":"fusion","history_type":1,"deck":1,"grade":3,"time":now-100,"context":context,"success_candidates":["100"],"fail_candidates":["101"]}
	check(service.record_failure(event),"actual event adapter records failure")
	var id: String=str(service.state.history[0].id)
	var revision: int=int(service.state.revision)
	var before: Dictionary=service.export_state()
	check(not service.prepare("900001",id,context,now,revision,[],["101"]).ok,"missing success choice")
	check(service.export_state()==before,"preview and cancel have no mutation")
	var prepared: Dictionary=service.prepare("900001",id,context,now,revision,["100"],["101"])
	check(prepared.ok and prepared.state.coupons["900001"]==0,"stage coupon debit and record consumption")
	check(service.export_state()==before,"no state published before durable save")
	check(service.import_state(prepared.state),"successful committed state reload")
	check(not service.prepare("900001",id,context,now,revision,["100"],["101"]).ok,"duplicate click rejected")
	check(service.candidates("900001",context,now).events.is_empty(),"already spent record hidden")
	check(service.import_state(before),"restore independent fixture state")
	fixture.coupons["900001"].profile.ChoiceFailCardCount=5
	for number: int in range(102,106):
		fixture.cards[str(number)]={"BuffCardDeckID":1,"GradeID":3}
		service.state.history[0].fail_candidates.append(str(number))
	check(not service.prepare("900001",id,context,now,int(service.state.revision),["100"],["101","101","101","101","101"]).ok,"special merge cannot repeat one failure choice five times")
	check(service.prepare("900001",id,context,now,int(service.state.revision),["100"],["101","102","103","104","105"]).ok,"special merge accepts exactly five distinct recorded failure candidates")
	fixture.coupons["900001"].profile.ChoiceFailCardCount=0
	check(service.prepare("900001",id,context,now,int(service.state.revision),["100"],["101"]).ok,"normal merge does not acquire special selection rule")
	fixture.coupons["900001"].profile.OwnerTypeID=2;fixture.histories[0].OwnerType=2
	service.settings.character="different-character"
	check(service.candidates("900001",context,now).events.is_empty(),"character-specific history cannot cross characters")
	fixture.coupons["900001"].profile.OwnerTypeID=1;fixture.histories[0].OwnerType=1
	check(service.candidates("900001",context,now).events.size()==1,"account scope differs from character scope")
	service.settings.account="different-account"
	check(service.candidates("900001",context,now).events.is_empty(),"account history cannot cross accounts")
	service.settings.account="offline-account";service.settings.character="offline-character"
	service.state.history[0].grade=2
	check(service.candidates("900001",context,now).events.is_empty(),"history minimum is distinct from coupon minimum")
	service.state.history[0].grade=3;fixture.cards["101"].GradeID=1
	check(not service.prepare("900001",id,context,now,int(service.state.revision),["100"],["101"]).ok,"candidate below coupon minimum is rejected")
	fixture.cards["101"].GradeID=3
	check(not service.resolve("900001",context,int(Time.get_unix_time_from_datetime_string("2028-01-01T00:00:00"))).ok,"zero DeleteTime value uses its actual expiry row")
	var effects: Array=fixture.coupons["900001"].effects.duplicate(true)
	fixture.coupons["900001"].effects=[effects[0],{"BonusTypeID":492,"Value":2028120105,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}]
	check(not service.resolve("900001",context,now).ok,"raw legacy time is not Unix time or a date row ID")
	service.settings.legacy_time_mode="calendar_yyyymmddhh"
	check(service.resolve("900001",context,now).ok,"explicit local legacy calendar policy is separate from source values")
	fixture.coupons["900001"].effects=[effects[0]]
	check(not service.resolve("900001",context,now).ok,"missing expiry is not automatically permanent")
	service.settings.allow_unknown_expiry=true
	check(service.resolve("900001",context,now).ok,"unknown expiry requires explicit local policy")
	fixture.coupons["900001"].effects=[effects[1]]
	check(not service.resolve("900001",context,now).ok,"missing season is not assigned latest season")
	service.settings.allow_no_season=true
	check(service.resolve("900001",context,now).ok,"explicit no-season policy does not fabricate a season")
	fixture.coupons["900001"].effects=effects
	check(bool(data.profiles["121"].IgnoreMinGradeMergeChance) and bool(data.profiles["121"].PossibleUnderGradeMerge),"both source skill exceptions are preserved")
	for profile: Dictionary in data.profiles.values():
		if int(profile.ID)==121:continue
		check(not bool(profile.IgnoreMinGradeMergeChance) and not bool(profile.PossibleUnderGradeMerge),"skill exceptions are not copied onto other return policies")
	service.import_state(prepared.state)
	var broken: Dictionary=before.duplicate(true);broken.coupons["900001"]=-1
	check(not service.import_state(broken) and service.blocked,"corrupt save blocks spending")
	check(service.export_state()==prepared.state,"corrupt save preserves live state")
	print(JSON.stringify({"TJ523_RESULT":failures.is_empty(),"failures":failures,"checks":checks,"coupons":139,"policies":10,"actual_world":false}))
	quit(0 if failures.is_empty() else 1)
