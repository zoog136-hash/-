extends "res://tests/patch523_registered_recipes_main_test.gd"
## Actual seven source contracts; controlled inputs, no UI/natural supply claim.
func run() -> void:
 var book=preload("res://scripts/crafting/patch523_rules.gd").new()
 check(book.load_file(OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES"),OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")),"exact latest source candidate loads")
 var items: Dictionary={}
 for entry: Dictionary in book.data.items.values():
  var record: Dictionary=entry.get("catalog_record",{})
  if not record.is_empty():items[str(record.name)]=record
 var ids: Array=[]
 for id: String in book.recipes:
  if book.recipes[id].has("missing_failure_policy"):ids.append(id)
 check(ids.size()==7,"all seven incomplete source outcomes have explicit policies")
 for id: String in ids:
  var recipe: Dictionary=book.recipes[id]
  var saved: Dictionary=recipe.missing_failure_policy.duplicate(true)
  for consume: bool in [false,true]:
   for fee: bool in [false,true]:
    recipe.missing_failure_policy.consume_materials_on_failure=consume
    recipe.missing_failure_policy.consume_fee_on_failure=fee
    var state: Dictionary=prepared(book,recipe)
    var before: String=JSON.stringify(state)
    var result: Dictionary=book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,int(recipe.outcomes[0].probability),{"level":100,"usage":{},"now":int(Time.get_unix_time_from_system())})
    check(result.get("ok",false),"source failure policy produces one candidate "+id+str([consume,fee])+str(result.get("reason","")))
    if not result.get("ok",false):continue
    var original_fee: int=int(recipe.adena)
    var expected: int=(state.gold-original_fee if consume else 0)+(original_fee if fee else 0)
    check(result.cost==expected and result.gold_after==state.gold-expected,"wallet ItemCraftInput and fee toggle independently "+id+str([consume,fee]))
    check((result.inventory.is_empty() and result.item_instances.is_empty()) if consume else (result.inventory==state.inventory and result.item_instances==state.instances),"failure material policy preserves or consumes exact source identities "+id)
    check(JSON.stringify(state)==before,"source failure staging never changes live input state "+id)
  recipe.missing_failure_policy=saved
 print("PATCH523_MISSING_FAILURE_POLICY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_recipes":ids.size(),"policy_combinations":4}))
 quit(0 if failures.is_empty() else 1)
