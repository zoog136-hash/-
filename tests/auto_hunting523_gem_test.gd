extends SceneTree
## Actual pinned source catalog + synthetic wallet for focused accounting guards.
const SCHEDULE=preload("res://scripts/auto_hunting/source_schedule.gd")
const POLICY=preload("res://scripts/auto_hunting/local_movement.gd")
class Wallet extends Node:
	var inventory:Dictionary={"다이아":100,"보존":5}
	var item_instances:Dictionary={}
	var locked:bool=false
	var gold:int=12345
	func _item_locked(_name:String)->bool:return locked
var checks:int=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("AUTO_HUNT_GEM_FAIL: ",label)
func run()->void:
	var source=SCHEDULE.new();check(source.load_configured(),"actual pinned Drive-restored pack loads")
	var gem_count:int=0
	for entry:Dictionary in source.list_destinations():
		if str(entry.currency.Name)!="Gem":continue
		gem_count+=1
		var id:int=entry.schedule.ID;var link:int=entry.destinations[0].link.ID;var price:int=entry.teleport.TeleportCost
		check(int(entry.currency.ID)==4 and int(entry.currency.AssetID)==22192 and int(entry.currency.DescID)==729861,"original Gem4 identity preserved")
		check(source.request_definition(id,link,99,999999).code=="UNSUPPORTED_CURRENCY","no implicit inventory-to-Gem binding")
		check(source.request_definition(id,link,99,999999,price-1).code=="INSUFFICIENT_GEM","original fee cannot be paid with Adena")
		var result:Dictionary=source.request_definition(id,link,99,0,price)
		check(result.ok and result.currency_id==4 and result.price==price and result.currency_asset_id==22192,"exact Gem funds accepted independently of gold")
	check(gem_count==23,"all23 original Gem menus checked")
	var world:=Wallet.new();root.add_child(world)
	var policy=POLICY.new();policy.settings_path="user://gem-policy-unit.json"
	check(policy.gem_wallet(world).code=="GEM_WALLET_DISABLED","explicit local wallet opt in required")
	check(policy.update_settings({"enabled":true,"end_inclusive":true,"search_order":"center_first","gem_wallet_enabled":true}).ok,"local wallet policy saved")
	check(policy.gem_wallet(world).balance==100,"existing HUD inventory wallet reused without grants")
	var staged:Dictionary=POLICY.cost_override(world,{"currency_id":4,"price":10})
	check(staged=={"inventory":{"다이아":90,"보존":5}} and world.inventory["다이아"]==100 and world.gold==12345,"staged debit leaves live resources unchanged")
	check(POLICY.cost_override(world,{"currency_id":4,"price":100})=={"inventory":{"보존":5}},"zero balance removes only wallet key")
	world.locked=true;check(policy.gem_wallet(world).code=="GEM_LOCKED","existing inventory lock preserved");world.locked=false
	world.item_instances={"123":{"name":"다이아","locked":true}}
	check(policy.gem_wallet(world).code=="GEM_INSTANCE_GUARD","physical/locked instance cannot be consumed as wallet");world.item_instances={}
	for invalid:Variant in ["100",-1,0.5,INF]:
		world.inventory["다이아"]=invalid
		check(policy.gem_wallet(world).code=="INVALID_GEM_WALLET","invalid wallet fails closed")
	world.inventory.erase("다이아");check(policy.gem_wallet(world).balance==0,"missing wallet never grants currency")
	var old:=FileAccess.open("user://gem-old-settings.json",FileAccess.WRITE)
	old.store_string(JSON.stringify({"schema":1,"policy":POLICY.POLICY_ID,"enabled":true,"end_inclusive":false,"search_order":"coordinate_order"}));old.close()
	var sha:String=FileAccess.get_sha256("user://gem-old-settings.json")
	var migrated=POLICY.new();migrated.settings_path="user://gem-old-settings.json"
	check(migrated.get_settings()=={"enabled":true,"end_inclusive":false,"search_order":"coordinate_order","gem_wallet_enabled":false,"allow_entry_area":false},"old policy preserved with new currency opt in off")
	check(FileAccess.get_sha256(migrated.settings_path)==sha,"reading old settings never rewrites bytes")
	print("AUTO_HUNT_GEM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"gem_menus":gem_count,"synthetic_wallet":true}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
