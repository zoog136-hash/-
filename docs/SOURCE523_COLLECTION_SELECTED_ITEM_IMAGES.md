# Selected physical collection equipment

The existing equipment collection candidate list already displayed original
item icons. Its registration action and final consume confirmation now receive
the exact selected physical equipment's image through the same admitted
`source523_image_assets.describe_item` provider.

`CollectionCandidates.item_selected` supplies the actual index in the existing
complete candidate sequence. The existing `RegisterCollectionItem` button is
cleared before each update. The image adapter re-reads the physical instance
and requires its record's explicit nonempty sourceId to equal the candidate's
source_id, plus the existing provider's recognized identity and original pack
checks. A legacy runtime name-only correspondence does not establish image
identity. Missing, changed or unadmitted records keep an empty button icon.
Evidence retains selected_instance_id, selected_source_id and the original
provider provenance/status without storing the texture in evidence.

The final shared confirmation uses the selected physical candidate captured by
the existing register request. Its exact callback must own that dialog before
its confirm_button is changed. The adapter does not choose a first candidate,
change collection slots or requirements, alter the request/revision, register
equipment, change quantities or touch inventory/save ownership. Existing view
rebuilds discard the old button/list; an old list callback cannot update a freed
or queued button. No node or layout was added.

Two existing receiver call paths are wired; this is not two observed renders
or a completed source usage denominator. No tests, compilation, game, rendering,
CI, resource upload, phone update or merge was run. Original pixels, installed
v30/62ZIP/index/source bank and all separate candidates are preserved.
