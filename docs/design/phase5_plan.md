# Phase 5 Plan: The Next Phase of Building (draft, decisions pending)

*Drafted 2026-09-25 at the user's request. This is a plan snapshot in the
phase4_content_plan.md tradition: prose and sequencing here, no checkboxes. The To-Do in
CLAUDE.md stays the only live list (per the 2026-09-09 restructure), and nothing below
is decided until the user approves it. Decision points are gathered at the end.*

## Where we stand

Phase 4 (the replacement world: 21 camps, five second-tier quests, Hadrik and Elara) is
BUILT and deployed to the fresh world as of 2026-09-22, with the starter book proven in
play and `phase4_content_checklist.md` partially exercised. The friends-build target is
2026-10-05. Meanwhile, this week's zone-size research (`docs/design/zone_size_limits.md`)
settled the engineering limits for the LARGE world the user wants: width is open to
West-Karana scale today, and verticality is blocked on exactly one server capability,
the terrain height model.

Phase 5 is what we build once the friends build ships (or in the slack around it). Four
tracks below, roughly ordered; A and B are already user-decided in substance, C and D
carry the new work.

## Track A: Close out phase 4 (prerequisite, not really "phase 5")

- Finish `phase4_content_checklist.md` (the remaining rings and quest arcs).
- The pending retests riding the current build: cursor slice 1.5's two 09-09 fixes,
  `bagspace_groupbars_checklist.md` (bag-space placer + group-bar seeding, needs the
  two-player session).
- Fold any phase 4 findings into the To-Do as usual.

## Track B: The decided server batch (all user-approved, build-ready)

Queued behind the phase 4 playtest precisely so it lands on a tested base. Suggested
build order, cheapest and least risky first:

1. **Dead-XP filter** (decided 2026-09-19): XP shares gated by 30 m proximity to the
   dying enemy plus an alive filter. Server-only, small.
2. **Full bags move with contents** (scope settled 2026-09-17): re-key the bags map when
   the parent slot moves; cursor may hold a non-empty bag; death path strips bag AND
   contents (extend the `clear_all` regression coverage).
3. **Pet levels, interim A** (decided 2026-09-19): warder = owner-1 deterministic,
   variance roll on manual summons only, pets at ~70% of the mob stat curve (tuning
   knob). SWG-style taming (option C) remains the Beast Master's destination later.
4. **Trade window slice 1** (designed + all calls decided 2026-09-19,
   `docs/design/trade_window.md`): escrow by locking, PD_W0028, both-sides deploy.
   Largest item; goes last so the protocol bump rides a stable base.

## Track C: Security batch (small, sharp, mostly new)

1. **NaN Move gate** (found 2026-09-25, To-Do entry exists): reject non-finite Move
   directions. A few lines plus a test. Do this FIRST in the phase; it is also a stated
   prerequisite of the height model work.
2. **Unclean-kill relogin retest** (standing item): re-test before assuming broken.
3. **Silent-refusals closeout**: recount the cast resolver's silent arms, answer any
   that remain, close the long-running item.
4. **`reset_password` ops bin** (scoped 2026-08-14): argon2 the new password, clear the
   account's sessions. Operator tool only.

## Track D: The big-world track (new; the height model is the headline)

This is the phase's new capability, and the reason it deserves a phase rather than a
batch: it unlocks the terrain the user actually wants to build.

1. **Server height model, design first.** The handoff guide for the building session
   already exists: `docs/session_notes/handoff_server_height_model.md`. Deliverable one
   is a design doc (exploit ledger, slices, user decisions); build follows approval.
   Summary of the shape: export the client terrain heightmap to a server-side file, the
   server samples ground height and pins player/mob/corpse/bag/NPC Y, 3D range checks
   become correct, jumping stays cosmetic, the client never gains Y authority.
2. **Scale-readiness fixes that matter before mob count grows** (both already known):
   the idle-enemy 20 Hz rebroadcast fix (existing To-Do; the regen.rs changed-or-keepalive
   pattern, with a bandwidth counter to measure), and the enemy AOI cell-crossing
   spawn/despawn gap found in the research (mobs chasing into view stream Position for
   an id the client never got a spawn for).
3. **The `/loc` command** (design: `docs/design/location_command.md`). Client-only,
   small, and load-bearing for everything else in this track: content authoring writes
   hand-picked world coordinates into `zone_camps.toml`/`npcs.toml`, playtest triage
   needs "where were you", and the height-model playtests need to read Y off the
   screen. Zero exploit surface (prints what the client already knows, own position
   only). Build early in the track; two small open calls in the design note.
4. **Terrain tooling and the first non-flat zone.** After the height model lands:
   terrain chunking in the client (one unchunked trimesh today), a heightmap export
   tool with a loud staleness check (build-stamp style), then the first authored
   terrain with real hills, points of interest, and visual-only cliffs, inside the
   envelope from zone_size_limits.md §6 (origin-centered, up to ~4 x 4 km freely).
5. **Deliberately NOT in this phase:** multi-zone (its own epic: wire message, server
   zone keying, zone lines), caves and stacked floors (needs real Y, not a height
   sample), navmesh pathing.

## Track E: Candidates, unscheduled (pull in if time allows)

`/r` + TAB tell-cycling (client-only, small), the cosmetic jump relay (first piece of
the remote animation channel; pairs naturally with height-model testing), the bind/Gate
unification sprint, the Tarnished Silver Ring AGI bug, player-inspect right-click
trigger, the UI theming pass (user has flagged layout as "pretty busted"; needs its
screenshot pass first).

## Decisions for the user

1. **Is the height model the headline of phase 5**, with Tracks B and C as its
   undercard, or should the decided batch (Track B) come first end-to-end before any
   big-world work starts?
2. **Does phase 5 get a date box** like the friends-build push, or run open-ended? (The
   schedule doc's structure expects phases to be frozen snapshots with a live status
   row either way.)
3. **Who builds the height model**: the user said a separate session will; confirm that
   session takes Track D item 1 only (design), with the build a separate approval.
4. **Track E picks**, if any, to promote into the phase now rather than leaving them in
   the To-Do pool.

Once decided, the phase's bullet list freezes here (this doc), a one-line row joins the
schedule's §7 status table in both `schedule.md` and `schedule.html`, and per-item
status lives only in the CLAUDE.md To-Do, per the 2026-09-09 rule.
