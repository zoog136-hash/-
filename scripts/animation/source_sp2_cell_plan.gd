extends RefCounted
## Pure, bounded ordering plan for already admitted SP2 cells. Static restored
## 524-origin code in the 525 analysis bundle, projected to 523. This is not
## a world renderer or visibility test.
## The caller supplies actual actor cell/identity and native submission order.
## Rebuilds a fresh submitted set; retained native entries need their actual
## insertion history, never a fixed role/file order inferred by this helper.
## No source bytes, images, cache leases, flags or blend operators are retained.
const MAX_SUBMISSIONS: int = 4096
const MAX_REFERENCES: int = 131072
const UINT32_MAX: int = 0xffffffff

static func _fail(message: String) -> Dictionary:
 return {"ok":false,"error":message}

static func _integer(value: Variant, low: int, high: int) -> bool:
 return value is int and int(value) >= low and int(value) <= high

static func _signed32(value: int) -> int:
 var low: int = value & UINT32_MAX
 return low - 0x100000000 if low >= 0x80000000 else low

static func _before(left: Dictionary, right: Dictionary) -> bool:
 if left.depth != right.depth: return int(left.depth) < int(right.depth)
 if left.identity_high != right.identity_high: return int(left.identity_high) > int(right.identity_high)
 if left.identity_low != right.identity_low: return int(left.identity_low) > int(right.identity_low)
 # Native lower_bound inserts a new exact tie before existing equal items.
 return int(left.sequence) > int(right.sequence)

## Each submission: refs from the unchanged production decoder, block_count,
## actor_cell:Vector2i, explicit identity_high/low:u32, layer_override:u8 and a
## source_key diagnostic label. Identity is actor+D0, never the sprite/file ID.
## Cells are independent dictionary buckets: their iteration order has no native
## meaning. Window/flat-index admission and inter-cell traversal belong to a
## separate verified world context and are deliberately not guessed here.
static func build(submissions: Array, reference_limit: int = MAX_REFERENCES) -> Dictionary:
 if reference_limit < 1 or reference_limit > MAX_REFERENCES: return _fail("Invalid cell-plan reference limit.")
 if submissions.size() > MAX_SUBMISSIONS: return _fail("Cell-plan submission limit exceeded.")
 var total: int = 0
 for source: Variant in submissions:
  if not source is Dictionary or not source.get("refs") is Array or not source.get("actor_cell") is Vector2i:
   return _fail("Cell plan requires decoded references and an explicit actor cell.")
  if not _integer(source.get("block_count"),0,65536) or not _integer(source.get("layer_override"),0,255):
   return _fail("Invalid SP2 cell block count or layer override.")
  if not _integer(source.get("identity_high"),0,UINT32_MAX) or not _integer(source.get("identity_low"),0,UINT32_MAX):
   return _fail("Cell plan requires the exact unsigned actor identity as two u32 words.")
  if not source.get("source_key") is String or str(source.source_key).is_empty():
   return _fail("Cell plan requires an explicit source diagnostic key.")
  total += source.refs.size()
  if total > reference_limit: return _fail("Cell-plan reference limit exceeded.")
  for ref: Variant in source.refs:
   if not ref is Dictionary or not _integer(ref.get("a"),-128,127) or not _integer(ref.get("b"),-128,127) or not _integer(ref.get("type"),0,255) or not _integer(ref.get("index"),0,int(source.block_count)-1):
    return _fail("Invalid decoded SP2 cell reference.")
 var cells: Dictionary = {}
 var sequence: int = 0
 for source_index: int in range(submissions.size()):
  var source: Dictionary = submissions[source_index]
  var actor: Vector2i = source.actor_cell
  for ref_index: int in range(source.refs.size()):
   var ref: Dictionary = source.refs[ref_index]
   # Native signed32 ADD followed by signed window comparisons. Admission is
   # not done here; retaining low32 avoids accidental float/u64 conversion.
   var cell := Vector2i(_signed32(int(actor.x)+int(ref.a)),_signed32(int(actor.y)+int(ref.b)))
   if not cells.has(cell): cells[cell] = []
   cells[cell].append({"source_key":source.source_key,"submission_index":source_index,
    "reference_index":ref_index,"block_index":int(ref.index),"world_cell":cell,
    "depth":int(source.layer_override) if int(source.layer_override) != 0 else int(ref.type),
    "identity_high":int(source.identity_high),"identity_low":int(source.identity_low),"sequence":sequence})
   sequence += 1
 for entries: Array in cells.values(): entries.sort_custom(_before)
 return {"ok":true,"error":"","cells":cells,"reference_count":total,
  "cell_count":cells.size(),"origin":"restored524_code_525_bundle_cell_lower_bound_to523_static_contract",
  "inter_cell_order_verified":false,"admission_or_blend_verified":false,"retained_history_verified":false}
