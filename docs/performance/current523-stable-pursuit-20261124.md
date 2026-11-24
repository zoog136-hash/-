# Keep an already valid static 523 auto-hunt pursuit route

The 523.837 Android log's five 300–392 ms `auto.search_route` calls are
initial target acquisition, not known repeats for a retained target. That
work is separate from this change.

The prior host pursuit checks for a replacement route every 0.65 seconds
even when the same obstructed target has not moved. At that existing
deadline, keep one already-installed path only if it belongs to the same
configured static 523 field (including source reader instance), combat
generation, actor ID, actor life and exact goal. The original path must have
a non-rewound cursor, be auto-owned and not stalled; its next walking leg
must still pass the field's line check. Exact copied waypoints prevent an
intervening edit from adopting the old result.

Failure of any guard uses the original synchronous pursuit in the same
call. There is no longer retry timer, path search continuation or failed
path cache. Acquisition, target visibility, attack decisions and manual
movement priority stay unchanged. New diagnostic tags distinguish skipped
pursuit from a real path calculation. The source evidence supports the
existing tile/diagonal rules only; the original pursuit cadence is unknown.

The production auto-hunt regression uses controlled sight and route
responses: after one initial call, ten expired deadlines validate the
current leg without a full repath; movement by even a fraction of a tile,
blocked leg, new NPC life, reopen of the same field object, combat change,
stalls and route edits restore repath. Native device speed and whole-frame
16 ms performance remain unmeasured.
