extends SceneTree
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const R=preload("res://scripts/quests/quest_regen523.gd")
var checks: int=0
var failures: Array[String]=[]
class View extends Node:
	var ui_preferences: Dictionary={}
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_REGEN_METADATA_FAIL "+label)
func _initialize()->void:
	var w:=View.new()
	for id: int in R.IDS:
		var rec: Dictionary=D.variant_item(D.definition_id(str(id)).get("native_record",{}),1);var original: Dictionary=rec.duplicate(true)
		check(R.action(w,rec).source_use_spec.activation_status=="unrestricted" and rec==original,"exact pinned input reduced without changing original pack definition")
		w.ui_preferences["quest523_mp_regen_interval_seconds"]=15.0
		check(R.action(w,rec).source_use_spec.typed_effects.tick_interval==15.0,"explicit host cadence configuration keeps original effect rows")
		for value: Variant in [0,"30",INF]:
			w.ui_preferences["quest523_mp_regen_interval_seconds"]=value
			check(R.action(w,rec).source_use_spec.activation_status=="blocked","disabled or invalid policy cannot enable a source item")
		w.ui_preferences.clear();var bad: Dictionary=rec.duplicate(true);bad.source_use_spec.blocked_reasons.append("unknown_positive_or_context_effect")
		check(R.action(w,bad).source_use_spec.activation_status=="blocked","unknown positive/context effect is preserved and blocks execution")
		bad=rec.duplicate(true);bad.source_use_spec.source_buff_bonus[0].CharacterLevel=1
		check(R.action(w,bad).source_use_spec.activation_status=="blocked","conditional source bonus is never promoted to unconditional recovery")
		bad=rec.duplicate(true);bad.source_use_spec.source_buff_bonus[0].bonus.Value=2.5
		check(R.action(w,bad).source_use_spec.activation_status=="blocked","fractional source amount is not truncated into an accepted native value")
	print("QUEST_REGEN_METADATA_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"read-only metadata and policy refusals; not producer/use proof"}));w.free();quit(0 if failures.is_empty() else 1)
