# Bind and Gate Playtest Checklist — 2026-10-08

Spell batch step 2 (design `docs/design/bind_and_gate.md`, the user's six calls of 10-05).
Bind Affinity and Gate are server spells now: the bind is the server's, Gate moves you with
the `Teleport` message, Succor and Evacuate land at the town square, and the client no longer
runs any of them locally online. **Needs a redeploy with the step 2 server commit or later AND
the next export** (the client's online gating is in the same batch). The server half alone
makes Gate reload the whole world scene on the old client, so run this sheet after the export.

| Spell | Who | Cost | Cast | Cooldown | Goes to |
|---|---|---|---|---|---|
| Bind Affinity | ten classes, level 1 | 30 mana | 3 s | none | sets the bind where the bound player stands |
| Gate | the same ten (Wizard, Druid, Cleric, Shaman, Necromancer, Magician, Sorcerer, Enchanter, Blood Mage, Bard), level 8 | 50 mana | 5 s | 300 s | your bind |
| Succor | Druid, Wizard, level 12 | 80 mana | 3 s | 60 s | the town square |
| Evacuate | Druid, level 16 | 120 mana | 5 s | 60 s | the town square, with your group in 30 m |

`server.log` anchors: `BIND applied caster=.. bound=.. x= z=`, `PORT applied caster=.. spell=..
port=bind|safe moved=N x= z=`, `CastSpell refused — target pre-flight ... spell=Bind Affinity`.
The `/loc` command gives you a position to compare against the log.

## Setup
- [ ] Redeploy the R720 with the step 2 server commit or later (boot line `dev_cmds=false`)
- [ ] Export the client from the same batch; `/version` on the login screen shows it
- [ ] A caster with Gate on the bar (Cleric 8 or any of the ten); `spelltest` has Rimewind (Wizard 10)

> **Known gotcha:** on the OLD client Gate still reloads the world scene locally while the
> server also moves you. If the world blinks and reloads, you are on a pre-step-2 export.

## 1 — Bind yourself, then Gate
- [ ] **Walk somewhere in the field (not the square), `/loc`, cast Bind Affinity with nothing targeted** → "Your soul is bound to this place." in chat; the log's `BIND applied` x/z match `/loc`. notes:
- [ ] **Cast Bind Affinity with a MOB targeted** → binds YOU where you stand (same line); the mob is not touched. notes:
- [ ] **Walk 30 m or more away, cast Gate (5 s bar)** → you land at the bind, not where you cast and not at the spawn; `PORT applied ... port=bind moved=1`. notes:
- [ ] **Cast Gate again straight away** → "Cast failed: Spell is on cooldown." and you do not move; mana stays. notes:
- [ ] **Log out and back in, then Gate (after the cooldown)** → the same bind: it is persisted. notes:
- [ ] **Die, Respawn** → you wake at the Bind Affinity bind (Respawn reads the same server bind). notes:

## 2 — No trains, and the pet comes along
- [ ] **Aggro a mob (let it hit you once), step out of its melee reach, cast Gate** → you land at the bind; the mob does NOT follow and walks home; nothing is beating on you at the bind. (A mob in melee range interrupts the bar on about 70% of hits: that is the channeling roll, not a bug. Use Evade or just distance.) notes:
- [ ] **Beast Master or a summoner: Gate with the pet out** → the pet is beside you at the bind in Follow stance; the pet panel still works. notes:
- [ ] **Park the pet with `/pet guard` 20 m from you, then Gate** → the pet still comes (user call D4: the pet always comes). notes:

## 3 — Binding another player (second seat)
- [ ] **Not grouped: target the other player anywhere and cast Bind Affinity** → "Cast failed: You can only bind yourself or a group member."; your mana does not dip. notes:
- [ ] **Grouped, the member stands OUTSIDE the town square (20 m or more from the spawn): cast on them** → "Cast failed: You can only bind another in a safe place, such as the town."; mana untouched. notes:
- [ ] **Grouped, the member stands IN the square: cast on them** → they get "Their soul is bound to this place."; their next Gate or Respawn lands there. notes:
- [ ] **Grouped, the member is DEAD in the square: cast on them** → "That target is no longer here." notes:

## 4 — Succor and Evacuate
- [ ] **Druid or Wizard 12: Succor from the field** → you land at the town square (`port=safe moved=1`). notes:
- [ ] **Druid 16 grouped with a second seat, both in the field within 30 m: Evacuate** → BOTH land in the square (`moved=2`); the member sees the move with no cast of their own. notes:
- [ ] **Same, but the member stands 40 m or more away** → only the caster moves (`moved=1`); the member stays. notes:
- [ ] **Same, but an UNGROUPED player stands beside the caster** → the stranger stays put. notes:

## 5 — Gates that must refuse
- [ ] **A class without Gate (Warrior, Monk) somehow fires it (hotbar from an old layout, or a macro)** → "Cast failed: ..." class refusal; nothing moves. notes:
- [ ] **Cast Gate and MOVE during the bar** → the cast cancels on the client ("You stop casting.") and you stay. notes:
- [ ] **Cast a zone port (Teleport: Greyveil, Circle of ...) online** → "<spell> isn't available online yet." before any bar; no mana. notes:

## 6 — Regression: nearby behavior unchanged
- [ ] **Sister Maelis still binds you** (right-click, bind) → "bound" line; Gate goes there afterwards. notes:
- [ ] **Resurrection accept still teleports you to the corpse** (not the bind). notes:
- [ ] **A kill in the field after a Gate** → XP and loot as before (the hate wipe did not break credit). notes:

## Notes / observations
-
