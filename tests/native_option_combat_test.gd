extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Host extends Fixture.Host:
	var player: Node2D
class Forced extends "res://scripts/cards/native_option_combat.gd":
	var rolls: int=0
	func roll(_weight: int) -> bool:rolls+=1;return true
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func advance(combat: RefCounted,seconds: float) -> void:
	# Production World owns and persists the shared cooldown clock.
	for key: String in combat.cooldowns.keys():
		combat.cooldowns[key]=maxf(0,float(combat.cooldowns[key])-seconds)
		if combat.cooldowns[key]<=0:combat.cooldowns.erase(key)
	combat.tick(seconds)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty():quit(2);return
	var host=Host.new();root.add_child(host);host.player=Node2D.new();host.add_child(host.player)
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	var service=Runtime.new();check(service.configure(host),"native runtime config")
	var combat=Forced.new();combat.configure(service)
	var attacker: Node=load("res://scenes/Monster.tscn").instantiate();root.add_child(attacker);attacker.set_physics_process(false);attacker.dead=false
	var cards: Dictionary={}
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in host.catalog_db[category]:cards[Cards.card_id(record)]=record
	var g: String="source:m508:1:18722";var h: String="source:m508:1:24504";var r: String="source:m508:98:23531"
	for id: String in [g,h,r]:
		var category: String="성물" if id==r else "변신"
		host.card_draw_fusion.owned[category][id]=true
		service.progress.cards[category][id]={"experience":0,"awakened":true,"attempts":1,"failures":0}
	host.equipped_catalog["변신"]=cards[g]
	var result: Dictionary=combat.incoming(attacker,"melee",180)
	check(result.damage==30 and result.heal==0 and combat.fired==[14463],"Girtaas exact150 reduction once")
	check(combat.incoming(attacker,"magic",100).damage==0,"reduction clamps zero")
	host.equipped_catalog["변신"]=cards[h]
	result=combat.incoming(attacker,"melee",10)
	check(result.heal==190 and combat.fired==[20344],"physical Halphas uses one invoke")
	check(combat.incoming(attacker,"magic",10).heal==0,"shared spell cooldown prevents physical magic double heal")
	advance(combat,3);result=combat.incoming(attacker,"magic",10)
	check(result.heal==190 and combat.fired==[20354],"magic invoke eligible after source3second cooldown")
	advance(combat,3);var before: int=combat.rolls
	check(combat.incoming(attacker,"melee",9).heal==0 and combat.rolls==before,"below source damage10 never rolls")
	host.equipped_catalog["변신"]={};host.equipped_catalog["성물"]=cards[r]
	before=combat.rolls
	combat.on_hit(attacker,"magic",true,true)
	check(combat.fired.is_empty() and combat.rolls==before,"physical-only invoke never rolls on magic spells")
	combat.on_hit(attacker,"melee",true,true)
	check(combat.fired.is_empty() and combat.rolls==before,"physical skill is still a spell event")
	combat.on_hit(attacker,"melee",false,false)
	check(combat.fired.is_empty() and combat.rolls==before,"main-target-only invoke never rolls on secondary target")
	combat.on_hit(attacker)
	check(combat.fired==[17601] and attacker.source_option_debuffs.size()==1,"horn original timed buff dispatch")
	check(attacker.source_option_healing(100)==0 and attacker.source_option_healing(100,true)==0,"source150percent heal and potion reduction clamp zero")
	combat.on_hit(attacker);check(attacker.source_option_debuffs.size()==1 and combat.fired.is_empty(),"repeat hit cooldown no duplicate buff")
	host.equipped_catalog["성물"]={};combat.tick(0)
	check(attacker.source_option_debuffs.is_empty() and not combat.cooldowns.is_empty(),"unequip releases buff but retains cooldown against toggle exploit")
	host.equipped_catalog["성물"]=cards[r];combat.on_hit(attacker)
	check(attacker.source_option_debuffs.is_empty(),"reequip cannot bypass cooldown")
	advance(combat,20);combat.on_hit(attacker)
	attacker.dead=true;combat.tick(0)
	check(attacker.source_option_debuffs.is_empty(),"death prunes attached status")
	attacker.dead=false;advance(combat,20);combat.on_hit(attacker);attacker.retire_for_pool()
	check(attacker.source_option_debuffs.is_empty(),"pool retirement clears all source debuffs")
	advance(combat,20);combat.on_hit(attacker)
	attacker.advance_source_option_debuffs(9.9);check(not attacker.source_option_debuffs.is_empty(),"source10second buff remains before deadline")
	attacker.advance_source_option_debuffs(.11);combat.tick(0)
	check(attacker.source_option_debuffs.is_empty() and combat.targets.is_empty(),"deadline expires effect and releases target handle")
	service.save_blocked=true;before=combat.rolls;combat.incoming(attacker,"melee",200);combat.on_hit(attacker)
	check(combat.rolls==before,"protected saves have no proc or RNG")
	attacker.queue_free();host.queue_free();await process_frame
	print("NATIVE_OPTION_COMBAT ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
