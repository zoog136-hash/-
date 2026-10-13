# Shared combat timeline

These are TWILIGHT implementation rules, not claimed original Lineage timing. Existing DB hit ratios and attack cadences remain the authority. Official footage observations are recorded separately in REFERENCE_OBSERVATIONS.md.

- A command snapshots its duration from the effective attack-speed multiplier, target weak reference and target life ID. Speed changes affect the next command; they cannot add strike events to a running command.
- `TwilightActorMotion` advances preparation → strike marker → recovery. Crossing the marker during a large delta emits once. Skipping an entire cycle retains the strike pose for one render sample while the gameplay deadline remains unchanged. Current player cycles have one release marker; explicit multihit skills create separate shot actions with independent once flags.
- Manual movement, stun/fear, map transition, transformation cancellation and death cancel pending attacks. Magic windup is canceled by silence. After release, an in-flight projectile has its own contact lifetime; changing selected target cannot retarget it. Map/player reset clears all generations; a monster death or pool reuse retires its old target flights.
- Self-circle attacks use the same motion strike signal as targeted attacks. There is no separate SceneTree damage timer. A rejected start cannot leave a metadata-only pending action.
- Physical shots resolve on arrival. Delayed volleys integrate only the part of the tick after launch. Rendering budgets never discard callbacks. Line-of-sight is checked before release and impact; existing specific obstruction callables retain segment checks.
- Boss specials snapshot their centre/direction/shape/radius at preparation. Telegraph and actual hit share that geometry. Cancellation and death clear warning state. Patterns remain existing per-boss DB local adaptations.
- Each pooled monster life owns one reward transaction. Repeated death notification cannot duplicate XP, Adena or floor drops; item pickup still uses the existing ground manager/controller.
- Casting-speed modifiers reduce cooldown through the shared cooldown policy. They no longer additionally shorten the casting/contact animation. This preserves the user's specified casting-speed decision.
- Visual intensity, reduced motion and detail budgets affect presentation only. No Engine.time_scale change. Reduced motion disables synthetic root accents/local hold, moving/scaling damage labels and item rarity animation; actual character frames, projectiles and readable boss warnings remain.

Existing save IDs, physical item-instance enchantments, item rates and map coordinate data are unchanged. All save tests use fresh XDG directories and copies/fixtures; no user save was provided or accessed.
