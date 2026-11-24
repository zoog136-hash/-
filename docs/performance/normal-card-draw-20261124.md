# Normal inventory card ticket draw

The normal TWILIGHT ticket (single or 11-pack) reaches `world._use_card_pack_item`
through the inventory activation signal. It does not use the original
owned-ticket adapter optimized in #867. This change uses the same HUD
publication batch for normal tickets and avoids copying all historical receipts,
pity data, and three decks only to keep a rollback of one draw. The rollback
checkpoint covers the affected deck's owned, spare and confirmation maps and
the normal draw RNG. Those nested maps contain scalar ownership or counts; the
card roll does not mutate receipt history, pity, or any other deck.

The save itself remains complete and synchronous. A failed save restores ticket,
cards, confirmation and RNG and never opens a result window. The successful
save still precedes all card publication, bag counts, result text, toast, log,
and reveal. The unchanged card engine uses the same grade tables and RNG calls.
The bag publication batch does not defer gameplay stats or reveal to a later
frame. It only coalesces intermediate row/detail refreshes.

New hitch details expose the normal draw/checkpoint, synchronous save,
post-commit publication, and reveal entry under separate names. The recorded
fixture timings do not include original/private card resources or Android.

A deliberately history-heavy isolated PC ABBA fixture (2,500 nested receipts
and 320 cards per deck) measured the new rollback checkpoint at 0.623 ms,
versus 5.577 ms for the former whole-state rollback snapshot. This is neither
the time to write the save nor the full handler's speedup.
