extends SceneTree
const S=preload("res://scripts/domination/domination_stone_source.gd")
const WINDOW=preload("res://scripts/ui/original_ui/source_main_domination_stone_window.gd")
var checks: int=0
var failures: Array=[]
class QuoteOwner extends RefCounted:
 var quote: Dictionary
 func merge_quote(_ids: Array) -> Dictionary:return quote
class View extends WINDOW:
 var owner: QuoteOwner=QuoteOwner.new()
 var shown: String=""
 func _runtime() -> Object:return owner
 func _message(text: String) -> void:shown=text
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label)
func quote(special: int,pairs: Array,group: int=1) -> Dictionary:
 return {"ok":true,"price":5,"grades":[[1,1000000]],"same_group":group,"same_group_probability_raw":special,"base_groups":pairs}
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var cases: Array=[
  [quote(200000,[[1,250000],[2,750000]]),400000000000],
  [quote(200000,[[2,1000000]]),200000000000],
  [quote(0,[[1,250000],[2,750000]]),250000000000],
  [quote(1000000,[[1,250000],[2,750000]]),1000000000000],
  [quote(200000,[[1,100000],[2,750000],[1,150000]]),400000000000],
  [quote(333333,[[1,333333],[2,666667]]),555555111111],
  [quote(-1,[[1,250000],[2,750000]],-1),0]]
 for entry: Array in cases:check(S.same_group_outcome_numerator(entry[0])==entry[1],"exact two-draw outcome numerator")
 # Enumerate each original integer base-roll value with the actual picker.
 # Multiply by the number of special successes/failures, rather than sampling
 # RNG or enumerating 1e12 pairs. Every pair has identical probability.
 var q: Dictionary=cases[0][0];var base_matches: int=0
 for roll: int in S.PROBABILITY_SCALE:
  if S.pick(q.base_groups,roll)==q.same_group:base_matches+=1
 var success_pairs: int=int(q.same_group_probability_raw)*S.PROBABILITY_SCALE+(S.PROBABILITY_SCALE-int(q.same_group_probability_raw))*base_matches
 check(base_matches==250000 and success_pairs==S.same_group_outcome_numerator(q),"complete actual picker enumeration agrees with displayed probability")
 var view:=View.new();view.owner.quote=q
 var before: Dictionary=q.duplicate(true)
 check(view._fusion_probability()==q,"actual probability callback returns unmodified quote")
 check(view.shown.contains("같은 종류 최종 40.0%") and view.shown.contains("우선 추첨 20.0%") and view.shown.contains("실패 시 기본 추첨 포함"),"actual UI distinguishes total outcome from special gate")
 check(q==before,"presentation leaves owner quote untouched")
 view.owner.quote=cases[-1][0];view._fusion_probability()
 check(not view.shown.contains("같은 종류"),"no eligible same-group gate retains grade-only display")
 view.owner.quote={"ok":false,"error":"locked"}
 check(not view._fusion_probability().ok and view.shown=="locked","failed quote shows owner refusal")
 print("DOMINATION_MERGE_PROBABILITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"enumerated_base_rolls":1000000,"synthetic_only":true}))
 quit(0 if failures.is_empty() else 1)
