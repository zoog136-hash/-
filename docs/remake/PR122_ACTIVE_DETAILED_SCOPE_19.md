# PR122 active detailed scope — 19 actors

The active production queue is `docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json`.

- Original historical scope: 31 actors = 2 unique + 29 mythic.
- Active scope after user-directed mythic gender consolidation: **19 actors = 2 unique + 17 mythic**.
- Approved detailed actors preserved: **2/19** (`transform:393`, `transform:267`).
- Pending detailed actors: **17/19**.
- The 12 excluded mythic IDs: `transform:131`, `transform:410`, `transform:132`, `transform:134`, `transform:136`, `transform:138`, `transform:140`, `transform:142`, `transform:161`, `transform:345`, `transform:258`, `transform:283`.
- Exclusion means **not an active gameplay character or animation production target**, not deletion of original art or historical evidence.
- Old `detailed_total=31` in staging archives and older resume text is a historical counter, NOT the active target denominator. Never count these 12 as pending. Do not modify massive staging archives to rewrite historical provenance.
- Preserve original sprites, source images, SHA manifests, commit history, and approval certificates. Do not delete source files.
- The gameplay list exclusion implementation lives in `feature/pr122-mythic-single-gender-filter` and is **not yet integrated** into this PR branch. Avoid claiming draw/fusion/collection runtime exclusion until that code is safely integrated and validated.
- The latest animation death-direction policy remains separate: preserve existing authored death directions and author only one new S direction when required.

Do not restart or re-author excluded subjects. All production and progress reports use the current 19-row queue, while historical staging evidence may still contain 31.
