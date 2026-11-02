extends SceneTree
const Status=preload("res://scripts/cards/native_awakening_status.gd")
const DATA=preload("res://data/cards/base508_option_awakening.json")
var errors: Array[String]=[]
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message)
func _initialize() -> void:
	var references: Dictionary={};var mapped: int=0
	for row: Dictionary in DATA.data.definitions:
		var result: Dictionary=Status.binding(row)
		if not result.ok:continue
		mapped+=1;references[result.status_effect_id]=result
		check(result.scope=="only_BuffCardAwakenEffect_plus_explicit_option_StatusEffectID","bounded source scope "+row.id)
		check(not result.uninterpreted_attrs.is_empty(),"attrs98/138 remain raw "+row.id)
	check(mapped==288 and references.size()==12,"288 primary status links resolve12 exact chains")
	check(references[1544].source_awaken_effect_id==61 and references[1544].sprite_id==22149,"Antaras exact known chain")
	check(references[2408].source_awaken_effect_id==101 and references[2408].sprite_id==24748,"Einhasad exact known chain")
	check(Status.DATA.data.status_chain_verified_count==368,"all primary and slot11 status joins verified without mismatch")
	var bad: Dictionary=DATA.data.definitions[0].duplicate(true)
	for effect: Dictionary in bad.native_source.effects:
		if effect.type.Name=="StatusEffectID":effect.bonus.Value=999999
	check(not Status.binding(bad).ok,"unrelated status48 cannot opt into sprite interpretation")
	print("NATIVE_AWAKENING_STATUS ",JSON.stringify({"checks":checks,"errors":errors,"primary_links":mapped,"status_chains":references.size(),"not_claimed":"unknown attrs98/138 lifecycle or live native aura renderer"}));quit(0 if errors.is_empty() else 1)
