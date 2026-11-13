# Pre-Door Check Playtest Checklist — 2026-11-03

A brand-new player's first 45 minutes, on the exact build the friends will hold on Nov 8
(planner row v16; since 11-13 the door is Thu Nov 19 (Nov 12 since 11-05) and the November bump lands first, so
this sheet gets a second run on the bump build, planner row v60). Nothing new is under test: this is the friends' evening played once,
alone, ahead of time. Anything odd gets a To-Do line the same day; fixes go out on Fri Nov 6.

> **The second run (the bump build, planner row v60, Tue Nov 10):** the `[x]` marks are the
> 11-03 run on the pre-bump build. Mark the rerun in each row's notes (`11-10: PASS`, or what
> happened), and the two rows still `[ ]` below are new since (the stamp's debug mark and the
> NPC bodies, both 2026-11-09): they need the export made after `6f37058`.
>
> **How the second run was marked (2026-11-11):** most rows were exercised by the master
> sheet's sittings of 11-06 and 11-09 (`bump_build_master_checklist.md`; a `covered by the
> master sheet` note names its row ids), and a sitting on 11-11 covered the rest (two seats,
> BOINKLE a new Necromancer on the GM account and GLOTRP; the `e0d0c65` zip on server
> `e358270`; 19:08 to 19:25 UTC). The `11-11:` notes are Claude's, from the journal and the
> screenshots the user pasted. What is left to run is the last bullet under Notes.

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
      zipped as `builds/ProjectDawn-alpha-de600ba.zip`. The only commit after it is docs. 11-10: the `e0d0c65` export (`/version`: exported 2026-11-10T06:34:48 UTC, gdext 7ff30c05), the zip the rerun ran on.
- [x] **Redeploy the R720 to `f06e88e`** (the usual stop, `cp`, start) and confirm
      (`journalctl -u projectdawn -n 20 --no-pager`) → `build="f06e88e" dev_cmds=false`, no
      migration. notes: 11-10: `build="e358270" dev_cmds=false`, live 14:56 UTC.
- [x] **Unzip the new build into a fresh folder** (not over an old one) → the login screen's
      bottom-right stamp matches the export, never `UNSTAMPED BUILD`. notes: 11-11: PASS (the login screenshot: `e0d0c65` in grey).
- [x] **Read the stamp on the bump-build zip, then `/version` in game** → the plain sha in
      grey, never `UNSTAMPED BUILD` and never `<sha>-debug` in amber (a debug export, which the
      stamp marks since 2026-11-09); `/version` has no `debug export` line. notes: 11-11: PASS
      (the screenshots: the login screen's `e0d0c65` in grey; `/version` prints `Build e0d0c65`,
      `branch fix/xp-leveling-overflow`, `exported 2026-11-10T06:34:48 UTC`, `gdext 7ff30c05`,
      and no `debug export` line).
- [x] **Note the start time** for the journal check at the end. notes: Journal started. 11-11: 19:08 UTC (the pasted journal's first line).

## 1 — Arriving
- [x] **Register a new account in the launcher** → it registers and logs straight in.
      notes: jingly 11-11: not run on a fresh account (BOINKLE plays on account 2, the GM account: the journal's dev coin grant, GmGive and dev full restore lines); the 11-03 mark stands.
- [x] **Create a character** (any race and class a friend might pick) → it enters the world
      in town with no error, the HUD, hotbar, hunger window and chat all on screen. notes: Jingly, Gnome Shadowknight 11-11: PASS (BOINKLE, char 49, a new Necromancer, level 1 at 19:16 UTC by the journal's level_req line; the master's O3.2 too).
- [x] **`/version`** → the same stamp as the login screen. notes: 11-11: PASS (the screenshots, both `e0d0c65`).
- [x] **Look around for a minute** → nothing in town attacks you; nameplates, the sky and
      the NPCs look right. notes: 11-06: covered by the master sheet (F1.1, H5.1).
- [ ] **Walk up to Brom, Thalia Mourne and Aldric** → each placeholder capsule stands on the
      ground, its foot at your feet and its name above its head (they sat half in the ground
      until 2026-11-09). notes: 11-11: no screenshot or word yet; the fix is in the `e0d0c65` zip.
- [x] **`/say` a line, then `/ooc` one** → both show in chat. notes: 11-11: PASS (the chat screenshot: `BOINKLE says, 'HI'`, `[OOC] BOINKLE: HELLO`).

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
      legs; the bags are empty. notes: 11-11: not run as rows (no inventory screenshot); the journal shows the new Necromancer at `armor=2` before any gear was given, the Ragged Shirt and Pants worn at birth. The refusal rows below stand on 11-03: the server's kit and NO DROP code are unchanged since `f06e88e`.
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
      sell it back, and the coin moves both ways. notes: 11-11: PASS for Brom and Elara (a Meat Pie bought for 6c and sold back for 3c at Brom; five Minor Healing Potions for 60c at Elara); Hadrik not in the window; 11-06: the master's H5.1 and O2.5.
- [x] **Right-click Thalia Mourne** → the bank opens; deposit an item and take it back.
      notes: 11-11: PASS (four items into the personal vault and back, then the shared vault and back, 19:14 to 19:15 UTC); 11-06: the master's B1 rows.
- [x] **Right-click Sister Maelis and bind** → a bind line in chat. notes: 11-06: covered by the master sheet (H5.1).
- [x] **Target a mob and `/con`** → a faction line and a level line. notes: 11-11: PASS (the chat screenshot: "Brom regards you indifferently."; a Plague Rat and a Gnoll Raider "regards you indifferently. Looks like quite a gamble." at level 1, yellow for a level 2 mob).
- [x] **Open the inventory, the character sheet and the spell book (if a caster)** → each
      opens, closes with ESC, and clicks stop at the window. notes: 11-06: covered by the master sheet (B3.2, O3.6).

## 4 — The starter book
- [x] **Take Rat Infestation from Brom and kill the rats** → the journal counts each kill;
      the turn-in pays coin and XP. notes: 11-11: PASS (accepted 19:16:36 UTC; nine Plague Rats killed 19:17 to 19:20, level 1 to 2 at the first and 2 to 3 at the eighth; completed 19:21:57, `reward=150`, the Folk of Greyveil +25 and the Watch +10).
- [x] **Take The Wolf Threat from Aldric** → wolves are south of the eastern road, the
      journal counts, the turn-in pays. notes: 11-11: accepted 19:16:51; five Grey Wolves killed 19:20 to 19:21 (one a spell kill); the turn-in was REFUSED at 19:21:52 (`quest turn-in rejected — inventory full`: the bags held Test Panel gear and the quest pays a Tarnished Silver Ring) and not retried inside the pasted window, so the payout is unmarked this run; the 11-03 mark stands.
- [x] **Loot a few corpses** → the loot window opens on right-click, items reach the bags.
      notes: 11-11: the bags being full, five `loot partially placed; remainder refunded to bag` lines (the refund path, right); 11-06: the master's O2.2.
- [x] **Reach level 2, then Restless Bones** → the level-up line, the quest accepts at 2.
      notes: 11-11: level 2 at 19:17:12 (and 3 at 19:19:46); no Restless Bones accept in the window, unmarked this run.
- [x] **If you reach level 3: Drive Back the Raiders** → accepts at 3, gnolls credit. notes: 11-11: at level 1 the accept was refused (`quest accept rejected — below level_req level=1 level_req=3`), the gate right; no accept after level 3 in the window.
- [x] **Sit to rest after a fight** → HP (and mana) come back faster seated. notes: 11-11: not seen (six dev full restores instead); 11-06: the master's O3.7.
- [x] **A caster: memorize and cast a spell on a mob** → it lands or fizzles with a line;
      nothing is silently eaten. notes: 11-11: PASS (Bone Shards memorized in gem 0 at 19:18:59; three fizzles with the line at `burned=2.0` each; a spell kill on a Grey Wolf at 19:21:11).

## 5 — A death
- [x] **Die once** (let a mob kill you) → the death screen, respawn at Sister Maelis's bind,
      no level lost below level 5. notes: 11-06/11-09: covered by the master sheet (O2.7, H4.1, F4.3, F4.4; higher-level characters, so the no-loss-below-5 half stands on 11-03).
- [x] **Walk back and loot your corpse** → worn gear goes back on, the rest to the bags,
      the corpse goes away. notes: 11-06/11-09: covered by the master sheet (O2.7, F8.1, F4.4).

## 6 — Leaving
- [x] **`/camp` while sitting** → the countdown, then the game closes on its own. notes: 11-09: covered by the master sheet (O2.8).
- [x] **Log back in** → the same place, the same gear, bags, coin and quest progress. notes: 11-09: covered by the master sheet (R2.1, H1.5).

## 7 — The record
- [x] **The R720 journal since the start time** → no `ERROR` line; paste any `WARN` lines
      here. notes: 11-11: PASS for 19:08 to 19:25 UTC (no `ERROR` or `WARN`, no `cannot see`, no `Attack rejected`; `world health` p50 0.5 ms, max 19.1 ms, `over_budget=0`, `slope_refusals=0`, two players).
- [x] **The console (backtick) during play** → no red line. notes: 11-11: PASS (the console screenshot: INFO only, the faction and alignment lines and `Skills: 0 available for class 'Necromancer'`, which is right: no active skill names the class).

## 8 — The fixes of 11-09 (the R720 at server `e358270`, live since 2026-11-10 14:56 UTC; the client zip `ProjectDawn-alpha-e0d0c65.zip` or later; the UI scale row needs `ProjectDawn-alpha-919671b.zip`, the 11-11 evening export)
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
- [ ] **A pet class: send the pet at a mob you never touch, and let the mob kill the pet**
      (the owner's hate token) → the moment the pet dies the mob turns on you and comes for
      you instead of walking home; a mob the pet fought beside you still prefers whoever hit
      it hardest. notes:
- [ ] **Esc, Options, Graphics: set UI Scale to 125%, Apply, quit the game, relaunch, log
      in** (the saved UI scale; needs the `919671b` zip, made 2026-11-11 evening) → the HUD is at 125%
      from the first frame in the world without opening Options (it used to come back at
      100% every login, the slider still reading 125%); the login screen looks as before;
      Apply at 100% afterwards puts it back. notes:

## 9 — The Monday export (the ammo slot, the knoll, the Selos' lines; needs the zip exported after 2026-11-13 and the R720 redeployed with it, its boot line reading `hash 5324d5d0c754`)
- [ ] **Buy a Hunter's Shortbow from Hadrik and twenty Arrow Bundle from Elara** → both sell
      (80 copper and 1 copper an arrow); the arrows' tooltip reads "Ammunition: worn in the ammo
      slot, one per shot" and the bundle weighs 2.0 at twenty. notes:
- [ ] **Right-click the arrows in a bag** → they go into the paperdoll's new Ammo cell (bottom
      right, under Wpn) reading "Arrow Bundle (20)"; right-click them there and they come back
      to the bags. notes:
- [ ] **Drag the arrows onto the Wpn cell, and a sword onto the Ammo cell** → the arrows land in
      Ammo anyway and the sword in Wpn (the wrong cell falls through to the right one); no
      refusal line, nothing lost. notes:
- [ ] **Wear the bow and auto-attack a wolf from about 15 m** → every shot takes one arrow (the
      Ammo cell counts down, hit or miss); the journal has no `Attack rejected` line for you.
      notes:
- [ ] **Shoot the quiver empty** → the Ammo cell empties on the last arrow, the next swing prints
      "You have no ammunition." at the swing cadence and nothing is sent (the journal shows no
      `Attack dropped — no ammunition` line for an honest client); putting arrows back resumes
      the shooting. notes:
- [ ] **Swap to the sword with arrows worn and fight** → the count never moves. notes:
- [ ] **A Ranger: Aimed Shot with the bow and an empty quiver** → "You have no ammunition." and
      no stamina spent; with arrows it fires and takes one. notes:
- [ ] **Die with arrows worn, then Loot All on your corpse** → the arrows come back into the
      Ammo cell with their count. notes:
- [ ] **`admin_report` after the sitting** → `shoot` rows, one per arrow with delta -1, and the
      check card balanced. notes:
- [ ] **Walk up the ridge's south face where the bandit knoll meets it (around x -58, z 70)**
      → the face refuses you everywhere along it (the knoll now ends at its foot); the bandit
      camp sits on the knoll's north slope and the walk out to it is as before. notes:
- [ ] **A Bard: stand still, sing Selos' Melody once from cold, then send `debug.log`** → the
      log's `cast start`, `cast release` and `speed buff` lines say whether the speed arrived
      before or after the release (the open Selos' question); a speed-up before the release
      line is the bug, after it is the song. notes:

## Notes / observations
- Anything that would confuse or annoy a friend, however small: a missing hint, a wrong
  word, a window in the way, a mob too strong, a long walk. These are the point.
-
- 11-11 (Claude, from the journal): **the first rat nearly killed the level 1 Necromancer.**
  BOINKLE (17 max HP) went 13, 9, 5, 2 to one Plague Rat (level 2, 26 HP, 5 a hit every
  2.5 s, reduced to 4 by the kit's armor 2) and lived on a Full Heal at 19:17:12; six Full
  Heals in the sitting. A friend has none. For the user: a mob too strong for the level 1
  quest, or EQ as it was (a level 1 caster meleed rats one at a time and sat between them)?
  **DECIDED 2026-11-11 (user): "rat level is fine."** The rat stays as it is.
- 11-11: the run was on the GM account (dev coin grant, GmGive, Full Heal), so the register
  row and a plain account's survival are not evidenced this run.
- 11-11: **left to run**, on a fresh plain account on the next zip: the NPC capsules (§1),
  the Wolf Threat turn-in with room in the bags, Restless Bones at 2 and the Raiders at 3
  (§4), and §8's six rows (the five fixes are live on the R720 and in `e0d0c65`; the UI scale
  row needs the `919671b` zip, made 11-11 evening, which carries all six).
- The default user name in the login screen is tyler_mkee.  This needs to be removed. Maybe it could say "Enter your user name" until someone begins filling the field.  Screen shot attached.  