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

## Who can test what

Every gated skill, with its class (from `data/skill_definitions.gd`). Your existing characters
cover more than half of it — **plump the Paladin** alone covers a refusal row and a damage row.

| Skill | Class | Effect | What to expect online |
|---|---|---|---|
| Shield Bash | **Warrior** | STUN | refusal, no stamina cost |
| Feign Death | **Monk** | FEIGN_DEATH | refusal |
| Hide | **Rogue** | STEALTH | refusal |
| Evade | **Rogue** | EVADE | refusal |
| Primal Instinct | **Beast Master** | EVADE | refusal |
| Holy Shield | **Paladin** (plump ✓) | ABSORB | refusal |
| Divine Blow | **Paladin** (plump ✓) | damage 1.4x | works as a normal swing |
| Backstab | **Rogue** | damage 3.0x | works as a normal swing |
| Harm Touch | **Shadow Knight** | damage 2.5x | works as a normal swing |
| Flying Kick | **Monk** | damage 2.2x | works as a normal swing |
| Aimed Shot | **Ranger** | damage 3.0x | works as a normal swing |
| Warder's Fury | **Beast Master** | pet attack | **actually works now** |

CC spells for §3: **Ensnaring Roots (Druid — Chumby ✓)**, Entangle (Druid), Slow (Shaman),
Immobilize (Enchanter), Spellbreak (Witch Hunter).

The minimum coverage run: **plump** (Holy Shield refusal + Divine Blow swing), **Chumby**
(Ensnaring Roots for §3), plus one fresh **Warrior or Monk** for a crash-class refusal
(Shield Bash / Feign Death), and a **Beast Master** if you want §2.

## 1 — Honest refusals (online)

- [ ] **Use Shield Bash on a server enemy** (Warrior) → "Shield Bash isn't available online yet."
      and your stamina bar does NOT dip. notes:
- [ ] **Use Feign Death** (Monk) → same refusal, no stamina cost, no cooldown started. notes:
- [ ] **Use Hide or Evade** (Rogue) **or Holy Shield** (Paladin — plump) → same refusal. notes:
- [ ] **Use a damage skill** — Divine Blow (plump), or Backstab / Flying Kick / Aimed Shot →
      still swings and lands server damage as before. notes:

## 2 — Warder's Fury actually works now (Beast Master)

- [ ] **Summon the warder, target an enemy, use Warder's Fury** → the warder runs in and attacks,
      with the pet-attack chat line. (Before: nothing at all happened.) notes:

## 3 — CC spells no longer crash their own cast

- [ ] **Cast Ensnaring Roots (Chumby the Druid) / Slow (Shaman) / Immobilize (Enchanter) on a
      server enemy** → the cast completes: mana spent once, damage (if any) lands, combat text
      appears. The root/slow itself does nothing visible — that's the known server gap, not a bug
      in this change. notes:
- [ ] **The enemy keeps behaving normally afterwards** (no client-side freeze or desync). notes:

## 4 — Offline regression (Test Room)

- [ ] **Shield Bash stuns a local enemy** as always. notes:
- [ ] **Feign Death de-aggros local enemies** as always. notes:
- [ ] **Sneak/Hide applies its buff** as always. notes:

---

## Result

- Client build (`/version`):
- Overall:
