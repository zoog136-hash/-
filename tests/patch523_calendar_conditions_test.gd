extends SceneTree
const CONDITIONS=preload("res://scripts/crafting/patch523_craft_conditions.gd")
func _initialize() -> void:
 var first: Dictionary={"ID":10,"Year":2020,"Month":1,"Day":1,"Hour":0,"Minute":0}
 var last: Dictionary={"ID":11,"Year":2030,"Month":1,"Day":1,"Hour":0,"Minute":0}
 var begin: int=Time.get_unix_time_from_datetime_dict({"year":2020,"month":1,"day":1,"hour":0,"minute":0,"second":0})-32400
 var end: int=Time.get_unix_time_from_datetime_dict({"year":2030,"month":1,"day":1,"hour":0,"minute":0,"second":0})-32400
 var window: Dictionary={"source_start":first,"source_end":last,"start_unix":begin,"end_unix":end,"utc_offset_minutes":540,"boundary":"start_inclusive_end_exclusive","clock_origin":"TWILIGHT explicitly configured clock; source has no timezone"}
 var recipe: Dictionary={"id":"synthetic-calendar-contract","craft_conditions":{"schema":"patch523-craft-conditions-v1","min_level":0,"max_level":0,"active_window":window}}
 var failures: Array=[]
 if not CONDITIONS.valid(recipe.craft_conditions):failures.append("complete source calendar shape rejected")
 for pair: Array in [[begin-1,false],[begin,true],[end-1,true],[end,false]]:
  if CONDITIONS.stage(recipe,1,{"now":pair[0],"level":1}).get("ok",false)!=pair[1]:failures.append("wrong calendar endpoint")
 var bad: Dictionary=recipe.craft_conditions.duplicate(true);bad.active_window.source_start.Month=13
 if CONDITIONS.valid(bad):failures.append("invalid source date accepted")
 bad=recipe.craft_conditions.duplicate(true);bad.active_window.start_unix+=60
 if CONDITIONS.valid(bad):failures.append("derived timestamp disagrees with source row")
 if CONDITIONS.stage(recipe,1,{"level":1}).get("ok",false):failures.append("missing clock accepted")
 var cup: Dictionary={"id":"bounded-cup-contract","craft_conditions":{"schema":"patch523-craft-conditions-v1","min_level":0,"max_level":0,"quota":{"limit":4,"anchor_unix":0,"period_seconds":0,"mode":"bounded_lifetime","clock_origin":"TWILIGHT conservative cap; native refresh meaning unavailable","source_restriction":{"ID":10,"ServiceTypeID":13,"Value":4,"RefreshUnitID":111,"isMultiCount":false}}}}
 var ledger: Dictionary={}
 for attempt: int in range(4):
  var staged: Dictionary=CONDITIONS.stage(cup,1,{"level":1,"now":begin+attempt*604800,"usage":ledger})
  if not staged.get("ok",false):failures.append("bounded source cap rejects legal attempt")
  else:ledger=staged.usage_after
 if CONDITIONS.stage(cup,1,{"level":1,"now":end,"usage":ledger}).get("ok",false):failures.append("time jump resets unresolved source quota")
 var invalid: Dictionary=cup.craft_conditions.duplicate(true);invalid.quota.limit=5
 if CONDITIONS.valid(invalid):failures.append("host cap exceeds original source Value4")
 invalid=cup.craft_conditions.duplicate(true);invalid.quota.source_restriction.isMultiCount=true
 if CONDITIONS.valid(invalid):failures.append("unknown source multiplicity silently accepted")
 print("PATCH523_CALENDAR_CONTRACT_RESULT ",JSON.stringify({"checks":15,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
