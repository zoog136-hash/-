extends "res://scripts/ui/native_touch_button.gd"
## Keep the settings column scrollable when a finger begins on a button.
var inventory_scroll: ScrollContainer

func _input(event: InputEvent) -> void:
	var drag_owned: bool = event is InputEventScreenDrag and event.index == finger
	super._input(event)
	if drag_owned and moved and is_instance_valid(inventory_scroll):
		var bar: VScrollBar = inventory_scroll.get_v_scroll_bar()
		inventory_scroll.scroll_vertical = clampi(inventory_scroll.scroll_vertical-roundi(event.relative.y),0,maxi(0,ceili(bar.max_value-bar.page)))
