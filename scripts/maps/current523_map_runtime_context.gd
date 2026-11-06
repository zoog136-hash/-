extends RefCounted
## Reads existing actor/server/calendar context without changing any state.
const SERVER_CONDITIONS=preload("res://scripts/cards/source_collection_conditions.gd")
const CONDITIONS=preload("res://scripts/crafting/patch523_craft_conditions.gd")

static func capture(world: Node) -> Dictionary:
	var result: Dictionary={"level":null,"now_unix":int(Time.get_unix_time_from_system()),"server_profile":{},"calendar_offset_minutes":null,"calendar_clock_origin":"","calendar_hold":"source_server_context_unavailable"}
	if not is_instance_valid(world):return result
	var level: Variant=world.get("level")
	if CONDITIONS.integer(level,1,2147483647):result.level=int(level)
	var recovery: Variant=world.get("death_recovery")
	var death_rules: Variant=recovery.get("source") if recovery is Object else null
	result["map_rule_consumers"]={"hunt_experience":world.has_method("current523_source_hunt_experience_rule"),"source_death":death_rules is Object and death_rules.get("ready")==true}
	var collections: Variant=world.get("card_collections")
	if not collections is Object or not is_instance_valid(collections) or not collections.has_method("source_server_context"):return result
	var profile: Variant=collections.call("source_server_context")
	if not profile is Dictionary or not SERVER_CONDITIONS.valid_context(profile):return result
	result.server_profile=profile.duplicate(true)
	result.calendar_hold="existing_shop_calendar_unavailable"
	var shop: Variant=world.get("source_shop")
	if not shop is Object or not is_instance_valid(shop):return result
	if shop.get("save_blocked")!=false:
		result.calendar_hold="existing_shop_calendar_blocked";return result
	var problem: Variant=shop.get("problem")
	if not problem is String or not problem.is_empty():
		result.calendar_hold="existing_shop_calendar_problem";return result
	var offset: Variant=shop.get("calendar_offset_minutes")
	if not CONDITIONS.integer(offset,-840,840):
		result.calendar_hold="existing_shop_calendar_offset_unconfigured";return result
	var shop_context: Variant=shop.get("server_context")
	if not shop_context is Dictionary:
		result.calendar_hold="existing_shop_server_context_unavailable";return result
	var adapted: Dictionary={"source_snapshot":profile.source_snapshot,"ServiceRegionCode":shop_context.get("region"),"WorldNo":shop_context.get("world_no")}
	if not SERVER_CONDITIONS.valid_context(adapted):
		result.calendar_hold="existing_shop_server_context_unavailable";return result
	if adapted.ServiceRegionCode!=profile.ServiceRegionCode or adapted.WorldNo!=profile.WorldNo:
		result.calendar_hold="existing_shop_server_context_conflict";return result
	var state: Variant=shop.get("state")
	if not state is Dictionary or not CONDITIONS.integer(state.get("clock_highwater"),0,9007199254740991):
		result.calendar_hold="existing_shop_calendar_clock_unavailable";return result
	if result.now_unix<state.clock_highwater:
		result.calendar_hold="existing_shop_calendar_clock_rollback";return result
	result.calendar_offset_minutes=int(offset)
	result.calendar_clock_origin="TWILIGHT existing explicit source523 shop calendar policy"
	result.calendar_hold=""
	return result

static func identity(context: Dictionary) -> Dictionary:
	var profile: Variant=context.get("server_profile",{})
	return {"map_rule_consumers":context.get("map_rule_consumers",{}).duplicate(true),"level":context.get("level"),"server_profile":profile.duplicate(true) if profile is Dictionary else {},"calendar_offset_minutes":context.get("calendar_offset_minutes"),"calendar_clock_origin":context.get("calendar_clock_origin",""),"calendar_hold":context.get("calendar_hold","source_server_context_unavailable")}
