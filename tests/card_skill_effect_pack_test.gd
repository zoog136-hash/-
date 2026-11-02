extends SceneTree
## Consumer test of every compiled clip in an explicit private addon staging root.
var errors: Array[String]=[]
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--effect-manifest="):manifest=arg.trim_prefix("--effect-manifest=")
	if manifest.is_empty() or not ResourceLoader.exists("res://scripts/animation/original_source_preview.gd"):
		push_error("Explicit original effect addon staging root and PR217 compositor required");quit(2);return
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var host:=Node2D.new();root.add_child(host)
	var original: Node2D=load("res://scripts/animation/original_source_preview.gd").new();host.add_child(original)
	var partial: Node2D=preload("res://scripts/cards/skill_awakening_partial_effects.gd").new();host.add_child(partial)
	var complete: int=0;var sparse: int=0;var layer_checks: int=0
	for key: String in index.records:
		if not key.begins_with("overlay:"):continue
		var sid: int=int(key.get_slice(":",1))
		var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest.get_base_dir().path_join(str(index.records[key].manifest))))
		if bool(record.get("card_skill_partial_overlay",false)):
			check(partial.play_source(manifest,sid,5,Vector2.ZERO),"sparse original source0 available "+key)
			partial.clear();sparse+=1;continue
		var ok: bool=original.configure(key,manifest)
		check(ok,"existing compositor configures exact clip "+key)
		if not ok:continue
		original.set_process(false);original.advance_source(0,"idle",5,0,false)
		var frame: Dictionary=record.tracks.idle.directions[0][0]
		# Native zero-tick tokens are instantaneous events, not visible held poses.
		for token: Dictionary in record.tracks.idle.directions[0]:
			if float(token.source_ticks)>0:frame=token;break
		check(original.installed() and original.last_source_frame==int(frame.source_frame),"original first positive-tick token selected "+key)
		for i: int in range(frame.layers.size()):
			var expected: Image=Image.load_from_file(manifest.get_base_dir().path_join(str(frame.layers[i].path)))
			check(original._layers[i].texture.get_image().get_data()==expected.get_data(),"exact original body/shadow texture "+key+":"+str(i));layer_checks+=1
		for layer: Dictionary in frame.get("effect_layers",[]):
			var expected: Image=Image.load_from_file(manifest.get_base_dir().path_join(str(layer.path)))
			check(original._effect_nodes[int(layer.layer_id)].texture.get_image().get_data()==expected.get_data(),"exact original clothes texture "+key+":"+str(int(layer.layer_id)));layer_checks+=1
		original.clear();complete+=1
	print("CARD_SKILL_EFFECT_PACK ",JSON.stringify({"checks":checks,"errors":errors,"full_direction_clips":complete,"sparse_direction_clips":sparse,"body_shadow_clothes_texture_checks":layer_checks,"not_claimed":"All original attachments, all direction semantics, FPS or M visual equivalence"}))
	host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
