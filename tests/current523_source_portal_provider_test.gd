extends SceneTree
const PROVIDER=preload("res://scripts/maps/current523_source_portal_provider.gd")
const OWNER=preload("res://scripts/maps/patch523_world_links.gd")
var checks: int=0
var failures: Array[String]=[]
class RuleFixture extends RefCounted:
	var territories: Dictionary={7:{"ID":7,"StartX":10,"StartY":20,"EndX":12,"EndY":22}}
	var rows: Array=[{"LandID":4,"LandAttributeTypeID":13,"TerritoryID":7,"Value":1}]
	func context_rows(table: String) -> Array:
		if table=="LandAttributeType": return [{"ID":13,"Name":"NoTeleportCome","UnitID":20},{"ID":2,"Name":"NoBookmark","UnitID":20}]
		return rows.duplicate(true) if table=="LandAttribute" else []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void:
	var provider:=PROVIDER.new()
	check(not provider.load_pack("/missing/definitions","0".repeat(64)) and not provider.loaded,"caller must supply exact owner definition pin")
	check(not provider.load_pack("/missing/definitions",PROVIDER.MANIFEST_SHA256) and not provider.loaded,"missing requested definitions cannot bind")
	check(provider.portal_evidence_for_land(1,"1/").is_empty() and provider.portal_context_for_land(1,"1/",1101).is_empty(),"unbound provider returns no declarations")
	var fixture:=RuleFixture.new()
	var holds: Array=provider._attribute_holds(fixture,4,Vector2i(10,20))
	check(holds.size()==1 and holds[0].row.Value==1,"authored restriction fixture retains its raw applicable rule")
	check(provider._attribute_holds(fixture,4,Vector2i(13,20)).is_empty(),"scoped restriction is not applied outside its original Territory")
	fixture.rows[0].Value=0
	check(provider._attribute_holds(fixture,4,Vector2i(10,20)).is_empty(),"known NoTeleportCome false is distinct from true")
	fixture.rows[0].TerritoryID=99
	check(provider._attribute_holds(fixture,4,Vector2i(10,20))[0].reason=="attribute_territory_unresolved","unknown attribute scope stays held")
	fixture.rows[0]={"LandID":4,"LandAttributeTypeID":99999,"TerritoryID":0,"Value":0}
	check(not provider._attribute_holds(fixture,4,Vector2i(10,20)).is_empty(),"unknown zero-valued type is not assumed to grant entry")
	var root: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--definition-root="): root=arg.trim_prefix("--definition-root=")
	if not root.is_empty():
		check(provider.load_pack(root,PROVIDER.MANIFEST_SHA256),"actual PR230 production definition pack: "+provider.problem)
		if provider.loaded:
			var context: Dictionary=provider.portal_context_for_land(1,"1/",1101)
			check(not context.is_empty() and context.definition_owner=="PR230_PATCH523_WORLD_LINKS" and context.definition_manifest_sha256==PROVIDER.MANIFEST_SHA256,"genuine owning loader supplies original context")
			if not context.is_empty():
				check(int(context.Portal.SourceX)==32668 and int(context.Portal.SourceY)==32803 and int(context.TargetTerritory.StartX)==32477 and int(context.TargetTerritory.StartY)==32855,"actual native1101 exact source and destination retained")
				check(not context.native_definition_contract.travel_enabled and not context.native_definition_contract.activation_known and context.source_travel_hold.is_empty(),"own manual adapter does not promote native activation; no absent restrictions invented")
				context.Portal.SourceX=0
				check(int(provider.portal_context_for_land(1,"1/",1101).Portal.SourceX)==32668,"context consumer cannot mutate owning definitions")
			var exception: Dictionary=provider.portal_context_for_land(4,"Aden/",350)
			check(not exception.is_empty() and int(exception.TargetTerritory.StartX)==34275 and int(exception.TargetTerritory.StartY)==32222,"Portal350 keeps exact M declaration rather than different packed raw candidate")
			check(provider.portal_evidence_for_land(4,"4/").is_empty(),"Land4 does not alias physical folder4; Aden namespace remains exact")
			check(not provider.portal_context_for_land(1,"1/",1101).is_empty(),"failed foreign-AssetPath request preserves prior valid definitions")
			check(not provider.load_pack("/missing/new-definitions",PROVIDER.MANIFEST_SHA256) and provider.loaded and not provider.portal_context_for_land(1,"1/",1101).is_empty(),"failed pack update preserves old valid binding")
			check(provider.cache_metrics().cached_native_lands<=4,"definition shard cache remains bounded")
	print("CURRENT523_PRODUCTION_PORTAL_PROVIDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_definition_pack":not root.is_empty(),"native_activation_verified":false,"map_play_verified":false,"owner_loader_blob":"0fcb00cba1d6ca7e5f2ea2e12aee187d622551e0"}))
	quit(0 if failures.is_empty() else 1)
