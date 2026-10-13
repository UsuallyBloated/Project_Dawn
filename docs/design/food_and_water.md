# Food and water, the EverQuest way

> **Status: DESIGNED 2026-10-12; ALL SIX DECIDED 2026-10-13 (user); SLICE 1 BUILT AND
> REVIEWED 2026-10-13, pending merge and playtest** (server `feat/food-and-water`, client
> `7728793` + `6b63ffe`; `food_and_water_checklist.md`, 20 rows; section 7 carries the
> decisions, section 5 the slices; the review's findings are folded into sections 3 and 4). The user's direction of
> 2026-10-12: "Our food and water system needs to work like EQ. Instead of like quick
> consumables." This replaces the buff model the consumables design assumed
> (`docs/concepts/tradeskills/consumables.md` "The Regen Loop") and the To-Do item
> "EQ-style food/water gating".

## 1. What EverQuest does

Researched 2026-10-12 from the Project 1999 wiki and forums and the EQEmulator forums (the
classic era; EverQuest II is a different game and was ignored). Sources at the end.

- **A character carries food and drink and eats and drinks them by itself.** Two hidden
  counters, hunger and thirst, run down in real time. When one empties, the game eats (or
  drinks) the first matching item it finds in the inventory, top-left first, bags included,
  and the counter refills by that item's size. "Only the top food in your inventory, ready
  to eat next" is what will be consumed; nothing else in the bags matters until it is.
- **Food has a size, not a buff.** An item's "duration" is the real time it feeds you for:
  one unit is 144 seconds; a snack is 1 to 5 units (about 2 to 12 minutes), a meal 6 to 20
  (14 to 48 minutes), a hearty meal 21 to 30, a banquet 31 to 40, a feast 41 to 50, an
  enduring meal 51 to 60, a miraculous meal 61 to 240 (nearly ten hours). The game checks
  whether it is time to eat about every 46 seconds, so there is a small lag. Drink is the
  same with its own names (whistle wetter, drink, refreshing, lasting, flowing, enduring,
  miraculous).
- **Hunger has stages, and the last one stops regeneration.** "You are hungry." and "You
  are thirsty." are the warnings; at the final stage, hit points and mana stop
  regenerating, and the P99 wiki says both food and drink are needed for mana and
  endurance to regenerate at all. The stage timing depends on the race (the wiki puts the
  final stage at about 90 minutes without a meal for a Halfling and 3 hours for a Human).
  Nobody dies of hunger, and there is no stat penalty.
- **Eating by hand is allowed only when there is room.** Clicking a food when full is
  refused with "You could not possibly eat any more, you would explode!" (drink likewise).
  Clicking a food early, when not yet hungry but not full, eats it for half its duration,
  which is how a player keeps a prized item from being auto-eaten (see stat food).
- **Stat food.** Some food carries stat bonuses; they apply while that item is the next to
  be eaten, so the classic trick is to keep the good item in the first slot and hand-eat
  cheaper food before it would be reached. Clicking the stat food itself eats it.
- **Modifiers.** On a mount food and drink go three times as fast; in a desert, drink goes
  twice as fast (six on a mount); you do not eat while zoning or dead; the Innate
  Metabolism AA slows consumption by about 2.5x.
- **Summoned food and water** (Summon Food, Summon Drink: Magician, Cleric, Druid lines)
  are ordinary small items that stack, the way a caster keeps a group fed.

## 2. What exists here today

- **Two items:** Bread Loaf (`food_hp_regen 4`, `food_duration 180`) and Water Flask
  (`food_mp_regen 5`, `food_duration 180`), both sold by the General Merchant, both also
  handed out by the Test Panel. No summon-food spell exists.
- **A click-to-use buff model.** Right-click sends `UseConsumable`; the server takes the
  stack, applies a 180 s HoT or MP-regen buff named `Food: <item>` / `Drink: <item>`
  (the mana leg is named `Drink MP: <item>`), fans a BuffSnapshot, and the client's buff bar
  shows a timer. The server refuses a second food or drink while one runs, except that the
  mana-only leg's name does not start with `Drink: `, so a second Water Flask IS taken while
  the first still runs: the "stacking flasks" the user saw on 2026-10-07 (fixed server-side
  2026-10-12 as a stopgap; it will not matter once this design lands).
- **Offline code** (`inventory_window.gd`, `bag_window.gd`, `BuffManager.add_food_buff`)
  applies the same buffs locally; it is vestigial (the project is multiplayer-only).
- **Regen** is server-authoritative (`world/regen.rs::tick_one`): per-level HP tables,
  sitting and meditate rates for mana, a flat stamina rate. Nothing about food reaches it;
  the food buffs are separate ticks in the buff step. Nothing is persisted about hunger.
- **A design hook already written:** the Revenant transformation is "immune to starvation
  and thirst; food/drink provide no benefit" (`docs/concepts/transformations/revenant.md`).

## 3. The design

Server-authoritative, one rule set, no client authority anywhere.

**Two counters on the character, persisted.** `hunger` and `thirst`, in seconds of fullness,
0 to a cap. Every character is born full. They run down one second per real second while
the character is in the world and alive (not while dead, not while offline, not in the
character select); the restart checkpoint writes them with the other resources.

**Eating is the server's job.** Every tick the server looks at each living in-world
character (as built; EQ checks about every 46 s, and checking every tick only trims that
lag): if `hunger` is at zero, it searches the inventory in slot order, base slots first
then bags in order, for the first item with `is_food`, takes one, and adds the item's size
to `hunger` (capped). Same for thirst with `is_drink`. The take is an ordinary inventory
write (the existing `decrement_at` + `InventoryDelta` path), so the client's bags update as
they do for any server-side removal. The character is told: "You eat a Bread Loaf." /
"You drink a Water Flask." in the System channel. The eat runs BEFORE the stage lines, so
a character that runs out with bread in the bags is fed that tick and never told it is
out of food.

**Hunger has three stages, told once each.** Full (above `HUNGRY_AT`): nothing. Hungry
(`HUNGRY_AT` down to 0): one line, "You are hungry." (or thirsty). Famished (0): one line,
"You are out of food." (or water), unless something was eaten that tick; the regen penalty
applies. Lines repeat only when the stage is re-entered, never per tick, and a character
that logs in hungry or out is told its stage once on entering the world (the counters do
not move offline, so the transition happened before it left).

**The penalty is EQ's: regeneration, not health.** `regen.rs::tick_one` gates on the two
flags: famished for food stops natural HP regen; famished for drink stops natural mana
regen; either stops stamina regen (EQ ties endurance to both). Nothing else: no damage, no
stat loss, no slowing, and the dead do not starve. Spells and potions still heal; sitting
still raises the rate when you are fed.

**Food size replaces the buff.** `ItemData.food_duration` is read as the fullness an item
adds, in seconds (Bread Loaf's 180 s is a snack by EQ's scale; section 7 decides the
numbers). `food_hp_regen` / `food_mp_regen` go away as effects; a FED character regenerates
at the normal tables, which is the whole benefit. (The consumables tradeskill doc's tiers
map onto sizes: a Simple Bread feeds longer than Hard Tack, a Lembas for hours; its stat
bonuses become stat food, below.)

**Eating by hand stays, with EQ's rules.** Right-clicking a food when `hunger` is at the cap
is refused with EQ's own line ("You could not possibly eat any more, you would explode!");
when there is room it eats the item now, for half its size (the hand-eat halving is what
keeps the auto-eat order meaningful). The `UseConsumable` arm keeps its potion path (heal
and mana potions are instant and unchanged).

**Stat food, when the tradeskill pass adds any.** The bonuses on the first food in slot order
apply while that item is next to be eaten; recomputed on every inventory change for that
character. Not in slice 1 (no item carries stats yet), designed so the slot-order rule is
already the one EQ's trick relies on.

**Modifiers.** The race multiplier is one table, `hunger::race_drain_multiplier` (decision 3
chose a toml beside the camps; a six-arm match with a unit test is the same fact in one
place and was built instead). Deferred: mounts (3x) when the mount system is server-side; a
desert zone multiplier with the multi-zone epic. The Revenant's immunity is NOT keyed on the
race string: the review found that a modified launcher could create a "Revenant" (its stat
block exists for the transformation; `create_character` validated only the name) and be
starvation-immune for life. Creation now accepts only the sixteen birth races and the
eighteen classes, and the immunity waits for the transformation to be server-side, keyed on
that state.

**The client shows the state and never decides it.** The buff bar's food and drink timers
become two small hunger and thirst indicators (three states each: fed, hungry, out), fed by a
new `HungerUpdate { hunger_secs, thirst_secs, hunger_cap, thirst_cap }` sent to the
character alone on EnterWorld, on every change of stage, after every eat and drink, and
otherwise once a minute (so a countdown can be drawn without a message per second). The
chat lines come from the server. `BuffManager`'s food and drink buffs, `Regen`'s use of
them and the two windows' offline eat paths are deleted.

## 4. Exploit ledger

1. **A forged `UseConsumable` cannot overfeed:** the server refuses at the cap and halves a
   hand-eat; nothing is minted either way.
2. **A forged inventory order cannot gain anything:** slot order only chooses WHICH food is
   eaten, as in EQ; every food feeds by its own size.
3. **Logging out does not pause hunger for free:** the counters are persisted at the
   checkpoint and on disconnect, and do not run while offline, which is EQ's rule too (you
   are not eating in the character select). The gain from logging out to avoid eating is
   nil: you come back exactly as hungry.
