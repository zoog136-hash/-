# Private definition consumption audit

`audit_content_consumption523.py` inventories every direct `content/*.json`
table in a supplied private ZIP. It validates every member's CRC, rejects
ambiguous member names and JSON keys, and retains table metadata rather than
source rows. It does not run the game, change a save, install content, or certify
that a semantic claim is true.

Keep the input ZIP, evidence ledger, runtime traces, and generated report outside
all Git checkouts. The tool refuses a report inside a checkout or one that would
overwrite an input, including hardlink aliases. Public code may contain the tool
and synthetic tests; original definition tables and audit output stay private.

Example (replace paths and the exact original hash):

```sh
python3 tools/audit_content_consumption523.py \
  --source /private/original.zip --repo . \
  --expected-sha256 <64-character-original-SHA256> --expect-tables 1065 \
  --verify-metadata --ledger /private/reviewed-evidence.json \
  --output /private/consumption-audit.json
```

The optional metadata check compares available `index.json`,
`table_inventory_1065.csv`, and `summary.json` counts/hashes against independently
read definitions. Archive bytes, compressed member bytes, uncompressed JSON
bytes, and generated cache bytes are distinct quantities.

The ledger has `schema_version: 1`, `source_sha256`, and a `records` array. Each
record names one original `table`, `feature`, `owner`, `reason`, `remaining`, and
`status`: `used`, `partial`, `main_unconnected`, `other_owner`, `excluded`, `empty`,
or `unresolved`. An omitted nonempty table remains unresolved; an omitted empty
table remains empty. Static code candidates cannot change either state.

`pipeline` records lists of `{path, line?, symbol?}` for `parser`, `compiler`,
`runtime_consumer`, `caller`, and `storage`. Paths must exist inside the reviewed
checkout. Used/partial records require parser, runtime consumer, and caller.
For an unmerged owner, keep the status `other_owner` and put the exact reviewed
PR/commit in evidence; do not claim its files exist on main.

`evidence` entries carry `id`, `kind`, `reference`, and `scope`. Stages
`static_reference`, `source_review`, `parse`, `compile`, `install`, `fixture`, and
`inspection_render` are separate from `gameplay`. Reviewed exclusion evidence
does not reduce either denominator.

A `gameplay` entry additionally needs `origin: normal_gameplay`, `run_id`, the
exact table `source_json_sha256`, and `artifact: {path, sha256}`. That artifact
must be a retained private JSON runtime trace with:

- `schema_version: 1`, `kind: gameplay_consumption_trace`,
  `origin: normal_gameplay`, `fixture: false`, `inspection_render: false`;
- matching `source_sha256`, `source_json_sha256`, `table`, and `run_id`;
- `caller: {path, symbol?}` matching a reviewed game caller;
- `observations` containing `{row_indices: [0, ...], fields: ["ID", ...]}`.

Row indices refer to the original source array. Source ID alone is insufficient:
the supplied originals include repeated IDs. Fields must exist on each observed
row. The report retains aggregate coverage and artifact SHA, not trace paths or
source values. A ledger's `coverage: {rows, fields, evidence_id}` must match the
retained trace. `used` requires all source rows and all fields of each row plus
`scope: all_rows_all_fields`; merely reading an entire JSON cannot satisfy this
semantic evidence contract. Human review must verify that the trace originates
from ordinary gameplay and that observations mean actual feature consumption.

Both denominators remain fixed, including excluded and empty tables. A partial
table never contributes its entire JSON size to the full-use numerator. The
reported full-table byte fraction attributes original JSON sizes only to fully
covered tables; exact consumed byte extents for partial fields remain unknown.
No ledger defaults to zero established use, rather than guessing from strings,
registration, cached parsing, fixture calls, or inspection renders.

Synthetic boundary tests:

```sh
python3 -m unittest discover -s tests -p test_audit_content_consumption523.py -v
```
