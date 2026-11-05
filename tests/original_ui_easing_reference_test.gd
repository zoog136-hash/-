extends SceneTree
const EASING=preload("res://scripts/ui/original_ui/source_easing.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size() not in [1,2]:quit(2);return
	var reference=FileAccess.open(args[0],FileAccess.READ)
	if reference==null:quit(2);return
	var checks: int=0
	var failures: int=0
	while not reference.eof_reached():
		var row=reference.get_csv_line()
		if row.size()==1 and row[0].is_empty():continue
		if row.size()!=10:quit(2);return
		for index: int in range(EASING.SUPPORTED.size()):
			checks+=1
			if absf(EASING.sample(EASING.SUPPORTED[index],float(row[0]))-float(row[index+1]))>0.000002:failures+=1
	if args.size()==2:
		var curves: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		for curve: Dictionary in curves:
			checks+=1
			if not EASING.accepts({"type":-1,"points":curve.points}):failures+=1
			if curve.reference.size()!=1001:quit(2);return
			for i: int in range(1001):
				checks+=1
				if absf(EASING.sample(-1,float(i)/1000.0,curve.points)-float(curve.reference[i]))>0.000002:failures+=1
		for bad: Dictionary in [{"type":-1,"points":[]},{"type":-1,"points":[[0,0],[1,1]]},{"type":10000,"points":[]}]:
			checks+=1
			if EASING.accepts(bad):failures+=1
	print("ORIGINAL_EASING_REFERENCE ",JSON.stringify({"checks":checks,"failures":failures,"reference":"compiled Cocos 3.6 source; explicit private CSV"}))
	quit(0 if failures==0 and checks>=9009 else 1)
