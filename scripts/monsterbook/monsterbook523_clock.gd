extends RefCounted
## Shared civil-clock validation; does not read the catalog or item registry.
static func valid(clock: String) -> bool:
	if clock.length() != 12 or not clock.is_valid_int(): return false
	var year := int(clock.substr(0,4))
	var month := int(clock.substr(4,2))
	var day := int(clock.substr(6,2))
	var hour := int(clock.substr(8,2))
	var minute := int(clock.substr(10,2))
	if year <= 0 or month < 1 or month > 12 or hour > 23 or minute > 59: return false
	var days: Array = [31,29 if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0) else 28,31,30,31,30,31,31,30,31,30,31]
	return day >= 1 and day <= int(days[month-1])


static func format_row(date: Dictionary) -> String:
	if date.is_empty(): return ""
	return "%04d%02d%02d%02d%02d" % [date.get("Year",0),date.get("Month",0),date.get("Day",0),date.get("Hour",0),date.get("Minute",0)]
