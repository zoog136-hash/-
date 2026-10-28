extends SceneTree

class Receiver extends Node:
	func _on_monster_died(_monster: TwilightMonster) -> void: pass
	func _on_player_hit(_monster: TwilightMonster, _damage: int, _kind: String) -> void: pass
	func _select_monster(_monster: TwilightMonster) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var population:=FieldPopulation.new()
	root.add_child(population)
	population.generation=7
	var monster: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	root.add_child(monster)
	var receiver:=Receiver.new()
	root.add_child(receiver)
	monster.world_controller=receiver
	monster.target_player=null
	monster.died.connect(receiver._on_monster_died)
	monster.player_hit.connect(receiver._on_player_hit)
	monster.selected.connect(receiver._select_monster)
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	var texture:=ImageTexture.create_from_image(image)
	monster.sprite.texture=texture
	monster.motion.frame_source=SpriteFrames.new()
	monster.species_visual=TwilightMonsterVisual.new()
	monster.add_child(monster.species_visual)
	monster.species_visual.effect_texture=texture
	var shared_visual: Dictionary={"old":"map"}
	monster.species_visual.visual=shared_visual
	monster.dead=true
	monster.damage_hit_count=3
	monster.set_meta("population_generation",7)
	if not population.recycle(monster):failures.append("recycle refused")
	if monster.get_parent()!=population.pool_root or population.available.size()!=1:failures.append("pool ownership")
	if monster.sprite.texture!=null or monster.motion.frame_source!=null or monster.species_visual.effect_texture!=null:failures.append("graphic retained")
	if not shared_visual.has("old"):failures.append("catalog visual mutated")
	if monster.world_controller!=null or monster.damage_hit_count!=0:failures.append("old life retained")
	if monster.died.is_connected(receiver._on_monster_died) or monster.player_hit.is_connected(receiver._on_player_hit) or monster.selected.is_connected(receiver._select_monster):failures.append("signal retained")
	if monster.is_physics_processing() or monster.collision_layer!=0 or monster.input_pickable:failures.append("dormant body active")
	population.available.pop_back()
	population.available_since.erase(monster.get_instance_id())
	monster.reparent(root,false)
	monster.setup({"name":"Reused","lv":1,"hp":30,"atk":3},null,receiver,texture)
	if monster.life_id!=1 or monster.dead or monster.sprite.texture==null or monster.collision_layer!=2 or not monster.is_physics_processing():failures.append("next life not restored")
	monster.queue_free()
	var spare: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	root.add_child(spare)
	spare.dead=true
	spare.set_meta("population_generation",7)
	if not population.recycle(spare):failures.append("spare recycle refused")
	population._trim_pool(0,true)
	if not population.available.is_empty():failures.append("idle pool did not shrink")
	print("MONSTER_POOL_RETIRE_RESULT ",JSON.stringify({"failures":failures,"cleared_graphic":true,"signals_disconnected":true,"trimmed":true}))
	quit(0 if failures.is_empty() else 1)
