extends RefCounted
## Bounded card-awakening status reference. Not a general attr48 interpreter.
const DATA=preload("res://data/cards/base508_option_extensions.json")
static func binding(definition: Dictionary) -> Dictionary:
	if not definition.has("native_source"):return {"ok":false,"status":"not_native"}
	var card: Dictionary=definition.native_source.card
	var matches: Array=[]
	for row: Dictionary in DATA.data.awaken_effects:
		if int(row.BuffCardDeckID)==int(card.BuffCardDeckID) and int(row.GradeID)==int(card.GradeID):matches.append(row)
	if matches.size()!=1:return {"ok":false,"status":"source_effect_ambiguous"}
	var effect: Dictionary=matches[0];var status: int=int(effect.StatusEffectID);var linked: bool=false
	for option: Dictionary in definition.native_source.effects:
		if option.type.Name=="StatusEffectID" and int(option.link.Level)==1 and int(option.bonus.Value)==status and int(option.bonus.BonusApplicationTypeID)==0 and int(option.bonus.BonusApplicationTargetID)==0:linked=true
	if not linked:return {"ok":false,"status":"source_option_status_not_linked"}
	var sprites: Array=[];var raw: Array=[];var pending: Array=[]
	for attr: Dictionary in DATA.data.status_effect_attrs:
		if int(attr.StatusEffectID)!=status:continue
		raw.append(attr.duplicate(true))
		if int(attr.StatusEffectAttrType)==48 and int(attr.GenderID)==0:sprites.append(int(attr.Value))
		else:pending.append(attr.duplicate(true))
	if sprites.size()!=1:return {"ok":false,"status":"source_sprite_reference_ambiguous"}
	return {"ok":true,"source_awaken_effect_id":int(effect.ID),"status_effect_id":status,"sprite_id":sprites[0],"raw_attrs":raw,"uninterpreted_attrs":pending,"scope":"only_BuffCardAwakenEffect_plus_explicit_option_StatusEffectID","runtime_visual_status":"sprite_reference_verified_lifecycle_attributes_pending"}
