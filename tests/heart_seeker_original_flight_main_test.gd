extends SceneTree
## Tests the existing Main cast -> release marker -> projectile -> single hit.
## The optional fixture uses the distributed bank, original raw members and
## the exact original action universe derived by the normal cooker.
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const EFFECTS=preload("res://scripts/resources/current523_source_effect_selection.gd")
const STORE=preload("res://scripts/resources/cooked_actor_store.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const ID="lmref_8f924b6a5bd9ab0a"
const MAIN_BANK="587b419b38fd9e66639b315788011c986439a005b2525942162ff71febc81eeb"
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("HEART_SEEKER_ORIGINAL_FLIGHT_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	ck(not EFFECTS.select_spell_row({},"effect","patch523").get("ok",false),"unproven skill cannot select an effect")
	var fixture:String=OS.get_environment("TWILIGHT_HEART_SEEKER_FIXTURE")
	var definitions:String=OS.get_environment("TWILIGHT_HEART_SEEKER_DEFINITIONS")
	if not fixture.is_empty() and not definitions.is_empty():
		await exact(fixture,definitions)
	print("HEART_SEEKER_ORIGINAL_FLIGHT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exact(fixture:String,definitions:String)->void:
	if not ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main save"):return
	STORE.root_override=fixture.path_join("cooked")
	STORE.reset_for_tests()
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w,"투사"),"actual Main with the source skill class")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false);w._clear_monsters()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",definitions);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"exact definition ZIP")
	w.original_skills.catalog.configure(w)
	var catalog:RefCounted=w.original_skills.catalog
	var record:Dictionary=catalog.record_for(ID)
	var skill:Dictionary=catalog.resolve(record) if not record.is_empty() else {}
	var raw:Dictionary=w.original_skills._heart_seeker_source_projectile(skill)
	if not ck(skill.get("mode")=="attack" and skill.get("attack_type")=="magic" and raw.get("ID")==86758 and raw.get("EffectSpriteID")==25373 and raw.get("EffectExplosionSpriteID")==25374,"real catalog admits exact separate outbound and impact source fields"):
		w.queue_free();await process_frame;return
	w.level=90
	w.original_skills.catalog.learned[ID]=1
	ck(not STORE.effect_index(MAIN_BANK).is_empty(),"production effect domain reader loaded exact derived inputs")
	var pinned:String=fixture.path_join("bank/manifest.json")
	ck(FileAccess.get_sha256(pinned)==MAIN_BANK,"complete released source bank manifest is pinned")
	var settings:Dictionary={"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":definitions,"manifest_path":pinned,"manifest_sha256":MAIN_BANK}
	var preview:Node2D=w.player.original_source_preview
	var context:Dictionary=preview._reference_request_context
	var source_context:Dictionary={"current523_source_bank":settings}
	preview._reference_request_context=source_context
	var exact_source:Dictionary=EFFECTS.select_spell_row(raw,"effect","patch523",source_context)
	if not ck(exact_source.get("ok",false) and exact_source.get("sprite_id")==25373 and exact_source.get("action_id")==0,"real bank resolves authored projectile Action 0: "+str(exact_source.get("reason",""))):
		w.queue_free();await process_frame;return
	# A/B the unchanged real cast/damage callback from the same initial input.
	# The existing host combat still owns trajectory, cooldown, RNG and hit.
	# This fixture does not mount a full original geographic pack; provide a
	# clear bounded QA field to run the actual game's range/sight predicates.
	w.field_map=null
	w.astar=AStarGrid2D.new()
	w.astar.region=Rect2i(0,0,128,128)
	w.astar.update()
	w.player.global_position=Vector2(845,840)
	w.monsters_root.show()
	w.monsters_root.process_mode=Node.PROCESS_MODE_INHERIT
	var control:Dictionary=drive(w,record,{})
	var source:Dictionary=drive(w,record,source_context)
	print("HEART_SEEKER_EVIDENCE ",JSON.stringify({"control":control,"source":source}))
	ck(control.get("cast",false) and source.get("cast",false),"normal skill owner accepts both identical casts")
	ck(not control.get("visual",false) and source.get("visual",false) and source.get("texture",false) and source.get("followed",false),"original outbound sprite paints and follows actual flight position")
	ck(source.get("flights")==1 and source.get("remaining_flights")==0 and source.get("resolved")==1,"exactly one live projectile and one actual successful impact")
	for key:String in ["hp","rng","mp","cooldown","inventory","ticks","resolved","target_state","events"]:
		ck(control.get(key)==source.get(key),"identical gameplay "+key)
	preview._reference_request_context=context
	STORE.root_override=""
	w.queue_free();await process_frame

func drive(w:Node,record:Dictionary,context:Dictionary)->Dictionary:
	var s:RefCounted=w.original_skills
	var f:Node2D=w.combat_flights
	f.clear()
	w.player.cancel_attack();w.pending_attack={}
	w.skill_cooldowns.clear();w.skill_global_cooldown=0.0;w.mp=mini(250,w._effective_max_mp())
	s.event_counts.clear()
	w.rng.seed=2224400
	w.player.original_source_preview._reference_request_context=context if not context.is_empty() else {"current523_source_bank":{}}
	var monster:TwilightMonster=w.MONSTER_SCENE.instantiate()
	w.monsters_root.add_child(monster)
	var ready:bool=monster.setup({"name":"과녁","hp":1000,"atk":1,"speed":0,"drop":[]},w.player,w,null)
	monster.set_physics_process(false)
	var pos:Vector2=w.player.global_position
	for delta:Vector2 in [Vector2(190,0),Vector2(-190,0),Vector2(0,192),Vector2(0,-192),Vector2(112,0)]:
		if w._has_line_of_sight_world(pos,pos+delta):
			monster.global_position=pos+delta;break
	w.selected_monster=monster
	var accepted:bool=s.cast(record,true)
	if not accepted:
		monster.queue_free()
		return {"cast":false,"reason":w.hud.message_label.text,"target_initialized":ready,"dist":monster.global_position.distance_to(pos),"visible":w._has_line_of_sight_world(pos,monster.global_position),"range":w.original_skills.catalog.resolve(record).get("range"),"dead":monster.dead}
	var old_hits:int=f.resolved_count
	w._release_player_attack(int(w.pending_attack.get("id",-1)))
	f.set_physics_process(false)
	var answer:Dictionary={"cast":true,"flights":f.flights.size(),"visual":false,"texture":false,"followed":false,"ticks":0}
	for step:int in range(32):
		if f.flights.is_empty():break
		f._physics_process(1.0/60.0)
		answer.ticks=step+1
		for flight: Dictionary in f.flights:
			if flight.get("source_spell_flight_id")!=86758:continue
			for node:Node in f.get_children():
				if node.is_queued_for_deletion() or node.get("reference_bank_status").get("source_actor_id")!=25373:continue
				answer.visual=node.visible and flight.get("visual_active",false)
				answer.followed=node.global_position.is_equal_approx(flight.position) and not node.global_position.is_equal_approx(flight.origin)
				for layer: Node in node.find_children("*","Sprite2D",true,false):
					if layer.texture!=null and layer.is_visible_in_tree():answer.texture=true
	answer.merge({"hp":monster.hp,"mp":w.mp,"cooldown":w.skill_cooldowns.get(str(record.name)),"inventory":w.inventory.duplicate(),"rng":str(w.rng.state),"resolved":f.resolved_count-old_hits,"remaining_flights":f.flights.size(),"target_state":[monster.hold_remaining,monster.stun_remaining,monster.fear_remaining,monster.slow_remaining],"events":s.event_counts.duplicate()})
	monster.queue_free()
	return answer
