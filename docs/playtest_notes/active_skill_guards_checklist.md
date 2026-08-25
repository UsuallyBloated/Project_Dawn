# Active Skill Guards Playtest Checklist — 2026-08-25

Verifies the fixes for active skills online: three skills silently aborted with runtime errors,
several were placebos, and CC spells crashed their own cast function against server enemies.

**Build prerequisite: client re-export only.** (Rides with the proximity-gate dialogue tweak.)

**What changed.**
| Thing | Was (online) | Now (online) |
|---|---|---|
| Shield Bash, Feign Death | silent runtime error *after* paying stamina + cooldown | honest refusal before any cost: "X isn't available online yet." |
| Evade, Holy Shield, Hide/Sneak | placebo (icon only, server ignores it) | same honest refusal |
| Backstab / Harm Touch / Flying Kick / Aimed Shot | work as normal swings | unchanged (multiplier gap is server work, tracked) |
| Warder's Fury | silent runtime error, warder never moved | routes through the real pet-attack command |
| CC spells (Ensnare, Slow, Immobilize, Spellbreak…) | runtime error aborting the cast function mid-way | land gracefully; the CC part does nothing visible (server has no enemy-CC model yet) |

Offline / Test Room: everything behaves exactly as before — the gates only bite in launcher mode.

---

## 1 — Honest refusals (online)

- [ ] **Use Shield Bash on a server enemy** → "Shield Bash isn't available online yet." and your
      stamina bar does NOT dip. notes:
- [ ] **Use Feign Death** → same refusal, no stamina cost, no cooldown started. notes:
- [ ] **Use Sneak/Hide (Rogue) or Evade** → same refusal. notes:
- [ ] **Use Backstab / a damage skill** → still swings and lands server damage as before. notes:

## 2 — Warder's Fury actually works now (Beast Master)

- [ ] **Summon the warder, target an enemy, use Warder's Fury** → the warder runs in and attacks,
      with the pet-attack chat line. (Before: nothing at all happened.) notes:

## 3 — CC spells no longer crash their own cast

- [ ] **Cast Ensnaring Roots / Slow / Immobilize on a server enemy** → the cast completes: mana
      spent once, damage (if any) lands, combat text appears. The root/slow itself does nothing
      visible — that's the known server gap, not a bug in this change. notes:
- [ ] **The enemy keeps behaving normally afterwards** (no client-side freeze or desync). notes:

## 4 — Offline regression (Test Room)

- [ ] **Shield Bash stuns a local enemy** as always. notes:
- [ ] **Feign Death de-aggros local enemies** as always. notes:
- [ ] **Sneak/Hide applies its buff** as always. notes:

---

## Result

- Client build (`/version`):
- Overall:
