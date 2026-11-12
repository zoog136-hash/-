extends SceneTree
## Closed presentation snapshots must not own source textures. No player data.
const HUD=preload("res://scripts/ui/original_ui/source_main_hud.gd")
var checks: int=0
var failures: Array[String]=[]

class LeasePack extends RefCounted:
	var releases: int=0
	func release_cache_leases() -> void:
		releases+=1

class View extends RefCounted:
	var opened: bool=true
	var closes: int=0
	func is_open() -> bool:return opened
	func close() -> void:
		opened=false
		closes+=1

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _payload() -> RefCounted:
	# Real texture ownership, tiny synthetic pixels rather than private art.
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.4,0.6,0.5))
	return ImageTexture.create_from_image(image)

func _run() -> void:
	var controller=HUD.new()
	var pack:=LeasePack.new()
	controller._pack=pack
	var view:=View.new()
	controller._inventory_view=view
	var item: RefCounted=_payload()
	var item_weak: WeakRef=weakref(item)
	controller._inventory_result={"ok":true,"owner_results":{3:{"texture":item}}}
	controller._inventory_name_result={"ok":true,"texture":item}
	item=null
	check(item_weak.get_ref()!=null,"diagnostic snapshot reproduces strong texture retention")
	controller.close_inventory()
	check(not view.opened and view.closes==1,"actual controller closes its view")
	check(controller._inventory_result.is_empty() and controller._inventory_name_result.is_empty(),"closed slot/name snapshots are cleared")
	check(item_weak.get_ref()==null,"closed snapshot releases last texture reference")
	check(pack.releases==1,"close returns CPU page leases")
	# Direct authored close signal takes a different path than close_inventory.
	var signalled: Array=[]
	controller.inventory_closed.connect(func() -> void:signalled.append(true))
	item=_payload()
	item_weak=weakref(item)
	controller._inventory_result={"texture":item}
	item=null
	controller._inventory_view_closed()
	check(item_weak.get_ref()==null and signalled.size()==1,"direct close signal retires snapshot before notifying HUD")
	var fallback: Array=[]
	controller.inventory_return_to_current_requested.connect(func(reason: Dictionary) -> void:fallback.append(reason.get("code")))
	item=_payload()
	item_weak=weakref(item)
	controller._inventory_result={"owner":{"texture":item}}
	item=null
	controller._inventory_view_fallback({"ok":false,"code":"source-selection-changed"})
	check(item_weak.get_ref()==null and fallback==["source-selection-changed"],"unsupported fallback retires the successful snapshot before forwarding its reason")
	# A live scene can continue to own exactly the same texture.
	item=_payload()
	var active:=Sprite2D.new()
	active.texture=item
	var before: PackedByteArray=active.texture.get_image().get_data()
	controller._character_result={"texture":item}
	item=null
	controller.close_character()
	check(controller._character_result.is_empty(),"closed character diagnostic snapshot is retired")
	check(active.texture!=null and active.texture.get_image().get_data()==before,"another live sprite retains exact pixels")
	for method: String in ["close_quest_window","close_change_window","close_shop_window"]:
		var count: int=pack.releases
		controller.call(method)
		check(pack.releases==count+1,method+" returns atlas leases")
	# Minimal/missing-pack hosts and repeated close remain safe.
	controller._pack=null
	controller.close_inventory()
	controller._inventory_view=null
	controller.free()
	active.free()
	print("ORIGINAL_UI_MENU_RETIREMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"private_pack_used":false}))
	quit(0 if failures.is_empty() else 1)
