# Separate private Sprite update candidate

The two recovered-original deltas are local candidates. Neither is part of the
frozen manual resource inventory, phone installation, or a public resource delivery.
Do not unzip them over the installed project: its old inventory would no longer
describe the selected bank. No runtime configuration is changed by this feature.

`data/source523_sprite_update_chain_v1.json` pins the complete ordered chain:
`cf2677b3 → 26c4f3db → c730e4e6`, both archive hashes, contract hashes, declared
compressed/uncompressed sizes and exact member counts. Never skip its first step
when starting from the phone's cf2677b3 bank. Those archive manifests remain
unchanged. The separate final adoption manifest is 31,599,142 bytes, pin
`7a600c3fda086c238ae01b5ad8f7f112893e1d64021fa16b5b4d310bcfe75543`,
below the unchanged 33,554,432-byte production manifest limit.

Actual plan preparation found 97 added raw descriptors with an acquisition-log
stage instead of the runtime's closed `received_not_additionally_validated`
stage. Their null SHA is intentionally unknown, not an invalid resource itself:
runtime uses the existing exact CRC/current523 source identity path. The new
manifest normalizes only that stage and preserves its old wording in
`source_acquisition_stage`. It retains every source identity, CRC, size and null
SHA. Source graphs for 819 of the 821 added action records refer to these members;
this identifies the affected metadata scope, not observed gameplay.

The received-bank writer now emits the runtime stage directly and preserves the
acquisition stage separately. No loader identity or integrity guard is relaxed.

`tools/lineagem_original/prepare_current523_sprite_update.py` consumes the two
private ZIPs and their exact contracts in that order, an exact base manifest and
the existing private source-bank config. It prepares a new private adoption plan;
it does not extract, install, select settings, access the network or run Godot.
It rejects incomplete chains, changed hashes, extra/duplicate/unsafe paths,
encrypted/symlink entries, oversized inputs and changes to existing source
identities, action records, domains or manifest policies. Every added raw/action
payload must match the target manifest and its individual transport SHA receipt.
For an existing received descriptor with null source SHA, its exact source
identity and CRC must also match. Transport SHA does not invent a source SHA.

Future use, after the separate delivery/receiver is authorized:

```sh
python3 tools/lineagem_original/prepare_current523_sprite_update.py \
  --base-manifest /private/old-bank/manifest.json \
  --source-config /private/old-source-bank.json \
  --contract /private/first-delta-contract.json \
  --archive /private/first-delta.zip \
  --contract /private/second-delta-contract.json \
  --archive /private/second-delta.zip \
  --output-plan /private/new-adoption-plan.json
```

The receiver must verify all base payloads, preserve the old bank/config and
create a separate candidate directory. Stage exact additions and combined proof,
then atomically publish the separate corrected adoption manifest last; do not
select either intermediate archive manifest. Create a new complete inventory for
that candidate; do not edit or reuse the frozen v30 manual inventory as its proof.
Prepare a separate config retaining the original tables/whitelist pins. Selecting
it is a distinct approved adoption action. Rollback means selecting the preserved
old config/bank, never attempting to reverse-overlay files. A failed preparation
does not switch anything; retain incomplete candidates for explicit handling.

Defined scope: 125 + 57 distinct new raw members and 455 + 366 distinct source
action records across 41 actors versus cf2677b3. Of the 182 same-name identity
candidates, 83 now have evidence, 75 participate in these action closures and 8
still need dependencies. Another 107 previously held members become usable.
The 182 added raw members and the 182 candidate names are different sets.
Two members use an existing whole-DAT current523-match receipt; the other newly
identified members retain the derived retained508 evidence level. Original
files_info.523 was not newly received. No action ID is assigned a new gameplay
role by these totals. Potions, ambiguous spell stages, emoticons and sound are
outside the continuation scope.

The preparation operation ran on the two real private archives and emitted a
private plan and separate corrected manifest. No resources were extracted or
selected, and no tests, game/compile/render/CI were run. Local bank registration, a packaged ZIP,
an adoption plan, runtime selection and observed gameplay remain separate states.
