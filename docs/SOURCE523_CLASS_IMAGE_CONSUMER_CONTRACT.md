# Original class/gender images (unexecuted)

The existing main HUD portrait now consumes
`ClassAssets.MainHUDPortraitID` through `source523_class_images.gd`. It uses
the actual world's existing `_source_visual_context()` native `class_id` and
explicitly selected `gender_id`. Local class indices, names, mythic-card
illustrations and filenames are not used as source image identities.

`SourceClassImages.resolve(context, "MainHUDPortraitID")` reuses Data271's
existing `current523_definition_rows.gd` exact original-archive reader:

1. `identity()` supplies the original current523 archive receipt.
2. `row("Class", class_id)` and `row("Gender", gender_id)` require the exact
   original entities.
3. `related("ClassAssets", "ClassID", class_id)` is filtered by the explicit
   GenderID and must have exactly one matching pair.
4. Only that row's declared role value becomes an AssetView lookup in the
   selected original image pack, retaining its actual type/path and exclusions.

ClassAssets has **no single ID**. Its key is `(ClassID, GenderID)`; the adapter
does not choose the first row or a default gender. The world's gender0 remains
unknown for this caller. The reader supplies no ClassAssets row number or
row/table SHA, and no such evidence is invented. Source row provenance remains
separate from the image pack's original pixel provenance.

The named static roles `HUD`, `BigHUD`, `MainHUDPortraitID` and `Icon` remain
distinct. The existing main HUD calls only `MainHUDPortraitID`. Zero/missing
fields do not fall back to another role. Lobby effects are original CSB assets,
Spine IDs are separate, and ProfileImage URLs are not local AssetIDs. No role
is promoted into an original character-selection portrait.

`hud_v20.gd.set_character_state` supplies the existing portrait TextureRect.
Its position, size, stretch mode and character shortcut/input remain unchanged.
The successful source portrait is retained while native class/gender, image
pack instance and selection status are unchanged, outside repeated pixel
lookups. Selection changes clear/rebind it. Leaving source-image selection
clears the source metadata; selected missing/unknown originals do not use the
authored class atlas as original art. The existing source-gender setter already
refreshes the HUD; this change does not select a gender, update saves or alter
class/actor/equipment behavior.

The returned source descriptor includes class/gender, exact ClassAssets role,
original loader status, unchanged-byte flag, static original Texture2D and
texture-free evidence. Native UI267 callers may reuse this image API only for
their actually declared role/target; this work adds no original UI node,
renderer, source geometry, replacement portrait or animation.

The existing Data271 reader and its configured original definition ZIP are
integration inputs. No source parser, extra pack, download, upload or config
rewrite is introduced. This code and actual portrait consumption are
unexecuted/unverified. No additional tests, game execution, rendering or CI
were started, and no original file/byte usage count advances.
