# Hunger Window Playtest Checklist — 2026-10-13

The hunger window (`docs/design/food_and_water.md` §8): a small panel below your character's
information bar with a Food and a Water bar, fed by the server; plus EQ's eating emote for the
people around you. **Rides the Oct 22 bump day** (PD_W0028): it needs the server redeployed from
the merged trade branch AND the new export with the rebuilt `gdext_net.dll`. Run
`godot --headless --path . -s tools/check_wire_layer.gd` on the export's checkout first; it must
list `hunger_update` as OK.

| What | Where it comes from |
|---|---|
| Bars | the server's counters (`HungerUpdate`, owner only): on entering, after any eat or drink, on a stage change, on death and respawn, and once a minute; the bars run down smoothly between sends |
| Colours | green fed; amber under 12 units (when the server says "You are hungry." / "thirsty"); red and empty when out |
| Hover | "Fed, about 2 h 10 min", "Hungry, 20 min left", "Out of food" (real time at your race's rate) |
| Emote | others within say range see `Chomp, chomp, chomp... <you> takes a bite from a <item>.` (drink: `Glug, glug, glug... <you> takes a drink from a <item>.`) |

Diagnostics: `server.log` anchors `auto-eat: the first in slot order`, `auto-drink: the first in
slot order`, `UseConsumable rejected — full`. A Test Panel GM can set appetite only by database
edit today; to start hungry, use `set_char_appetite`'s SQL on a copy, or just play long enough.

## 1 — The window

- [ ] **Enter the world** → a small panel sits directly below your character's HP/MP/stamina window, as wide as it, with a Food and a Water bar, both full and green. notes:
- [ ] **Hover each bar** → "Fed, about N h N min"; the time matches your race (a Halfling's is half a Human's). notes:
- [ ] **Watch a bar for a minute** → it creeps down smoothly; it does not jump when the server's minute update lands. notes:
- [ ] **Drag the panel somewhere else** → it moves like the other panels (its position is not remembered across a relog; no HUD panel's is yet). notes:
- [ ] **Full bars stay shown** → the panel never hides because you are full (decision b). notes:

## 2 — Eating and drinking

- [ ] **Right-click a Bread Loaf while full** → refused with "You could not possibly eat any more, you would explode!" in chat, and the Food bar flashes twice. Nothing is taken. notes:
- [ ] **Right-click a Water Flask while full** → the same for water; only the Water bar flashes. notes:
- [ ] **Eat by hand once a bar has room** → the bar jumps up at once by half the loaf's size (a hand-eat feeds half), and "You eat a Bread Loaf." in chat. notes:
- [ ] **Let a bar run out with food in your bags** (or start low) → you eat on your own the moment it empties; the bar jumps up; you are never told "You are out of food." notes:
- [ ] **Run out with nothing to eat** → the bar turns red and empty, hover says "Out of food", and HP stops regenerating. notes:

## 3 — The emote (two seats)

- [ ] **Seat B stands beside seat A; A eats by hand** → B's chat shows `Chomp, chomp, chomp... <A> takes a bite from a Bread Loaf.` A does not see that line, only "You eat a Bread Loaf." notes:
- [ ] **A drinks** → B sees the `Glug, glug, glug...` line. notes:
- [ ] **A auto-eats** (runs out with bread in the bags) → B sees the emote for that too. notes:
- [ ] **B walks two cells away (over 120 m) and A eats** → B sees nothing. notes:
- [ ] **B's own bars never move when A eats** → the window is yours alone. notes:

## 4 — Death and stage changes

- [ ] **Die** → both bars stop moving while you are dead (hover says "Fed" with no time). notes:
- [ ] **Respawn** → the bars start moving again. notes:
- [ ] **Cross into Hungry** → the bar turns amber the moment "You are hungry." appears in chat. notes:

## Notes / observations
