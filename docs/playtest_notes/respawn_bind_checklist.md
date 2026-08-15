# Respawn / Bind Point Playtest Checklist — 2026-08-12

Closes the respawn death-loop: the first external tester died, respawned on the spot beside the
two mobs that killed her, and died again 20 seconds later. Respawn now moves you.

**What changed.** The server owns your respawn location. `Respawn` teleports you to your **bind
point**, or to the **starter spawn** if you have never bound (never the death site). A new Soul
Binder NPC (**Sister Maelis**, at the town spawn) sets your bind. A **death lock** stops you walking
your corpse around during the respawn countdown.

**Build prereq (both halves):**
- [ ] Server: pull + `cargo build --release` + `cp target/release/projectdawn-server ~/` + restart.
      Migration `0011_bind_points.sql` applies automatically on boot.
- [ ] Client: rebuild gdext (`addons/gdext_net/build.ps1` or the bash fallback) **then** re-export.
      The DLL carries the new bind send, and the export must happen AFTER the rebuild.

> **Ordering trap:** verify the exported DLL matches the addon one before testing, or you will be
> testing a client that physically cannot send a bind:
> `md5sum builds/gdext_net.dll addons/gdext_net/gdext_net.dll`

Diagnostics: `journalctl -u projectdawn -f` on the host. Grep `bind point set` for binds.

## Setup
- [x] Server deployed + restarted (boot line still `dev_cmds=false rate_limit=false`)
- [x] Client gdext rebuilt, then re-exported; DLL hashes match
- [x] Log in with a character that can safely die (low stakes, no gear you mind dropping)

## 1 — The death loop is broken (the headline, works UNBOUND)
No bind needed for this section; unbound respawn goes to the starter spawn.
- [x] **Walk well away from town, let a mob kill you, wait out the respawn** → you reappear at the
      **town spawn**, NOT beside the mob that killed you. notes: confirmed, wakes up at town spawn.
- [x] **You are not immediately re-attacked** on arrival. notes: BUT found: mobs kept attacking the
      CORPSE at the death site. Fixed in server 97c7fac (dead players excluded from the enemy-AI
      target list + aggro/threat wiped on death). Re-tested: mobs break off immediately and return
      to their spawn points.
- [ ] **Your corpse is still back where you died** (the corpse run is intact — this fix must not have
      removed the corpse). notes:

## 2 — Death lock
- [x] **While dead (before respawn fires), try to move** → the character does not walk. notes: first
      pass showed the corpse TWITCHING (client still predicted + sent, server rejected and yanked it
      back). Fixed in client 80cbf55 (gate _physics_process on PlayerDeath.is_dead). Re-tested: no
      twitch at all.
- [x] **After respawning, movement works normally again.** notes:

## 3 — Binding with Sister Maelis
- [x] **Find Sister Maelis at the town spawn and talk to her** → dialogue opens, offering to bind.
      notes:
- [x] **Choose "Bind my soul to this place"** → she confirms, and the combat log says "Your soul is
      bound to this place." `journalctl` shows `bind point set` with your char_id. notes:
- [x] **Now go die somewhere far away** → you respawn **at Maelis / the bind point**. notes: see the
      DB proof below — visually inconclusive on its own.

## 4 — Bind persists
- [x] **Bind, log out, log back in, then die** → you still respawn at the bind point (it survived
      the relog, i.e. it persisted to the database, not just memory). notes: bind survived a relog
      AND a server restart + binary swap.
- [x] **(If convenient) restart the server, then die** → bind still honored. notes:

## 5 — Bind is refused while dead (guard)
- [ ] **Die, and while dead/awaiting respawn try to bind** (you would have to reach her as a corpse;
      if you cannot get there dead, mark `[-]`) → refused, no `bind point set` in the log. This guard
      stops a corpse binding where it fell, which would rebuild the loop. notes:

## 6 — Regression: nothing else about death changed
Swept 2026-08-14. The first three are proven by the server log, quoted below.
- [x] **XP/death penalty still applies** on death as before. notes: `level change char_id=4
      from=36 to=35` on death — the de-level penalty fired exactly as before.
