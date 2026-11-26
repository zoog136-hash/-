# Original 523 shop work at Main startup
Main still binds all shop supplies before opening play; no work was postponed
to opening the shop. The shop model still uses its verified bake and the same
release/first-reopen path. Only two registration operations changed:
- The skill-book installer uses a temporary append-only name index on the
  audited Main owner, so 100 missing/new names do not scan the whole catalog
  separately. First match, append order, physical state, unknown custom
  owners and quest-held/removed-item checks are preserved.
- Cash-package boot registration reads ordered source UnitID=4 product IDs
  (and applicable bonuses) without constructing labels, payment, duration, or
  UI restriction fields it never used here. UI/payment/claim still use the full
  original offer and rules; the eligibility or cost of no item was changed.

PC headless, installed original definition ZIP and real Main. Same-process
comparison on the same source: 592 displayed/currently bound offer identities
with/without bonuses returned the same ordered IDs (including duplicates),
110.876 -> 29.847 ms. Repeated skill-book setup on equivalent copied candidate
arrays in the real World: 100 binding/append records precisely equal,
2,257.305 -> 68.213 ms (paired run; includes temporary name-index construction
but does not measure a whole frame). No source hash changes. Actual Main
market entry opens on its initial click, 907.299 ms for this test from request
through the view (not an A/B; no device or 16ms claim). 1,194/1,194 full
checks; standalone catalog contracts 28/28 and cash-install scope separately.

Separate actual Main PC starts with pinned source: warm shop phase 10.291 s
(previous revision) vs 7.098 s (this revision). Cold code-cache runs 20.107 s
vs 18.931 s shop phase on this host. These are single sessions with varying
load/cache histories, not repeated/scientifically controlled complete launch
measurements. On the new warm run, 5.021 s is still cash-package binding (the
next measured bottleneck); model load 294ms, skill-book binding 74ms, ticket
binding 605ms, NPC binding 254ms. All five now have named boot records. Actual
tests select private source by TWILIGHT_PATCH523_CONTENT; without it the CI
test asserts basic absent-source semantics, not 1,194 raw-source assertions.
