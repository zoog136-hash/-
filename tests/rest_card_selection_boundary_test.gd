extends SceneTree
## Integration boundary fixtures only; no native cards/items or user saves.
const SAVE=preload("res://scripts/cards/card_selection_save.gd")
var checks: int=0
var failures: Array[String]=[]
class FixtureOptions extends RefCounted:
 var state: Dictionary={"schema":1,"fixture_only":true}
 func export_state()->Dictionary:return state.duplicate(true)
class FixtureWorld extends Node:
 var inventory: Dictionary={"qa-material":2}
 var item_instances: Dictionary={"qa-item":{"fixture_quantity":1}}
 var option_awakening=FixtureOptions.new()
 var selection_gate: RefCounted
 var calls: int=0
 var error: Error=OK
 var authorized_inside: bool=false
 var reenter: bool=false
 var reentrant_result: Error=OK
 var received: Dictionary={}
 func _save_game(_quiet: bool,staged: Dictionary)->Error:
  calls+=1;authorized_inside=selection_gate.authorizes(staged);received=staged.duplicate(true)
  if reenter:reentrant_result=selection_gate.commit(self,true,staged)
  return error
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("REST_CARD_SAVE_FAIL "+label)
func primary(w: Node)->Dictionary:
 return {"equipped_catalog":{"fixture":"qa-card"},"inventory":w.inventory.duplicate(true),"item_instances":w.item_instances.duplicate(true),"card_option_awakening":w.option_awakening.export_state(),"hp":9,"mp":8}
func _initialize()->void:
 var w:=FixtureWorld.new();root.add_child(w);w.selection_gate=SAVE.new()
 var live: Dictionary={"inventory":w.inventory.duplicate(true),"items":w.item_instances.duplicate(true),"options":w.option_awakening.export_state()}
 var wider: Dictionary=primary(w);w.reenter=true
 check(w.selection_gate.commit(w,true,wider)==OK and w.calls==1 and w.authorized_inside,"PR231 wider immutable ownership snapshot reaches one sealed writer")
 check(w.received==wider and w.reentrant_result==ERR_BUSY and not w.selection_gate.authorizes(wider),"full payload retained, reentrant writer blocked and seal released")
 check(w.inventory==live.inventory and w.item_instances==live.items and w.option_awakening.export_state()==live.options,"stage/save gate never adopts/debits live source owners")
 w.reenter=false;w.error=ERR_FILE_CANT_WRITE
 check(w.selection_gate.commit(w,true,wider)==ERR_FILE_CANT_WRITE and not w.selection_gate.authorizes(wider),"failed writer propagates and releases seal without publishing state")
 w.error=OK
 for key: String in ["inventory","item_instances","card_option_awakening"]:
  var bad: Dictionary=primary(w);bad[key]["qa-forbidden-change"]=true;var count: int=w.calls
  check(w.selection_gate.commit(w,true,bad)==ERR_INVALID_DATA and w.calls==count,"wider quote cannot change another snapshot owner: "+key)
 var before: int=w.calls;w.inventory["qa-material"]=3
 check(w.selection_gate.commit(w,true,wider)==ERR_INVALID_DATA and w.calls==before,"stale wider inventory rejected before save");w.inventory=live.inventory.duplicate(true)
 for owner_key: String in ["equipped_catalog","card_option_awakening"]:
  var compact: Dictionary={owner_key:{"fixture_only":true},"hp":9,"mp":8}
  check(w.selection_gate.commit(w,true,compact)==OK and w.received==compact and not w.selection_gate.authorizes(compact),"PR248 compact single-owner selection preserved: "+owner_key)
 var bad: Dictionary=primary(w);bad["gold"]=1000;before=w.calls
 check(w.selection_gate.commit(w,true,bad)==ERR_INVALID_PARAMETER and w.calls==before,"no extra output/currency owner enters selection boundary")
 bad=primary(w);bad.hp=1.5
 check(w.selection_gate.commit(w,true,bad)==ERR_INVALID_PARAMETER,"fractional vitals refused")
 check(w.inventory==live.inventory and w.item_instances==live.items and w.option_awakening.export_state()==live.options,"all failure/compact paths preserve unrelated live ownership")
 print("REST_CARD_SAVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true,"native_selection_effect_not_claimed":true}))
 w.free();quit(0 if failures.is_empty() else 1)
