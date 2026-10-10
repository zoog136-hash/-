extends "res://scripts/maps/field_population.gd"
class_name OriginalSourcePopulation
const MAX_ACTIVE: int=96
func _zone_active(region: Dictionary) -> bool:
	return field!=null and (field as OriginalPlayableField).source_spawn_active(region,world.player.global_position)
func _spawn_slot(slot: Dictionary) -> void:
	if world.monsters_root.get_child_count()<MAX_ACTIVE: super._spawn_slot(slot)
func _spawn_point(region: Dictionary) -> Vector2:
	return (field as OriginalPlayableField).sample_source_spawn(region,world.player.global_position,world.rng) if field!=null else Vector2.INF
func _process(delta: float) -> void:
	if field==null: return
	if wake_clock<=0:
		for slot: Dictionary in slots:
			if not is_instance_valid(slot.monster): continue
			var monster: TwilightMonster=slot.monster as TwilightMonster
			if monster.dead or monster.global_position.distance_squared_to(world.player.global_position)<=1800*1800: continue
			slot.monster=null
			monster.set_physics_process(false)
			if available.size()<MAX_POOL:
				monster.hide()
				monster.reparent(pool_root,false)
				available.append(monster)
			else:
				world.monsters_root.remove_child(monster)
				monster.queue_free()
	super._process(delta)
