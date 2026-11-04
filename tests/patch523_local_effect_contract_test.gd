extends SceneTree
const COMBAT=preload("res://scripts/crafting/patch523_equipment_combat.gd")
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
func _initialize() -> void:
 # Explicit synthetic interface fixture, never an owned/source reward record.
 var option: Dictionary={"ID":9001,"InvokeOptionTypeID":6,"AttackTypeID":0,"BySpellAttack":false,"Param1":2000000}
 for key: String in ["Param2","Param3","Param4","Param5","Param6","MaterialTypeID","MaterialAmount","IsAmmoAttack","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:option[key]=0
 var effect: Dictionary={"row_id":90001,"probability":150000,"kind":"attack_weapon_scale","option":option}
 var failures: Array=[];var checks: int=0
 checks+=1
 if not COMBAT.valid(effect):failures.append("fully typed normal weapon-scale interface rejected")
 for mutation: Dictionary in [{"Param1":500000},{"BySpellAttack":true},{"AttackTypeID":62},{"MaterialAmount":1},{"Param6":82},{"SuccessedInvokeOptionID":3}]:
  var changed: Dictionary=effect.duplicate(true);changed.option.merge(mutation,true);checks+=1
  if COMBAT.valid(changed):failures.append("unsupported contract accepted "+str(mutation))
 var record: Dictionary={"patch523_invoke_options":{"1":[effect]}}
 var settings: Dictionary=ENHANCE.policy();var original: String=settings.source_weapon_scale_scope
 settings.source_weapon_scale_scope="disabled";checks+=1
 if not COMBAT.summary(record,1).contains("disabled"):failures.append("disabled weapon scope not disclosed")
 settings.source_weapon_scale_scope=original
 record={"enhancement_extra_options":{"1":{"source_melee_flat_reduction_ignore":4}}};original=settings.source_typed_flat_ignore_consumer
 settings.source_typed_flat_ignore_consumer="disabled";checks+=1
 if not COMBAT.summary(record,1).contains("disabled"):failures.append("disabled typed projection not disclosed")
 settings.source_typed_flat_ignore_consumer=original
 print("PATCH523_LOCAL_EFFECT_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_interface_fixture":true}))
 quit(0 if failures.is_empty() else 1)
