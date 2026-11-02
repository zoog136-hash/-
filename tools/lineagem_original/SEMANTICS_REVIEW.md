# Source timing, compositing, and visual review — pending new DB evidence

This records the earlier read-only timing/blend investigation. Verified base508 DB joins have since been received and701 source definitions registered. Original resources remain unchanged; source-specific playback adapters were subsequently added without invented timing or blending. Identity/tier tables are no longer a blocker. The later parser fixes preserve indented declarations, direction-slot addresses, and alias layer overrides.

## Literal timing evidence

All30 supplied base508 SPR files were read as strict CP949. They contain explicit110.framerate values including24 (3,072 occurrences),36 (2,815),48 (83),45 (52),38 (48), and other rates. No matching source comment explains a default FPS or cross-header scope.

- list_22.spr:5051 #22258 has36 at5052, then24 at5072; alias22262 starts5168 and repeats36 at5169,24 at5189.
- list_28.spr:7692 #28439 has36 at7693,24 at7714; alias28443 starts7812 and repeats36 at7813,24 at7834.
- list_29.spr:2969 #29187 has no own110 directive; preceding file directive is24 at2806.
- list_22.spr:18689 #22869 has no own110; preceding file directive is24 at18592.
- list_25.spr:11068 alias25759 has no own110; preceding file directive is24 at10954.

These positions support the current nominal interpretation of explicit sections in the two reviewed transforms. They do **not** prove a default24, file-global state, reset-on-header behavior, alias rate inheritance, or the native client's speed modifiers. `original_spr.read` resetting its rate toNone at a header is a conservative no-guess policy, not an established native engine reset rule. An alias overriding an action without an explicit rate remains unresolved even if a base action has a rate.

The earlier A3 paths cannot establish M defaults: tools/l1j/build_spx_source_pack.py:196 sets tick_rate_verified=false and its CLI default24 is at319. tools/run_pr122_native_tick_preview.py:77 likewise records native_client_tick_rate_verified=false. Those provisional24Hz values must not become M evidence. Existing authored animation profile FPS is also not native evidence.

## Literal compositing evidence

Across the supplied source,104.attr(8) occurs8,405 times and attr(128)4,348 times; values1/5/12/256 also occur. Names such as_sc/_mu and integer attributes are literal facts, not definitions of blend equations or draw order.

Known source declarations:22260 and28441 have attr8;22261 and28442 have attr128. Existing scripts/animation/source_spx_player.gd:140 explicitly leaves attr8/128 unguessed; its verified blend enum accepts an externally verified mapping and does not provide one. The supplied RESULTS.txt and CATEGORY_RESULTS.txt also explicitly leave final blending/depth/anchor semantics unverified. No obtained document supplies an authoritative mapping to additive/multiply or an alpha factor.

The16 selected sc/mu files for the reviewed idle/walk/run/basic-attack tracks were decoded read-only. Among1,200 direction/frame samples,1,168 are nonempty. In particular, all selected Halpas sc/mu samples contain pixels. Girtas mu has32 legitimately empty samples, spread across run/idle/attack; empty source layers must not be reconstructed. Current preview omits these layers, so it is demonstrably an incomplete composition, even though the body animates. See omitted-layer-review.json for exact files, native frame IDs, offsets, sizes, and counts. No composite shader was tried.

## Current game-image limitations

The10 captured Main screenshots and observations cover the two fronts through idle/walk/run/attack/idle. They show source bodies without an obvious entire-body disappearance or added procedural root deformation. This is a limited still-image observation, not eight-direction/all-frame quality approval.

Known omissions/unverified aspects:

