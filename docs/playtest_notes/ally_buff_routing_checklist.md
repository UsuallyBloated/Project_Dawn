# ALLY-Target Buff Routing Playtest Checklist — 2026-06-09

Covers making 10 buffs castable on a targeted group-mate over the wire (was: every buff
self-only). **Re-export Project_Dawn and restart the server with the new build before
running** (server `spells.toml` + `tick.rs` changed; client `spells.gd` /
`buff_manager.gd` / `spell_definitions.gd` changed).

The 10 ally-castable buffs + who casts them (and min level):

| Buff | Effect | Caster(s) | Lvl |
|---|---|---|---|
| Bless | +5 WIS | Cleric, Paladin | 4 |
| Strength | +12 STR | Enchanter | 8 |
| Valor | +10 STR, +50 max HP | Cleric | 10 |
| Spirit of the Bear | +10 STR, +5 CON | Shaman | 10 |
| Brilliance | +10 INT, +5 WIS | Enchanter | 10 |
| Thorns | damage shield (8 nature/hit) | Druid | 10 |
| Spirit of Wolf | +40% move speed | Druid, Shaman | 12 |
| Clarity | +8 MP/s regen | Enchanter | 14 |
| Gift of Insight | +8 WIS, +5 INT | Shaman | 14 |
| Haste | +50% attack speed | Enchanter | 16 |

Tip: keep the in-game console open on **both** clients (F2 / backtick) for client-side state
(BuffSnapshot → reconcile). Server-side, the cast route now logs `"ALLY buff applied"`
(caster + target + spell) on each peer buff — grep `server.log` for it to confirm the
server applied to the right target. Heals still log `"ALLY heal applied"`.

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server (release build)
- [x] Two clients logged in: A (caster, a buffing class) and B (target)
- [x] A invites B, B accepts → both HUDs show the 2-person group roster
- [x] `/pvp off` on both (default) unless a section says otherwise

> **Mana caveat:** regen is currently **disabled** (commit 835d442 — food/water gates it),
> so a buffing class drains fast and won't recover on its own. **Test Panel → Full Heal now
> restores MP server-side.** Click Full Heal to top A off between casts; one refill covers
> several buffs. A failed cast now prints "Cast failed: Not enough mana." in the combat log,
> so watch for that — if you see it, top up before continuing.

## 1 — Core: buff lands on the targeted ally, NOT the caster (the headline)
For each buff, A targets **B** (click B / tab to B) and casts. Open B's character window
to read stats. Full Heal A first so no cast silently fails for mana.

- [x] **Bless** on B → B's **WIS +5**; "Bless" icon appears on B's buff bar. notes:
- [x] A's own WIS is **unchanged** and A has **no** Bless icon. notes:
- [x] **Strength** on B → B's STR +12; icon on B; A unaffected. notes:
- [x] **Valor** on B → B's STR +10 **and max HP +50**; icon on B; A unaffected. notes:
- [x] **Brilliance** on B → B's INT +10 / WIS +5; icon on B. notes:
- [x] **Spirit of the Bear** on B → B's STR +10 / CON +5; icon on B. notes:
- [x] **Gift of Insight** on B → B's WIS +8 / INT +5; icon on B. notes:
- [x] **Stacking:** Bless **then** Valor **then** Strength on B → all three stick at once
  (B shows WIS+5, STR+22, max HP+50; three separate icons). notes:

## 2 — Non-stat buff types land on the ally (effect, not just icon)
- [x] **Clarity** on B → B's mana ticks up faster; "Clarity" icon on B; A's mana regen normal. notes:
- [x] **Haste** on B → B's melee auto-attack visibly swings faster; "Haste" icon on B. notes:
- [x] **Spirit of Wolf** on B → B **moves faster**; SoW icon on B; A's speed normal. notes:
- [x] **Thorns** on B → pull an enemy onto B; enemies hitting B take nature damage back
  (combat log / floating numbers); "Thorns" icon on B. notes:

## 3 — Self-cast still works (no target / self targeted)
- [x] With **no target** (or A targeting A), A casts **Bless** → A gets WIS +5 + icon (self-buff). notes:
- [x] Same for **Clarity** / **Haste** / **Spirit of Wolf** on self → A buffed normally. notes:

## 4 — Fallback targets (no flicker, no lost buff)
- [x] A targets an **enemy NPC** and casts **Strength** → A self-buffs (server self-casts);
  the buff sticks (does NOT flash on then vanish). notes:
- [x] A targets **A's own pet** (Beast Master/Necromancer warder/skeleton) and casts a pure
  buff (e.g. Bless) → falls back to buffing **A** (pet buffs deferred); buff sticks. notes:
- [x] A targets a **pet** and casts a **heal** (e.g. Spirit Mend / Warder's Mend path) →
  the **pet** is healed, not A (heals still route to pets). notes:

## 5 — Expiry + dispel reconcile on the recipient
- [x] Buff B, then let a short one expire server-side → B's icon clears **and the stat
  returns** (e.g. WIS back down) within ~1 tick. notes:
- [x] `/pvp on` both. A buffs B (group-mate, allowed). C (a third client, ungrouped, /pvp on)
  casts **Antimagic Ward** or **Expose** on B → B's reconstructed buff clears + stat reverts. notes:

## 6 — Bystander (third-party) view
- [x] A buffs B. A third client C (in range) targets B → C sees the buff on B's target-frame
  buff bar (remote render path). notes:

## 7 — PvP gate (beneficial cast refused on a hostile)
- [x] `/pvp on` on A. A targets an **ungrouped** player D and casts **Bless** →
  "You cannot cast that on an enemy." No mana spent, no cast bar. notes:
- [x] `/pvp on` on A. A targets **grouped** B and casts Bless → **allowed**, lands on B. notes:
- [x] `/pvp off` on A. A targets ungrouped D and casts Bless → cast proceeds (peer state is
  server-side); server applies or rejects per D's flag. notes:

## 8 — Class spread (each casting class routes correctly)
- [x] **Cleric** Bless/Valor on B → lands. notes:
- [x] **Enchanter** Clarity/Haste/Strength/Brilliance on B → land. notes:
- [x] **Druid** Spirit of Wolf / Thorns on B → land. notes:
- [x] **Shaman** Spirit of the Bear / Gift of Insight / Spirit of Wolf on B → land. notes:
- [x] **Paladin** Bless on B → lands. notes:

## 9 — Regression: self-only buffs unchanged
- [x] **Rune** (Enchanter) cast with B targeted → buffs **A** (still self-only); B unaffected. notes:
- [x] **Spellshield** (Enchanter) with B targeted → buffs A; B unaffected. notes:
- [x] **Hunter's Eye** (Ranger), **Lich Form** (Necro), Bard songs → still self / unchanged. notes:

## Notes / observations
-Great work.
