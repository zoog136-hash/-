# Current523 source-cell context reaches existing death rules

UNEXECUTED / UNVERIFIED PR285 continuation. No tests, compilation, game,
rendering or CI were run. Phone, resource bank, v30,62ZIP/index, source files,
configuration and existing saves were not modified.

The existing death owner already consumes exact LandAttribute/territory rows
for kinds3,4,494,878,1122, with its existing loss/recovery policies. It reads
Land identity from field data and source position only through world_to_source.
Generic current523 fields provide source_land_id, but do not implement that
legacy projection interface. Their source position therefore remained INF;
land-wide rows could apply while every territorial row was skipped.

The map-owned death_source_context(point) now supplies the selected generic M
Land and integer source cell through the existing source coordinate basis. It
requires a loaded field, finite point, supplied bounds and an original member
SHA from source_cell_info. Inclusive territory comparisons use the actual cell
index, consistently with existing generic source entry-condition comparisons;
source canvas pixels or legacy grids are not substituted. This is the existing
OWN source-cell projection, not a claim of native actor-foot equivalence.

The death runtime prioritizes that purpose-specific context only for the exact
generic source marker and matching declared Land. All existing death attribute
selection, amount formulas, exemptions, item custody, saved pending transaction,
restoration costs and writer remain the existing owner's implementation. No
second attribute catalog or death penalty engine is added. Non-generic fields
retain their previous coordinate path.

A new optional source_location annotation in newly captured death receipts
retains exact Land/AssetPath, source cell, source manifest, original member/SHA
and coordinate-policy identity. Existing map/cause/IDs/receipt fields and save
version are unchanged; old receipts are not rewritten or reinterpreted. The
annotation grants no travel, revival or refund permission on reload.

This connects current source-cell context to the already implemented regional
death consumer. It does not establish native safety zones, new death formulas,
whole-map execution coverage or native source-attribute ordering. Missing point
provenance retains the prior unknown-position behavior; no cell is fabricated.
