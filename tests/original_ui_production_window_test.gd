extends SceneTree
## Original 523 제작 window (source_main_production_window). Synthetic (no
## original files): the window names the exact client CSBs and fails closed
## without them, product names drop TWILIGHT bookkeeping, the recipe list
## scroll bounds follow the rows, 제 작 asks through the existing 제작 확인
## and the HUD opens the window before the TWILIGHT crafting screen.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_production_window.gd")
const CRAFT=preload("res://scripts/ui/renewal_crafting.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeCrafting extends RefCounted:
	var recipes: Dictionary={"r1":{"name":"원본523 · 시험 물약","category":"물약","result":{"item":"시험 물약","quantity":2},"materials":[{"item":"재료","quantity":3}]}}

class FakeGame extends Node:
	var crafting:=FakeCrafting.new()
	var ok: bool=true
	func _craft_quote(_id: String, _count: int) -> Dictionary:
		return {"ok":ok,"cost":0,"reason":"재료 부족"}

class ConfirmHost extends Node:
	signal craft_requested(recipe_id: String, batches: int)
	var asked: Array=[]
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		asked.append([title,body,action])
		callback.call(1)
		return null

class PreviewHost extends TwilightWorld:
	var index_reads: int = 0

	func _sync_item_instances() -> void: pass
	func _inventory_total_weight() -> int: return 30
	func _carrying_capacity() -> int: return 100

	func _craft_item_index() -> Dictionary:
		index_reads += 1
		return {"local_bar":{"name":"local_bar"}}

	func _quote_craft(recipe_id: String, batches: int, weight: int, capacity: int, local_items: Dictionary) -> Dictionary:
		return {"id":recipe_id,"batches":batches,"weight":weight,"capacity":capacity,"items":local_items}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_PRODUCTION_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ALL=="UI/Production/Production_All.csb" and WINDOW.TAB_LIST=="UI/Production/Production_Tab_List.csb" and WINDOW.ROW_ITEM=="UI/Production/Production_List_Item.csb" and WINDOW.ROW_MATERIAL=="UI/Production/Production_List_Material_Set.csb","the window names the client's Production members")
	check(WINDOW.LAYOUT_POSITION==Vector2(600.0,-337.5),"Production_All sits at ProductionScene's Production_All_Layout (600, 337.5)")
	var pack:=FakePack.new()
	var host:=Node.new()
	var configured: Dictionary=WINDOW.new().configure(pack,host)
	check(not configured.get("ok",true) and configured.get("code")=="source_production_window_member_missing" and configured.get("member")==WINDOW.ALL,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.ROW_SORT)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROW_SORT,"a missing nested member is named")
	host.free()
	check(WINDOW._title({"name":"원본523 · 마족의 지팡이"},{"item":"마족의 지팡이 · 원본#123","level":0},"x")=="마족의 지팡이","the product name drops the source id")
	check(WINDOW._title({"name":"원본523 · 시험"},{},"x")=="시험","without a product the recipe name drops 원본523")
	check(WINDOW._title({},{"item":"장검","level":7},"x")=="+7 장검","an enchanted product shows its level")
	check(WINDOW.TABS.equip==["무기","방어구","장신구"] and WINDOW.TABS.other==["물약","재료"],"장비 / 기타 hold the TWILIGHT recipe categories")
	var scroll=WINDOW.ListScroll.new()
	var content:=Node2D.new()
	scroll.y=-500.0
	scroll.bind(content,408.0,64.0*10)
	check(is_equal_approx(scroll.minimum,408.0-640.0) and is_equal_approx(scroll.y,408.0-640.0) and is_equal_approx(content.position.y,scroll.y),"the list scroll stops at its last row")
	scroll.bind(content,408.0,64.0*3)
	check(scroll.minimum==0.0 and scroll.y==0.0,"a short list does not scroll")
	content.free()
	_confirmation()
	_ready_rows()
	_sources()
	print("ORIGINAL_UI_PRODUCTION_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _confirmation() -> void:
	var host:=ConfirmHost.new()
	var game:=FakeGame.new()
	var emitted: Array=[]
	host.craft_requested.connect(func(id: String, count: int) -> void: emitted.append([id,count]))
	check(CRAFT.confirm_craft(host,game,"r1",3),"제 작 asks through the existing confirmation")
	check(host.asked.size()==1 and host.asked[0][0]=="제작 확인" and str(host.asked[0][1]).contains("×3"),"the confirmation names the amount")
	check(emitted==[["r1",3]],"accepting emits the existing craft request")
	game.ok=false
	check(not CRAFT.confirm_craft(host,game,"r1",1) and host.asked.size()==1,"a refused quote asks nothing")
	check(CRAFT.recipe_of(game,"r1").get("category")=="물약","recipe_of reads the existing registry")
	host.free();game.free()

## 사용자 목록 28: craftable recipes first from the start, the others dimmed
## with the row's original Btn_Disabled layer and still selectable.
func _ready_rows() -> void:
	var window=WINDOW.new()
	check(window._ready_first,"제작 가능 우선 is on when the window opens")
	var ids: Array[String]=["a","b","c","d"]
	check(WINDOW.ready_first(ids,func(id: String) -> bool:return id in ["c","a"])==["a","c","b","d"],"craftable recipes come first, each group in its own order")
	var host := PreviewHost.new()
	var preview: Callable = host.production_preview_quote()
	var native: Dictionary = preview.call("patch523:1172",1)
	check(host.index_reads==0 and native.items.is_empty() and native.weight==30 and native.capacity==100,"original preview does not copy the name-based item catalog")
	var legacy: Dictionary = preview.call("local",1)
	check(legacy.items.has("local_bar") and preview.call("other",2).items==legacy.items and host.index_reads==1,"legacy quotes build the catalog once within the same preview")
	var art: Dictionary = {"name":"iron"}
	host.loot_catalog["by_name"] = {"iron":art}
	check(is_same(host.production_item_record("iron"),art) and host.production_item_record("missing").is_empty() and host.index_reads==1,"individual item icons need neither a full catalog copy nor an absent grant")
	host.free()
	for name: String in ["sort","items","materials"]:window._scrolls[name]=WINDOW.ListScroll.new()
	var game:=FakeGame.new()
	game.crafting.recipes["r1"]["result"]["source_id"]="77"
	var ready: Dictionary=window._item_row(game,"r1")
	check(not ready.spec.Btn_Disabled.visible and ready.spec.Btn_Disabled.exclude and ready.spec.Label_Production.visible and ready.ok,"a craftable row does not instantiate the dim layer")
	check(ready.spec.Btn_Pressed.exclude and not ready.spec.Btn_Normal.get("exclude",false) and ready.spec["Panel/Btn_CheckBox/Btn_Enable"].exclude,
		"a default row mounts only the active button and bookmark variants")
	game.ok=false
	var blocked: Dictionary=window._item_row(game,"r1")
	check(blocked.spec.Btn_Disabled.visible and not blocked.spec["Btn_Disabled/Nd_SoldOut"].visible and not blocked.spec.Label_Production.visible and not blocked.ok,"a recipe that cannot be made shows the original dim layer, not 품절")
	check((blocked.spec.Btn_Disabled.activate as Callable).get_method()=="_select" and (blocked.spec.Btn_Disabled.activate as Callable).get_bound_arguments()==["r1"],"a dimmed row still selects its recipe")
	game.free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("if _open_original_production(): return"),"제작 opens the original window first")
	check(hud_text.contains("_hold_original_inventory_window(\"제작\","),"a rejected selected pack holds the crafting screen and reports the reason")
	check(hud_text.contains("refresh_production_window()") and hud_text.contains("close_production_window()"),"a craft refreshes and closing the workspace closes the window")
	check(hud_text.contains("CraftUI.pending_focus") and hud_text.contains("select_recipe(target)"),"획득처 → 제작 selects the recipe in the original window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_production_window","func production_window_is_open","func close_production_window"," or production_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_production_window.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	check(text.contains("Craft.confirm_craft(") and text.contains("patch523_material_choices"),"제 작 and 대체 use the existing owners")
	check(text.contains("const ITEM_WINDOW"),"the recipe list builds only rows near its visible part")
	var panel_text: String=FileAccess.get_file_as_string("res://scripts/ui/patch523_npc_panel.gd")
	check(panel_text.contains("process_mode = Node.PROCESS_MODE_ALWAYS"),"the 보스 기술 button keeps hiding under an original window")
