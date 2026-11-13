extends RefCounted
## Exclusive boundaries within one synchronous setup, including failed setup.
## Parent spawn.setup and view/SP2 details remain inclusive; never sum them.
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
var _started: int = HITCH.now()
var _boundary: int = _started
var _phase: String = "reset"
var _phases: Dictionary = {}
var _npc: int = -1
var _sprite: int = -1
var _enabled: bool = HITCH.enabled

func identify(record: Dictionary) -> void:
	_npc = int(record.get("source_m_npc_id",-1))
	_sprite = int(record.get("source_m_sprite_id",-1))

func phase(next: String) -> void:
	if not _enabled: return
	var at: int = HITCH.now()
	var elapsed: int = maxi(0,at-_boundary)
	_phases[_phase] = int(_phases.get(_phase,0))+elapsed
	HITCH.detail("setup."+_phase,_boundary)
	_boundary = at
	_phase = next

func finish(accepted: bool) -> void:
	if not _enabled: return
	phase("")
	# Bound retained diagnostics to the slowest setup in each recorded frame.
	HITCH.slow_spawn({"usec":_boundary-_started,"npc":_npc,"sprite":_sprite,
		"accepted":accepted,"phases_usec":_phases})
