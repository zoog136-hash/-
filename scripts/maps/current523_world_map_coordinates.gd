extends RefCounted
## OWN registration for the original image owner's continuous texture pixels.
## Source anchors/Ratio remain unchanged. This is not a recovered M formula.
const POLICY: String = "OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1"

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _pair(value: Variant) -> bool:
	return value is Array and value.size()==2 and _number(value[0]) and _number(value[1])

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"coordinate_policy":POLICY,"native_image_info_formula_confirmed":false}

static func project(field: RefCounted, pixel: Dictionary, options: Dictionary={}) -> Dictionary:
	if options.get("coordinate_policy",POLICY)!=POLICY:return _fail("world_map_coordinate_policy_unavailable")
	if field==null or field.get_meta("current523_source_field",false)!=true:return _fail("world_map_mobile_source_field_required")
	var coordinates: Variant=field.get("coordinates")
	if coordinates==null or not coordinates.get("valid"):return _fail("world_map_field_coordinates_unavailable")
	if pixel.get("native_texture_pixel_registration_complete")!=true or pixel.get("pixel_space")!="intrinsic_texture_top_left_x_right_y_down" or pixel.get("pixel_coordinate_convention")!="continuous_edges_before_display_flips":return _fail("world_map_registered_original_pixel_required")
	var point: Variant=pixel.get("raw_pixel")
	var extent: Variant=pixel.get("texture_size")
	if not point is Vector2 or not point.is_finite() or not extent is Vector2 or not extent.is_finite() or extent.x<=0 or extent.y<=0:return _fail("world_map_image_point_invalid")
	# The UI owner checks the true displayed rectangle and clip ancestry.
	# Flipped edges may equal the intrinsic extent. Do not clamp or snap.
	if point.x<0 or point.y<0 or point.x>extent.x or point.y>extent.y:return _fail("world_map_point_outside_original_image")
	var info: Variant=pixel.get("source_image_info")
	if not info is Dictionary:return _fail("world_map_source_image_info_required")
	for key: String in ["Ratio","BaseLocX","BaseLocY","BasePixelX","BasePixelY"]:
		if not _number(info.get(key)):return _fail("world_map_source_anchor_invalid")
	if float(info.Ratio)<=0:return _fail("world_map_source_ratio_not_positive")
	var ratio_scale: Variant=options.get("ratio_scale",1.0)
	var anchor: Variant=options.get("source_anchor_offset",[0.5,0.5])
	if not _number(ratio_scale) or float(ratio_scale)<=0 or float(ratio_scale)>1000000 or not _pair(anchor) or absf(float(anchor[0]))>1 or absf(float(anchor[1]))>1:return _fail("world_map_own_registration_invalid")
	var bx: Vector2=coordinates.get("basis_x")
	var by: Vector2=coordinates.get("basis_y")
	var determinant: float=float(bx.x)*float(by.y)-float(bx.y)*float(by.x)
	if not bx.is_finite() or not by.is_finite() or not is_finite(determinant) or absf(determinant)<0.000001:return _fail("world_map_field_basis_not_invertible")
	# OWN assumption: Ratio is field canvas units per original image pixel,
	# the image axes follow the field canvas, and BaseLoc names a cell center.
	# Reuse this field's basis; no PC projection, image resizing or new pixels.
	var ratio: float=float(info.Ratio)*float(ratio_scale)
	var dx: float=(float(point.x)-float(info.BasePixelX))*ratio
	var dy: float=(float(point.y)-float(info.BasePixelY))*ratio
	var source_x: float=float(info.BaseLocX)+float(anchor[0])+(dx*float(by.y)-dy*float(by.x))/determinant
	var source_y: float=float(info.BaseLocY)+float(anchor[1])+(dy*float(bx.x)-dx*float(bx.y))/determinant
	if not is_finite(source_x) or not is_finite(source_y) or absf(source_x)>2147480000 or absf(source_y)>2147480000:return _fail("world_map_source_components_out_of_range")
	var target: Vector2=coordinates.components_to_world([source_x,source_y])
	if not target.is_finite():return _fail("world_map_target_not_finite")
	return {"ok":true,"source_components":[source_x,source_y],"source_cell":Vector2i(floori(source_x),floori(source_y)),"world_position":target,"raw_pixel":point,"source_image_info":info.duplicate(true),"coordinate_policy":POLICY,"native_image_info_formula_confirmed":false,"own_ratio_scale":float(ratio_scale),"own_source_anchor_offset":anchor.duplicate(),"image_or_source_data_written":false}
