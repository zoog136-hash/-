extends SceneTree
const R=preload("res://scripts/refine523/bless_refine523_rules.gd")
const S=preload("res://scripts/refine523/bless_refine523_service.gd")
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label)
func _initialize() -> void:
 check(R.normal_amount(101,10,3)==336,"native float32 ceil before count")
 check(R.normal_amount(100,15)==116,"float32 rounding retained")
 check(R.normal_amount(6000,15)==6901,"float32 boundary retained")
 check(R.normal_amount(1,0,9000000000000000000)==R.MAX_DISSOLVE_AMOUNT,"exact safety boundary accepted")
 check(R.normal_amount(2,0,9000000000000000000)==-1,"multiplication rejected before integer wrap")
 check(R.normal_amount(9000000000000000000,100)==-1,"base plus amplification rejected before addition")
 check(R.normal_amount(9223372036854775807,9223372036854775807)==-1,"huge float conversion rejected")
 check(R.normal_amount(1,-1)==-1 and R.normal_amount(1,0,0)==-1,"invalid inputs refused")
 check(S.dissolve_total(R.MAX_DISSOLVE_AMOUNT-1,1)==R.MAX_DISSOLVE_AMOUNT,"batch exact limit")
 check(S.dissolve_total(R.MAX_DISSOLVE_AMOUNT,1)==-1,"batch over limit refused")
 check(S.dissolve_total(9000000000000000000,9000000000000000000)==-1,"two valid amounts cannot wrap aggregate")
 check(S.dissolve_total(12,34)==46,"ordinary totals unchanged")
 check(S.dissolve_total(0,-1)==-1 and S.dissolve_total(-1,1)==-1,"invalid amount cannot enter quote")
 print("DISSOLVE_AMOUNT_BOUNDS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_pack_used":false}))
 quit(0 if failures.is_empty() else 1)
