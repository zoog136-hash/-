# Remaining-system integration

Base: main after the verified PR262 closeout in #268. This Draft consolidates the non-UI/map/Sprite work; sound is excluded. It is not authorized as a bulk main merge.

## Included in the initial checkpoint

The exact public PR264 backend from checkpoint8488ada8: seven unconfirmed523 source/domain/runtime/UI-service modules, the labelled host policy, and five focused tests. This is13 existing code/data/test paths. Five isolated fixture suites passed336 checks. The original-source portions of those suites were not run in this initial checkpoint. Main activation and original UI node/pixel wiring are still pending; module presence is not completed gameplay.

## Inclusion still pending

- PR231: latest unpublished UI-boundary changes and shared card/slot/inventory/atomic-save hooks.
- PR248: latest unpublished form removal, card-selection save ownership and conditional effects.
- PR264: shared Main, skill and blessing hooks plus remaining integration tests.
- PR265: latest unpublished processing, native equipment result adoption, inventory/physical quantity synchronization and source constraints.
- PR218: remaining public monster code and six local-file comparison decisions. Newer Main protections must survive; private map-region source input stays private and with the map owner.
- PR228: per-file supersession audit for the six explicitly labelled host examples and older quest service; no overwrite of original523 quests.
- Honing, item-icon adapter, weapon helper and native-equipment effect handoffs: latest received code is preserved, but inclusion and combined execution are not yet complete.

The combined local candidate has undergone conflict resolution and parsing; that is not a claim that every candidate path is included in this public Draft. Further commits must identify actual included paths and validation. Original PRs remain open until their latest unique changes are accounted for.

## Boundaries and remaining work

PR267 owns original UI, PR222 owns maps, and the new dedicated Sprite task owns full SP2 connection. This Draft preserves their existing calling contracts and does not copy their renderers or implement Sprite completion. It creates no substitute UI or artwork.

The merged quest milestone has3621 definitions and58 of146 initial ItemClasses with at least one bounded path.88 ItemClasses and four learned-spell effect boundaries remain; they are not erased by PR262 closeout. Connect actual item ownership to use/equip, partial quantity, effects and one confirmed receipt/save transaction. Keep Test/server/date restrictions and explicit unknown source semantics.

Original archives, packs, pixels, saves, private delivery references and runtime identifiers are excluded from public changes. Received private handoffs and original working states remain preserved. CI is not run; commits use [skip ci].
