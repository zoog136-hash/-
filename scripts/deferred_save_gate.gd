extends RefCounted

## Throttles saves for state changes that are safe to lose a few seconds of.
##
## The first request opens a window of `interval` seconds; every request that
## arrives inside it rides along, so a burst of quickslot/shop/equip actions
## costs one disk write instead of one per action. The window is never extended
## by later requests, so unsaved data is at most `interval` seconds old even
## under continuous activity. Transactions (enhancement, crafting, card draws)
## and the pause/quit notifications must NOT go through this gate: they save
## immediately and call cancel() through the normal save path.

var interval: float = 10.0
var remaining: float = -1.0
var requests: int = 0
var fires: int = 0

func _init(seconds: float = 10.0) -> void:
	interval = seconds

func request() -> void:
	requests += 1
	if remaining < 0.0:
		remaining = maxf(0.0, interval)

func pending() -> bool:
	return remaining >= 0.0

## Advance the window. Returns true exactly once, on the tick it elapses.
func tick(delta: float) -> bool:
	if remaining < 0.0:
		return false
	remaining -= delta
	if remaining > 0.0:
		return false
	remaining = -1.0
	fires += 1
	return true

## Drop any pending request. Called whenever a save has just been committed,
## because that save already contains every earlier change.
func cancel() -> void:
	remaining = -1.0
