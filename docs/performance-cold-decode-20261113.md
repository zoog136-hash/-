# Cold SP2 decoding follow-up (2026-11-13)

Base: main `3ea41de9dee65cf3cbe2c65c9f68e6d3cbaa5b45`. Independent of unmerged #442; that branch and its APK are preserved. This change does not include #442's CRC, optional-role or population-budget changes. No resource, visual-policy, gameplay, save, exchange or character-creation changes.

## Problem and change

A population loop can check its 4ms budget only after `monster.setup()` returns. One cold `configure_admitted → _configure_selected_roles → load_bank → _member → PARSE_CACHE.parse → DECODER.parse` remains synchronous. The historical phone report (523.384, 1,303 previous-run hitches, one maximum 12,749ms frame with a 12,432ms population section) does not identify which child operation consumed that time. This work does not claim to reproduce or eliminate it.

The decoder used `reader.take(count)`, an intermediate run array and `indices.append_array(samples)` for every command. The block's sample bytes are contiguous. It now advances the same reader with the same per-command truncation check, copies that byte range once per block, and fills a preallocated run buffer. Zero counts, row/horizontal steps, reference order, first bad palette sample, cursor/error and parsed output are unchanged. No resources/pixels/frames are skipped.

For an encoded block the run buffer is at most 255 × 4 × 4 = 4,080 bytes before trimming zero-count runs. This removes temporary per-command buffers; it is not a measured RSS reduction or a whole-game memory cap. Parsed data still belongs to the existing shared lease service; no new cache or retained input is introduced.

New inclusive per-frame details: `sp2.decoder_total`, `decoder_brotli`, `decoder_candidate`, `decoder_metadata`, `decoder_samples`, `decoder_geometry`, `decoder_bounds` (all use the `sp2.` prefix). Counters record input/body bytes, commands, blocks, references, samples and success/rejection. The total/candidate wrapper includes failures; phase rows describe completed phases/groups, so a failing phase may be present only in its parent total. Group phase call count is not monster count. Detail rows are `[sum_us,calls,max_call_us]` internally and milliseconds in saved hitch JSON. Nested rows must not be added together. Shared/disk hits bypass the decoder, so their absence is meaningful only alongside existing `sp2.disk_hit` and asset statistics.

Changing the decoder source changes the existing disk-parse code key. Previously cached device entries are rebuilt on their next use. First entry after update can therefore be colder; old entries follow the existing cache pruning policy. The parse schema, limits and integrity policy are unchanged.

## Observations, not time guarantees

Initial alternating direct-parser probes (11 samples, official Godot 4.7.2 Linux headless; synthetic FE; no shared/disk cache) gave:

| Synthetic member | Previous median | New median |
| --- | ---: | ---: |
| 833,335 bytes / 24,800 commands | 38.486ms | 28.080ms |
| 1,922,235 bytes / 57,120 commands | 92.619ms | 69.671ms |
| 135,621 bytes / four-entry palette | 18.670ms | 17.501ms |

A separate compressed stress case expands 1,230 bytes into 17,203,875 bytes, with 520,200 commands and 16,126,200 samples. Five alternating observations gave 630.049ms → 432.197ms. This probe overlapped core validation. One new sample recorded ~17ms Brotli, ~172ms metadata and ~243ms sample processing; these are one observation's inclusive details, not components of the median. This deliberately repetitive generated input is not a real monster. It demonstrates why a small compressed file and existing byte/count limits cannot guarantee a 4ms execution time.

The existing bounds remain 2MiB input, 32MiB body, 65,536 blocks, 131,072 references, 1,048,576 commands and 16,777,216 samples. They bound data/work dimensions, not elapsed time. Multiple members, ambiguous palette candidates, JSON/tracks, pixel rendering and engine upload add work beyond one decoder call.

A diagnostic reference-preview probe (five roles × 32 tokens × eight directions; one 1,666,155-byte generated body, two tiny generated members) produced identical tracks in cold/shared-warm/disk-warm states. Cold configure was 268.158ms, including 80.580ms parse-cache operations and 59.196ms fresh decoding; shared-warm configure was 145.089ms with no decoder calls. Initial frame work was 3.041ms cold / 0.893ms shared-warm. These single observations overlapped core checks and exclude actual NPC admission, pool/physics, original 40MB manifest bake and actual GPU upload. They show that action/track preparation also remains after raw parse caching; they do not identify the phone's 12.432s cause.

Machine-readable observations are in `performance-cold-decode-20261113-evidence.json`. Initial direct-parse fingerprints there hash the hex representation of serialized output; the reusable benchmark hashes serialized bytes directly. Comparisons in each probe use the same representation and require equality.

## Source comparison

The already materialized original Windows analysis ZIP (`ee7fe088f39fd3d317631c66bddf4d436d55d08046081e267f934c4e3802716c`) and its P10 `SPRITE_CACHE_LIFETIME_REPORT_KO.md` describe RawSpriteFile hit at `01C74AB0` returning a strong reference after LRU movement without another reader/parser call; SpriteAsset `01C716E0` returns immediately when Graphics exists. Its 64MiB raw LRU is not a full memory cap. Current TWILIGHT shared/disk parse hits remain intact. This PR's contiguous-copy implementation is an independent Godot optimization, not a recovered native algorithm.

The supplied Android static analysis describes request/worker/completion-cache-check separation (`0x5543594 → 0x554389c → 0x5543c44`). XP Hero's verified IL2CPP metadata declares pool, shared-cache, async request and bundle-release structures, but does not prove their scheduling or function bodies. The mod APK remains static-only and was not executed. Neither source supplies performance measurements for this PR.

Moving the current bank wholesale to a worker would race shared manifest/member/cache/lease state and mix Node/texture operations with data preparation. A later staged/worker design needs immutable request data, map/slot generations, exact pin revalidation and a single main-thread admission/commit. `monster.setup()` cannot safely yield halfway through actor registration. No unverified asynchronous ownership rewrite is introduced here.

## Verification and limits

- 38,916 deterministic comparisons with the previous block algorithm: full result/block bytes, cursor/error, every truncated prefix, varied palette/command patterns, maximum 255-command block and empty runs. No timing assertion.
- Existing full-parser output fingerprint, cache corruption, changed-member/pin and exact pixel-renderer checks remain registered in core CI.
- Stage builder's 14 Python tests passed. Full runtime/save/resource validation is recorded in the PR after completion.
- Required old preflight command `tools/check_resource_integrity.py --root .` cannot run: script is absent in current main. Actual `check_no_legacy_resources.py --root .` passed (`tracked=20`). This is not original-art delivery; no original art was added.
- No actual Android device, device logcat, original failing SP2, GPU timing or RSS measurement. No crash/shutdown investigation or #442 merge.

Reproduce direct parsing in an isolated XDG profile with official 4.7.2:

```sh
git show 3ea41de9dee65cf3cbe2c65c9f68e6d3cbaa5b45:scripts/resources/current523_sp2_decoder.gd > /tmp/baseline_decoder.gd
# Optional generated Brotli stress file; Python brotli is needed only here.
python3 tools/benchmarks/make_sp2_cold_fixture.py --output /tmp/synthetic-cold.sp2
godot --headless --path . --script res://tools/benchmarks/benchmark_sp2_cold_decode.gd -- --baseline-decoder=/tmp/baseline_decoder.gd --compressed=/tmp/synthetic-cold.sp2 --output=/tmp/cold-decode.json
godot --headless --path . --script res://tools/benchmarks/benchmark_sp2_cold_bank.gd -- --output=/tmp/cold-bank.json
```
