# One read for exact verified runtime inputs

In a **cold, synchronous** selection or load, do not open a pinned file once to hash it and then again to read the same content. Verify the byte buffer that the consumer actually parses or decodes. The byte buffer is cleared before invoking the JSON parser; no persistent cache or second full-file buffer is introduced. Each existing input size bound, SHA-256, schema, branch selection and pixel/timing rule remains in force.

Changed: cold raw 523 effect and awakening bank manifests; the pinned 523 raster-effect manifest and each PNG read; cold 523 world-link manifest, Land shard and shared conditions population. Existing warm rechecks, cooked effect paths, worker adoption/validation, record/texture limits, the existing condition-row sharing and raw/legacy fallback order stay unchanged.

## Matched I/O validation

Linux Godot 4.7.2, independent XDG profiles, same generated fixture inputs and production consumer entry points. A local host probe counted completed libc `fread` bytes on known fixture files (not elapsed time or source assets). One-pass data sizes:

| Accepted cold input | Baseline → new full payload passes | Payload bytes |
|---|---:|---:|
| Raw effect bank manifest | 2 → 1 | 342 |
| Awakening bank manifest | 2 → 1 | 342 |
| Raster effect manifest | 2 → 1 | 654 |
| Raster effect PNG | 2 → 1 | 99 |
| World-links manifest | 2 → 1 | 484 |
| Land shard | 2 → 1 | 405 |
| Conditions | 2 → 1 | 783 |

The wrong SHA files (including equal-length mutated text and PNG) stay at one pass and are rejected before use. Short reads and missing declared shard length are refused. The valid fixtures cover Korean text with a UTF-8 BOM and CRLF, equivalent to both existing Godot text APIs. The first PNG frame compares exact decoded bytes, source origin, duration and decoded-budget accounting. Current edited paths and the unchanged baseline both pass the same correctness test. This does **not** estimate Android frame time or show that these inputs were the cause of a reported hitch.

## Scan and deliberate exclusions

Reviewed candidates from 345 matching file-open/get-bytes/get-text/hash/image/ZIP code lines in animation (40), boot (38), maps (133), monsters (50), NPC (1) and resources (83). This is a call-site triage count, not 345 duplicates or a trace of all reachable file reads. Original UI is outside this branch. Kept streaming ZIP verification and later member reads, pre-/post-write durability checks, warm file-change guards and exact source provenance/stamp checks. Skipped update readers and save migration because their verification boundaries are different. Historical map/pack readers not selected by the current source mode were not substituted for current paths. No changes to the actor proof/pose, NPC closure, or native ownership commits under separate review.

Two structural duplicates remain intentionally untouched here: the global bake reader and SP2 manifest index. Both have their own code identity in existing device-cache keys; changing those files globally can force a broad bake rebuild. Address those only with explicit cache-key compatibility validation, or when that rebuild is otherwise required. No code in those loaders was modified.
