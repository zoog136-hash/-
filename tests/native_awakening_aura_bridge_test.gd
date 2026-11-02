extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Actor extends Node2D:
	var source_facing: int=5
	var mode: String="compatible"
	func clear() -> void:pass
	func installed() -> bool:return true
	func source_playback_mode() -> String:return mode
	func source_role() -> String:return "idle"
class Host extends Fixture.Host:
	var option_awakening
	var presentation_settings: Dictionary={}
var errors: Array[String]=[]
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty() or not ResourceLoader.exists("res://scripts/animation/source_awakening_aura.gd"):push_error("Explicit catalog and existing PR217 aura renderer required");quit(2);return
	var host=Host.new();root.add_child(host);host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	var service=Runtime.new();host.option_awakening=service;check(service.configure(host),"configure native option adapter")
	var identity: String="source:m508:2:11692";var record: Dictionary=service.core.catalog["마법인형"][identity]
	check(not service.source_visual_awakened("마법인형",record),"possession or grade alone never awakens")
	host.card_draw_fusion.owned["마법인형"][identity]=true
	check(not service.source_visual_awakened("마법인형",record),"owned canonical card still requires saved option completion")
	service.progress.cards["마법인형"][identity]={"experience":0,"awakened":true,"attempts":1,"failures":0}
	check(service.source_visual_awakened("마법인형",record),"existing PR217 API accepts source option completion")
	check(not service.source_visual_awakened("성물",record),"category mismatch rejected")
	var legacy: Dictionary=record.duplicate(true);legacy.sourceId="11692"
	check(not service.source_visual_awakened("마법인형",legacy),"legacy numeric identity never migrated into native aura")
	var actor=Actor.new();root.add_child(actor)
	var renderer: Script=load("res://scripts/animation/source_awakening_aura.gd")
	var aura: Node2D=renderer.new();root.add_child(aura)
	var rule: Dictionary=renderer.rule("마법인형",record)
	check(int(rule.effect_row.ID)==61 and int(rule.effect_row.StatusEffectID)==1544 and int(rule.sprite_id)==22149,"existing renderer consumes exact Antaras source chain")
	aura.configure("마법인형",record,service.source_visual_awakened("마법인형",record),actor,"user://missing-native-pack/manifest.json",{})
	check(aura.status=="awakening_pack_not_installed" and not aura.visual.installed(),"missing private addon diagnosed without a generated aura")
	var secondary: Node2D=preload("res://scripts/cards/native_doll_subslot_visual.gd").new();root.add_child(secondary)
	secondary.actor=actor;secondary.binding=identity
	secondary.sync_existing_source_aura(host,record,"user://missing-native-pack/manifest.json")
	check(is_instance_valid(secondary.source_aura) and secondary.source_aura.get_script()==renderer and secondary.source_aura.status=="awakening_pack_not_installed","secondary slot reuses the same PR217 aura renderer")
	var secondary_id: int=secondary.source_aura.get_instance_id()
	secondary.sync_existing_source_aura(host,record,"user://missing-native-pack/manifest.json")
	check(secondary.source_aura.get_instance_id()==secondary_id,"repeat secondary sync reuses renderer node")
	secondary.clear();check(secondary.source_aura.status=="inactive","secondary release deactivates existing source renderer")
	secondary.actor=null;secondary.queue_free()
	var sprite: int=int(aura.sprite_id);aura.configure("마법인형",record,true,actor,"user://missing-native-pack/manifest.json",{})
	check(int(aura.sprite_id)==sprite,"repeated sync preserves existing binding")
	actor.mode="strict";aura.configure("마법인형",record,true,actor,"user://missing-native-pack/manifest.json",{})
	check(aura.status=="strict_unverified_composition","strict mode preserves existing source composition boundary")
	host.card_draw_fusion.owned["마법인형"].erase(identity)
	check(not service.source_visual_awakened("마법인형",record),"loss of ownership removes visual authority")
	aura.configure("마법인형",record,false,actor,"user://missing-native-pack/manifest.json",{})
	check(aura.status=="inactive" and aura.sprite_id==0,"completion removal deactivates only source aura")
	aura.queue_free();actor.queue_free();host.queue_free();await process_frame
	print("NATIVE_AWAKENING_AURA_BRIDGE ",JSON.stringify({"checks":checks,"errors":errors,"renderer":"existing PR217 component; no duplicate renderer","pixels":"private addon remains required"}));quit(0 if errors.is_empty() else 1)
