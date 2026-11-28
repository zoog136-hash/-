extends SceneTree
## Source sprite bounds and the result-only anchor. No private assets needed.
const PREVIEW=preload("res://scripts/animation/original_source_preview.gd")
const CAMERA=preload("res://scripts/maps/field_camera_scale.gd")
const VFX=preload("res://scripts/animation/combat_vfx.gd")
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func run() -> void:
	var texture: ImageTexture=ImageTexture.create_from_image(Image.create(64,64,false,Image.FORMAT_RGBA8))
	var monster: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	root.add_child(monster)
	monster.set_physics_process(false)
	monster.position=Vector2(200.0,240.0)
	monster.sprite.texture=texture
	monster.sprite.region_enabled=true
	monster.sprite.region_rect=Rect2(0,0,24,44)
	monster.sprite.position=Vector2(3.0,-22.0)
	var shown: Rect2=monster.sprite.get_global_transform()*monster.sprite.get_rect()
	var head: Vector2=monster.combat_caption_position()
	check(head.is_equal_approx(Vector2(shown.get_center().x,shown.position.y-4.0*CAMERA.text_scale())),"the displayed region's top supplies the caption point")
	monster.position+=Vector2(7.0,12.0)
	check(monster.combat_caption_position().is_equal_approx(head+Vector2(7.0,12.0)),"the next hit uses the current actor position")
	var overlay:=PREVIEW.new()
	root.add_child(overlay)
	overlay.position=head
	var sprite:=Sprite2D.new()
	sprite.texture=texture
	sprite.position=Vector2(19.0,-110.0)
	overlay.add_child(sprite)
	overlay._layers.append(sprite)
	sprite.hide()
	overlay._caption_anchor=head
	overlay._align_combat_caption()
	check(overlay._caption_anchor==head,"a blank lead-in keeps the first visible frame's alignment pending")
	sprite.show()
	overlay._align_combat_caption()
	var bounds: Rect2=PREVIEW.sprite_world_bounds(sprite)
	check(Vector2(bounds.get_center().x,bounds.end.y).is_equal_approx(head),"the original result's bottom centre meets the requested point despite its authored offset")
	var original: Vector2=overlay.position
	sprite.position.y-=10.0
	check(overlay.position==original and not overlay._caption_anchor.is_finite(),"later source movement keeps the exact same adjusted origin")
	var vfx:=VFX.new()
	var calls: Array=[]
	vfx.source_result_visual=func(kind: String, point: Vector2) -> bool:
		calls.append(["generic",kind,point]);return true
	vfx.source_head_result_visual=func(kind: String, point: Vector2) -> bool:
		calls.append(["head",kind,point]);return true
	root.add_child(vfx)
	vfx.number(head,"MISS",Color.WHITE,false,false,true)
	vfx.number(head,"CRIT 576",Color.WHITE,true,true,true)
	vfx.number(head,"MISS",Color.WHITE)
	check(calls.size()==3 and calls[0]==["head","miss",head] and calls[1]==["head","final_blow",head-Vector2(0.0,21.0*CAMERA.text_scale())] and calls[2]==["generic","miss",head],"monster miss and final blow align while generic feedback retains its origin")
	check(vfx.active.size()==1 and vfx.active[0].display=="576","native caption still preserves the damage number")
	calls.clear()
	vfx.clear()
	vfx.show_result_titles=false
	vfx.number(head,"MISS",Color.WHITE,false,false,true)
	vfx.number(head,"CRIT 576",Color.WHITE,true,true,true)
	check(calls.is_empty() and vfx.active.size()==1 and vfx.active[0].display=="576" and not vfx.active[0].caption,"live title suppression applies to both source captions and fallback text")
	vfx.free()
	overlay.free()
	monster.free()
	print("MONSTER_COMBAT_CAPTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
