# Ported Spells Playtest Checklist — 2026-10-05

Nine ordinary class nukes existed on the client but not on the server, so casting one online
did nothing: the server refused it as an unknown spell. They are now in the server's spell
data. **Server-only: needs the R720 on `c0046af` or later. No client export needed**; the
client has always had these on its bars.

| Spell | Class | Level | Cast | Damage |
|---|---|---|---|---|
| Bloodfire | Sorcerer | 4 | instant | 40 fire |
| Void Lance | Sorcerer | 6 | 1.0 s | 55 arcane |
| Tempest Bolt | Sorcerer | 10 | 1.5 s | 65 lightning |
| Blizzard | Wizard | 8 | 2.0 s | 65 ice |
| Thunder Clap | Wizard | 10 | 2.5 s | 100 lightning |
| Cascade of Stars | Enchanter | 12 | 1.5 s | 55 arcane |
| Chorus of Misery | Bard | 10 | 1.5 s | 45 arcane |
| Feral Shriek | Beast Master | 4 | instant | 35 spirit |
| Judgment | Paladin | 12 | 2.0 s | 80 holy |

Tip: a GM account can reach the level with the Test Panel's Level Up button. In `server.log`
a cast the server does not know logs `unknown spell name — server-side cast dropped`; none of
the nine should produce that line any more.

## Setup
- [ ] Redeploy the server (boot line shows `build=` at `c0046af` or later, `dev_cmds=false`)

## 1 — The spells do something now
- [ ] **Cast any one of the nine at a mob, on its class at or above its level** → the cast bar runs, the mob takes damage (a damage number and a chat line), mana is spent and the cooldown starts. notes:
- [ ] **Cast a second one from a different class if you have the character** → same. notes:
- [ ] **Kill a mob using only one of these spells** → kill credit, XP and loot arrive as with any other spell. notes:

## 2 — The gates still hold
- [ ] **Try one below its level (for example Thunder Clap at level 9)** → refused; no mana spent. notes:
- [ ] **Cast one at a mob more than 25 m away** → refused as too far; no mana spent. notes:

## 3 — Regression
- [ ] **Cast a spell your class has always had (Fireball, Smite, a heal)** → unchanged. notes:

## 4 — Two suspected bugs to confirm (found by reading the code on 2026-10-05, never seen in play)
Either result is useful. A "yes, it happens" turns a suspicion into a confirmed bug with a fix already planned.

- [ ] **Charm a mob (Enchanter or any class with a charm spell) and watch it for ten seconds** → SUSPECTED: the charmed pet vanishes about a second after the charm lands, and `server.log` shows `charm expired — pet released`. If it stays for its full duration, the suspicion is wrong. notes:
- [ ] **Stand about 20 m from a Decrepit Skeleton (west of town) and cast a nuke at it; keep casting** → SUSPECTED: it stands still and takes every hit without coming for you, because you are outside its 16 m leash but inside the 25 m spell range. A mob that turns and chases you means the suspicion is wrong. Try the same from about 10 m to see the normal reaction. notes:

## Notes / observations
-
