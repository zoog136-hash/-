# Live Forge Item-CSB host receiver (local, unexecuted)

This is a TWILIGHT host policy, not recovered private-client registration.
It separates verified original ItemClass/Icon/AssetView/CSB/atlas hierarchy
from attachment to the actual current Forge equipment slot. The original
`authored_sprite_anchor`/`original_registration_confirmed=true` descriptor
path remains unchanged. No original registration flag is manufactured.

## Actual public signatures and caller

```gdscript
const Receiver = preload("res://scripts/ui/original_ui/source_item_scene_receiver.gd")
var issued: Dictionary = Receiver.capture_forge(hud, "equipment")
# On success, issued.receiver is the actual typed RefCounted, not a JSON token.
var proof: Dictionary = issued.receiver.validate_descriptor(descriptor)
var attachment: Dictionary = issued.receiver.validate_attachment(player, 15012, descriptor)
```

`capture_forge(hud: Node, role: String="equipment") -> Dictionary` accepts
only the live source-main controller's ordinary Forge equipment receiver.
It reuses `original_enhance_slot_receiver("equipment")`. That receiver now
also requires the actual selected entry's nonempty `instance_id`, a live
`world.item_instances[instance_id]`, and the same name and physical raw record.
The selected ItemList metadata must still equal the actual target reference.
No new inventory or physical ID is created. Scroll/inventory/quickslot
receivers are not admitted by this factory.

Success shape (Object fields stay in memory):

```gdscript
{
  "ok": true,
  "receiver": typed_receiver,
  "registration": {
    "schema": "twilight-item-scene-host-registration-v1",
    "kind": "TWILIGHT_host_registration",
    "space": "twilight_host_sprite_anchor",
    "original_registration_confirmed": false,
    "receiver": typed_receiver,
    "target": {
      "member": "UI/CommonUi/Common_Slot.csb",
      "source_sha256": "b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6",
      "manifest_sha256": actual_live_ui_pack_pin,
      "node_offset": 15012
    },
    "host_policy": "identity original item-CSB root at actual live equipment Common_Slot15012 authored Sprite anchor; no fit/offset or inferred playback"
  },
  "target": same_target_dictionary,
  "current_raw_record": current_physical_record_copy,
  "actual_target_reference": current_target_reference,
  "physical_instance_id": current_physical_id,
  "rendered": false
}
```

Image-owned `native_scene_descriptor(info, context)` must consume the supplied
`context.source_host_registration` as a distinct branch, without requiring
or creating an original-client `native_registrations[]` assertion. The UI's
actual `source_main_enhance_slots.refresh()` now requests its existing provider
through `source_native_icon_scenes.request(hud, image, context)` with:

```gdscript
context = {
  "source_slot_contract": SourceScene.external_scene_slot_contract(player.source_pack, COMMON, 15012),
  "source_host_registration": issued.registration
}
```

The Image owner supplies its existing canonical identity and actual selected
source pack in a descriptor:

```gdscript
{
  "pack": actual_selected_icon_source_pack,
  "manifest_sha256": exact_icon_pack_pin,
  "member": exact_original_icon_csb_member,
  "source_sha256": exact_original_csb_sha256,
  "registration": context.source_host_registration.duplicate(true),
  "bindings": {},
  "image_owner_identity": {
    "consumer": {
      "source_table": "ItemClass", "source_id": actual_item_class_id,
      "source_field": "IconID",
      "source_row_canonical_sha256": exact_current_row_sha,
      "source_table_sha256": "adaf246e6a70c2e24f144a5147bebaff27e9168bc5a74da8bcf871ca1287a165"
    },
    "icon_id": actual_canonical_icon_id,
    "asset_id": actual_canonical_asset_id,
    "image_pack_manifest_sha256": actual_canonical_image_provenance_manifest
  }
  # No playback key: these five sources declare no trigger/repeat policy.
}
```

The receiver re-queries `Images.describe_item(current.record)` and current
`Icons.bindings`/`Icons.packs_by_manifest`; the descriptor is not its own
identity authority. A descriptor with any playback key is rejected for this
five-case admission subset. Empty bindings are required so a provider cannot
hide an inconvenient node, clip, blend or glow. Original source hierarchy is
configured by the existing strict full-scene renderer, not inspection mode.

