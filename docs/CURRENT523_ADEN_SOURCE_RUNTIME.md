# Current523 Aden source intake

Base: main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. This change registers
current cumulative523 LineageM Land4 (`AssetPath=Aden/`) originals through the
actual Main world API. It is the source-loading stage of mainland integration.
It does not implement current523 map rendering, movement, collision or travel.

## Runtime contract

`world.open_current523_aden_sources(private_pack_root)` accepts an external
`aden523.json` manifest with exactly677 literal source members. The canonical
member/size/SHA256 inventory is pinned to
`e236f89849bcc6fc618feb13046c077adff59f909ad376b408c9b24fafc3288c`.
All source paths must exist with the declared size. Every consumed file and its
seven contiguous sections are hashed and independently scanned in Godot.

`world.current523_aden_source_members()` lists registered literal members;
`world.read_current523_aden_source("Map/Aden/800a8000.s32")` returns raw floor,
cover, attribute, object, opacity, declaration and opaque tail section bytes.
Count headers remain in their sections. No storage index becomes a world cell.
`world.close_current523_aden_sources()` releases the registry. Failed replacement
preserves an already accepted registry. These calls do not select a live field,
move the player, spend currency, activate a portal or write a save.

The current523 changed member `800a8000.s32` is210523bytes, SHA256
`ab3b89eb4a9be8b2b5448c60bcf4c7ac6d4164ada21d85f88ffc7f566e9b2b96`.
The inventory excludes its older508 version and the distinct world-siege root
`Map/13225/`. All677 originals are retained, including `800f7ff3e.s32`, without
truncating its name or inventing an origin. Coordinates, projection, movement,
collision, height, regions, zones, safety/combat and drawing order stay UNKNOWN.

## Build the separate private pack

Materialize the existing current523 Aden evidence archive and the M-only scope
archive into a private directory. Preserve their original source bytes. Run:

```sh
python3 tools/map_restore/build_current523_aden_pack.py \
  --source-dir /private/aden-evidence/selected_originals \
  --summary /private/aden-evidence/results/all_Aden_map_structure_summary.json \
  --land-declaration /private/m-only/results/M_only_Land4_assetpath_and_explicit_zone_declarations.json \
  --output /private/aden523-pack
```

The builder requires the exact current677-member source inventory, checks CRC
when present, verifies section offsets/hashes and byte-exact reserialization,
then independently rereads the staged pack before atomic directory publication.
It rejects output inside a Git repository and refuses to replace an existing
output. Original bytes and generated packs must remain separate from this PR.

## Validation and remaining work

- Python real-source suite:17tests passed, including all677 original roundtrips,
  private-pack construction, failed-stage cleanup and corrupted-copy rejection.
- Final Python guard suite:19tests,18passed and1real-source test skipped; the
  earlier real677 check remains separate evidence.
- Godot4.7.2 raw-source test consumed all677 members (78146066bytes), checked
  exact reassembly and malformed/stale/foreign manifests:1393checks passed.
- Actual Main current523 source API:16checks passed, including the changed523
  member, nonstandard filename, failed replacement and unchanged live field/save.
- Existing committed resource integrity:723atlases,41442frames,233420026bytes.
- Core gate passed: actual Main/current field and save preservation35checks;
  raw malformed-input unit20checks; identical-save and deferred-save regressions
  passed. A pass for Main's existing default field is not current523 map equivalence.

The local private manifest is1392476bytes, SHA256
`2ae38fe09eba75653e4db476b70a9e3168cba18d8051cf302b177a1a7634e90a`.
Its status is PRIVATE_LOCAL_ONLY; durable delivery of this generated pack is not
established. Existing Library source archives remain the reconstruction inputs.
No original art delivery ledger status is upgraded.

The historical `check_resource_integrity.py --source-dir` ledger still requires
`a1.zip`, which is absent here. The actual supplied523 archives were separately
verified by SHA256 and full ZIP CRC. This is not a pass for the old six-archive
ledger. Additional coordinate-tool evidence download hit HTTP401; no downloaded
bytes or runtime coordinate claims came from that failed transfer.

Rendering, M-specific compositing, valid source-to-world placement, movement-bit
meaning, actor foreground occlusion and actual region travel remain follow-up
work. PC tools can support investigation but their format support and diagnostic
images do not establish any of these engine semantics. No other PR or the older
catalog-main-validation compatibility branch is merged by this change.
