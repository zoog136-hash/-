extends SceneTree
## Complete pinned lexical input validation; not an image-usage or engine test.
const SOURCE=preload("res://scripts/maps/current523_spr_declarations.gd")
var checks: int=0
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var directory: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-directory="):directory=arg.trim_prefix("--source-directory=")
	if directory.is_empty():printerr("Verified original source directory required");quit(2);return
	var source=SOURCE.new()
	check(source.load_directory(directory),"all30 originals,1012 exact source blocks and original token offsets validate: "+source.problem)
	if source.definitions.is_empty():finish({});return
	check(source.source_files.size()==30 and source.definitions.size()==1012,"complete held lexical closure is loaded")
	check(source.references.size()==227,"all227 explicit source references are preserved as data")
	var definitions: int=0;var action_sequences: int=0;var unresolved: Dictionary={};var modifiers: int=0
	for id: int in source.definitions:
		var d: Dictionary=source.display_definition(id);definitions+=1
		check(d.declaration_sha256==source.definitions[id].raw_declaration_sha256 and not d.raw_bytes.is_empty(),"definition retains exact source proof: "+str(id))
		if d.has("unsupported"):unresolved[id]=d.unsupported
		if not d.sequence.is_empty():action_sequences+=1
		modifiers+=d.unapplied_modifiers.size()
	var forest: Dictionary=source.display_definition(29175)
	check(forest.sequence[0].frame==14 and forest.sequence[0].duration==4 and forest.sequence[1].frame==0,"original forest sequence14→0 and duration4 override stored order")
	var elf: Dictionary=source.display_definition(14297)
	check(elf.sequence[0].frame==22 and elf.sequence[1].frame==0,"new source beyondlist29 applies original22→0 sequence")
	var torch: Dictionary=source.display_definition(85)
	check(torch.sequence.size()==11 and not torch.unapplied_modifiers.is_empty(),"inline declaration keeps source frames and unexecuted modifiers without inventing effects/sounds")
	check(source.display_definition(24592).is_empty(),"undeclared24592 remains undeclared")
	var zero: Dictionary=source.display_definition(2302)
	check(zero.sequence[0].frame==2 and zero.sequence[0].duration==0,"original2302 frame2/tick0 are preserved")
	check(SOURCE.own_frame_at(zero.sequence,0).frame==2 and SOURCE.own_frame_at(zero.sequence,1000).frame==2,"explicit own zero-tick hold never invents frame images or a positive duration")
	var self_cycle: bool=false
	for edge: Dictionary in source.display_definition(24147).references:
		if int(edge.target_id)==24147:self_cycle=true
	check(self_cycle,"original24147 self-reference is retained without activation")
	var cached=SOURCE.new();check(cached.load_directory(directory),"verified source cache can be reused without a second source fetch")
	source.definitions[29175].actions.clear()
	check(cached.display_definition(29175).sequence[0].frame==14,"consumer mutation cannot change frozen shared source data")
	finish({"source_files":source.source_files.size(),"definitions":definitions,"verified_raw_tokens":source.verified_tokens,"original_action3_sequences":action_sequences,"unapplied_modifiers":modifiers,"unsupported":unresolved})
func finish(result: Dictionary) -> void:
	result["checks"]=checks;result["failures"]=failures;result["native_activation_clock_blend_or_usage95_verified"]=false
	print("CURRENT523_GLOBAL_SPR_SOURCE_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
