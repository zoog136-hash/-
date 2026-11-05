extends RefCounted
## Read the first complete original flat plist dictionary, as Cocos SAXParser does.
static func parse(raw: PackedByteArray) -> Dictionary:
	if raw.size()>4*1024*1024:return {"ok":false,"error":"particle_plist_size_bound"}
	var xml:=XMLParser.new()
	if xml.open_buffer(raw)!=OK:return {"ok":false,"error":"particle_plist_xml"}
	var depth: int=0
	var kind: String=""
	var key: String=""
	var text_value: String=""
	var values: Dictionary={}
	while xml.read()==OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name_value: String=xml.get_node_name()
				if name_value=="dict":
					depth+=1
					if depth!=1:return {"ok":false,"error":"nested_particle_dictionary"}
				elif depth==1:
					if name_value not in ["key","string","real","integer","true","false"]:return {"ok":false,"error":"unsupported_particle_value"}
					kind=name_value;text_value=""
					if xml.is_empty():
						if key.is_empty():return {"ok":false,"error":"particle_key_missing"}
						if kind=="string":values[key]=""
						elif kind in ["true","false"]:values[key]=kind=="true"
						else:return {"ok":false,"error":"empty_particle_scalar"}
						kind="";key=""
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not kind.is_empty():text_value+=xml.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				var name_value: String=xml.get_node_name()
				if name_value=="dict" and depth==1:
					return {"ok":true,"values":values} if values.has("maxParticles") else {"ok":false,"error":"not_particle_dictionary"}
				if name_value==kind:
					if kind=="key":key=text_value
					elif key.is_empty():return {"ok":false,"error":"particle_key_missing"}
					elif kind=="string":values[key]=text_value;key=""
					elif kind in ["real","integer"]:
						if not text_value.is_valid_float() or not is_finite(float(text_value)):return {"ok":false,"error":"invalid_particle_number"}
						values[key]=int(text_value) if kind=="integer" else float(text_value)
						key=""
					kind="";text_value=""
	return {"ok":false,"error":"incomplete_particle_dictionary"}
