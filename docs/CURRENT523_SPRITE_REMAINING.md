# Current523 Sprite continuation after PR278

PR278 merged as `5db920332f9298b4fc1f70713dde11740c91a7d2`.
Its source HEAD `b3d2664c7b670a1aa1f3aa0dc34ef209fd3bba32` has the same
tree as that main commit: `9256439445cbbcc3488047cf11f69b7543d372dc`.
This continuation preserves the existing callers, ownership, transactions,
save namespaces, exclusions and source-only admission. It does not deliver
additional original files or claim original playback has been observed.

## Existing checkpoint

The preserved private bank contains 34,357 registered original members;
the priority scope is separately 34,031 of 45,990. Class primary-action
requests are 114 connected and 43 pending out of 157. These are constructor
and registry results, not proof of actual game playback. Originals, archives,
settings and saves remain private and must not enter this PR.

## Exact outstanding inputs

The following twelve physically missing members retain their existing
size/CRC/container receipts in the private input handoff:

- `Sprite/23491-{32,48,56,64,72,80}.sp2`
- `Sprite/23492-{32,48,56,64,72,80}.sp2`

These 28 Class member references still lack exact source identity evidence:

- `Sprite/6262-336.sp2`
- `Sprite/25007-{0,24,32}.sp2`
- `Sprite/25704-{16,24,32}.sp2`, `Sprite/25705-{16,24,32}.sp2`
- `Sprite/26215-{0,8,32}.sp2`, `Sprite/26216-{0,8,32}.sp2`
- `Sprite/27935-{0,8,16}.sp2`, `Sprite/27936-{0,8,16}.sp2`
- `Sprite/28397-{0,8,32}.sp2`, `Sprite/28398-{0,8,32}.sp2`

Names alone do not establish physical absence, version, dummy status or
current523 admission. Do not replace missing identity with a numeric estimate.
The historical blocked955 handoff contained 1,093 references, only thirteen
with physical identity fields; it was not 1,093 proven missing original files.
After the Sprite76 receipt, 1,089 references remained (twelve with physical
identity and 1,077 without). Preserve the corrected private ledger.

The earlier remote07/08 scope also retains physical dependencies
`Sprite/21713-0.sp2` and `Sprite/24503-0.sp2`, and eight unresolved
`22485-{0,8,32,40,48,56,64,72}` identity records. Do not merge these scope
counts with Class action requests or count a metadata match as a receipt.

## Remaining consumer contracts

| Existing consumer | Required input before further activation |
| --- | --- |
| HP item233 consume effect | Original sprite16007 and its exact declared action |
| Polymorph presentation | ConstantData31131 names sprite6082; exact original action/domain remains unresolved |
| Invoke type34 and ambiguous spell stages | Complete original option/spell row and exact declared stage/action agreement |
| Ground item body | Exact ItemClass.SpriteID-to-member/frame relationship and original renderer role; type9 does not authorize an actor action |

Reuse the existing successful-use event once. Preserve
`source_use_context.visual_dispatch_attempted`, cure310 prepare/commit,
and the current ground owner's full original row and physical selection.
An icon, drop effect, same-numbered actor or invented idle/FPS cannot stand
in for the ground body. Missing art remains pending.

For new receipts, use the saved constructor plan and existing registrar,
deduplicate exact member identities, retain original bytes/provenance and
exclusions, then connect only the supported original role through the
existing caller. Do not retry the denied external archive or repeat already
completed source-package searches/downloads.

## Validation boundary

The cf2677 bank manifest is 31,361,924 bytes. Its aggregate manifest readers
(reference bank, effect selection and awakening selection) require the finite
32MiB `MAX_MANIFEST_JSON` allowance. Individual action JSON retains its 16MiB
`MAX_JSON` limit. Both still require their configured SHA256 before parsing;
source identity, paths, raw member/decoder limits and cache budgets are unchanged.
The installer must require all three manifest readers to include this code
before selecting the cf2677 bank. This changes no bytes in the approved 19-file
distribution, and does not constitute an installation or runtime test.

At the PR278 source HEAD, the resource check and 47 skill policy checks
passed. Core run42050340676 failed because the isolated Actions runner lacked
the private original definition ZIP; this is separate from missing Sprite
members in the continuation above. The existing reader requires exactly
25,031,173 bytes, SHA256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`,
via `TWILIGHT_PATCH523_CONTENT` or an existing original ZIP receiver.

No approved private Actions delivery provider has been established. Do not
publish the archive, create credentials, weaken its hash guard, or replace
the actual Main save gate with a narrower fixture. This new PR has no CI
authorization inherited from PR278 and no new local tests, game execution,
compilation or rendering have been performed.
