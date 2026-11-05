extends RefCounted
## Retained API name for old callers. It cannot construct or execute a form.
const Presentation=preload("res://scripts/cards/source_card_operation_presentation.gd")
func configure(_service: RefCounted) -> void:pass
func refresh() -> Dictionary:return Presentation.request(Presentation.CRAFT)
func _execute() -> Dictionary:return Presentation.request(Presentation.CRAFT)
