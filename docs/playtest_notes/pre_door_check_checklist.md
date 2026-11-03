# Pre-Door Check Playtest Checklist — 2026-11-03

A brand-new player's first 45 minutes, on the exact build the friends will hold on Nov 8
(planner row v16). Nothing new is under test: this is the friends' evening played once,
alone, ahead of time. Anything odd gets a To-Do line the same day; fixes go out on Fri Nov 6.

**The build:** the friends get the client exported from the deploy branch
(`fix/xp-leveling-overflow`) at `12d4e5c` or later, and the R720 runs server `f06e88e`:
the starting kit (every character born in a Ragged Shirt, Ragged Pants and a Trainee's
weapon, all NO DROP, user 2026-11-03) is on both sides, so the two go out together. The bump
(facing, the split, the offline removal) waits until after the 8th, so none of it is in this
build.

**Play as a friend would:** a new account with no GM flag. A GM account has the Test Panel
and dev commands, which no friend will have, and they hide what a friend would hit.

| Starter quest | Giver | Level | Kill | Where |
|---|---|---|---|---|
| Rat Infestation | Brom | 1 | 8 Plague Rats | out the back of his shop |
| The Wolf Threat | Aldric | 1 | 5 Grey Wolves | south of the eastern road |
| Restless Bones | Aldric | 2 | 8 Decrepit Skeletons | the Bonepile |
| Drive Back the Raiders | Brom | 3 | 8 Gnoll Raiders | the rocky flats, east |

Diagnostics: the in-game console (backtick) shows client errors in red. On the R720:
`journalctl -u projectdawn --since "<start time>" | grep -E "ERROR|WARN"`.

## Setup
- [ ] **Export the client from `fix/xp-leveling-overflow`** with the deploy branch's
      `gdext_net.dll` → the export log shows `[BuildStamp] stamped <sha>` for the deploy
      branch's head. notes:
- [ ] **Redeploy the R720 to `f06e88e`** (the usual stop, `cp`, start) and confirm
      (`journalctl -u projectdawn -n 20 --no-pager`) → `build="f06e88e" dev_cmds=false`, no
      migration. notes:
- [ ] **Unzip the new build into a fresh folder** (not over an old one) → the login screen's
      bottom-right stamp matches the export, never `UNSTAMPED BUILD`. notes:
- [ ] **Note the start time** for the journal check at the end. notes:

## 1 — Arriving
- [ ] **Register a new account in the launcher** → it registers and logs straight in.
      notes:
- [ ] **Create a character** (any race and class a friend might pick) → it enters the world
      in town with no error, the HUD, hotbar, hunger window and chat all on screen. notes:
- [ ] **`/version`** → the same stamp as the login screen. notes:
- [ ] **Look around for a minute** → nothing in town attacks you; nameplates, the sky and
      the NPCs look right. notes:
- [ ] **`/say` a line, then `/ooc` one** → both show in chat. notes:

## 2 — The starting kit
| Class | Weapon |
|---|---|
| Warrior, Paladin, Shadow Knight, Bard, Ranger, Witch Hunter | Trainee's Sword |
| Rogue, Blood Mage | Trainee's Knife |
| Cleric, Monk, Druid | Trainee's Club |
| Shaman, Beast Master | Trainee's Spear (one-handed) |
| Magician, Wizard, Sorcerer, Necromancer, Enchanter | Trainee's Staff (two-handed) |

- [ ] **Open the inventory on the new character** → the paperdoll shows the class's Trainee's
      weapon in the main hand, the Ragged Shirt on the chest and the Ragged Pants on the
      legs; the bags are empty. notes:
- [ ] **Hover each piece** → the tooltip leads with `NO DROP`. notes:
- [ ] **Swing at a mob** → the hits use the Trainee's weapon (a staff for a caster, two hands).
      notes:
- [ ] **Unequip the weapon, then try to sell it to Brom** → "That item is NO DROP: it cannot
      leave you.", no coin. notes:
- [ ] **Drag it out onto the world** → the same line, no drop confirm, nothing on the ground.
      notes:
- [ ] **At Thalia, deposit it into the shared (account) vault** → the same line; deposit it
      into your own vault → it goes in, and comes back out. notes:
- [ ] **Equip it again** → back in the main hand. notes:
- [ ] **(Optional, needs a second person) Offer it in a trade** → the same line, the partner
      sees nothing offered. notes:
- [ ] **Later, a real weapon drops or is bought** → equip it, then destroy the Trainee's
      weapon from the bags → it is gone. notes:

## 3 — The town
- [ ] **Right-click Brom, Elara and Hadrik** → each opens a shop; buy one cheap item and
      sell it back, and the coin moves both ways. notes:
- [ ] **Right-click Thalia Mourne** → the bank opens; deposit an item and take it back.
      notes:
- [ ] **Right-click Sister Maelis and bind** → a bind line in chat. notes:
- [ ] **Target a mob and `/con`** → a faction line and a level line. notes:
- [ ] **Open the inventory, the character sheet and the spell book (if a caster)** → each
      opens, closes with ESC, and clicks stop at the window. notes:

## 4 — The starter book
- [ ] **Take Rat Infestation from Brom and kill the rats** → the journal counts each kill;
      the turn-in pays coin and XP. notes:
- [ ] **Take The Wolf Threat from Aldric** → wolves are south of the eastern road, the
      journal counts, the turn-in pays. notes:
- [ ] **Loot a few corpses** → the loot window opens on right-click, items reach the bags.
      notes:
- [ ] **Reach level 2, then Restless Bones** → the level-up line, the quest accepts at 2.
      notes:
- [ ] **If you reach level 3: Drive Back the Raiders** → accepts at 3, gnolls credit. notes:
- [ ] **Sit to rest after a fight** → HP (and mana) come back faster seated. notes:
- [ ] **A caster: memorize and cast a spell on a mob** → it lands or fizzles with a line;
      nothing is silently eaten. notes:

## 5 — A death
- [ ] **Die once** (let a mob kill you) → the death screen, respawn at Sister Maelis's bind,
      no level lost below level 5. notes:
- [ ] **Walk back and loot your corpse** → worn gear goes back on, the rest to the bags,
      the corpse goes away. notes:

## 6 — Leaving
- [ ] **`/camp` while sitting** → the countdown, then the game closes on its own. notes:
- [ ] **Log back in** → the same place, the same gear, bags, coin and quest progress. notes:

## 7 — The record
- [ ] **The R720 journal since the start time** → no `ERROR` line; paste any `WARN` lines
      here. notes:
- [ ] **The console (backtick) during play** → no red line. notes:

## Notes / observations
- Anything that would confuse or annoy a friend, however small: a missing hint, a wrong
  word, a window in the way, a mob too strong, a long walk. These are the point.
-
