# Actual result-owner phase pixel API

Compatible with UI286 a2f73b12229a4b8cc7a87ae7e24542cdef0bc7f5.
This is an on-demand image-provider bridge, not an assigned/rendered result UI.

The existing card instance exports `original_result_card_image()`. It calls
`source523_result_card_images.describe(self)`, which queries that same instance's
UI-owned `original_result_card_contract()`. Current canonical sourceId/raw card
ID/GradeID must agree. Only the actual front/back phase selects a descriptor;
transition returns unavailable and leaves existing rolling candidates intact.
Missing Myth/Sole/event variants keep the UI owner's explicit unavailable
result. No rank/first-grade alias, alternate card or card-back fallback is used.

The selected exact member/source SHA/manifest pin, literal case-sensitive
FileData and its already opened source_pack supply `pack.texture(ref,true)`.
The returned descriptor retains original file size/SHA, node identity, complete
authored widget/parent chain and original clip declarations without interpreting
them as seconds, loops or original-client call ordering. It reports
original_phase_pixels_resolved with pixels_assigned=false and
runtime_target_registered=false. Decoder/PMA behavior remains in the existing
source_pack; no original bytes, source atlas, renderer or UI node is fabricated.

The remaining result receiver is specific: current Face._art fits the portrait
to its host rectangle and the back path stretches one Texture2D to the entire
Face. Neither operation expresses the newly supplied original Sprite/ancestor
transforms. Applying the new texture to those fields would lose the original
registration. An exact source-parent-coordinate to this actual Face registration
or an existing original Sprite receiver is still required before assignment.
This bridge therefore does not silently replace Face.back/artwork or draw an
invented center/fit. The UI metadata owner and image renderer owner must retain
that boundary when establishing the actual receiver.

Fusion-stage background remains separately unassigned: its two original
ImageView layers require tint, 9-slice, ordering and parent registration. Inner
backing11140 is not the whole-screen background and is never substituted.

SpecialDungeon's new actual selected-owner API is consumed by
`source523_dungeon_images.describe_selected_special(view)`. It passes the exact
actual_selected_entry unchanged through the existing row/type/path/pixel
provider and checks the echoed special_dungeon_id/entrance_asset_id. It retains
the UI owner's original target descriptor, selected index and unregistered
state; it creates no target or invocation during selection/closing. UI still
owns Panel392 to ListView_Daily2560 insertion and ImageView28700's static-asset
receiver. Source Sprite-only external slots are not treated as ImageViews.

Both compatible owners and an approved pack containing these exact scopes are
dependencies. UI v36 is a local-only candidate, not downloaded/applied here;
phone v30/62ZIP/index/bank and every other candidate remain unchanged. No
resource upload, test, compile, game, render, CI or merge was performed.
The added provider/owner queries are unexecuted/unverified, not completed screen
or observed-pixel claims. Quest still awaits the owner's complete selected
mixed-reward presentation/overflow model; excluded work targets stay excluded.
