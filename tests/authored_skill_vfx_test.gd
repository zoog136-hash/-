extends SceneTree

const VFX = preload("res://scripts/skills/skill_vfx.gd")
const LIBRARY = preload("res://scripts/skills/skill_vfx_library.gd")
const FLIGHTS = preload("res://scripts/animation/combat_flights.gd")
var failures: Array[String] = []
var checks: int = 0
var contacts: int = 0
var events: Array[String] = []

class StatusTarget:
	extends Node2D
	var life_id: int = 1
	var dead: bool = false
	var stun_remaining: float = 2
	func combat_hit_position() -> Vector2: return global_position + Vector2(0, -24)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("AUTHORED_VFX_FAIL ", label)

func run() -> void:
	var library: TwilightSkillVFXLibrary = LIBRARY.new()
	var rows: Array = preload("res://scripts/skills/skill_catalog.gd").read_json("master.json").records
	check(library.profiles.size() == rows.size(), "coverage follows actual master roster")
	var atlases := 0
	for row: Dictionary in rows:
		var id := str(row.id)
		var profile := library.profile_for(id)
		check(not profile.is_empty(), "profile " + id)
		if not profile.has("atlas"): continue
		var entry := library.acquire(id)
		check(not entry.is_empty(), "load independently authored atlas " + id)
		if entry.is_empty(): continue
		atlases += 1
		var frames: SpriteFrames = entry.frames
		for phase: String in ["prepare", "cast", "release", "travel", "impact", "aftermath", "end", "persistent", "status", "resist"]:
			check(frames.has_animation(phase) and frames.get_frame_count(phase) > 0, id + " " + phase)
		var a := frames.get_frame_texture("impact", 0) as AtlasTexture
		var b := frames.get_frame_texture("impact", 1) as AtlasTexture
		check(a.region != b.region and a.region.size == Vector2(128, 128), "independent frame regions")
		check(a.atlas.get_size() == Vector2(1024, 1536), "96 real raster cells imported")
		check(frames.get_frame_count("impact") == 20 and frames.get_frame_count("travel") == 8, "denser contact and travel animation")
		check(is_equal_approx(frames.get_frame_duration("impact", 0) / frames.get_animation_speed("impact"), .016), "nonuniform milliseconds survive SpriteFrames")
		library.release(str(entry.key))
	check(atlases == 80, "natural effects and upgrade inheritance have real assets")
	check(library.resident_rgba_bytes() <= 48 * 1024 * 1024, "bounded decoded atlas cache")
	check(library.entries.size() <= 8, "96-cell atlases keep the same 48MiB budget")
	library.trim()
	var pinned: Array[Dictionary] = []
	var unique: Array[String] = []
	for id: String in library.profiles:
		if library.profiles[id].has("atlas"): unique.append(id)
	for index: int in range(8): pinned.append(library.acquire(unique[index]))
	check(library.resident_rgba_bytes() == 48 * 1024 * 1024, "memory accounting includes every extra atlas row")
	check(library.acquire(unique[8]).is_empty(), "pinned atlas budget cannot be evicted or exceeded")
	library.release(str(pinned[0].key))
	var admitted := library.acquire(unique[8])
	check(not admitted.is_empty() and library.resident_rgba_bytes() == 48 * 1024 * 1024, "unpinned least recent atlas makes room")
	for entry: Dictionary in pinned: library.release(str(entry.key))
	library.release(str(admitted.get("key", "")))
	library.trim()
	check(library.entries.is_empty(), "idle trim releases textures")
	var vfx: TwilightOriginalSkillVFX = VFX.new()
	var flights: TwilightCombatFlights = FLIGHTS.new()
	var target := Node2D.new()
	root.add_child(vfx)
	root.add_child(flights)
	root.add_child(target)
	await process_frame
	vfx.set_process(false)
	flights.set_physics_process(false)
	vfx.phase_started.connect(func(_id: String, phase: String, _point: Vector2) -> void: events.append(phase))
	var arrow := "lm_b9f1605d690c64f7"
	target.position = Vector2(210, 24)
	for index: int in range(3):
		flights.launch(Vector2.ZERO, target, "ranged", func() -> void:
			contacts += 1
			vfx.emit_skill(arrow, "impact", target.position), 1050, index * .08, vfx.flight_options(arrow))
	flights._physics_process(.05)
	check(contacts == 0 and not events.has("impact"), "no hit before real arrival")
	check(events.count("release") == 1, "delayed volley does not release early")
	for index: int in range(30): flights._physics_process(.02)
	check(contacts == 3 and events.count("impact") == 3, "three real contacts produce three impacts")
	check(events.count("release") == 3 and events.count("travel") == 3, "three arrows use actual volley delays")
	flights.clear()
	vfx.clear()
	events.clear()
	for direction: int in range(8):
		target.position = Vector2.from_angle(direction * TAU / 8) * 220 + Vector2(0, 24)
		flights.launch(Vector2.ZERO, target, "ranged", func() -> void: contacts += 1, 1050, 0, vfx.flight_options(arrow))
		flights._physics_process(.02)
		var travel: Dictionary = {}
		for item: Dictionary in vfx.live:
			if item.phase == "travel": travel = item
		check(not travel.is_empty(), "eight-direction sprite admitted")
		if not travel.is_empty():
			var body := (travel.layers as Node2D).get_child(0) as AnimatedSprite2D
			var painted_tip := body.global_transform * Vector2(48, 0)
			check(painted_tip.distance_to(flights.flights[0].position) < .01, "painted arrow tip follows authoritative position")
		flights.clear()
		vfx.clear()
	contacts = 0
	# Pool pressure must not turn a visual limit into a missing attack.
	vfx.set_detail("low")
	target.position = Vector2(20, 24)
	for i: int in range(256):
		flights.launch(Vector2.ZERO, target, "ranged", func() -> void: contacts += 1, 1050, 0, vfx.flight_options(arrow))
	flights._physics_process(.1)
	check(contacts == 256, "visual pressure preserves every damage callback")
	check(vfx.live.size() <= 64 and vfx.audio_pool.players.size() == 6, "low detail and audio limits")
	var stale := vfx.flight_options(arrow)
	vfx.clear()
	check(not stale.visual_step.call({"position":Vector2.ONE, "previous":Vector2.ZERO}), "clear invalidates old visual generation")
	check(vfx.live.is_empty() and vfx.library.entries.is_empty(), "clear releases live nodes and atlas pins")
	vfx.set_detail("full")
	vfx.emit_skill("lm_dcb006041216f9c6", "impact", Vector2(300, 100), Vector2.INF, {"ground_point":Vector2(300, 154)})
	var lightning_body := (vfx.live[0].layers as Node2D).get_child(0) as AnimatedSprite2D
	check((lightning_body.global_position + Vector2(0, 42)).distance_to(Vector2(300, 154)) < .01, "lightning feet use actual actor ground independent of hit height")
	vfx._process(.63)
	check(vfx.live.size() == 1 and str(vfx.live[0].phase) == "aftermath", "contact transfers to its tail")
	var tail_body := (vfx.live[0].layers as Node2D).get_child(0) as AnimatedSprite2D
	check((tail_body.global_transform * Vector2(0, 27)).distance_to(Vector2(300, 154)) < .01, "dust origin stays at actual ground after the lightning column ends")
	vfx.clear()
	var chain_id := ""
	for id: String in vfx.library.profiles:
		if vfx.library.profiles[id].get("program") == "chain_lightning": chain_id = id; break
	vfx.emit_skill(chain_id, "impact", Vector2(300, 100), Vector2(100, 100))
	var chain_layers: Node2D = vfx.live[0].layers
	var chain_body := chain_layers.get_child(0) as AnimatedSprite2D
	var chain_flare := chain_layers.get_child(2) as AnimatedSprite2D
	check((chain_body.global_transform * Vector2(-56, 0)).distance_to(Vector2(100, 100)) < .01 and (chain_body.global_transform * Vector2(56, 0)).distance_to(Vector2(300, 100)) < .01, "electric bridge terminates at both real link endpoints")
	check(chain_flare.global_position.distance_to(Vector2(300, 100)) < .01 and chain_flare.scale == Vector2.ONE, "chain collision light stays on target instead of stretching at link midpoint")
	vfx.clear()
	for direction_index: int in range(8):
		var heading := Vector2.from_angle(float(direction_index) * TAU / 8.0)
		vfx.emit_skill(arrow, "impact", Vector2(300, 100), Vector2.INF, {"direction":heading, "ground_point":Vector2(300,154)})
		vfx._process(float(vfx.live[0].ttl) + 0.01)
		var dust := (vfx.live[0].layers as Node2D).get_child(0) as AnimatedSprite2D
		check((dust.global_transform * Vector2(0,21)).distance_to(Vector2(300,154)) < .01 and is_zero_approx(dust.rotation), "all headings settle dust at feet without rotating ground particles")
		vfx.clear()
	vfx.library.profiles[chain_id]["scale"] = 1.4
	vfx.emit_skill(chain_id, "impact", Vector2(300,100), Vector2(100,180))
	var scaled_bridge := (vfx.live[0].layers as Node2D).get_child(0) as AnimatedSprite2D
	check((scaled_bridge.global_transform * Vector2(-56,0)).distance_to(Vector2(100,180)) < .01 and (scaled_bridge.global_transform * Vector2(56,0)).distance_to(Vector2(300,100)) < .01, "scaled chain art still terminates on both world contacts")
	vfx.clear()
	vfx.library.profiles[chain_id]["scale"] = 1.0
	var meteor_token: Dictionary = {}
	var meteor_flight := {"position":Vector2.ZERO, "previous":Vector2.ZERO, "origin":Vector2.ZERO, "target":weakref(target), "speed":1050.0}
	var meteor_origin := vfx._flight_visual_pose(meteor_flight, "lm_45cdacd8a42d0e5a", meteor_token)
	check(meteor_origin.point.y < target.position.y - 100, "meteor begins above the target")
	meteor_flight.position = target.position + Vector2(0, -24)
	var meteor_end := vfx._flight_visual_pose(meteor_flight, "lm_45cdacd8a42d0e5a", meteor_token)
	check(meteor_end.point.distance_to(target.position + Vector2(0, -24)) < .01, "meteor tip terminates at actual target")
	check(meteor_flight.speed == 1050.0 and not meteor_flight.has("callback"), "render path does not rewrite combat flight state")
	vfx.emit_skill(arrow, "impact", Vector2.ZERO)
	vfx._process(2.0)
	check(vfx.live.is_empty(), "long frame consumes elapsed aftermath instead of resurrecting a fresh tail")
	vfx.emit_skill(arrow, "cast", Vector2.ZERO)
	vfx._process(.25)
	check(vfx.live.size() == 1, "ground layer retains its own longer lifetime")
	if vfx.live.size() == 1:
		var container: Node2D = vfx.live[0].layers
		check(not container.get_child(0).visible and container.get_child(1).visible, "body and ground finish independently")
	vfx._process(1.0)
	check(vfx.live.is_empty(), "all cast layers retire after their own deadlines")
	var status_target := StatusTarget.new()
	root.add_child(status_target)
	vfx.maintain_status("lm_43e9715d967ef3cb", status_target, "stun")
	check(vfx.live.size() == 1, "status visual follows actual status target")
	status_target.life_id += 1
	vfx._process(.01)
	check(vfx.live.is_empty(), "a recycled monster life cannot inherit the old status visual")
	status_target.queue_free()
	vfx.use_private_sources = false
	vfx.emit_skill("lm_816e9fd2e2e8a4e8", "impact", Vector2.ZERO)
	check(vfx.live.size() == 1 and vfx.live[0].layers != null, "blocked SPX preview still has an explicitly unverified authored fallback")
	check(vfx.library.profiles.size() == 125 and vfx.library.preview_profiles.size() == 2, "preview fallbacks never become executable skills")
	vfx.clear()
	for container: Node2D in vfx.layer_pool:
		for sprite: AnimatedSprite2D in container.get_children(): check(sprite.sprite_frames == null, "pooled sprites do not retain texture resources")
	vfx.queue_free()
	flights.queue_free()
	target.queue_free()
	await process_frame
	print("AUTHORED_VFX_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
