# Existing NPC source actions in the current523 bank

The current bank view now consumes the existing boss-combat presentation API:
`advance_source_action(action_id, delta, facing, sequence)`,
`source_action_duration(action_id)`, and `clear_source_action()`.
Previously these calls inherited the old pack implementation, whose raw-track
registry is not populated by the current bank view. The accepted original boss
action therefore could not reach the bank renderer.

The combat owner still chooses the source action from its existing original
attack MotionType/WeaponType agreement and checks life, sequence and generation.
The view binds that exact ID on its already admitted NPC Sprite through the
ordinary pinned bank reader, with a single non-looping caller attack role. Keeping
that existing role also preserves identity/action-scoped source timing repairs;
an arbitrary new role label must not discard an available original clock.
It never selects a similar action, applies damage or creates a combat event.
At most one additional action preview is retained, shares any existing texture
budget, and is freed on owner release, death or sequence replacement. The owner's
existing recovery hold remains intact. Source FPS/timing stays unresolved when
the source did not declare it; no new FPS or duration estimate is introduced.

Primary NPC body roles remain exact original idle3/walk0/attack1. Hit2 and death8
are now independently probed optional roles, like the already supported source
run binding. A missing optional SP2/action cannot reject all available primary
roles. Requesting a missing role hides the body for that state, never substitutes
idle, attack, old-pack art or a generated frame. A later valid state restores the
body without unhiding the whole owner view. Independent source effects remain
under their existing event/context contracts while the body is hidden.

Missing explicit action inputs remain pending for the current host motion. The
failed request does not require a successful combat presentation handle to clear
its visual hold when that motion ends. Pending state inspection does not return
an older successful frame as the requested missing action.

Source-only spawn admission, current original NPC identity, original exclusions,
SHA checks, member paths, decoder bounds, combat timing, ownership and saves are
unchanged. This code connects existing inputs; no bank or approved distribution
file is changed or uploaded again. Missing16007/6082 inputs, exact Class and
dependency identities, type9 ground roles and Invoke34 admission remain separate.

The reference reader shares one immutable parsed manifest for the same path/pin
across live NPC/action readers. It still reads and hashes the actual bounded
manifest bytes on every load, and retains the per-render metadata-pin checks and
per-use SP2 SHA/CRC checks. Actor JSON is not added to this shared cache. Nested
manifest arrays/dictionaries are read-only, and outgoing member provenance is
copied so one consumer cannot edit another actor's source identity. Reader reset
detaches its dictionary reference instead of clearing the shared snapshot. This
avoids a separate parsed31MiB registry per NPC without trusting timestamps or
weakening the source admission boundary; no performance measurement is claimed.

No tests, compilation, game, rendering or main CI were executed for this change.
Actual displayed source actions and gameplay equivalence remain unobserved.
