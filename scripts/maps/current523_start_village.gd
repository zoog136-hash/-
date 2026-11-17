extends RefCounted
## The village where 523 characters start, and the village every own fallback
## uses (사용자 결정 2026-11-17: 시작 지점은 아덴 마을이 아닌 기란 마을).
##
## Point: original M `Locations` row 473 "[리스타트 좌표] 기란 마을" (Land 4),
## the original restart coordinate of Giran town. It lies inside the original
## Giran village territory `TerritoriesVillage` 1367 (IsVillage, Land 4,
## X 33332..33548, Y 32630..32900), next to the original Giran NPC Locations
## (e.g. 265 통합 창고지기 노딤 33433,32817 · 703 변신술사 라윈 33441,32808 ·
## 814 텔레포터 멀린 33430,32825).
##
## The original tables hold one restart Location per village but no table that
## maps a field Territory to its restart village, so choosing one village for
## the new-character start, the blocked-position fallback, the tutorial and
## old-map relocations and the 523 return scroll stays the user's own policy.
## The landing is the first clear cell in rings around this point (see
## current523_aden_play_controller._village_return_point).

const LAND_ID := 4
const NAME := "기란 마을"
const LOCATION := {"ID":473,"Name":"[리스타트 좌표] 기란 마을","LandID":4,"X":33441,"Y":32813}
const VILLAGE_TERRITORY := {"ID":1367,"LandID":4,"StartX":33332,"StartY":32630,"EndX":33548,"EndY":32900}
const POLICY := "OWN_GIRAN_LOCATION473_CLEAR_RING_V1"
const DECISION := "사용자 결정 2026-11-17: 시작·귀환 마을 기란"
## Original LandAttribute 230858 gives the Giran village territory (1367)
## "ObjectLazyLoad" (type 651): a client object-loading hint, not an entry
## restriction (docs/items523_remaining_missing_rules.md treats it the same for
## teleports). Opening, resuming or returning inside the village does not wait
## on it; every other hold is kept.
const ENTRY_WAIVE: Array[String] = ["ObjectLazyLoad"]

## Source cell of the start point.
static func cell() -> Vector2i:
	return Vector2i(int(LOCATION.X), int(LOCATION.Y))

## Source position (cell center) of the start point, as saved in a
## character's `character_source_cursor.source_position`.
static func source_position() -> Array:
	return [float(LOCATION.X) + 0.5, float(LOCATION.Y) + 0.5]

## A character cursor placing the character at the start village.
static func cursor() -> Dictionary:
	return {"native_land_id":LAND_ID, "source_position":source_position()}

## True when `source_cell` (absolute Land 4 cell) is inside the original Giran
## village territory.
static func in_village(source_cell: Vector2i) -> bool:
	return source_cell.x >= int(VILLAGE_TERRITORY.StartX) and source_cell.x <= int(VILLAGE_TERRITORY.EndX) \
		and source_cell.y >= int(VILLAGE_TERRITORY.StartY) and source_cell.y <= int(VILLAGE_TERRITORY.EndY)
