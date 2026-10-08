# Interrupted Casts Cost Mana Playtest Checklist — 2026-10-08

Spell batch step 3 (user call of 2026-10-05): a cast that a HIT interrupts costs the spell's
mana in proportion to how far the bar had run, capped at what you have. A deliberate cancel
(moving, ESC) stays free, and a hit that did no damage charges nothing. Server-only: **needs a
redeploy with `4303459` or later**; the client testers hold already settles the bar on the
server's `ManaUpdate`. Old client builds show the refund for one frame, then the true value.

The numbers: `charge = mana_cost x (seconds into the bar / the spell's cast time)`, rounded
in the chat line. Bind Affinity (30 mana, 3 s) interrupted at 1.5 s costs 15; Gate (50 mana,
5 s) interrupted at 4 s costs 40. The server's cast time is used, never the client's bar.

`server.log` anchors: `cast interrupted by incoming damage caster=.. spell=.. mana_charged=..`
(and the PvP flavours); the chat line is "Your concentration breaks: N mana lost."

## Setup
- [ ] Redeploy the R720 with the step 3 commit or later (boot line `dev_cmds=false`)
- [ ] A caster at full mana standing next to a mob that hits for real (a Rotting Skeleton or a Gnoll Raider; the Decrepit Skeletons hit for 3, which is fine too)

> **Known gotcha:** the interrupt itself is a roll (about 70% per hit at Channeling 0, less as
> the skill rises). A cast that survives a hit costs nothing extra; keep casting until one is
> interrupted. Watch the console: `Cast failed: interrupted (hit during cast)` is the row.

## 1 — An interrupt costs part of the mana
- [ ] **Start a long cast (Bind Affinity 3 s, or Gate 5 s) with a mob beating on you; wait for an interrupt** → "Cast failed: interrupted (hit during cast)" then "Your concentration breaks: N mana lost."; the mana bar lands N below where it was, and stays there (no refund creeping back). notes:
- [ ] **Compare N with the log's `mana_charged`** → the same number (rounded). notes:
- [ ] **Note how far the bar had run when the hit landed** → N is about that fraction of the spell's cost (early hit: small; late hit: nearly the whole cost). notes:
- [ ] **Interrupted with less mana than the charge** → the bar goes to zero, not below; the line says what was taken. notes:

## 2 — What stays free
- [ ] **Start a cast and MOVE before it finishes** → "You stop casting."; full mana back; no "concentration breaks" line. notes:
- [ ] **Start a cast and press ESC** → same: free. notes:
- [ ] **A cast that is refused by the server (out of range, on cooldown, no target)** → costs nothing, as before. notes:
- [ ] **Rune or another absorb up, a hit fully absorbed while casting** → if the cast is interrupted at all, no mana is charged (the line does not appear). notes:

## 3 — Group view (second seat)
- [ ] **A group-mate watches your mana bar in the group panel while you are interrupted** → their copy of your bar drops by the same N (the server fans the true value to everyone). notes:

## 4 — Regression: nearby behavior unchanged
- [ ] **A cast that survives a hit (no interrupt)** → completes, costs the normal full price once, Channeling can skill up. notes:
- [ ] **An instant cast (Smite) while being hit** → unaffected. notes:

## Notes / observations
-