4. **Death does not reset the counters** (a famished player who dies and respawns is still
   famished; a corpse run on no regen is EQ's lesson about packing food). The death strip
   takes the food to the corpse like everything else.
5. **The drain runs on the server clock, never on a client message**, so a client that
   sends nothing cannot stay fed, and a client that floods cannot eat faster.
6. **Stat food's bonus is recomputed server-side from the real inventory**, so a client
   cannot claim a bonus from food it does not hold first.
7. **The penalty is capped at "no regen",** so the worst case for a player who ignores the
   system is the EQ experience, not a death loop (the one thing the first tester's bind
   problem taught: no self-built unwinnable states).
8. **No oracle:** `HungerUpdate` goes to its owner only (slice 1 sends only chat lines, to
   the owner).
9. **Accepted residual (review 2026-10-13):** the auto-eat writes the fed counter with the
   resources and the missing loaf with the stores in two separate statements; a crash
   between them restores one loaf per character while keeping the fullness. One
   four-copper loaf per character per crash; recorded, not fixed (folding the counters into
   `save_stores_atomic` is the fix if it ever matters).
10. **A forged race or class at creation is refused** (`char_data::CREATION_RACES`,
   `PLAYABLE_CLASSES`): the Revenant's block, and any future transformation's, cannot be
   chosen at birth.

## 5. Slices

- **Slice 0 (done 2026-10-12, stopgap on the current model):** the server's already-drinking
  check recognises the mana-only leg, so a second Water Flask is refused while the first
  runs.
- **Slice 1, the system (server + client, one protocol bump for `HungerUpdate`):** the two
  counters with migration `0013_hunger.sql`, persistence in the resource checkpoint and the
  reap, the drain in the world loop with the per-race multiplier, the eat check, the three
  stages and their lines, the regen gate, the hand-eat rules, the client's deletions and a
  minimal state (the chat lines; the window follows its own note, decision 6). Tests: the drain and
  the stage lines (unit), the auto-eat picking slot order through bags (integration), the
  regen gate (integration: a famished character's HP does not rise out of combat, a fed
  one's does), the hand-eat refusal at the cap and the halving, persistence across a
  relogin, no drain while dead. Rides the next protocol-bump day with the trade window.
- **Slice 2, content:** sizes for the tradeskill tiers in `consumables.md`, Summon Food and
  Summon Drink spells (which classes: section 7), the General Merchant's stock priced so a
  day of play is affordable, stat food once an item carries stats.
- **Slice 3, later:** the mount and zone multipliers, a race multiplier if wanted.

## 6. Checklist

`food_and_water_checklist.md`, written with slice 1: eat and drink happen on their own and
say so, the bars update, the hungry and out-of-food lines come once each, no regen when out,
regen back after eating, hand-eat refused when full, hand-eat halves, slot order through a
bag, the state survives a relogin, the dead do not starve, the Revenant is immune.

## 7. Decisions, all made 2026-10-13 (user)

1. **The scale: EQ's own pace.** One unit is 144 s. Bread Loaf = a meal of 20 units (48
   minutes); Water Flask = a drink of 15 units (36 minutes, the size of EQ's summoned Globe
   of Water); the cap 100 units (4 hours); "You are hungry." at 12 units left (about 30
   minutes); out at 0. A three-hour evening is four loaves and five flasks.
2. **What stops when famished: EQ's split.** No food stops HP regen, no water stops mana
   regen, either stops stamina regen.
3. **Race timing: EQ drains by race.** The drain gets a per-race multiplier. What the
   sources give: a Human reaches the final stage after about 3 hours without a meal, a
   Halfling after about 90 minutes (the P99 wiki), so Human 1.0 and Halfling 2.0. No source
   found for the other races; they start at 1.0, with two of our own (not EQ's) calls flagged
   for the user: Ogre and Troll at 1.5 (big eaters in the lore), Fae at 0.75. One table in
   `data/races.toml` beside the camps, read at the drain. *(Built as a match in
   `hunger.rs`, one place with its test; Half-Ogre joined Ogre and Troll at 1.5, the user's
   to keep or drop.)*
4. **Hand-eating: EQ's rules exactly.** Refused when full with EQ's line; half size when
   early; the first food in slot order is what the character eats on its own.
5. **Summon Food and Summon Drink: corrected.** The first draft said "Mag, Cle, Dru at level
   1, a stack of 20", which was wrong, as the user suspected. The data: **Summon Drink** is
   Magician 1 (10 mana, 4 s, ONE Globe of Water per cast), Cleric 3 to 5, Shaman 2 to 5,
   Druid 10 to 14 depending on the era's data; **Summon Food** is Magician 1, Cleric 9,
   Shaman 9, Druid 14, one Black Bread ("This is a meal!") per cast. Stacks come much later:
   Cornucopia (Magician 21, 20 breads), Everfount (Magician 22, 20 globes), Abundant Food
   and Abundant Drink (Cleric 29 to 33, four each). Decided: slice 2 gets Summon Drink and
   Summon Food at those levels for Magician, Cleric, Shaman and Druid, one item per cast,
   with the item sizes above; the stack spells wait for the content pass.
6. **The bars: its own UI window, planned first.** Two small icons (food, drink) each beside
   a progress bar showing the character's current hunger and thirst, in its own small
   movable window like the group and pet panels; colour per stage. The user wants it planned
   rather than sent at once, so slice 1 ships the server half and the chat lines, and the
   window's design (size, placement, what the bar reads, whether it hides when full) is a
   short note for the user before the client half is built.

## 7a. The questions as they were asked (for the record)

1. **The scale.** EQ's unit is 144 s. Proposed: `Bread Loaf` = a meal of 20 minutes
   (1200 s), `Water Flask` = a drink of 20 minutes; the cap 2 hours; `HUNGRY_AT` 10 minutes
   left; `EAT_AT` 0 (eat when the counter empties, as EQ does, so a snack is not wasted
   topping up a full stomach). A tester who plays a three-hour evening eats nine loaves
   and drinks nine flasks; at the merchant's 3 copper a flask that is pocket change.
   Alternative: EQ's own slower pace (a meal is 48 minutes, the cap 4 hours).
2. **What stops when famished.** Proposed (EQ, per the P99 wiki): no food stops HP regen,
   no drink stops mana regen, either stops stamina regen. Alternative: only halve them.
3. **Race timing.** EQ drains by race (a Halfling starves in half a Human's time). Proposed:
   no race multiplier in slice 1 (one number for everyone); add it with the race trade-off
   pass if wanted.
4. **Hand-eating.** Proposed: EQ's rules exactly (refused when full with EQ's line; half
   size when early). Alternative: refuse any hand-eat above `HUNGRY_AT` (simpler to explain,
   kills the stat-food trick).
5. **Summon Food and Summon Drink.** Proposed for slice 2: Magician, Cleric and Druid get
   both at level 1 (EQ), producing a stack of 20 snacks; it is also the honest answer to "I
   forgot to buy bread" in a dungeon.
6. **The bars.** Proposed: two small icons beside the buff bar with a tooltip countdown and a
   colour per stage; no numbers on the HUD. Alternative: a text line in the character window.

## Sources

- Project 1999 wiki, Summon Drink / Summon Food / Cornucopia / Everfount pages (via search
  summaries; the wiki refused direct fetches), Al'Kabor spell data
  https://lucy.alkabor.com/spell_50.html (Summon Food: CLR/9 DRU/14 SHM/9 MAG/1, 10 mana,
  4.00 cast, one Black Bread) and https://lucy.alkabor.com/spell_52.html (Abundant Drink),
  Allakhazam https://everquest.allakhazam.com/db/spell.html?spell=53 (Abundant Food, CLR 33)
  and ?spell=55 (Cornucopia, MAG 21), and the Allakhazam magician spell list (Summon Drink
  CLR/3 DRU/10 SHM/2 MAG/1; Everfount MAG/22): the summon line, decision 5.
- Project 1999 wiki, Food and drink: https://wiki.project1999.com/Food_and_drink (the
  stages, "hit-points and mana will no longer regenerate", the explode line, race timing;
  the page reset twice on fetch, so its wording is from the search summary)
- Project 1999 forums, "Food Duration... (Extremely Long!!!)":
  https://www.project1999.com/forums/showthread.php?t=333600 (the 144 s unit, the tiers, the
  46 s check, mounts, deserts, hand-eat halving, "only the top food... adds to your stats")
- EQEmulator forums, "Food Consumption question":
  https://www.eqemulator.org/forums/showthread.php?t=41676 (the emulator's hunger/thirst
  levels, mounted drain, "if a character is hungry or thirsty, client combat regeneration is
  affected")
