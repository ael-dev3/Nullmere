# What Nullmere carries over from Warpkeep

Nullmere grows out of [Warpkeep](https://github.com/ael-dev3/Warpkeep), a
persistent browser strategy game built around Farcaster identity. Warpkeep's
development halted on 17 October 2026 and its source was published for reuse.
This note records what Nullmere keeps, what it adapts and what it leaves behind.
It is based on a read of Warpkeep at
[`dffe544`](https://github.com/ael-dev3/Warpkeep/tree/dffe5442db5713b2d99c3fef658b49565b8548eb).

**In one paragraph:** keep the universe, the premise and the principles. Keep
SpacetimeDB as the authority, along with Warpkeep's pure 0.4 rules core and the
patterns around it. Keep the hex-world model and the public world vocabulary,
and reuse the owner's original assets freely under CC0. Drop Farcaster, the
browser/Three.js client, the Warpkeep name and the warpkeep.com operations
machinery. Leave every third-party or unresolved-rights asset where it is.
Warpkeep never had combat, diplomacy, alliances, territory or fog of war, so
those 4X pillars are new work for Nullmere.

| Area | Carries over | Changes or is dropped |
| --- | --- | --- |
| Universe and premise | The Hegemony, Keepers, curated admission, the world vocabulary | Farcaster-bound fiction (FID keeps, Warplet guardians), Community Marks |
| Principles | Server authority, safe retries, honest status, provenance, measured quality | Mobile-first and Farcaster-social goals become Mac-first and pseudonymous |
| Game design | Gather → choose → build → benefit → return; four resources; buildings and timings | Grows into full 4X: exploration, expansion, diplomacy, war |
| World and map | Axial hex model, regions and names, public cell schema, generation algorithms | Greater Realm's private atlas and seeds (never in the repo) |
| Backend | SpacetimeDB; `spacetimedb/gameplay04` rules core; adapter, receipt and migration patterns | G001/G002 module bodies, release-recovery service, ~570 ops scripts, Maincloud identities |
| Identity | Patterns: auth epochs, identity binding, short-lived scoped tokens | Sign In with Farcaster, Mini App Quick Auth, FID as primary key |
| Client | Lifecycle, quality-tier and reduced-motion lessons | React, Three.js, Vite and the Verdant Citadel art direction |
| Assets | Owner-original work, now CC0 | Suno scores, the Warplet character, unresolved-rights media, third-party references |

## Licensing: what Nullmere may copy

- **Code** is Apache-2.0
  ([LICENSE](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/LICENSE)).
  Copied files keep their license notice and should say they were changed.
- **Original assets and creative documentation**, including lore, manifests and
  AI-assisted work, are dedicated to CC0 1.0 from 17 October 2026
  ([ASSET-REUSE.md](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/ASSET-REUSE.md)).
  No permission or attribution is needed. The dedication covers only rights the
  owner controls.
- **Third-party and externally governed material keeps its own terms**
  ([ASSETS-LICENSE.md](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/ASSETS-LICENSE.md)).
  Concretely:
  - The menu and Lowlands scores were project-provided with unresolved source
    rights.
  - The Genesis 002 score is marked "made with suno"; Suno's terms still apply.
  - The Warplet guardian is a Farcaster-related character with external rights.
  - The SavageIndie BlendSwap tree reference is CC BY 4.0.
  - The menu film and the retired Frontier Keep are unresolved.
  - Studied references (Pelagic, Three.js Water Pro, Desert Dusky) were never
    copied and must not be.
  - The Inner Keep 3D library is recorded as `LicenseRef-Warpkeep-Provenance-Required`
    with mixed source terms.

  Check an asset's dated provenance record before reusing it.
- **Names.** Warpkeep's [trademark note](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/TRADEMARKS.md)
  reserves the Warpkeep name, logos and domain. Nullmere has its own name, and
  in-world names such as the Hegemony and the regions are original creative
  documentation (CC0).
- **The Hyperion Cantos is inspiration, not material.** Warpkeep never names
  Dan Simmons' characters, places or terms, and Nullmere should keep it that
  way: no Shrike, Time Tombs, TechnoCore or the like.

This repository copies no Warpkeep code or assets. The launcher's lake, moon,
stars and icon are procedural and original. The Apache-2.0 and CC0 license
texts are the canonical ones.

## Universe and premise

**Keep:**

- **The promise.** "A real person, a permanent keep, and a world worth
  returning to" ([product direction](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/docs/design/warpkeep-direction.md)).
  For Nullmere the person is pseudonymous, but still real and still singular.
- **The Hegemony as a fiction with explicit limits.** The
  [Social Contract](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/public/social-contract/index.html)
  frames admission as a covenant: "The gates do not open for the many. They
  open for the sworn." Its articles fit a small, curated community whose
  politics and drama are the point:
  - The Realm endures beyond any citizen.
  - War stays inside the Realm.
  - Access follows conduct.
  - Honest counsel strengthens the Realm.
- **Keepers, keeps and the Realm** as the core nouns.
- **World vocabulary:**
  - The regions: the Hegemony Lowlands, Frostmere Reach, Sunscar Expanse,
    Mirefen Delta, Stonewake Isles and Emberwood March.
  - The Tier II marches: Crownwood, Ironveil and Glasswater.
  - Throneheart, with its dormant throne anchor.
  - Eighteen sealed gates between regions.
  - Terrain names: Stillwater Lake, Amethyst Heath, Weathered Ridge, Ancient
    Stone, Sunlit Meadow.
  - Nullmere's "-mere" sits naturally beside Frostmere and Stillwater.

**Note:** Warpkeep's lore is thin. It has names, titles and the Social Contract's
voice, but no written history, factions or warp mythology. Nullmere has to
write its own canon, and the black lake under the launcher's full moon is an
obvious place to begin.

**Drop:**

- Fiction tied to Farcaster: keeps keyed by FID, Warplet guardians chosen by
  FID, the Farcaster channel as the public square.
- Community Marks and the Hegemony Mark. These were experimental,
  non-transferable accounting units with no cash value. If Nullmere ever adds
  something similar, keep the same hard line: it is not a financial product.

## Principles

These carry over nearly word for word from Warpkeep's direction document and
[AGENTS.md](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/AGENTS.md):

- Judge additions by how they strengthen choices, progress and the desire to
  return, not by feature count or code volume.
- Make the next useful decision obvious. Show spendable versus pending
  resources, exact costs and shortages, and what completion changes.
- **The server is authoritative** for identity, admission, ownership,
  resources, routes, timers and outcomes. Client prediction is presentation,
  never a grant.
- Make retries, stale terms, reconnects and uncertain outcomes understandable
  and safe. Never hide a new irreversible command inside an automatic refresh.
- **AI-assisted creation does not become game authority.** This matters
  directly for on-device Foundation Models NPCs. They may voice, summarise and
  advise, but they never decide outcomes or grant resources.
- Prefer coherent original art with recorded provenance. Reduce decoration
  before sacrificing legibility or responsiveness.
- Judge quality through actual play, measured responsiveness, visible state
  and failure recovery.
- Respect reduced motion and hidden windows, and keep quality tiers.
- Conserve CI. Validate locally, batch changes, and don't run CI experiments.

**What changes:**

- Warpkeep optimised for phones and Farcaster's social graph. Nullmere is
  Mac-first and pseudonymous, with Apple-platform conventions: menu
  commands, keyboard control, full screen and accessibility settings.
- Warpkeep's world was mostly decorative around a gathering loop. Nullmere is a
  4X game, so geography, visibility and other players become the substance of
  play.

## Game design

**Carries over:** the 0.4 economic heartbeat,
**gather → choose → build → benefit → return**
([gameplay spec](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/docs/superpowers/specs/2026-09-05-warpkeep-0.4-gameplay-design.md),
[`policy.ts`](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/spacetimedb/gameplay04/policy.ts)):

- **Resources:** Food, Wood, Stone and Gold.
- **Workers:** each journey reserves capacity at a resource location. Cargo
  becomes spendable only on an authoritative return.
- **Buildings:**
  - Mills, Lumber Camps, Stoneworks and Goldworks raise matching yield
    (10 + 2 × building level).
  - Barracks shorten travel by 5% per level.
  - The Cathedral shortens construction by 5% per level.
- **Costs and timings:**
  - Costs scale ×1, 3, 7, 15, 31 by level.
  - Builds take 2 m, 15 m, 1 h, 4 h or 12 h.
  - Gathering takes 1 m, 10 m, 1 h or 8 h.
  - Balances cap at 1,000,000, and overflow is recorded.
- **Command terms are captured when accepted.** A later building completion
  does not rewrite them.

**Grows into 4X:** Warpkeep's roadmap listed scouting, trade, alliances and
shared objectives, training and conflict, and seasons and community
institutions as possibilities. In Nullmere they become the pillars:

- **Explore:** scouting, plus fog of war enforced by the server. Warpkeep's
  security notes warn that client-side fog is never safe.
- **Expand:** more than one keep, territory, and opening the sealed gates.
- **Develop:** the economic loop above, extended.
- **Diplomacy:** alliances, treaties and messaging. Warpkeep's never-activated
  [Realm Chat V1 contract](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/docs/design/realm-chat-v1-contract.md)
  is a ready base for rate limits, reports and moderation.
- **War:** armies, conflict, and consequences that persist.
- **Durable history:** a server-side chronicle of treaties, betrayals, sieges
  and founding moments. This is new, and central to the brief.

## World and map

Two models exist in Warpkeep:

- **Genesis 001, "the Hegemony Lowlands".** This is public and reproducible.
  - A pointy-top axial hex grid with 10,000 cells: a radius-57 disc plus a
    partial ring.
  - Generated deterministically from the public seed `HEGEMONY_GENESIS_001`.
  - Seven terrain kinds.
  - A coast flood fill and a drainage graph with 12 rivers.
  - Digest-pinned resource-site catalogs: 24 gold mines, and 96 each of farms,
    logging camps and quarries.
  - Code in [`spacetimedb/src/world.ts`](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/spacetimedb/src/world.ts),
    [`waterWorld.ts`](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/spacetimedb/src/waterWorld.ts)
    and [`src/game/map/`](https://github.com/ael-dev3/Warpkeep/tree/dffe5442db5713b2d99c3fef658b49565b8548eb/src/game/map).
- **The Greater Realm.**
  - A 100k–150k-cell continent with 10 regions, built by a roughly
    12,000-line offline generator in
    [`scripts/atlas/`](https://github.com/ael-dev3/Warpkeep/tree/dffe5442db5713b2d99c3fef658b49565b8548eb/scripts/atlas).
    The generator models pseudo-tectonics, erosion, Priority-Flood drainage,
    climate and biomes, with integer arithmetic throughout.
  - **The real atlas and its seeds are private and are not in the
    repository.** Don't try to reconstruct them. Nullmere should generate its
    own world from its own private seed.

**Carries over:**

- Hex math and seed mixing. Port these to Swift for the client, and watch
  32-bit wrapping.
- The region and gate structure, with the names above.
- The public cell schema in
  [`greaterRealmPublicContract.ts`](https://github.com/ael-dev3/Warpkeep/blob/dffe5442db5713b2d99c3fef658b49565b8548eb/src/greater-realm/greaterRealmPublicContract.ts).
  It covers elevation, slope, biome, landform, hydrology, travel class and
  movement cost, and is a strong template for Nullmere's tile tables.
- 15×15 axial-bin chunking with levels of detail.
- Corridor-protected blocker placement, farthest-point site selection and the
  movement-cost formula.

The generator is easiest to reuse as is: run it offline in Node with a
Nullmere seed, then import the result.

**Stays behind:** the Three.js terrain, water, grass and forest renderers. A
Metal world renderer would start from the data, not from those modules.

## Backend

Warpkeep already used SpacetimeDB as its authority. Its modules are written in
TypeScript and pinned to `spacetimedb` 2.6.1. They are:

- the live G001 realm, with 86 tables;
- a shared pure rules core, `spacetimedb/gameplay04`;
- an owner-only test realm (PTR) running the 0.4 rules;
- a sealed Genesis 002 realm.

**Carries over:**

- [`spacetimedb/gameplay04/`](https://github.com/ael-dev3/Warpkeep/tree/dffe5442db5713b2d99c3fef658b49565b8548eb/spacetimedb/gameplay04),
  about 2,300 lines. It imports no SpacetimeDB, browser or Farcaster code,
  and reaches storage through interfaces. It provides:
  - deterministic Worker journeys;
  - construction quotes;
  - a placement grid;
  - a command protocol with a monotonic sequence, request keys,
    compare-and-set revisions and a bounded receipt ring, so retries are
    exact;
  - lazy plus scheduled reconciliation.

  The only Farcaster residue is the name `ownerFid`, which becomes a player id.
- The PTR adapter shape in `spacetimedb/ptr/src/gameplay*.ts`: private tables,
  procedures that return whole snapshots, and scheduled wakeups. It comes with
  the gameplay04 test suites.
- Practices and workarounds:
  - additive-only schema migrations, verified against frozen fixtures;
  - explicit wire names;
  - a scheduled-reducer guard (`ctx.connectionId === null` and
    sender = database identity);
  - public projections stripped of identities, kept apart from private
    authority tables, which suits fog of war.

**Dropped:**

- The G001 module body: legacy expeditions, rollout and cutover machinery,
  Daily Marks, and the retired wallet and SNAP tables.
- The sealed G002 module.
- The PTR owner-anchor tables.
- The `services/release-recovery` Cloudflare signer.
- Roughly 570 publish, attestation and operator scripts.
- The Maincloud database identities and everything that names warpkeep.com.

**Identity:**

- **Replace:** the auth bridge's Sign In with Farcaster, Quick Auth, Mini App
  webhooks, access-request queue and `farcaster:<fid>` subject checks.
- **Keep as patterns:** exact-claim token parsing, auth epochs for instant
  revocation, an identity-binding table, short-lived scoped tokens and rate
  limiting.

  For a pseudonymous, curated community, the simplest fit is SpacetimeDB's
  own identity and token (kept in the Keychain) with invite-based admission. A
  small OIDC issuer is the alternative if accounts need recovery.

**Swift client:**

- SpacetimeDB has no official Swift SDK. The official SDKs cover Rust, C#,
  TypeScript and Unreal.
- A community package exists
  ([avias8/spacetimedb-swift](https://swiftpackageregistry.com/avias8/spacetimedb-swift))
  and needs evaluation.
- The fallbacks are a native client for the BSATN WebSocket protocol
  (`v2.bsatn.spacetimedb`), or HTTP procedure calls for snapshot-style reads,
  as the PTR realm already does.
- A live multiplayer map will want subscriptions, which favours one of the
  first two options.

## Client and presentation

Warpkeep's client used React, TypeScript, Three.js and Vite, tuned for phones,
in the bright **Verdant Citadel** style: pale masonry, teal roofs, a voxel
forest. None of that code or art direction carries over. Nullmere is
SwiftUI/AppKit now and Metal later, and its look is dark, vast and quiet.

**Lessons that do carry over:**

- One owner per renderer, responsible for loading, animation, disposal and
  context recovery.
- Quality tiers and reduced-motion and hidden-window policies that bound
  optional work.
- Decorative geometry never decides navigation, placement or yield.
- Visual quality is judged from rendered frames and measured performance,
  not scene-graph tests.
- From the Living Realm studies: finite audio cues and intentional silence
  rather than permanent drones. That fits the launcher's silence.

## Assets at a glance

| Asset group | Reuse in Nullmere? |
| --- | --- |
| Owner-original images, icons, castles, buildings, units (Warpkeep-Assets) | Allowed under CC0, but check each provenance record for creation-service terms. The bright, mobile art direction also doesn't match Nullmere. |
| Hegemony Mark artwork | Allowed (CC BY 4.0, and CC0 for the owner's rights). Unlikely to fit unless Nullmere keeps the Hegemony's heraldry. |
| Menu and realm scores (Suno-made or project-provided) | Not without confirming the source terms. |
| Warplet guardian and Farcaster Mini App art | No: Farcaster identity and external character rights. |
| Menu film and poster, retired Frontier Keep | No: unresolved rights. |
| Third-party references (Pelagic, Water Pro, Desert Dusky, tree references) | Never copied, and never to be. |

## Open decisions

1. **Licensing.** This repository mirrors Warpkeep's final position: code under
   Apache-2.0, original art and docs under CC0. CC BY 4.0 for creative work
   is the alternative if attribution matters.
2. **Identity and admission.** SpacetimeDB identity with invites, or an OIDC
   issuer (for example Sign in with Apple) behind a pseudonymous profile.
3. **Server language.** TypeScript modules reuse `gameplay04` directly. Rust
   modules would mean a port.
4. **Canon.** Decide which Hegemony names and regions Nullmere's world keeps.
5. **Swift client transport.** The community SDK, a native BSATN client or
   HTTP procedures.
