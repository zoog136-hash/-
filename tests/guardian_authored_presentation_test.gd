extends SceneTree
const Presentation=preload("res://scripts/growth/guardian_authored_presentation.gd")
var checks: int=0
var failures: int=0
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var presentation=Presentation.new();presentation.settings_path="user://guardian-presentation-test.cfg"
	if FileAccess.file_exists(presentation.settings_path):DirAccess.remove_absolute(presentation.settings_path)
	root.add_child(presentation)
	expect(presentation.preferences==Presentation.DESIGN.data.defaults,"explicit authored defaults")
	expect(presentation.save_preference("cards",false),"card visibility persists")
	expect(presentation.save_preference("volume",25),"volume persists")
	var hash: String=FileAccess.get_sha256(presentation.settings_path)
	for invalid: Array in [["volume",101],["volume",-1],["volume",0.5],["sounds",1],["cards","yes"],["unknown",true]]:
		expect(not presentation.save_preference(invalid[0],invalid[1]),"invalid preference rejected")
	expect(FileAccess.get_sha256(presentation.settings_path)==hash,"invalid changes preserve disk bytes")
	var restored=Presentation.new();restored.settings_path=presentation.settings_path;root.add_child(restored)
	expect(restored.preferences==presentation.preferences,"fresh consumer reloads saved settings")
	AudioServer.add_bus();var bus: int=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"GuardianAudioQA")
	var capture:=AudioEffectCapture.new();AudioServer.add_bus_effect(bus,capture)
	for voice: AudioStreamPlayer in presentation.voices:voice.bus="GuardianAudioQA"
	for event: String in ["open","success","failure","representative","reset"]:
		capture.clear_buffer()
		expect(presentation.play_confirmed(event) and presentation.last_event==event,"confirmed cue "+event)
		var voice: AudioStreamPlayer=presentation.voices[(presentation.cursor+1)%2]
		expect(voice.playing and voice.stream.get_length()>0 and voice.volume_db<0,"authored stream actually playing")
		await create_timer(.12).timeout
		var samples: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
		var peak: float=0
		for sample: Vector2 in samples:peak=maxf(peak,sample.abs().x+sample.abs().y)
		expect(peak>0,"nonzero mixed PCM output for "+event)
	expect(presentation.voices.size()==2,"bounded two voice pool")
	expect(presentation.save_preference("sounds",false),"mute saves")
	expect(not presentation.play_confirmed("success") and not presentation.voices[0].playing and not presentation.voices[1].playing,"mute stops existing and future cues")
	presentation.save_preference("sounds",true);presentation.save_preference("volume",0)
	expect(not presentation.play_confirmed("reset"),"zero volume is off")
	var valid_hash: String=FileAccess.get_sha256(presentation.settings_path)
	# A directory at the activation path makes the atomic rename fail after the
	# candidate is written; the old in-memory preferences must stay untouched.
	var blocked: String="user://guardian-presentation-blocked.cfg"
	DirAccess.make_dir_recursive_absolute(blocked)
	presentation.settings_path=blocked
	var before: Dictionary=presentation.preferences.duplicate(true)
	expect(not presentation.save_preference("cards",true) and presentation.preferences==before,"failed activation rolls settings back")
	expect(FileAccess.get_sha256(restored.settings_path)==valid_hash,"failed activation preserves last valid settings bytes")
	DirAccess.remove_absolute(blocked)
	presentation.queue_free();restored.queue_free();await create_timer(.1).timeout
	AudioServer.remove_bus(bus)
	print("GUARDIAN_AUTHORED_PRESENTATION_RESULT: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
