# Unpublished boss whole-batch follow-up

Scope: all 13 unpublished boss candidates, **429 required clips / 392 selected clips**, after mythic and legendary batches. The six already-published bosses and their prior actual-Main results were preserved, not rerun. Across the 15 new boss drafts, historical source production is 495/495 and selected resources are 458/495 (66 already-published clips plus this 392); neither number means final visual approval.

## Local resource connection fix

All 13 partial candidate SpriteFrames lacked `twilight_native_locomotion_staging`. The ordinary resolver could select an unrelated first animation when a requested role was absent and treat it as legacy art. In the actual Main run, Grim Reaper's unavailable idle after attack caused 60 virtual-foot assertion failures. New versioned candidate resources add the existing native-contract metadata, so missing views remain explicitly unavailable and do not gain a fabricated role. Existing same-direction monster WALK→RUN and authored S death rules apply. No controller code, attack clocks, source PNG, source regions, frame ordering, palette, name/alias relation or production catalog changed.

`pr158-native-contract-v01/` contains 13 new SpriteFrames and 13 profile copies whose sole content change is the referenced frames path. The staging manifest selects these versions. Every previous resource remains at its original path/SHA; all other actors and all track/source metadata are identical. The explicit preservation proof and 392-clip selected RGBA/texture/proof audit passed. All 723 required atlases / 41442 frames passed integrity. Published six connections remain unchanged.

## Validation and remaining failures

Initial whole-batch Main result: 392 clips, 156 assertions failed. These separate into 60 actual foot-position failures, 93 incorrect test assumptions that the marker must be frame 3, and 3 six-pose quality failures. The existing boss profiles explicitly use marker frame **2**; the test was corrected to assert the profile's existing marker, never changing the marker contract to satisfy the test.

After the resource change, one affected-batch Main replay completed **392/392 clips, 2349/2349 existing poses**, 93 single authoritative release events, zero remaining foot/marker/timing/body/collision failures. The process correctly exits **FAIL with 3 assertions**: Grim Reaper N attack and Prince Deus N/NW attack contain only five selected poses. The original six-pose assertion is retained, and none is approved. 389/392 selected clips meet that pose-count check; 37/429 requested clips remain excluded source HOLD. These are separate from the three selected five-pose holds.

The original unselected six-pose geometry and pixels remain preserved. An internal side-by-side review confirmed the excluded poses change weapon hands or contain duplicate staffs. Restoring those bad poses, cloning a pose to reach six, or lowering the quality criterion would hide the problem. Source correction is blocked by the unchanged image-authoring restriction; no generation was attempted. New final approvals: **0**. New default production connections: **0**. Other direction/model/articulation quality review is still pending, not inferred from these technical results.

Both complete logs/reports are retained. All final phase sheets are delivered. Before-change captures are delivered for the Grim Reaper failure; the other unchanged before-change sheets remain local and are not claimed as delivered. `boss-first-executed-harness.gd.txt` preserves the initial test assumptions. No full CI was repeated per clip or per actor.
