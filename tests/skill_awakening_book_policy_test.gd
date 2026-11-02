extends SceneTree
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
var errors: Array[String]=[]
var checks: int=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:
	var core=Core.new();var seen: Dictionary={}
	for identity: String in core.cards:
		var requirement: Dictionary=core.book_requirement(identity)
		if requirement.is_empty():continue
		var id: String=str(requirement.item_class_id)
		if seen.has(id):continue
		seen[id]=true
		check(requirement.quantity==1 and requirement.quantity_provenance=="explicit_user_policy","one book user policy "+id)
		check(not core.prepare_book_debit(identity,{}).ok,"missing book rejected "+id)
		check(not core.prepare_book_debit(identity,{"wrong":99}).ok,"wrong source book rejected "+id)
		var owned: Dictionary={id:2};var before: int=hash(owned)
		var result: Dictionary=core.prepare_book_debit(identity,owned)
		check(result.ok and result.source_book_counts[id]==1 and hash(owned)==before,"exactly one staged without mutation "+id)
		check(not result.committed and not result.fee_verified,"no unverified fee transaction "+id)
		check(core.prepare_book_debit(identity,{id:1}).source_book_counts.is_empty(),"last book removed "+id)
		check(not core.prepare_book_debit(identity,{id:1.5}).ok,"fractional quantity rejected "+id)
	check(seen.size()==5,"five exact source book IDs")
	print("SKILL_BOOK_POLICY ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