- [x] **Corpse loot still works** — return to your corpse and retrieve your gear. notes:
      `corpse created char_id=4 corpse_id=2000000018 item_stacks=3`, then
      `corpse looted empty — despawned corpse_id=2000000018`. Gear went to the corpse and came back.
- [x] **Resurrection still works** (Cleric/Paladin res on a corpse), and accepting still summons you
      to the corpse rather than the bind point. notes: full chain in the log —
      `resurrection cast received spell=Reclaim Soul` -> `resurrection offered xp_percent=20` ->
      `resurrection accepted refund=45372`. The Paladin tier refunded 20% of that death's lost XP.
- [ ] **Offline / Test Room death still respawns you locally** (the client keeps its own path when
      there is no server). notes: not exercised — offline leaves no server-log trace, so this row
      needs an in-client check if we want it closed.

## DB proof (sections 3-4 were visually inconclusive)

Sister Maelis stands at `(-2, 0, 5)` and `STARTER_SPAWN` is `(0, 0, 0)` — about 5.4 units apart, so
"respawned at bind" and "fell back to the starter spawn" look identical in game. The checklist as
first written could not distinguish them. Resolved with the database instead:

```
-- after: die, respawn, DO NOT MOVE, log out cleanly (logout flushes position immediately)
SELECT name, pos_x, pos_z, bind_x, bind_z FROM characters WHERE id=1;
Pockets|-3.16501545906067|2.23090076446533|-3.16501545906067|2.23090076446533
```

`pos` equals `bind` to every decimal place. A fallback would have written `0 / 0`. That is
conclusive: the respawn teleported to the stored bind point.

Note the bind coordinates are the PLAYER's standing position, not Maelis's own `(-2, 0, 5)` — which
independently confirms `BindAtCurrentLocation` captures where you stand, as intended.

**Design note for later:** with a single Soul Binder standing at the spawn, a bind and the default
respawn are effectively the same place, so the feature has no *visible* effect yet. That is fine and
EQ-like (your bind is town until you find another binder), but a second binder elsewhere would make
it obvious.

## §6 regression sweep — PASSED (2026-08-14)

The concern was that the respawn/death-lock/aggro work had disturbed the death path. It had not.
Server log for the sweep, in order:

```
19:58:55  level change char_id=4 from=35 to=36        (dev level-up to set up the test)
20:01:27  bind point set char_id=4 x=-1.696 y=0.0 z=9.208
20:01:46  level change char_id=4 from=36 to=35        (DIED — de-level penalty applied)
20:01:47  corpse created char_id=4 corpse_id=2000000018 item_stacks=3
20:02:38  resurrection cast received caster=4 spell=Reclaim Soul corpse_id=2000000018
20:02:38  resurrection offered caster=4 corpse_id=2000000018 xp_percent=20
20:02:40  resurrection accepted char_id=4 corpse_id=2000000018 xp_percent=20 refund=45372
20:03:23  corpse looted empty — despawned corpse_id=2000000018 char_id=4
```

Death penalty, corpse creation with gear, resurrection (offer + accept + XP refund), and corpse
loot-to-despawn all still work. Also note the bind was re-set to a new position that session, so
`BindAtCurrentLocation` is repeatable rather than one-shot.

## Still open (small)
- §5 (bind refused while dead) — needs someone to actually attempt a bind as a corpse. The guard is
  in the handler and unit-reasoned, but not exercised.
- §6 row 4 (offline / Test Room respawn) — offline leaves no server-log trace, so it needs an
  in-client check.
- §1 row 3 (corpse present at the death site) — implicitly covered by the sweep above, which created
  and looted a corpse, but never checked as its own row.

## Notes / observations
> Design note: no post-respawn invulnerability was added. The reasoning is that a safe respawn
> location makes it unnecessary. If section 1 shows anything chasing you at the spawn point, say so
> and we will revisit that call.
-
