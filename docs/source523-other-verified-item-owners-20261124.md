# Original advanced solvents and historical blessing charge definitions

The selected bag instance of an original advanced/top solvent now opens the
already-implemented equipment dissolve owner with its exact physical UID.
Opening the chooser does not save or consume. Confirmation rechecks the same
stack's selection, availability, eligibility, expiry and locks instead of using
another same-ID stack, and uses the pre-existing approximation for advanced
dissolve yield without changing it. Source ItemClass IDs 117534, 118682, 149423,
and 192664 declare method 24→117544 or 34→192654. 117534 and 149423 retain their
source date policies; the normal method-14 #183 is deliberately separate.

Original 523 item definitions #122744, #123254, #123572, #123662, #124342,
#125971, #132933, #157071 each specify a pure charge amount, cap and group 12,
and the Korean source description agrees with the amount. Their older records
lack the later PlayerEinasadBless marker. Only these exact verified shapes
select the existing Ainhasad owner; their normal expiry, level, lock and region
rules are unchanged. This does **not** reactivate expired campaigns.

Current runtime accepts only the already-modeled map/dungeon time pools. Of
14 remaining time stones, 12 refer to ServiceType 52 and two invitations refer
to group 32422, whose original TimeLimit is zero. Existing ServiceType 13
positive base-time charging must not reinterpret those as ordinary stones.
No countdown, server schedule or timer was fabricated.

Scoped Linux Main regression:
`TWILIGHT_TEST_SOLVENT_SOURCE=<verified d5192 archive> godot --headless --script res://tests/bless_refine523_test.gd`
36 assertions include exact source profiles, real inventory activation, no
consumption on open, wrong UID and writer-failure preservation, and one selected
solvent + one target committed together. Old charge profiles are source checks,
not live successful activation of expired event items. Android not tested.
