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
- [ ] **XP/death penalty still applies** on death as before. notes:
- [ ] **Corpse loot still works** — return to your corpse and retrieve your gear. notes:
- [ ] **Resurrection still works** (Cleric/Paladin res on a corpse), and accepting still summons you
      to the corpse rather than the bind point. notes:
- [ ] **Offline / Test Room death still respawns you locally** (the client keeps its own path when
      there is no server). notes:

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

## Still untested (2026-08-13)
Sections 1-4 pass conclusively. These rows were NOT exercised and are the reason this is ticked as
"core feature proven" rather than "fully swept":
- §1 row 3 (corpse still present at the death site), §5 (bind refused while dead), and all of §6.
- **§6 matters most.** This change touched the death path, so **corpse loot** and **resurrection**
  are the two regressions with a real chance of being affected. Worth five minutes before this is
  considered closed for good.

## Notes / observations
> Design note: no post-respawn invulnerability was added. The reasoning is that a safe respawn
> location makes it unnecessary. If section 1 shows anything chasing you at the spawn point, say so
> and we will revisit that call.
-
