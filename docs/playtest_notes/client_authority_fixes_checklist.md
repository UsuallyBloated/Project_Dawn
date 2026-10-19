# Client-Authority Fixes Playtest Checklist — 2026-10-19

The first three fixes from the client-authority audit (`docs/security/client_authority_audit_2026_10_19.md`;
the rule, user 2026-10-19: "Events happening on the client are a no-go"). Each moves something
the client used to decide onto the server.

| Fix | What changed | Ships with |
|---|---|---|
| 1 | Made-up hit, miss and evade messages are GM-only (only the Test Panel sends them) | the next redeploy (server `23bba2c`) |
| 2 | The server decides movement speed: run speed x its own speed buffs x snare x carry weight; mounts refused online | **the Oct 22 bump, both sides together** (`feat/server-speed`, server `9a3e1aa`, client `291d433`). An older client against the new server walks at two thirds speed. |
| 3 | Spell power on the server: INT on nukes, WIS on heals, the casting-skill multipliers, spell crits | the next redeploy (server `b81da60`) |

Diagnostics: a GM's Test Panel hit lands in the GM action log (`admin_report`, `hit_broadcast`);
crits show as crit hits in the combat log; carry weight shows on the character sheet.

## Setup
- [ ] For §1 and §3: the server redeployed at `b81da60` or later (`build=` on the boot line)
- [ ] For §2: the Oct 22 redeploy and export (after `feat/server-speed` is merged)
- [ ] A GM account; for §1 a second seat (two-boxing works)

## 1 — Fake hits are GM-only
- [ ] **As a GM, Test Panel → hit / miss / evade buttons at a second seat** → the second seat still sees the combat text, as before. notes:
- [ ] **The second seat, sitting, takes one of those Test Panel hits** → (after the Oct 22 export) it stands up, as from any hit; this is the GM tool working. notes:

## 2 — The server decides speed (Oct 22 build)
- [ ] **Run in a straight line** → the same speed as before the change; no rubber-banding. notes:
- [ ] **Crouch and walk** → half speed, smooth. notes:
- [ ] **Cast Spirit of Wolf, run** → faster by about 40%, not double; no rubber-banding. notes:
- [ ] **Get snared by a mob, run** → slow on your screen without snapping back (if it snaps, note it: the client's own prediction of a snare is the known gap). notes:
- [ ] **GM: give yourself a pile of copper until the sheet shows over capacity, run** → slower, and the "You are encumbered!" line; past double capacity, a crawl and no stamina regen. notes:
- [ ] **Right-click a mount whistle** → "Mounts are not available online yet." and you stay on foot. notes:

## 3 — Spell power (next redeploy)
- [ ] **A caster casts a level 1 nuke at a mob several times** → bigger than before (a 30-damage nuke lands around 45 to 55 for a fresh caster), the numbers vary only by an occasional crit (shown as a crit, 1.5 to 2 times). notes:
- [ ] **A Cleric heals a hurt partner** → more than the spell's base (Healing Light 60 lands around 67 at level 1); the same number every cast. notes:
- [ ] **A DoT (Entangle, Dark Decay)** → its ticks are the same size as before; only the direct hit grew. notes:
- [ ] **Play an evening as a caster** → note whether low-level nukes now feel too strong; the formula is the client's as written, and `docs/design/spell_formula_research.md` has the options if it is. notes:

## Notes / observations
-
