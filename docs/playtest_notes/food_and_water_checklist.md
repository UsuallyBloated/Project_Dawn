# Food and Water (the EQ way) Playtest Checklist — slice 1

The character carries food and drink and eats and drinks them by itself; being out of
either stops natural regeneration. Design: `docs/design/food_and_water.md` (decided
2026-10-13). Server half on `feat/food-and-water` (merged for the Oct 22 redeploy); the
client half (the item sizes, the tooltip) rides the same day's export. The hunger window
is planned separately: for this sitting the chat lines are the only indicator, as in EQ.

**Needs:** the redeploy with the food branch AND the new export (the old client shows the
old buff-style tooltip, nothing worse). A character of level 5 or more with an empty
stomach is the quickest way to see the regen gate; the Test Panel can set HP low.

| Thing | Where | Notes |
|---|---|---|
| The counters | not on the HUD yet | every character migrates FULL (4 hours of each); to test the famished state fast, ask for a GM hand (the counters are columns `hunger` and `thirst` on `characters`, seconds; set them to 0 on the host) |
| The lines | chat, System channel | `You are hungry.` / `You are thirsty.` at about 29 minutes left; `You are out of food.` / `You are out of water.` at zero; `You eat a Bread Loaf.` / `You drink a Water Flask.` on an auto-eat |
| Log lines | `server.log`: `auto-eat: the first in slot order`, `auto-drink: ...`, `UseConsumable rejected — full` | |
| Sizes | tooltip: `Food: a meal (48 min)`, `Drink: a drink (36 min)` | Bread Loaf 2880 s, Water Flask 2160 s |

## Setup
- [ ] Server from `feat/food-and-water` (or the deploy branch after its merge); boot line shows the new `build=`. notes:
- [ ] The new export (the tooltip on a Bread Loaf reads `Food: a meal (48 min)`). notes:
- [ ] A character with bread and water in the bags, counters set to 0 on the host for the fast rows (or a long evening for the slow ones). notes:

## 1 — Eating and drinking happen on their own
- [ ] **Log in with the counters at 0 and bread in base slot 3, more bread in a pouch** → within a second: `You eat a Bread Loaf.`, the base-slot stack loses one, the pouch is untouched; same for water (`You drink a Water Flask.`). notes:
- [ ] **Watch the log** → one `auto-eat` line per eat, naming `base` slot 3. notes:
- [ ] **Move the only bread into the pouch and empty the counter again (GM)** → the pouch's loaf is eaten this time (slot order reaches into bags). notes:

## 2 — The stages, told once
- [ ] **Set hunger to 2000 s (GM) and play on** → one `You are hungry.` as it passes about 1728 s left, and nothing more for the next minutes. notes:
- [ ] **Let it reach 0 with no bread carried** → one `You are out of food.`, then silence (no line per tick). notes:
- [ ] **Buy bread and put it in a bag** → it is eaten at once (the counter was already 0) and the lines stop. notes:

## 3 — No food, no regen
- [ ] **Out of food, HP below max, stand still out of combat for a minute** → HP does not rise; mana does (water is fine). notes:
- [ ] **Out of water instead** → mana does not rise; HP does. notes:
- [ ] **Out of either** → stamina does not rise. notes:
- [ ] **Eat (auto or by hand)** → regen resumes on the next tick; a heal spell and a potion worked throughout (only natural regen stops). notes:

## 4 — Eating by hand, EQ's rules
- [ ] **Right-click a Bread Loaf when full** → `You could not possibly eat any more, you would explode!`; the loaf stays. notes:
- [ ] **Right-click one when merely not full** → it is taken, and feeds for half its size (a GM reading the column: +1440 s, not +2880). notes:
- [ ] **Right-click a Water Flask when full** → the drink line of the same refusal. notes:

## 5 — Persistence and the dead
- [ ] **Log out with the counters part-way, log back in** → they continue from where they were (no drain while offline). notes:
- [ ] **Die with the counters low, lie dead for two minutes, respawn** → the counters did not move while dead; they resume on respawn. notes:
- [ ] **Play a Halfling and a Human side by side for ten minutes** → the Halfling's counters fall twice as fast (GM reads the columns). notes:

## 6 — Regression
- [ ] **A heal potion and a mana potion** → work as before (instant, no counter involved). notes:
- [ ] **The buff bar** → shows no food or drink entry any more; nothing else changed. notes:
- [ ] **The Revenant** (if one can be made) → its counters never move. notes:

## Notes / observations
-
