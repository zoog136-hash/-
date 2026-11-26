# Native inventory cold-open work

The 523.837 Android capture attributed 2,006 and 467 ms to inventory staging
in two frames. These are inclusive spans, not full frame or GPU times. The
existing five-second reopen cache does not cover a cold open or a rejected
reopen. This change does not replace original art or add an opening delay.

- Stage one detached inventory snapshot. Original display order directly
  references rows in that snapshot rather than copying every displayed row
  recursively again. Legacy owner rows are still copied. The external icon
  callback receives a detached copy. Select/use continue checking live
  ownership, uniqueness and filtering.
- On cold open retain one full margin row (the 40-pixel row tail is bounded by
  the 76-pixel pitch). The second offscreen row is no longer built in the tap
  handler; normal scrolling retains the two-row lookahead. There is no frame
  delay for rows that are visible or intersect the edge. Original 4/8 column
  branches, transforms, icon source and opening clip are unchanged.
- Separate diagnostic timings for owner list, bindings, original scene tree,
  initial slot binding, visible lines and cold-open icon owner. Icon owner is
  nested in other timings; don't add them. The logger still exports slow-frame
  summaries, not a trace of every opening.

## Verification

Headless Godot 4.7.2, synthetic fixtures: cold open builds four extra rows
instead of five at the sample top position; scrolling builds the newly
needed lines synchronously. The actual slot producer tests owner order and
exact physical references, mutation isolation, duplicate rejection and stale
action refusal. Reopen and native routing regressions run independently.

The isolated slot producer benchmark, five paired samples, passes one owner
snapshot to both implementations. Median for constructing both normal and
expanded bindings: 64 owned items 4.56 to 4.28 ms; 256 items 17.66 to 17.34 ms.
This small result measures only synthetic binding CPU; it does not include
original tree creation or real icons and cannot explain the two-second gap.

The exact original UI/image pack was not installed here; Android cold-open
response and first-visible frame still need a matched replay. Use the phase
times to decide whether to optimize the actual source tree or image owner next.
