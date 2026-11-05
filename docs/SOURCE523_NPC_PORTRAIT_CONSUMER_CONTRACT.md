# Original NPC illustration consumer (unexecuted)

`scripts/ui/source523_npc_images.gd` shares the existing original NPC
illustration lookup between the actual NPC selector and UI267's original
dialogue portrait receiver. This code has not been executed or verified.

## Existing source provider

`resolve(catalog, npc_class_id)` consumes the existing opened
`patch523_npc_catalog.gd` instance. Its pinned source pack supplies the original
NpcClass row, source snapshot/archive and row index. The positive ID must match
that supplied original row. Only its declared `IllustAssetID` becomes an
AssetView lookup through `source523_image_assets`; the asset's actual type/path
is retained. The image pack supplies original pixel provenance and exclusions.
It does not claim a canonical NpcClass-table check.

The existing NPC inspector calls this same resolver for its existing selector.
Missing rows or image fields, zero, excluded images and unsupported formats
remain unavailable. An absent row in that provider is not a statement that the
whole original NpcClass table lacks the NPC. No name, Sprite, local ID, outline,
screen-message image or combination image substitutes for this role.

`resolve_definition(npc_class_id)` separately reuses Data271's existing
[current523_definition_rows.gd](https://github.com/zoog136-hash/-/blob/6622063ee90806c1c753c695978f586ef7906cc3/scripts/resources/current523_definition_rows.gd)
static `identity()` and `row("NpcClass", id)` APIs. Its exact original-archive
identity and unique full row supply town NPCs too, without combat-category or
attackability restrictions. This reader is an integration dependency and is
not copied into the image branch. Its existing original ZIP selection remains
unchanged; no new NPC pack or importer is created. It supplies no row position,
row SHA or table SHA, so none is invented. Both source-provider paths exclude an
explicit original `TestNPC:true` illustration and share the same asset resolver.

## Integration269 registration

UI267 publishes the receiver in
[ORIGINAL_UI_NPC_PORTRAIT_ABI.md](https://github.com/zoog136-hash/-/blob/3b9821b10096667449eb34b4aa1fe015095b6c67/docs/ORIGINAL_UI_NPC_PORTRAIT_ABI.md).
Once the real context producer is available, the integration owner calls:

```gdscript
const NpcImages = preload("res://scripts/ui/source523_npc_images.gd")
NpcImages.bind_dialogue(hud, context_provider)
```

This registers through the existing
`hud.bind_original_npc_dialogue_portrait(context_provider, image_provider)`.
The default image callback uses the full original-definition reader. A caller
may explicitly pass `world.patch523_npc_spells.catalog` as the third argument to
retain that pinned catalog's narrower row extent. The wrapper binds this chosen
provider to `dialogue_image(context, source_target, catalog=null)`, leaving the
exact two-argument callback expected by UI267. It does not switch suppliers on
failure or install a substitute context producer
or overwrite a registration at HUD startup. UI267 owns controller replacement,
the current dialogue model, attachment, visibility, input and teardown.

The context producer receives the actual current dialogue's `(npc_id,node_id)`
and must return its authoritative relation:

```text
ok: true
npc_id: same actual dialogue NPC string
node_id: same actual dialogue node string
npc_class_id: positive TYPE_INT mobile NpcClass.ID
source_basis: nonempty texture-free Dictionary from the real producer
```

The existing installed source-NPC dialogues use L1J identities. This image
adapter neither converts those keys nor creates a mapping. A positive integer
alone is insufficient: the image callback still requires its original row from
the selected source provider. Missing reader/archive, context or source-row extent stays
an explicit dependency rather than selecting a nearby/name-matched NPC.

## Original target and returned image

UI267 supplies the existing `Scene.external_scene_slot_contract` for original
`UI/NpcDialogue/NpcDialogue_All.csb`, SHA256
`f27872592f0f7f6b74b81308bc64f98f4bc337beff60c030f4f1ac060aed4ccf`,
Sprite4912. The callback uses its actual selected UI manifest pin and exact
target identity. It does not reconstruct widget geometry or parent transforms.

The accepted result echoes the exact `npc_class_id`,
`role: NpcClass.IllustAssetID`, `route: source523_images` and
`status: original_linked`, with the existing original Texture2D, nonempty pixel
provenance, `original_bytes_unchanged: true` and original loader `source_status`.
The source NPC relation and current dialogue/target evidence are retained.
AnimatedTexture and CSB are not converted into a static portrait, and no
`source_scene_descriptor`, root-registration flag or repeat policy is supplied.

The v14 composition explicitly includes the externally supplied Sprite4912.
Its original source upload path accepts the real pixels before showing that
node. Earlier text/button-only scopes cannot display this portrait; current
UI267 receiver code and the appropriate selected original composition are
integration inputs, not files copied into this image branch. The image callback
creates no source pixels or fallback from the editor preview.

Registration success is not texture assignment or observed game display.
The authoritative dialogue/mobile-ID producer remains integration269's pending
input. No new tests, game execution, rendering, CI, source-byte audits or uploads
were performed for these changes. Existing packs, user selections and saves
remain preserved.
