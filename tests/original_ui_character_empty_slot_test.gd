extends SceneTree
## The original 캐릭터 정보 equipment page (source_main_character_equipment_bindings):
## an empty Common_Slot button is not inert. A slot with a TWILIGHT equipment
## slot opens the bag (TWILIGHT 근사: choose the item there); a slot TWILIGHT
## has no equipment for (휘장, 각반, 견갑, 귀걸이, 룬...) says so.
const BINDINGS=preload("res://scripts/ui/original_ui/source_main_character_equipment_bindings.gd")
const SIDE=preload("res://scripts/ui/renewal_character.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	signal inventory_pressed
	var messages: Array[String]=[]
	var bag_opened: int=0
	func _init() -> void:
		inventory_pressed.connect(func() -> void: bag_opened+=1)
	func show_message(text: String) -> void:
		messages.append(text)

class FallbackWorld extends Node:
	var slot_lookups: int=0
	func _equipment_slot_base(_item: Dictionary) -> String:
		slot_lookups+=1
		return "weapon"

class FallbackHud extends Node:
	var item_image_index: Dictionary={"아이템":{"removed":"res://assets/retired/weapon.png"}}
	var catalog_data: Dictionary={"아이템":[{"name":"removed"},{"name":"없음"},{"name":"원본","image_path":"user://source523/item.png"}]}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_CHARACTER_EMPTY_SLOT_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var bindings=BINDINGS.new()
	bindings._hud=weakref(hud)
	var weapon: Dictionary=bindings.empty_slot("weapon","Slot_Weapon")
	check(weapon.get("opened")=="inventory" and hud.bag_opened==1 and hud.messages[-1]=="가방에서 장착할 무기를 고르세요","an empty weapon slot opens the bag: "+str(hud.messages))
	bindings.empty_slot("helmet","Slot_Helmet")
	check(hud.bag_opened==2 and hud.messages[-1]=="가방에서 장착할 투구를 고르세요","an empty helmet slot opens the bag")
	bindings.empty_slot("necklace","Slot_Necklace")
	check(hud.messages[-1]=="가방에서 장착할 목걸이를 고르세요","the object particle follows the slot name")
	bindings.empty_slot("boots","Slot_Boot")
	check(hud.messages[-1]=="가방에서 장착할 부츠를 고르세요","부츠를")
	bindings.empty_slot("belt","Slot_Belt")
	check(hud.messages[-1]=="가방에서 장착할 벨트를 고르세요","벨트를")
	bindings.empty_slot("body","Slot_Armor")
	check(hud.messages[-1]=="가방에서 장착할 갑옷을 고르세요","갑옷을")
	var insignia: Dictionary=bindings.empty_slot("","Slot_Insignia")
	check(insignia.get("notice")=="no_twilight_slot" and hud.bag_opened==6 and hud.messages[-1]=="휘장 칸에 장착할 장비는 TWILIGHT에 없습니다","a slot without TWILIGHT equipment says so and opens nothing")
	for slots: Dictionary in BINDINGS.PAGES.values():
		for offset: int in slots.slots:
			check(BINDINGS.SLOT_TITLES.has(str(slots.slots[offset].source_name)),"every original slot has a title: "+str(slots.slots[offset].source_name))
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_character_equipment_bindings.gd")
	check(text.contains("Callable(self,\"empty_slot\").bind(physical_slot,str(slot.source_name))") and not text.contains("\"activate\":Callable()}"),"no equipment slot button is bound to an empty Callable")
	var world:=FallbackWorld.new()
	var fallback:=FallbackHud.new()
	world.add_child(fallback)
	var side:=SIDE.new()
	side.bind_item_art(fallback)
	check(world.slot_lookups==0 and side.empty_slot_art.is_empty(),"missing, original-pack and retired pictures are skipped before resolving placeholder slots")
	side.free()
	world.free()
	hud.free()
	print("ORIGINAL_UI_CHARACTER_EMPTY_SLOT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
