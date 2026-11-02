extends SceneTree
const EXCLUDE=preload("res://scripts/animation/source_reference_exclusions.gd")
const SOURCE=preload("res://scripts/lineagem_base508.gd")
const POLICY=preload("res://scripts/animation/source_playback_policy.gd")
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
var failures:int=0
var count:int=0
func check(value:bool,label:String) -> void:
	count+=1
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var root_path:String=INSTALL.active_root()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("manifest.json")))
	var active_cards:int=0;var held_cards:int=0;var files:Dictionary={};var events:Dictionary={};var active_references:int=0
	var selected_record:Dictionary={};var selected_tracks:Dictionary={};var selected_key:String="";var selected_state:Dictionary={}
	for entry:Dictionary in EXCLUDE.data().affected_source_cards:
		var kind:String={"변신":"transform","마법인형":"doll","성물":"relic"}[entry.category]
		var key:String=kind+":"+entry.source_id
		var enabled:bool=entry.runtime_policy=="exclude_unlocated_references"
		check(EXCLUDE.eligible(key,"base508")==enabled,"exact grade/card gate")
		check(not EXCLUDE.eligible(key,"base509"),"different snapshot rejected")
		if not enabled:held_cards+=1;continue
		active_cards+=1
		var canonical:Dictionary={}
		for card:Dictionary in SOURCE.cards().catalog[entry.category]:
			if card.sourceId==entry.source_id:canonical=card;break
		for sid:Variant in canonical.source_inworld_sprite_ids:
			var index:Dictionary=manifest.records.get("sprite:"+str(int(sid)),{})
			if index.is_empty():continue
			var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INSTALL.resolve_file(root_path,index.manifest)))
			var before:String=JSON.stringify(record)
			var tracks:Dictionary=POLICY.tracks(record,kind,"compatible")
			var original:Dictionary=tracks.duplicate(true)
			var state:Dictionary=EXCLUDE.apply(record,tracks,key,manifest)
			check(JSON.stringify(record)==before,"raw definition preserved")
			for role:String in tracks:
				check(tracks[role].directions==original[role].directions,"all frame pixels/ticks/annotations preserved")
				check(tracks[role].loop==original[role].loop and tracks[role].effective_fps==original[role].effective_fps,"loop/clock preserved")
			for file:String in state.excluded_layer_files:files[file]=true
			for rule:Dictionary in state.excluded_event_rules:events[int(rule.event_sprite_id)]=true
			active_references+=state.excluded_layer_references.size()
			if not state.excluded_layer_references.is_empty() and selected_record.is_empty():selected_record=record;selected_tracks=original;selected_key=key;selected_state=state
	# Exact event targets are muted without deleting their original annotations.
	for rule:Dictionary in EXCLUDE.data().event_rules:
		var entry:Dictionary={"enabled":true,"excluded_event_rules":[rule]}
		var event:Dictionary={"role":rule.role,"token_index":rule.token_index,"annotation":{"raw":"]"+str(int(rule.event_sprite_id))}}
		check(EXCLUDE.event_excluded(entry,event,int(rule.event_sprite_id)),"exact missing event excluded")
		check(not EXCLUDE.event_excluded(entry,event,4221),"unrelated real event preserved")
		event.token_index+=1
		check(not EXCLUDE.event_excluded(entry,event,int(rule.event_sprite_id)),"different event token preserved")
	check(active_cards==36 and held_cards==7,"36 hero-or-lower closed, four upper plus three event held")
	check(events.size()==7,"only exact seven unavailable event targets gated")
	check(not EXCLUDE.eligible("sprite:19006","base508"),"literal inspection not rewritten")
	var changed:Dictionary=selected_record.duplicate(true)
	changed.body_id+=1
	check(EXCLUDE.apply(changed,selected_tracks.duplicate(true),selected_key,manifest).excluded_layer_references.is_empty(),"body guard")
	changed=selected_record.duplicate(true)
	for directive:Dictionary in changed.source_all_declarations.directives:
		if int(directive.code)==105:directive.body=str(directive.body)+" ";break
	check(EXCLUDE.apply(changed,selected_tracks.duplicate(true),selected_key,manifest).excluded_layer_references.is_empty(),"raw reference hash guard")
	var changed_tracks:Dictionary=selected_tracks.duplicate(true)
	for role:String in changed_tracks:changed_tracks[role].source_raw_body+=" "
	check(EXCLUDE.apply(selected_record,changed_tracks,selected_key,manifest).excluded_layer_references.is_empty(),"action hash guard")
	# Supplied real pixels must win over an older exact exclusion.
	changed_tracks=selected_tracks.duplicate(true)
	for ref:Dictionary in selected_state.excluded_layer_references:
		changed_tracks[ref.role].directions[0][0].effect_layers.append({"layer_id":ref.source_layer.sprite_id,"path":"pixels/newly_supplied_source.png"})
	check(EXCLUDE.apply(selected_record,changed_tracks,selected_key,manifest).excluded_layer_references.is_empty(),"available effect layer preserved")
	# Sample only representative actual renderer paths; no whole-roster visual audit.
	for key:String in ["transform:m508:1:19058","transform:m508:1:10391","doll:m508:2:12902"]:
		var view:=VIEW.new();root.add_child(view);view.playback_mode_override="compatible"
		check(view.configure(key,root_path.path_join("manifest.json")),"representative body loads despite missing reference")
		check(bool(view.reference_exclusion_status.get("enabled",false)),"actual configure uses canonical request key before sprite selection")
		for direction:int in range(8):
			for role:String in ["idle","walk","attack"]:
				view.advance_source(0.3,role,direction,direction+1,role=="attack")
				check(view.last_source_frame>=0,"representative direction/loop/attack samples")
		view.advance_source(30.1,"idle",2,0,false);check(view.last_source_frame>=0,"idle loop boundary remains playable")
		view.playback_mode_override="strict"
		check(view.configure(key,root_path.path_join("manifest.json")),"strict does not reject whole card")
		view.advance_source(0.1,"idle",2,0,false);check(view.last_source_frame>=0,"strict body preserved")
		view.clear();check(view.reference_exclusion_status.is_empty(),"card switch clears policy state");view.free()
	print("SOURCE_REFERENCE_EXCLUSIONS ",JSON.stringify({"checks":count,"failures":failures,"closed_cards":active_cards,"classification_only_cards":held_cards,"excluded_layer_addresses":files.size(),"excluded_event_targets":events.size(),"metadata_reference_instances":active_references,"source_pixels_or_timing_changed":false}))
	quit(0 if failures==0 else 1)
