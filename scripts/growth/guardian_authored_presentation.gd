extends Node
## Fallback presentation only. Original glow stays in guardian_original_glow.gd.
## No original card atlas / six original UI OGG payloads have been received.
const DESIGN=preload("res://data/growth/guardian_authored_presentation.json")
const AUDIO=preload("res://scripts/audio/presentation_audio.gd")
# 78b7d50 excluded the shared WAVs from the original-only installation; these
# cues therefore have no sample and stay silent.
const SAMPLES={"soft":null,"accent":null,"contact":null}
var settings_path: String="user://guardian_authored_presentation_v1.cfg"
var preferences: Dictionary=DESIGN.data.defaults.duplicate(true)
var voices: Array[AudioStreamPlayer]=[]
var cursor: int=0
var played: int=0
var last_event: String=""

func _ready() -> void:
	name="GuardianAuthoredPresentation"
	var config:=ConfigFile.new()
	if config.load(settings_path)==OK:
		for key: String in preferences:
			var value: Variant=config.get_value("presentation",key,preferences[key])
			if _valid(key,value):preferences[key]=value
	for i: int in range(2):
		var voice:=AudioStreamPlayer.new()
		add_child(voice);voices.append(voice)

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in voices:
		voice.stop();voice.stream=null
	voices.clear()

func _valid(key: String,value: Variant) -> bool:
	if key in ["cards","sounds"]:return value is bool
	return key=="volume" and value is int and int(value)>=0 and int(value)<=100

func save_preference(key: String,value: Variant) -> bool:
	if not _valid(key,value):return false
	var candidate: Dictionary=preferences.duplicate(true)
	candidate[key]=value
	var config:=ConfigFile.new()
	for entry: String in candidate:config.set_value("presentation",entry,candidate[entry])
	var temporary: String=settings_path+".tmp"
	if config.save(temporary)!=OK:return false
	var verify:=ConfigFile.new()
	if verify.load(temporary)!=OK:return false
	for entry: String in candidate:
		if verify.get_value("presentation",entry)!=candidate[entry]:return false
	if DirAccess.rename_absolute(temporary,settings_path)!=OK:
		DirAccess.remove_absolute(temporary)
		return false
	preferences=candidate
	# Muting/volume changes affect voices that are already playing, too.
	for voice: AudioStreamPlayer in voices:voice.stop()
	return true

func play_confirmed(event: String) -> bool:
	if not DESIGN.data.cues.has(event) or not preferences.sounds or int(preferences.volume)==0:return false
	var world: Node=get_parent()
	if world!=null and "presentation_audio" in world and is_instance_valid(world.presentation_audio) and world.presentation_audio.muted:return false
	if voices.is_empty():return false
	var cue: Dictionary=DESIGN.data.cues[event]
	if SAMPLES.get(cue.sample)==null:return false
	var voice: AudioStreamPlayer=voices[cursor]
	cursor=(cursor+1)%voices.size()
	voice.stop();voice.stream=SAMPLES[cue.sample]
	voice.pitch_scale=float(cue.pitch)
	voice.volume_db=float(cue.gain_db)+linear_to_db(float(preferences.volume)/100.0)
	voice.play();played+=1;last_event=event
	return true
