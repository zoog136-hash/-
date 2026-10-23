# PR122 hero art generator — HTTP 400 recovery (2026-10-23)

## Latest executed recovery (2026-10-23)

The remote compatibility commits were preserved through a normal merge into
the hero branch after committing the three verified hero rigs. Neither PR122
nor its mythic/legendary branch was changed.

`generate()` now filters the actual HTTP request body immediately before
serialization, allowing only `model`, `prompt`, `n`, `size`, `quality`,
`background`, and `output_format`. This also removes injected `reasoning`,
`temperature`, `text`, and token controls when another caller passes them.
The Work service implementation is not present in this editable repository;
this fixes the owned compatibility caller, not the upstream service.

The latest saved Death155 run prompt is supported without changing its text.
The run default now selects that reviewed 3 × 2 S-only probe and 1536 × 1024,
rather than accidentally sending the earlier, visually rejected armor prompt
with an eight-heading sheet size. The historical four requests remain intact.

Seven local tests pass, including inspection of the serialized HTTP body,
one-call-only handling of HTTP 400, missing-credential behavior, and decoding
and saving a mocked PNG response. Mocked test images are temporary fixtures,
not generated artwork or evidence of API success.

One execution preflight was made for Death155 using the corrected prompt and
explicit execution flags. It stopped **before sending any HTTP request**:
`OPENAI_API_KEY` is not configured. The environment reports no configured
secrets or runtime variables. The receipt is
`evidence/visual-review-20261023/image-compat-single-probe.json`.
Actual new API-generated PNGs: **0**. PNG/SHA/frame-split/Godot verification
of that API result is **not available**. No identical failing built-in request
was repeated. The latest user instruction authorizes this compatibility
execution; it does not supply the missing credential.

The source-reuse work continued independently: 352, 405 and 407 passed direct
visual review and actual Main/Player validation. Nerupa406 now has an original
insectoid portrait-part rig candidate, rather than a different humanoid proxy;
its latest r007 version now passes direct Main review and is approved after
preserving the source dark limb ink and correcting shared bind/surface settings.
Earlier seam/contact HOLD revisions remain intact. The authoritative scope
remains 25, independently approved 4, pending 21;
default game integration remains 0.

## Confirmed failure

Saved evidence: `docs/remake/pr122-hero-parallel/evidence/next-unique-20261022/image-tool-failure.json`.

Image request for DEATH155 (run, attack, support, single-S death) failed before any source artwork was produced:

`HTTP 400 invalid_request_error / unknown_parameter: Unknown parameter: 'reasoning'`

The saved error is an **image tool/API request schema problem**, not proof that art contents, prompts, or pre-existing sprites are broken. The existing sources, failed prompts, source provenance, approval/HOLD state and PR122 branch must be preserved.

The OpenAI Images API documents image output options and does **not** accept `reasoning` in `POST /v1/images/generations`. Reasoning controls from a text/Responses model must not be merged into image-generation arguments. A tool/Work adapter that injects this field cannot be repaired by editing Godot assets.

## Immediate fix/workflow

1. Do not repeatedly issue the unchanged image-tool call after this deterministic HTTP 400.
2. If the caller owns the request construction, remove the `reasoning` key (and other unrecognized text-model options) **from the image request itself**. Use only that selected image tool's documented arguments. Keep the prompt unchanged; changing image instructions cannot cure an unsupported API parameter.
3. Start with **one** minimal image generation request and confirm an actual PNG exists, can be decoded, has expected dimensions and SHA-256. Do not run a large batch on an unverified transport.
4. If the built-in Work image tool still automatically injects `reasoning`, mark `UPSTREAM_ADAPTER_BLOCKED`; do **not** claim success or burn additional retries. Escalate the error to the tool provider with the saved sanitized error and request identifier. Restarting Work or changing the model can be tried only as a diagnostic, not declared a fix.
5. If an authorized API account and separately approved API charges are available, the optional `tools/pr122_image_generation_compat.py` sends **an explicit Images API allowlist** without `reasoning`. This is a workaround, not a patch to Work's internal tool. It defaults to a no-network dry run and refuses API execution without explicit `--execute --confirm-billing`. Do not request or paste API keys into chat or Git.

## Safe, no-network preflight

```bash
python3 tools/pr122_image_generation_compat.py --task run
python3 tools/pr122_image_generation_compat.py --task attack
python3 tools/pr122_image_generation_compat.py --task support
python3 tools/pr122_image_generation_compat.py --task death
python3 -m unittest discover -s tests -p pr122_image_generation_compat_test.py
```

These commands construct the proper JSON arguments and perform no paid image generation. They do not establish image rendering success.

## Optional direct Images API fallback (separate billing, only with user approval)

If this Work environment has an authorized `OPENAI_API_KEY` environment variable and the user explicitly approves additional Images API costs:

```bash
python3 tools/pr122_image_generation_compat.py \
  --task run --execute --confirm-billing \
  --output /workspace/generated_images/pr122-death155-run.png
```

Use distinct output files for attack/support/death. The tool will refuse to overwrite an existing file, save the PNG and print only path/SHA/size. Existing Work access does **not** imply separate API credits; if no approved key exists, do not try this fallback.

Do not invoke optional paid execution automatically, and do not consider preflight success to be a regenerated sprite or a character approval. Proceed with Godot 4.7.2 frame/grid/identity/pose/foot contact verification and preserve failed raw outputs. Keep chat images, base64 and verbose binary logs out of the conversation.

## Scope

No existing original artwork, actor profile, production catalog, runtime, or game sprite is changed by this compatibility addition. Hero parallel work stays isolated from the active PR122 mythic/legendary branch, and final approval remains unchanged until actual generated source and game playback pass.
