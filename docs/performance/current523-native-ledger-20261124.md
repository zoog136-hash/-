# Native use-ledger: reuse an exact active match without copying

The original 523 ItemClass, bless identity, and MaxStackAmount governed item
identity and limits. The local ownership/use journal is a TWILIGHT save
contract, not an observed original client save protocol. In the 523.837
Android capture, native-stack validation took 278 ms inside one 833 ms
pickup. That inclusive time is not attributable solely to row comparison.

Previously comparison-only callers built a full detached receipt tree just
to discard it after equality. Now they compare field count, original
types/values and the exact nested receipt against the same expected fields.
Stored and exported rows still detach their receipt. In full validation, a
ledger row matched to an already proven active receipt for the same physical
ID does not recursively reprove that receipt. Ledger-only and non-native
rows still enter independent provenance checks. All quantity, duplicate
ownership, merge, partition, discard and writer gates are unchanged. No
persisted cache, save format, gameplay ordering or background worker change.

The core item-stacking fixture compares the production matcher with the old
Dictionary equality, including extra/missing keys, int/float distinctions,
nested changes, split/discard fields and false active/ledger-only matches.
The active control-flow fixture injects the first proof result explicitly;
it does not claim to emulate the original definition pack.

Optional Godot 4.7.2 microbenchmark:
`TWILIGHT_BENCH_LEDGER_COMPARE=1 godot --headless --path . -s tests/item_stacking523_test.gd`.
512 synthetic nested rows, median across nine trials (12 batches each):
5.55 ms → 2.42 ms for comparison alone. This excludes full validation, the
actual original pack, device latency and disk writes.
