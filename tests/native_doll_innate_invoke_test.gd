extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
const Unlock=preload("res://scripts/cards/native_doll_unlock_item.gd")
class Host extends Fixture.Host:
	var player: Node2D
	var level: int=95
	var active_skill_buffs: Dictionary={}
class Forced extends "res://scripts/cards/native_option_combat.gd":
	var rolls: int=0
	func roll(_weight: int) -> bool:rolls+=1;return true
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var input: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):input=arg.trim_prefix("--native-cards=")
	if input.is_empty():quit(2);return
	var host:=Host.new();root.add_child(host);host.player=Node2D.new();host.add_child(host.player)
	host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(input)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	var runtime=Runtime.new();check(runtime.configure(host),"native runtime")
	var combat=Forced.new();combat.configure(runtime)
	var cards: Dictionary={}
	for record: Dictionary in host.catalog_db["마법인형"]:cards[Cards.card_id(record)]=record
	var target: Node=load("res://scenes/Monster.tscn").instantiate();root.add_child(target);target.set_physics_process(false);target.dead=false;target.hp=100000
	var hit: String="source:m508:2:19231";var heal: String="source:m508:2:13763";var wood: String="source:m508:2:28"
	for id: String in [hit,heal,wood,"source:m508:2:19451","source:m508:2:11692"]:host.card_draw_fusion.owned["마법인형"][id]=true
	for secondary: bool in [false,true]:
		runtime.progress[Unlock.FIELD]=Unlock.marker();runtime.progress["native_subslot_identity"]=""
		for id: String in [hit,heal]:
			host.skill_cooldowns.clear();target.dead=false;target.hp=100000
			host.equipped_catalog["마법인형"]=cards[wood] if secondary else cards[id]
			runtime.progress["native_subslot_identity"]=id if secondary else ""
			var before: int=combat.rolls
			if id==hit:
				combat.on_hit(target,"melee",true,true)
				check(target.hp==100000 and combat.rolls==before,"innate physical proc excludes physical spell "+str(secondary))
				combat.on_hit(target)
				check(target.hp==99499 and combat.fired==[10661],"source 500+1 fixed magic damage once "+str(secondary))
				combat.on_hit(target);check(target.hp==99499,"innate cooldown blocks repeated hit "+str(secondary))
			else:
				var result: Dictionary=combat.incoming(target,"magic",20)
				check(result.heal==0 and combat.rolls==before,"source heal excludes magic damage "+str(secondary))
				result=combat.incoming(target,"melee",9)
				check(result.heal==0 and combat.rolls==before,"source minimum10 checked before RNG "+str(secondary))
				result=combat.incoming(target,"melee",20)
				check(int(result.heal)>=491 and int(result.heal)<=510 and combat.fired==[3323],"source490+1d20 no material for explicit None type "+str(secondary))
				check(combat.incoming(target,"melee",20).heal==0,"source heal shared3second cooldown "+str(secondary))
			host.equipped_catalog["마법인형"]={};runtime.progress["native_subslot_identity"]="";var clock: Dictionary=host.skill_cooldowns.duplicate(true)
			check(combat.effects(combat.active()).is_empty() and not clock.is_empty(),"unequip clears innate authority without resetting cooldown "+str(secondary))
			host.equipped_catalog["마법인형"]=cards[wood] if secondary else cards[id];runtime.progress["native_subslot_identity"]=id if secondary else ""
			check(host.skill_cooldowns==clock,"re-equip cannot reset source clock "+str(secondary))
	# Unsupported duration/resistance semantics remain inert before RNG.
	runtime.progress["native_subslot_identity"]=""
	for id: String in ["source:m508:2:19451","source:m508:2:11692"]:
		host.skill_cooldowns.clear();host.equipped_catalog["마법인형"]=cards[id]
		var before: int=combat.rolls;combat.on_hit(target)
		check(combat.rolls==before and combat.fired.is_empty(),"unsupported resistance/duration path never guesses "+id)
	host.card_draw_fusion.owned["마법인형"].clear();check(combat.effects(combat.active()).is_empty(),"unowned doll cannot contribute innate invoke")
	var bindings: Dictionary=preload("res://data/cards/base508_option_extensions.json").data.subslot_npc_bindings
	check(bindings.size()==166 and bindings.values().all(func(row: Dictionary)->bool:return row.display_sprite_verified),"166 exact NPC-to-display sprite joins")
	check(bindings["source:m508:2:25058"].npc_class_id==104588 and bindings["source:m508:2:25058"].sprite_id==24031 and bindings["source:m508:2:25058"].primary_sprite_ids.is_empty(),"Taco explicit additional-only NPC with display join; no invented primary NPC")
	host.queue_free();target.queue_free();await process_frame
	print("NATIVE_DOLL_INNATE ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
