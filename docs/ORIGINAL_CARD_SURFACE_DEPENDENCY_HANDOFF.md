# Original-only card presentation dependency handoff

Local continuation based on main `52c8f4be5c739a6cf258dce72c9f886e712dfa7b`.
No tests, compilation, installation, game, render or CI were run. No original
assets, settings, saves, private source manifests or Drive identifiers are added
to Git. This is a consumer-code candidate, not a completed original UI delivery.

## Retained actual input path

Card result and fusion portraits keep the existing
`source_card_presentation.detail(record, acquired, detail_view)` supplier.
It canonicalizes the real card identity through `lineagem_base508.canonical`,
selects the declared IllustrationAssetID/HidedIllustrationAssetID or
DisplayBaseAssetID role, and uses the already selected current image pack.
Its asset/path/type/SHA provenance and dummy exclusions are unchanged.
DisplayScreenAssetID is not repurposed as a portrait, frame or card back.
No old `image_path` or authored demo atlas substitutes for a missing native card.

The draw/fusion services, physical input selection, ownership counts, pity,
confirmation and save calls are not changed. Existing result names and reveal
controls remain. The synthetic five-grade developer showcase has no original
card identities and now reports that requirement instead of painting invented
cards. Retired authored result WAVs are excluded; no original audio is claimed.

## Explicit surface inputs, still pending

`original_card_surfaces.bind(role, member, member_sha256, node_offset, grade_id)`
opens the existing single selected original UI pack. The exact scene must be
included in that selected pack, match its file and scene SHA, and contain one
selected Sprite/ImageView node at the supplied original offset with its literal
fileNameData. Its pixels are read by the existing source_pack.texture provider.
The caller must supply the actual role relationship; this API does not infer it
from a node name, portrait, first scene, grade rank or atlas region.

Required owner handoff:

| Consumer role | Required exact original input |
| --- | --- |
| reveal_back | Card back CSB path/SHA, selected image-node offset and original fileNameData |
| reveal_background | Result screen's actual background CSB/node/role |
| fusion_background | Actual fusion-screen background CSB/node/role |
| awakening_background | Actual awakening-result background CSB/node/role, independently supplied |
| grade_frame | Each authoritative current GradeID to its actual original frame CSB/node/role |

No values for these inputs were supplied to this continuation. The current
selected combined UI contract must be extended by its owner if the required
scenes/pixels are not already in scope. No new pack ID, scene SHA, node offset
or source role is fabricated. Unbound surfaces return
`source_card_surface_original_node_role_pending`; they do not create placeholder
images, re-enable base508's excluded card atlas, or receive arbitrary originals.
The previous painted atlas/frame/backdrop and generated aura are not fetched.
Original portraits and existing textual/input ownership remain independent of
these unresolved decorative roles. Actual display and full-function equivalence
remain unverified, including the missing surface roles and disabled synthetic
developer showcase.

## Owner boundaries and deployment

Read owner checkpoints: PR283 `0d3a1ce832ef955b173e4186334db5d745fc9284`
and PR286 `b8064a7972a4f0d8a0d21eb36b12adf7ae0ec1aa`.
No changed file overlaps either checkpoint's changed-file list. Their unmerged
item, typed inventory, production, warehouse and original-image changes are not
copied, overwritten or claimed integrated.

This local branch must be reviewed and normally integrated into main before a
phone can receive its consumers. Publishing installer PR275 alone does not
apply these files: packed_code reads actual main. No client overlay, automatic
PR merge, direct-main push or protection bypass is implemented.

Other original-only preload blockers remain in project icon, growth art,
option-lightning art, enhancement audio and world/UI presentation audio owners.
This candidate does not claim to supply those original roles. The installer
keeps its fail-closed dependency gate until all required owner changes and
original inputs are actually present.