1. Visible source sc/mu pixels are omitted; the current appearance cannot be called the final native composition.
2. Native shadow pixels are rendered literally. Native opacity/draw semantics and its relation to a physical foot anchor remain unverified; an invented shadow alpha/anchor correction was not applied.
3. Source direction bit5 → game down is based on the inspected poses. Full native-world cardinal semantics and all eight game-view transitions remain unapproved.
4. Texture extents change with the original poses while the root remains scale1/rotation0/native offsets. Different pose bounds must not be normalized or called erroneous size wobble without an original-client comparison.
5. The software-rendered captures report roughly10–24FPS. Intermediate native poses can be skipped by a low render rate while the source timeline advances. Android30FPS, temporal smoothness, and loop-boundary visual approval remain untested.
6. Normal Aden boot was blocked by a separate map pack missing from this sparse checkout. The successful screenshots use the explicitly selected authored albino validation fixture; they do not validate the normal Aden world.

## Verified compatibility hazards before the incoming NPC data is applied

- scripts/monster.gd:202 flips positiveAC to negative, then physical_resolution.gd uses abs(target_ac). A raw signed sourceAC must be retained and its adapter reviewed; copying it blindly would lose sign meaning.
- monster.gd:204 forces HP to at least30. This would overwrite a verified lower sourceHP.
- monster.gd:251 forces EXP to at least10, and world.gd:2580 forces final gainedEXP to at least1, with blessing/equipment/map multipliers. A source0 is not currently preserved.
- Monster has noMP/maxMP storage or native monster MP-consumption model. Storing sourceMP and enabling new skill-cost behavior are separate changes.
- experience_progression.gd explicitly uses a TWILIGHT balance curve; sourceExp units and nativeExp→local reward policy require traceable handling, not an unexplained numeric overwrite.
- Current source_npc_id fields include previous source namespaces. M NpcClass numeric IDs and Sprite IDs must not be equated with those IDs or each other.
- NpcClass internalName is not the display identity; the parent reports DescId→DescData_Korean as the display-name join. Same display name orSprite may identify multiple region/purpose variants. Incoming exact row IDs must be retained; Level and MonsterBookLevel must not be treated as verified combat level.

No NPC/card gameplay values were changed during this investigation. Once the validated package arrives, its exact joins and provenance supersede earlier name-only candidates while keeping unverified semantics explicit.

## Subsequent declaration/address corrections

SPR headers may be indented. Leading whitespace must be removed before recognizing a new declaration; otherwise the following actor contaminates the previous action map. The formerly missing16471/21850/29420 declarations are present in the supplied originals.21909 idle is10frames, not the12frames of its indented successor21910. Source DB evidence remains preserved while current parsed SPR evidence is recorded separately.

An action flag0 retains a fixed source direction slot; flag1 adds the facing slot. Physical SP2 suffix is(slot & ~7), stored mask bit is(slot &7).24789 demonstrates this structurally: chunk0 bit0 holds12 idle frames, bits1–7 hold8 walk frames, and chunk8 bit0 holds the remaining8-frame walk direction. Shadow/clothes references, including9516→8135, must resolve recursively and respect alias-local declarations. Run references come from the run declaration, not the preceding walk declaration.

## Girtas identity-scoped observed candidate (2026-11-02)

Compatibility mode now limits a screen/multiply candidate to body22258's
attachment22260(sc) and22261(mu). It does not redefine source104.attr8/128.
Mu is drawn first at z1, sc next at z2. Each pass copies the current framebuffer:
`multiply(dst,src)=dst*src`; `screen(dst,src)=1-(1-dst)*(1-src)`;
RGB output is `mix(dst, operation(dst,src), source_alpha)` at opacity1.
Source RGBA bytes, offsets and timing stay unchanged. BackBufferCopy is required
between passes so the second samples the first result. This adds two framebuffer
copies for this appearance; Android cost is unmeasured. Strict mode still hides
these unverified attachments. `--lineagem-girtas-legacy-blend` selects the prior
ADD/MIX(alpha0.5) candidate for repeatable comparison.

Parent research reports five pose-matched M GIF samples at0/240/480/710/920ms:
screen/multiply body-interior MAE8=16.9–18.1 versus30.2–43.1 for ADD/MIX0.5.
This is observational support for these two sprites only. The evidence ZIP is
not yet received in this execution environment, so independent reference-image
comparison remains pending; no exact M compositor or global equivalence claimed.
