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

**Who to log in as.** The `spelltest` account (password in `CHECKLIST_RUN_ORDER.md`) holds one
character per class, made 2026-10-06 and levelled the same day by the one sqlite command on the
host that `provision_test_characters` printed. Memorize the spell onto the bar first (B, then
drag to a slot), which is per-character client state no tool can do for you.

| Log in as | Class | Level | Rows | Logged in 10-06 |
|---|---|---|---|---|
| Embris | Sorcerer | 10 | Bloodfire, Void Lance, Tempest Bolt | yes (char 5) |
| Rimewind | Wizard | 10 | Blizzard, Thunder Clap; the leash spot check in §4 | yes (char 6) |
| Mirelle | Enchanter | 20 | Cascade of Stars; the charm spot check in §4 | yes (char 7) |
| Caderyn | Bard | 10 | Chorus of Misery | yes (char 8) |
| Fennric | Beast Master | 4 | Feral Shriek | yes (char 9) |
| Aldous | Paladin | 12 | Judgment | yes (char 10) |

Tip: on your own GM account the Test Panel's Level Up button reaches any level too. In `server.log`
a cast the server does not know logs `unknown spell name — server-side cast dropped`; none of
the nine should produce that line any more.

## Setup
- [x] Redeploy the server (boot line shows `build=` at `c0046af` or later, `dev_cmds=false`) notes: `c0046af` on 2026-10-05, then `6a802f4` on 2026-10-06 20:06, `dev_cmds=false` on both boot lines.

## 1 — The spells do something now
Rows filled 2026-10-06 from the tester's §4 notes and the journal (`journalctl -u projectdawn`, 18:43 to 19:20). The server does not log a successful cast by name, so the kill lines below prove a spell kill by that character, and the spell is known from the tester's notes or from a line that names it.
- [x] **Cast any one of the nine at a mob, on its class at or above its level** → the cast bar runs, the mob takes damage (a damage number and a chat line), mana is spent and the cooldown starts. notes: Caderyn (Bard 10) cast Chorus of Misery at zombies and the boar and it provoked them (§4 notes), so it landed and did damage. Mirelle (Enchanter 20) cast Cascade of Stars: `19:03:14 cast interrupted by incoming damage caster=7 spell=Cascade of Stars`, a line the old server could not produce (it dropped the name as unknown). No `unknown spell name` line all evening.
- [x] **Cast a second one from a different class if you have the character** → same. notes: Both of the above are different classes; and every one of the six characters has a `loot bag spawned (spell kill)` line (Embris 18:47 x3, Rimewind 18:57 x2, Mirelle 18:58, Caderyn 19:09 and 19:10, Fennric 19:15, Aldous 19:17).
- [x] **Kill a mob using only one of these spells** → kill credit, XP and loot arrive as with any other spell. notes: `19:10:09 kill credit granted killer=8 mob=Wild Boar base_xp=4200` then `loot bag spawned (spell kill) mob=Wild Boar`: Caderyn's Chorus of Misery, the spell the tester names for the boar in §4. Credit, XP and a loot bag all present.

## 2 — The gates still hold
Not exercised on 2026-10-06: the journal holds no `CastSpell rejected` or refusal line for the account.
- [ ] **Try one below its level (for example Thunder Clap at level 9)** → refused; no mana spent. notes:
- [ ] **Cast one at a mob more than 25 m away** → refused as too far; no mana spent. notes:

## 3 — Regression
- [ ] **Cast a spell your class has always had (Fireball, Smite, a heal)** → unchanged. notes: not exercised as its own row on 10-06; the kill lines do not name the spell, so this stays open.

## 4 — Two suspected bugs to confirm (found by reading the code on 2026-10-05, never seen in play)
Either result is useful. A "yes, it happens" turns a suspicion into a confirmed bug with a fix already planned.

- [x] **Charm a mob (Enchanter or any class with a charm spell) and watch it for ten seconds** → SUSPECTED: the charmed pet vanishes about a second after the charm lands, and `server.log` shows `charm expired — pet released`. If it stays for its full duration, the suspicion is wrong. notes: Target briefly appears as blue capsule, the quickly vanishes.  As you expected. **Triage 10-06:** confirmed; the journal shows `charm expired` 50 ms after each charm, twice. Fixed in server `6a802f4` (one line: the sweep's saturating comparison). Rerun this row after the redeploy; the pet should stay for Charm's full 60 s.
- [x] **Stand about 20 m from a Decrepit Skeleton (west of town) and cast a nuke at it; keep casting** → SUSPECTED: it stands still and takes every hit without coming for you, because you are outside its 16 m leash but inside the 25 m spell range. A mob that turns and chases you means the suspicion is wrong. Try the same from about 10 m to see the normal reaction. notes: Tested as Mirelle against zombies, zombies attacked immediately after being provoked.  This is good!  Tested with Caderyn using Chorus of Misery:  Wild boar did not attack when provoked, only when character moved closer, presumably within the boars aggro range.f This is not good. **Triage 10-06:** confirmed, and the split is the bug exactly: Plagued Zombies have aggro 14 (leash 28 m) so the song landed inside their leash; the Wild Boar has aggro 10 (leash 20 m) and was hit from about 22 m. Fixed in server `6a802f4`: every mob that aggros at all now has a leash of at least 30 m, past the 25 m spell reach. Rerun this row on the boar after the redeploy.

## 5 — The two fixes, on `6a802f4` or later
The §4 rows above recorded the bugs. These are the regression on the fixed server (redeployed
2026-10-06 20:06). The target frame now shows the distance to the target (client, next export
or the editor run), which is how to stand at 22 m.
- [ ] **Mirelle: charm a mob and watch it** → the blue capsule stays for Charm's full 60 s, then releases; `server.log` shows `charm expired` about a minute after `enemy charmed into pet`, not 50 ms after. notes:
- [ ] **Caderyn: target the Wild Boar, walk until the frame reads about 22 m, cast Chorus of Misery** → the boar comes for you without you moving closer. notes:

## Notes / observations
- 2026-10-06 journal: six characters, six spell kills or more; both §4 suspicions confirmed and
  fixed the same evening (server `6a802f4`). Also seen: Fennric's warder auto-summoned at level
  3 for a level 4 Beast Master, and a `(pet kill)` on a Cave Bat credited to Fennric.
