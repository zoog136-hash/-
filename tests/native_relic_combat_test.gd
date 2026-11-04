extends SceneTree
const Fixture=preload("res://tests/native_option_awakening_test.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
class Host extends Fixture.Host:
	var player: Node2D
class Target extends Node2D:
	var dead: bool=false
	var hp: int=10000
	var calls: int=0
	func apply_source_option_debuff(_origin: String,_duration: int,_buffs: Array) -> bool:return false
	func take_damage(amount: int,_critical: bool,_kind: String) -> void:hp-=amount;calls+=1
class Forced extends "res://scripts/cards/native_option_combat.gd":
	var rolls: int=0
	var weights: Array[int]=[]
	func roll(weight: int) -> bool:rolls+=1;weights.append(weight);return true
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	var host=Host.new();root.add_child(host);host.player=Node2D.new();host.add_child(host.player)
	host.catalog_db=Registry.apply_catalog({});host.card_draw_fusion.configure(host.catalog_db)
	var runtime=Runtime.new();check(runtime.configure(host),"native runtime configures")
	var identity: String="source:m508:98:22182"
	host.card_draw_fusion.owned["성물"][identity]=true
	runtime.progress[Unlock.FIELD]=Unlock.marker();runtime.progress[Slot.FIELD]=identity
	var combat=Forced.new();combat.configure(runtime)
	var target=Target.new();root.add_child(target)
	check(combat.active().is_empty(),"source-scoped invoke requires explicit server context")
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	check(combat.active().has("relic_subslot11:"+identity),"additional relic enters a separate contextual origin without primary equip")
	check(Slot.effects(runtime,identity).invoke_options.size()==1,"only the verified22182 invoke leaves pending state")
	combat.on_hit(target,"magic",true,true)
	check(combat.rolls==0 and target.calls==0,"physical trigger never rolls on spell attacks")
	combat.on_hit(target,"melee",false,false)
	check(combat.rolls==0 and target.calls==0,"source main-target condition enforced before RNG")
	combat.on_hit(target)
	check(combat.fired==[16572] and target.calls==1 and target.hp==9499,"exact source fixed500 plus1d1 damage once")
	check(combat.weights==[30000],"source percentage raw weight is passed unchanged")
	combat.on_hit(target)
	check(combat.rolls==1 and target.calls==1,"source cooldown prevents repeat proc")
	var cooldown: Dictionary=host.skill_cooldowns.duplicate(true)
	runtime.progress[Slot.FIELD]=""
	check(combat.active().is_empty(),"release removes contextual invoke immediately")
	runtime.progress[Slot.FIELD]=identity
	combat.on_hit(target)
	check(host.skill_cooldowns==cooldown and target.calls==1,"reselect cannot reset durable world cooldown")
	host.skill_cooldowns.clear();runtime.save_blocked=true;combat.on_hit(target)
	check(combat.rolls==1 and target.calls==1,"save protection blocks invocation and RNG")
	runtime.save_blocked=false;host.card_draw_fusion.owned["성물"].erase(identity);combat.on_hit(target)
	check(combat.rolls==1 and target.calls==1,"ownership removal disables invoke")
	target.queue_free();host.queue_free();await process_frame
	print("NATIVE_RELIC_COMBAT ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
