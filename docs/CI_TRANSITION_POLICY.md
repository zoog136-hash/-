# Source transition validation — approved 2026-11-02

The merge gate during the source replacement is:

1. **Core runtime, save preservation and resource paths**: Python syntax; Godot
   import and real Main startup; the current source-map field/renderer; durable
   saves and historical-to-current migration; physical equipment, collection
   progress, HP/MP/gold and exact boss cooldown preservation; rejection without
   overwriting a save when a required map pack is missing.
2. **Verify committed assets, manifest SHA, and delivery status**: the existing
   committed-resource integrity check, unchanged.

Every core run uses its exact Git inputs and isolated temporary user data. It
imports a production resource graph rather than all staging/evidence images.
The actual committed current Aden pack is required: missing input is a failure,
not a skip. Parsing, execution and resource errors remain failures even if the
engine exits zero. Source packs, saves and historical definitions are preserved.

The existing presentation, full integration, source-contract, legacy map,
recovery and cache audits retain their commands and assertions under manual
`workflow_dispatch`. Run them explicitly after integration or for a relevant
change. An old NativePngField-specific audit does not describe the replacement
SourceMap field; current map and save compatibility is tested in the core gate.
This separation does not establish visual equivalence or original-art delivery.

No workflow disables repository branch protection. If remote required-context
settings disagree with these approved names, a repository administrator must
update that setting through the normal authorized path. User merge approval is
still required. This policy does not approve any additional PR for merging.