## Original source admission subset

Every basename below has the literal prefix `UI/CsbFile/icon/`.

| CSB basename | ItemClass IDs | Icon / Asset | Pin |
| --- | --- | --- | --- |
| Fx_Item_Armor_Pants_Myth_Eodin.csb | 242761,243271 | 83331 / 320181 | first |
| Fx_Item_Armor_Shield_Myth_Eir.csb | 253282,253292 | 83762 / 321512 | first |
| Fx_Item_Weapon_Bow_Myth_Alice.csb | 239911,239941 | 83063 / 319133 | Alice |
| Fx_Item_Weapon_Staff_Myth_Alice.csb | 239971,239981 | 83073 / 319143 | Alice |
| Fx_Item_Weapon_Sword_Myth_Alice.csb | 253302,253312 | 83992 / 321782 | Alice |

First pin: `566a4a66e894abdb3a761e8c0cca51d95799c52989a097030cab76839d99fb19`.
Alice pin: `ebf14ad21218b6ac7d5a9e9e68ef3c81f366b78e0e725df04e2ec69f2a5894f0`.
The receiver constants retain each exact CSB SHA and all ten canonical row
SHAs supplied by the Image owner, not names or similar-looking ID guesses.

Full four/five-node sets and parent offsets are checked, including original
clipping Panels. The pin/hash loader and strict renderer retain all source
FileData/atlas references, per-node anchor/position/scale/alpha/flip/blend and
the nonuniform 128x128 Glow layers. Unsupported required capabilities fail
the whole assignment. There is no 64x64 snapshot, fitting, centering or new
picture. The five roots' original identity transforms are required by prepare.

The host target is EnchantScene Project724, Enchant_All Project144788
(Inventory_Slot1), then the actual Common_Slot Sprite15012. This mapping is
the explicit source-pair/official-guide/current-Forge host policy documented
in `ORIGINAL_UI_ENHANCE_SLOT_HOST_ABI.md`, not a private native controller.

## Validation, lifecycle and handoff status

`validate_descriptor(descriptor: Dictionary) -> Dictionary` and
`validate_attachment(renderer: Node2D, offset: int, descriptor: Dictionary) -> Dictionary`
return `ok=true`, `registration_kind="TWILIGHT_host_registration"`,
`original_registration_confirmed=false`, current `target`,
`physical_instance_id`, `source_internal_proof` (member/SHA/pin/node count/clip
requirement), and `runtime_rendering_verified=false` only after their checks.
Failure shape is `{ok:false,error:code,code:code,runtime_rendering_verified:false}`.

Revalidation happens before prepare, after strict construction, immediately
before attachment and on subsequent cached Forge refreshes. Weak references
reject freed/queued/replaced/hidden controllers/players, changed target/record
or physical ownership, changed selected root/pins and mismatched canonical
row/Icon/Asset metadata. The existing actual Forge change/hide/close path
clears the owned display, detaches/stops its scene and restores its matching
legacy view. Provider failures are not cached as permanent completed displays.
`clear_bound_source_visual(15012)` handles both the actual Sprite texture and
native child; the former ImageView-only clear call did not clear Sprite15012.

No `play`, `seek`, inferred loop or trigger is added. Without playback the
existing prepare leaves serialized source defaults stopped. Source animation
metadata, such as Sword clip end116 versus duration170, is not a policy.

At receiver checkpoint `7b8338408`, the Image descriptor branch was a separate
owner dependency. Its exact owner-supplied narrow patch is now composed locally:
Image file base blob `f4b73c60098ea11071822b015a7992e427d8f373` to result blob
`180733119a945d2546acac74aacf84e1b663bf84`. It consumes this exact typed schema,
requires the actual receiver script and calls `validate_descriptor` before
returning a descriptor. This removes the missing provider branch only; it is
not evidence of an actual current owned item or displayed scene. A newly selected
current source pack must already contain all original dependencies; neither
this adapter nor the caller selects/installs packs. No actual owned/selected
profile of these five icons was found in the Image investigation. This is
local conditional code, not observed attachment/rendering or complete use.

Frozen v30/62 ZIPs, all local v45/v46 and earlier candidates, phone/configs/
saves and all originals are unchanged. No tests, compilation, parser, game,
rendering, CI, upload, publication or merge was performed.
