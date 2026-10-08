# Global Cooldown Playtest Checklist — 2026-10-08

Spell batch step 4 (user call of 2026-10-05): after any cast, no spell may start for the
global cooldown, and every spell gem greys for it. Bard songs are exempt on both sides, so
twisting still works. The client refuses a cast inside it before any bar or mana
("You cannot cast again yet."); the server refuses the same at CastStart (a timed cast loses
no cast time) or at CastSpell (an instant one), with the true mana. **Needs the redeploy with
`9c4895e` or later AND the next export** (the gem greying and the client-side refusal
are in the client; on an old client the server still refuses, and you see "Cast failed: You
cannot cast again yet." with the bar cancelled).

| Side | Length | Where it bites |
|---|---|---|
| Client | 2.25 s (`Spells.GLOBAL_COOLDOWN_SECS`) | before the bar: no mana spent |
| Server | 2.0 s (`GLOBAL_COOLDOWN`) | CastStart (timed) or CastSpell (instant) |

The server's is a quarter second shorter, so an honest player who waits out the gems is
never refused. `server.log` anchors: `CastStart refused — inside the global cooldown` and
`CastSpell rejected — inside the global cooldown`, each with `remaining_ms`.

## Setup
- [ ] Redeploy the R720 with `9c4895e` or later (boot line `dev_cmds=false`)
- [ ] Export the client from the same batch; `/version` shows it
- [ ] A caster with several spells on the bar; a Bard with two or three songs on the bar (`spelltest` has Caderyn, Bard 10)

## 1 — The gems grey
- [ ] **Cast any instant spell (Smite)** → every spell gem on the hotbar and the spell bar greys for about two seconds with a countdown, then clears. notes:
- [ ] **Cast a timed spell (a 3 s heal)** → the gems grey when the cast LANDS, not when the bar starts. notes:
- [ ] **A spell with a longer cooldown of its own (Smite, 3 s) next to the others** → Smite's gem keeps its own 3 s countdown; the others clear at the global 2.25 s. notes:
- [ ] **Bard: cast a song** → the song gems do NOT grey; the Bard's non-song spells (Chorus of Misery) do. notes:

## 2 — The refusal
- [ ] **Press a second spell inside the two seconds** → "You cannot cast again yet." in chat, no cast bar, no mana spent. notes:
- [ ] **Hold the spell key down / mash it** → the next cast starts the moment the gems clear, not before, and lands. notes:
- [ ] **A refused cast (out of range, no target) then another spell at once** → the second cast goes through: a refusal starts no global cooldown. notes:
- [ ] **A cast you cancel by moving, then another spell at once** → goes through: a cancel starts none either. notes:

## 3 — Bards twist
- [ ] **Bard: cast three songs back to back as fast as the keys go** → all three land (chat shows each), no "cannot cast again yet". notes:
- [ ] **Bard: a song, then Chorus of Misery at once** → the nuke lands (a song starts no cooldown); then a second nuke at once is refused. notes:

## 4 — The server agrees (second seat optional)
- [ ] **Grep the log after §2** → no `inside the global cooldown` lines from honest play: the client refused first every time. notes:
- [ ] **Old client (if one is still around): mash two spells** → the server refuses the second with "Cast failed: You cannot cast again yet."; the mana bar settles on the true value. notes:

## 5 — Regression: nearby behavior unchanged
- [ ] **Per-spell cooldowns** (Smite's 3 s, Gate's 300 s) → still refuse as before, "Spell is on cooldown." notes:
- [ ] **A cast interrupted by a hit** → the interrupt charge (step 3) still applies; the global cooldown does not start on an interrupted cast. notes:
- [ ] **Melee auto-attack and active skills** → untouched; only spells share the global cooldown. notes:

## Notes / observations
-
