extends SceneTree
## Static item icons have no authored scene slot to register. Animated icons
## must still receive the same verified Common_Slot Sprite contract.
const HUD=preload("res://scripts/ui/original_ui/source_main_hud.gd")
const UI_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const IMAGE_OWNER=preload("res://scripts/ui/source523_image_assets.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const PIN="5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
const ANIMATED="UI/Icon/TestAnimated.csb"
var checks: int=0
var failures: Array[String]=[]

class ImageFixture extends RefCounted:
	var texture:=PlaceholderTexture2D.new()
	var status: String="original_linked"
	func source_consumer_row(_table: String, id: int) -> Dictionary:
		return {"ok":true,"row":{"ID":id},"provenance":{}}
	func resolve_consumer(_table: String, _id: int, _key: String) -> Dictionary:
		return {"ok":status=="original_linked","status":status,"texture":texture if status=="original_linked" else null,
			"provenance":{"path":ANIMATED if status=="unsupported_csb" else "icon/static.png","asset_type_id":101 if status=="unsupported_csb" else 1}}

class BagFixture extends Node:
	func _item_visual_record(_reference: String, record: Dictionary) -> Dictionary:
		return record
	func _find_item_record(_reference: String) -> Dictionary:
		return {}

class HudFixture extends Node:
	var lineage_inventory_ui: Node
	var _original_icon_scene_provider: Callable

class CountingPack extends UI_PACK:
	var slot_reads: int=0
	var real_pack: bool=false
	func layout_source(member: String) -> Dictionary:
		if member==SLOTS.SLOT_MEMBER:slot_reads+=1
		if real_pack:return super.layout_source(member)
		return {"_source_sha256":SLOTS.SLOT_SHA,"nodeTree":{"_offset":SLOTS.ICON,"classname":"Sprite","children":[],
			"options":{"position":[0,0],"anchorPoint":[0.5,0.5],"size":[64,64],"blendFunc":{"src":1,"dst":771}}}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("BAG_ICON_SLOT_FAIL ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var pack:=CountingPack.new()
	var path: String=OS.get_environment("TWILIGHT_INVENTORY_ICON_UI44")
	if path.is_empty():
		pack.manifest={"externally_bound_texture_nodes":{SLOTS.SLOT_MEMBER:[SLOTS.ICON]}}
		pack.manifest_sha256=PIN
	else:
		pack.real_pack=true
		if not pack.open(path,PIN).get("ok",false):
			check(false,"an explicitly supplied original UI pack must verify")
			quit(1)
			return
	var fixture:=ImageFixture.new()
	IMAGE_OWNER._selection_checked=true
	IMAGE_OWNER._selected=true
	IMAGE_OWNER._pack=fixture
	var hud:=HudFixture.new()
	var bag:=BagFixture.new()
	hud.add_child(bag)
	hud.lineage_inventory_ui=bag
	var seen: Array[Dictionary]=[]
	hud._original_icon_scene_provider=func(_info: Dictionary, context: Dictionary) -> Dictionary:
		seen.append(context)
		return {"ok":true,"descriptor":{"member":ANIMATED}}
	var controller:=HUD.new()
	controller._hud=weakref(hud)
	controller._pack=pack
	var record: Dictionary={"name":"fixture","source_m_native_item":true,"source_snapshot":"patch523","source_item_class_id":85}
	var entry: Dictionary={"name":"fixture","reference":"fixture@@@slot","record":record}
	var context: Dictionary={"member":SLOTS.SLOT_MEMBER,"node_offset":SLOTS.ICON,"slot_project_offset":17,"reference":entry.reference}
	var count: int=22
	var samples: Array[float]=[]
	for sample: int in count:
		var started: int=Time.get_ticks_usec()
		for index: int in 20:
			var result: Dictionary=controller._inventory_original_image(entry,context)
			if not result.get("ok",false) or result.texture!=fixture.texture:
				check(false,"static item continues using the existing exact texture")
				break
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	samples.sort()
	var static_reads: int=pack.slot_reads
	check(static_reads==0 and seen.is_empty(),"static icons skip the animated slot lookup for every owned reference")
	fixture.status="missing_current_member"
	var missing: Dictionary=controller._inventory_original_image(entry,context)
	check(missing.get("owner_result",{}).get("reason")=="missing_current_member" and pack.slot_reads==static_reads,
		"missing images keep their reason and skip slot registration")
	fixture.status="unsupported_csb"
	var animated: Dictionary=controller._inventory_original_image(entry,context)
	check(animated.get("source_scene_descriptor",{}).get("member")==ANIMATED and pack.slot_reads==static_reads+1 and seen.size()==1,
		"only animated icons resolve and send the authored slot")
	if not seen.is_empty():
		var slot: Dictionary=seen[0].source_slot_contract
		check(slot.ok and slot.node_offset==SLOTS.ICON and slot.source_sha256==SLOTS.SLOT_SHA and slot.manifest_sha256==PIN
			and seen[0].reference==entry.reference and seen[0].slot_project_offset==17,"registration preserves the same physical reference and exact original node")
	var incorrect: Dictionary=context.duplicate()
	incorrect.node_offset=-1
	check(not controller._inventory_original_image(entry,incorrect).get("ok",false) and seen.size()==1,
		"unregistered animated destinations remain blocked")
	check(not context.has("source_slot_contract"),"augmented context is private to the animated call")
	IMAGE_OWNER.clear_selection()
	controller.free()
	hud.free()
	print("BAG_ICON_SLOT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_ui":pack.real_pack,"static_reads":static_reads,
		"batch_ms_p50":samples[count/2],"batch_ms_p95":samples[ceili(float(count)*0.95)-1]}))
	quit(0 if failures.is_empty() else 1)
