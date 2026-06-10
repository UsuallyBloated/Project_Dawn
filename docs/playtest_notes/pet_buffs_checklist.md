# Pet Buffs Playtest Checklist — 2026-06-10

Verifies pets are now stat-driven and ALLY buffs apply to them with real effects (not
cosmetic). Pets carry primary stats; STR buffs raise melee damage, Valor raises max HP,
Haste speeds swings, Spirit of Wolf speeds movement, HoTs heal over time. **Re-export
Project_Dawn and restart the server with the new build before running** (server `entity.rs`
/ `tick.rs`, client `remote_pet.gd` / `remote_pet_manager.gd` / `hud.gd` changed).

How pet stats work (so results are predictable):

| Buff | Effect on pet | Verify via |
|---|---|---|
| Strength (+12 STR) | +2 melee dmg (str delta / 5) | pet's hit numbers go up |
| Spirit of the Bear (+10 STR) | +2 melee dmg | hit numbers |
| Valor (+50 max HP) | pet HP pool grows | pet HP bar max |
| Haste (+50%) | pet swings ~1.5× faster | swing cadence |
| Spirit of Wolf (+40%) | pet moves faster | follow/chase speed |
| Healing Wave / Regrowth (HoT) | pet heals per tick | pet HP bar ticks up |
| Bless / Brilliance / Gift of Insight | stored on pet, no combat effect in v1 | icon only (by design) |
| Thorns | icon shows; reflect deferred (v1) | icon only — see §6 |

Tip: server logs `"ALLY pet buff applied"` (caster + pet target + spell) per pet buff —
grep `server.log`. Skeleton base melee dmg is 8; with +12 STR it should read 10.

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server (release build)
- [x] Caster A logged in (Necromancer for Summon Skeleton, or a class with a pet); a buffing
  alt B if testing cross-class buffs
- [x] A summons a pet (Necromancer **Summon Skeleton**, cost 60 — Full Heal first for mana)
- [x] Pull a weak enemy so the pet is actively meleeing (so damage/cadence is observable)

> **Mana caveat:** regen is disabled — **Test Panel → Full Heal** tops mana server-side. A
> failed cast prints "Cast failed: Not enough mana." Top up between casts.

## 1 — Stat buffs raise the pet's melee damage (the headline)
A targets its own pet and casts:

- [x] **Strength** on the pet → pet's hit numbers rise (skeleton 8 → 10). notes:
- [x] A (the caster) is **not** strengthened — only the pet. notes:
- [x] **Spirit of the Bear** on the pet (Shaman) → pet hit numbers rise. notes:
- [x] **Valor** on the pet (Cleric) → pet's **max HP grows** (+50 on the bar). notes:
- [x] Unbuffed baseline first: before any buff, confirm the pet hits for its base (skeleton
  8), so the increase is clearly the buff (no accidental rebalance). notes:

## 2 — Haste + Spirit of Wolf change pet behavior
- [x] **Haste** on the pet → pet's auto-attack visibly swings faster (~1.5×). notes:
- [x] **Spirit of Wolf** on the pet → pet moves noticeably faster when following/chasing. notes:

## 3 — HoT heals the pet
- [x] Let the pet take damage, then cast **Healing Wave** or **Regrowth** on it → pet HP
  ticks up over the duration (not a single jump). notes:

## 4 — Pet buff bar (target frame)
- [x] Target the pet → the target frame lists the pet's active buffs with live countdowns. notes:
- [x] A second buff on the pet appears as an additional line (stat buffs stack on pets too). notes: This is currently working as intended, but i would eventually prefer small buff icons.  The same image as the player's main buff bar, but small enough to fit in the target HUD.  And also scales with target HUD.
- [x] A bystander C targeting the same pet sees the same buff list (server-fanned). notes:

## 5 — Expiry returns the pet to baseline
- [x] Let a pet buff expire (or short-duration one) → its icon clears AND the effect reverts
  (STR buff: hit numbers drop back; Valor: max HP shrinks). notes:

## 6 — Thorns on a pet (v1 partial — expected)
- [x] Cast **Thorns** on the pet → "Thorns" icon shows on the pet. notes:
- [x] Pull an enemy onto the pet → **reflect damage does NOT happen yet** (deferred in v1;
  the icon/tracking is in place, the reflect hook is a follow-up). Confirm no crash. notes:

## 7 — Regression: unbuffed pets + buffing self
- [x] An unbuffed pet (no buffs) deals exactly its base damage (skeleton 8) — no rebalance. notes:
- [x] Casting a buff on **yourself** (no pet targeted) still self-buffs normally; the pet is
  unaffected. notes:
- [x] Casting Clarity on the pet → no effect (pets have no mana); icon may show, harmless. notes: Can you confirm this?

## Notes / observations
-Great work.
