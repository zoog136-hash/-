extends SceneTree
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const POLICY=preload("res://scripts/monsters/patch523_spawn_policy.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
var failures: Array[String]=[]
var checks: int=0
class Host extends Node:
	var active_map_id: String="aden_world"
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("PATCH523_EXTRA_FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(POLICY.settings().enabled,"latest523 definitions requested")
	var record: Dictionary=ROSTER.for_spawn("lineagem_base508:npc:93102:spawn:554792:territory:200832","aden_world")
	check(not record.is_empty(),"new exact source671 context factory")
	if record.is_empty():quit(1);return
	var original: String=JSON.stringify(record)
	var admission: Dictionary=POLICY.admit(record,"aden_world")
	check(admission.ok and admission.applied,"new context passes current523 class/territory/condition checks")
	var host:=Host.new();root.add_child(host)
	var actor: TwilightMonster=(load("res://scenes/Monster.tscn")as PackedScene).instantiate()
	root.add_child(actor)
	check(actor.setup(record,null,host,null),"new actual Monster setup with exact private model")
	actor.set_physics_process(false)
	check(actor.source_m_npc_id==93102 and actor.max_hp==int(record.hp) and actor.monster_level==int(record.lv),"new native identity and source stats")
	check(not actor.permits_auto_selection() and actor.source_targeting.IsSelectable and actor.source_targeting.snapshot=="patch523","current category separates automatic and manual selection")
	check(actor.gold_reward==0 and actor.drop_items.is_empty(),"no invented loot or currency")
	check(JSON.stringify(record)==original,"caller source context stays unchanged")
	if is_instance_valid(actor.source_m_view):
		var view: Node=actor.source_m_view
		for role: String in ["idle","walk","attack","hit","death"]:
			for frames: Array in view._tracks[role].directions:
				for layer: Dictionary in frames[0].layers:
					if layer.relation!="body":continue
					var texture: Texture2D=VIEW._texture(view._root.path_join(layer.path),layer)
					check(texture!=null and texture.get_width()==int(layer.pixel_size[0]) and texture.get_height()==int(layer.pixel_size[1]),"new role/direction body sample decodes")
	else:check(false,"actual native view missing")
	actor.retire_for_pool();check(actor.source_targeting.is_empty(),"retired native selection state cleared")
	var orc: Dictionary=ROSTER.for_spawn("lineagem_base508:npc:257:spawn:803:territory:563","aden_world")
	check(actor.setup(orc,null,host,null),"next native life setup")
	actor.set_physics_process(false)
	check(actor.permits_auto_selection(),"different native category replaces excluded state")
	actor.free();host.free()
	print("PATCH523_EXTRA_TARGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"npc_id":93102,"body_samples":40,"new_production_spawns":0}))
	quit(0 if failures.is_empty()else 1)
