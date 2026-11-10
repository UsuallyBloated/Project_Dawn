# Pre-Door Check Playtest Checklist — 2026-11-03

A brand-new player's first 45 minutes, on the exact build the friends will hold on Nov 8
(planner row v16; since 11-05 the door is Thu Nov 12 and the November bump lands first, so
this sheet gets a second run on the bump build, planner row v60). Nothing new is under test: this is the friends' evening played once,
alone, ahead of time. Anything odd gets a To-Do line the same day; fixes go out on Fri Nov 6.

> **The second run (the bump build, planner row v60, Tue Nov 10):** the `[x]` marks are the
> 11-03 run on the pre-bump build. Mark the rerun in each row's notes (`11-10: PASS`, or what
> happened), and the two rows still `[ ]` below are new since (the stamp's debug mark and the
> NPC bodies, both 2026-11-09): they need the export made after `6f37058`.

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
- [x] **Export the client from `fix/xp-leveling-overflow`** with the deploy branch's
      `gdext_net.dll` → the export log shows `[BuildStamp] stamped <sha>` for the deploy
      branch's head. notes: done by Claude 2026-11-03: `[BuildStamp] stamped de600ba`, branch
      `fix/xp-leveling-overflow`, `dirty: false`, DLL md5 `39b8555a` (the deploy branch's);
      zipped as `builds/ProjectDawn-alpha-de600ba.zip`. The only commit after it is docs.
- [x] **Redeploy the R720 to `f06e88e`** (the usual stop, `cp`, start) and confirm
      (`journalctl -u projectdawn -n 20 --no-pager`) → `build="f06e88e" dev_cmds=false`, no
      migration. notes:
- [x] **Unzip the new build into a fresh folder** (not over an old one) → the login screen's
      bottom-right stamp matches the export, never `UNSTAMPED BUILD`. notes:
- [ ] **Read the stamp on the bump-build zip, then `/version` in game** → the plain sha in
      grey, never `UNSTAMPED BUILD` and never `<sha>-debug` in amber (a debug export, which the
      stamp marks since 2026-11-09); `/version` has no `debug export` line. notes:
- [x] **Note the start time** for the journal check at the end. notes: Journal started.

## 1 — Arriving
- [x] **Register a new account in the launcher** → it registers and logs straight in.
      notes: jingly
- [x] **Create a character** (any race and class a friend might pick) → it enters the world
      in town with no error, the HUD, hotbar, hunger window and chat all on screen. notes: Jingly, Gnome Shadowknight
- [x] **`/version`** → the same stamp as the login screen. notes:
- [x] **Look around for a minute** → nothing in town attacks you; nameplates, the sky and
      the NPCs look right. notes:
- [ ] **Walk up to Brom, Thalia Mourne and Aldric** → each placeholder capsule stands on the
      ground, its foot at your feet and its name above its head (they sat half in the ground
      until 2026-11-09). notes:
- [x] **`/say` a line, then `/ooc` one** → both show in chat. notes:

## 2 — The starting kit
| Class | Weapon |
|---|---|
| Warrior, Paladin, Shadow Knight, Bard, Ranger, Witch Hunter | Trainee's Sword |
| Rogue, Blood Mage | Trainee's Knife |
| Cleric, Monk, Druid | Trainee's Club |
| Shaman, Beast Master | Trainee's Spear (one-handed) |
| Magician, Wizard, Sorcerer, Necromancer, Enchanter | Trainee's Staff (two-handed) |

- [x] **Open the inventory on the new character** → the paperdoll shows the class's Trainee's
      weapon in the main hand, the Ragged Shirt on the chest and the Ragged Pants on the
      legs; the bags are empty. notes:
- [x] **Hover each piece** → the tooltip leads with `NO DROP`. notes:
- [x] **Swing at a mob** → the hits use the Trainee's weapon (a staff for a caster, two hands).
      notes:
- [x] **Unequip the weapon, then try to sell it to Brom** → "That item is NO DROP: it cannot
      leave you.", no coin. notes:
- [x] **Drag it out onto the world** → the same line, no drop confirm, nothing on the ground.
      notes:
- [x] **At Thalia, deposit it into the shared (account) vault** → the same line; deposit it
      into your own vault → it goes in, and comes back out. notes:
- [x] **Equip it again** → back in the main hand. notes:
- [ ] **(Optional, needs a second person) Offer it in a trade** → the same line, the partner
      sees nothing offered. notes:
- [ ] **Later, a real weapon drops or is bought** → equip it, then destroy the Trainee's
      weapon from the bags → it is gone. notes:

## 3 — The town
- [x] **Right-click Brom, Elara and Hadrik** → each opens a shop; buy one cheap item and
      sell it back, and the coin moves both ways. notes:
- [x] **Right-click Thalia Mourne** → the bank opens; deposit an item and take it back.
      notes:
- [x] **Right-click Sister Maelis and bind** → a bind line in chat. notes:
- [x] **Target a mob and `/con`** → a faction line and a level line. notes:
- [x] **Open the inventory, the character sheet and the spell book (if a caster)** → each
      opens, closes with ESC, and clicks stop at the window. notes:

## 4 — The starter book
- [x] **Take Rat Infestation from Brom and kill the rats** → the journal counts each kill;
      the turn-in pays coin and XP. notes:
- [x] **Take The Wolf Threat from Aldric** → wolves are south of the eastern road, the
      journal counts, the turn-in pays. notes:
- [x] **Loot a few corpses** → the loot window opens on right-click, items reach the bags.
      notes:
- [x] **Reach level 2, then Restless Bones** → the level-up line, the quest accepts at 2.
      notes:
- [x] **If you reach level 3: Drive Back the Raiders** → accepts at 3, gnolls credit. notes:
- [x] **Sit to rest after a fight** → HP (and mana) come back faster seated. notes:
- [x] **A caster: memorize and cast a spell on a mob** → it lands or fizzles with a line;
      nothing is silently eaten. notes:

## 5 — A death
- [x] **Die once** (let a mob kill you) → the death screen, respawn at Sister Maelis's bind,
      no level lost below level 5. notes:
- [x] **Walk back and loot your corpse** → worn gear goes back on, the rest to the bags,
      the corpse goes away. notes:

## 6 — Leaving
- [x] **`/camp` while sitting** → the countdown, then the game closes on its own. notes:
- [x] **Log back in** → the same place, the same gear, bags, coin and quest progress. notes:

## 7 — The record
- [x] **The R720 journal since the start time** → no `ERROR` line; paste any `WARN` lines
      here. notes:
- [x] **The console (backtick) during play** → no red line. notes:

## 8 — The fixes of 11-09 (the R720 at server `a137b96` or later; the client zip `ProjectDawn-alpha-e0d0c65.zip` or later)
- [ ] **Log in while a partner watches** (two seats; the login facing seed) → your body appears
      facing where it logged out and never turns on its own, on the partner's screen and on
      yours (it used to face the scene's default, then snap a tick later). notes:
- [ ] **Swap weapons with nothing targeted, then fight** (the swing re-time) → the first swing
      of the fight waits the new weapon's full delay; in the journal no `Attack rejected —
      swing-rate limit (too fast)` line for you. notes:
- [ ] **A charmer (a Bard 14 or an Enchanter): charm a camp mob and let something kill the pet
      inside the charm's last five seconds** (the charm-expiry fix) → when the charm runs out
      nothing comes back and no bag drops; the journal has no `charm expired — mob returned
      hostile` line for that pet and no `stray kill`; the camp respawns the mob on its own
      timer. notes:
- [ ] **Wear a proc weapon (Flamebrand) through a few kills** (the proc log line) → the
      journal shows `weapon proc` lines naming the proc and the amount whenever the client
      prints "Flaming Strike for N". notes:

## Notes / observations
- Anything that would confuse or annoy a friend, however small: a missing hint, a wrong
  word, a window in the way, a mob too strong, a long walk. These are the point.
-
- The default user name in the login screen is tyler_mkee.  This needs to be removed. Maybe it could say "Enter your user name" until someone begins filling the field.  Screen shot attached.  