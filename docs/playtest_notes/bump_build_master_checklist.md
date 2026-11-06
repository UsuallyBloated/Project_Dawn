# Bump Build Master Checklist — 2026-11-06

The five sheets written for the November bump build, compiled into one sitting order. The
build: the R720 at server `267065f` (boot line `build="267065f" dev_cmds=false
terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`) and the export from client
`da83ea8` (`builds/ProjectDawn-alpha-da83ea8.zip`), both live since 2026-11-05 evening.

**Fill this sheet only.** Every row carries a tag naming the row it stands for in its source
sheet, and a row that appears in two or three sheets is here once with every tag. When this
sheet comes back, Claude copies each mark into the five sheets, which stay the record the To-Do
cites. Mark `[x]` pass, `[-]` blocked or skipped, and write what happened after `notes:`.

| Tag | Sheet | Rows |
|---|---|---|
| O | `overnight_2026_11_01_checklist.md` | O2.n = §2 row n, O3.n = §3 row n (§1 passed on 11-02, not rerun) |
| H | `height_model_checklist.md` | H1.n to H7.n; HS.n = Setup |
| F | `first_hills_checklist.md` | F1.n to F10.n; FS.n = Setup |
| R | `remote_facing_checklist.md` | R1.n to R3.n; RS.n = Setup |
| B | `held_item_bank_and_vendor_checklist.md` | B1.n to B3.n; BS.n = Setup |

The order: setup once, then one seat in town, one seat on the flat camps, one seat on the
hills, then two seats on the flat ground, two seats on the hills, and the record last. Parts
A to C can be one evening and parts D to F another; a part can stop and resume.

## What to bring

| Need | For |
|---|---|
| A GM account on the main seat | the Test Panel rows, Fling, Trigger Death, Level Up, `/give`; spawning the mob below the face (E.8) |
| A pet class with Gate (a Magician or Necromancer: a summoned pet, a nuke, Gate at 8) | the pet rows, the evade nukes, Gate |
| On the second seat, a Cleric (a heal and a buff on a group-mate, the resurrection, Gate at 8) | parts D and E; the sight rows need a spell cast on a group-mate |
| A few stacks of Bread Loaf, some coin, a Small Pouch with something in it, and enough items to fill the personal vault's 10 slots | part A's bank and merchant rows (`/give` on the GM account) |
| Optional, marked "if to hand": a Bard (Aria of Dismay, a song), a bow, a Druid or Wizard (Succor), a caster at level for a point-blank AoE, an Enchanter or Bard for a charm, a Conjured Bread, a plain (non-GM) account | the rows that say so; mark `[-]` without them |

## Where things are (the hills)

x east, z north, `/loc` reads them; the town at the origin, flat out to about 60 m with the
first two rings of camps (the Bonepile, Wolf Run, the Rat Warrens, the Shallow Graves, the gnoll
raiders, the Boar Thicket, the Festering Mound).

| Feature | Where | What to expect |
|---|---|---|
| The bandit knoll | (-58, 60) | the outpost on an 8 m rise |
| The Greywood ridge and the pass | along z = 85 from x = -120 to 120; the pass at x = 0 | a wall about 18 m high with 61° sides; a flat gap 20 m wide at x = -10 to 10 |
| The Broken Crypt's bowl | (2, 118), north of the ridge | a dip with a low rim |
| The western hills, the Sunken Barrow, the Ossuary | centred (-160, 0); the pit at (-150, -6); the Ossuary at (-170, 0) | a broad rise to about 25 m; a pit 12 m deep, walls 30 to 40°; the Ossuary on the high ground |
| The old rocks (Rotfang) | (3, -72) | a 6 m rise |
| The war camp's shelf | (2, -150) | an 8 m rise |
| The spiders' rise | (110, 2) | a 6 m rise |
| The Wraith Gate plateau | x 150 to 200, z -40 to 30 | flat at 18 m; ramps up its south side (z -70 to -40) and north side (z 30 to 60); its west edge (x = 150) a cliff |
| The rim | the outer 20 m of the plate | rising to 40 m at the edge, a face nobody climbs |

Fall costs (no armor, shield or attacker reduces them): nothing to 2 m, then 2.5% of max HP a
metre, all of it at 42 m. A 5 m fling costs 7.5%, a 20 m one 45%, the Wraith Gate's 18 m cliff
40%.

Diagnostics, for part F: `journalctl -u projectdawn --since "<start>" | grep -E "ERROR|WARN|panic|cannot see|no sight|fall damage|slope_refusals=[1-9]|dev_fling"`.
There is nothing to start: the R720's journal keeps every line on its own.

> **Known gotchas.** A held item is deposited by a LEFT CLICK on a vault cell; there is no drag
> gesture (the held item follows the mouse, so the click is the drop). The client refuses a cast
> it cannot see before the bar; a `cannot see` line in the journal after a cast the client let
> through is the finding, a refusal on screen with no line is the rule working. Fling and
> Trigger Death do nothing on a plain account by design. On the 11-02 run the bag window still
> showed a Destroy button (the pre-removal export); on this export it must be gone.

## Setup (once)
- [ ] (HS.1, FS.1, RS.1, BS.1) **The R720's boot line and the client's stamp** → `build="267065f"` (or later), `dev_cmds=false`, `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`; the login screen's stamp and `/version` read `da83ea8` (or later) on both seats. notes:
- [ ] (HS.2, FS.2, RS.2) **On the client checkout, `.\tools\check_all.ps1`** → all 15 PASS, among them `check_terrain_lockstep.gd` (1681 heights, the collider rebuilt, 6 NPCs on the ground), `check_terrain_sight.gd` and `check_wire_layer.gd`. notes:
- [ ] (HS.3, FS.3) **Note the start time** for the journal check in part F. notes:
- [ ] (BS.2) **The characters from the table above**, the main seat beside Thalia Mourne (the banker) and Brom with the loaves, the coin and the pouch. notes:

## A — One seat: the town (flat)
- [ ] (O3.1) **The login screen** → no Offline button. notes:
- [ ] (O3.2) **The lobby** → the character list and Enter World only (no Solo, Host, Join, Test Room, Test Dungeon or Delete Save). Create a character from it as usual. notes:
- [ ] (F1.1) **Log in and look around the town** → flat as before; the hills visible in the distance, flat-shaded (faceted) and tinted green low, grey-brown high; the ground solid underfoot and from above (never seen through, never the far slopes from behind). notes:
- [ ] (H5.1, F1.3) **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before; the NPCs stand on the ground. notes:
- [ ] (O2.5, B3.1) **Buy from Brom, sell to him from a bag slot, right-click deposit from the bags with the bank open, withdraw** → coins and items move as before. notes:
- [ ] (B1.1) **Open the bank, lift a stack of loaves onto the cursor, click an empty personal vault slot** → the loaves land in the personal vault (any slot; the server picks) and the hand is empty. notes:
- [ ] (B1.2) **Lift another stack of the same loaves, click any personal vault cell** → it merges into the vault's stack (up to the stack cap). notes:
- [ ] (B1.3) **Lift an item, click a shared vault slot** → it lands in the shared vault. notes:
- [ ] (B1.4) **Lift an item, click an OCCUPIED vault cell holding a different item** → it deposits into a free slot of that vault; nothing is swapped. notes:
- [ ] (B1.5) **With the personal vault full (10 slots), lift an item and click a cell** → "Your bank vault is full." and the item stays in hand. notes:
- [ ] (B1.6) **Lift the pouch (with something in it), click a vault cell** → "Bags can't go in the bank vault." at once, nothing sent (no journal line), the pouch stays in hand. notes:
- [ ] (B1.7) **Right-click a vault item while holding something** → it still withdraws into the bags; the held item stays in hand. notes:
- [ ] (B1.8) **Walk out of the banker's reach with the window open, lift an item, click a cell** → "There is no banker near you." (the proximity gate, unchanged). notes:
- [ ] (B2.1) **Open Brom, SELL tab, with loaves in hand** → the list starts with "In hand: Bread Loaf (N)", then the bags' items. notes:
- [ ] (B2.2) **Select it and sell 2** → "Offered Bread Loaf x2 to the merchant.", the coin arrives, the hand keeps the rest and the entry's count updates. notes:
- [ ] (B2.3) **Sell the rest** → the hand empties and the "In hand" entry leaves the list. notes:
- [ ] (B2.4) **Lift the pouch (with something in it), select "In hand: Small Pouch", sell** → "Empty the bag before selling it."; nothing sold. notes:
- [ ] (B2.5) **Open the SELL tab empty-handed, and with a Conjured Bread (no vendor value) in hand** (if to hand) → no "In hand" entry either time. notes:
- [ ] (B2.6) **Lift an item with the SELL tab already open** → the entry appears without reopening the window. notes:
- [ ] (B3.2) **A click on the inventory, the paperdoll or the world while holding** → places, equips or drops as before; the bank and vendor windows take only their own clicks. notes:
- [ ] (O3.6) **Open a bag window** → no Destroy button in it; destroying still works by holding the item over the inventory's trash cell. notes:
- [ ] (O3.7, H1.6) **Eat by hand, drink by hand, sit to regen, stand, sing a song (a Bard, if to hand)** → all as before; the regen and buff bars follow the server. notes:
- [ ] (O3.8) **`/dismount`** → not a command any more (nothing can be mounted online). notes:
- [ ] (O3.5) **The Test Panel (GM): Spawn Normal, Spawn Named, Despawn All, a GEAR give, Give 1,000 Copper, a faction slider, Take 20 dmg, Full Heal, Trigger Death** → each works as before. The removed buttons (the CHARACTER section, STATS OVERRIDE, ZONE TRAVEL, God Mode, No Cooldowns, Clear All Buffs) are gone. notes:
- [ ] (R2.3) **Turn to face a new way, then Test Panel spawn a mob** → it lands in front of where you actually face (the stale yaw used to put it in front of your login facing). notes:
- [ ] (F7.1) **Test Panel, Fling 5 m, anywhere** → the body goes up 5 m and drops: "You hit the ground hard for N damage." with N about 7.5% of max HP. notes:
- [ ] (F7.2) **Fling 20 m** → about 45% of max HP, the line, the HP bar. Full Heal after. notes:
- [ ] (F7.3) **On a plain account, the Test Panel's Fling** (if one is to hand) → nothing happens. notes:

## B — One seat: the flat ground (the first two rings of camps)
- [ ] (H1.1) **Walk and run in every direction, turn in place, strafe** → the speed and the feel as before; no rubber-banding, no pull forward or back. notes:
- [ ] (H1.3) **Jump while running** → as before (the jump stays cosmetic; nothing on the server reads it). notes:
- [ ] (H1.5) **Jump about, run off the town's steps and bumps, Quit Game mid-jump and log back in** → never a "You hit the ground hard" line, HP untouched, the relogin ordinary (on flat ground the server's fall never begins: a drop needs more than the body's half-metre snap). notes:
- [ ] (H1.2) **Run under Spirit of Wolf or Selos' Melody** (if a caster is to hand) → the buffed speed as before. notes:
- [ ] (R3.2) **`/loc` before and after a minute of turning in place** → the position reads the same: turning moves nobody. notes:
- [ ] (F1.4, H3.1) **Walk the first two rings' camps** → flat ground; mobs stand on the ground where they spawn, notice you at their aggro radius, chase, fight and walk home as before. notes:
- [ ] (O2.2, H2.1) **Melee a camp mob to death, loot the corpse** → swings land, the kill pays XP, the loot window takes items. notes:
- [ ] (O2.3, H2.2) **Cast a nuke at 25 to 30 m and a heal; let one fizzle or get interrupted** → they land, mana and lines as before; no "You cannot see your target." anywhere on the flat ground. notes:
- [ ] (H2.3) **A bow at range** (if one is to hand) → arrows land as before. notes:
- [ ] (H2.4) **A point-blank AoE** (a caster at level: Nature's Wrath, Ice Storm, Inferno; if to hand) → every mob inside the radius is hit. notes:
- [ ] (H2.5) **A Bard: Aria of Dismay on a mob** (if to hand) → the slow pulses as before. notes:
- [ ] (H3.2, O3.4) **Summon a pet (or the warder), attack a mob, watch the console** → it appears beside you on the ground, follows, and attacks on `/pet attack`; no red line on each hit (online it used to error on every mob hit). notes:
- [ ] (H3.3) **Charm a mob and let the charm end** (an Enchanter or a Bard, if to hand) → the mob comes back where it stood. notes:
- [ ] (F9.6) **Pull a mob, run until it turns for home, then hit or nuke it on its walk back** → "<mob> evades your attack." or "Your target is evading."; it heals to full at home and fights normally when pulled again. notes:
- [ ] (O2.7, H4.1, H4.2, F8.1) **Die (to a mob, or Trigger Death), respawn, walk back and loot the corpse** → the corpse lies at the death spot; the respawn lands at the bind, on the ground; gear goes back on. notes:
- [ ] (H4.3, F8.2) **Gate (and Succor, if a Druid or Wizard is to hand)** → the arrival at the bind or the town square, on the ground, the pet along. notes:

## C — One seat: the hills
A loop: north to the bandit knoll, the ridge, the pass and the crypt; west to the Barrow, the
Ossuary and the rim; south to the old rocks and the war camp's shelf; east to the spiders' rise
and the Wraith Gate. The first five rows span the loop and tick when every place named is done.

- [ ] (F1.2) **Walk onto a hilltop (the bandit knoll is the first) and stand still, then jump** → you stand on the surface (feet on it, not sunk into it) and jump from it as on flat ground. notes:
- [ ] (F2.1) **Walk from the town to the bandit knoll, the old rocks, the spiders' rise and the war camp's shelf** → uphill is slower (a 30° slope costs about a quarter of the speed), downhill full speed; no rubber-banding, no pull forward or back. notes:
- [ ] (F3.1) **Fight at the bandit knoll, the spiders' rise and the war camp's shelf** → mobs stand on the slope where they spawn, chase you up and down it, fight and walk home as before. notes:
- [ ] (F3.3) **Pull a mob from above or below a slope and run** → it follows over the ground and leashes home as before. notes:
- [ ] (F8.3) **Summon a pet and walk it over the hills** → it follows, standing on the ground. notes:
- [ ] (F2.2) **North to the Greywood ridge, then into its side** → the ridge cannot be walked up: the body slides back and stays at its foot. notes:
- [ ] (F2.3) **Through the pass at x = 0 to the Broken Crypt** → a flat way through at walking speed; the crypt in its bowl beyond. notes:
- [ ] (F2.4) **West to the Sunken Barrow and the Ossuary** → up the western hills, down into the pit and out again (its walls are steep but walkable), on up to the Ossuary. notes:
- [ ] (F3.2) **Fight in the Sunken Barrow** → the zombies come up out of the pit after you. notes:
- [ ] (F6.1) **Stand on the Sunken Barrow's rim and look in** → the zombies below; nukes from the rim land where the rim does not hide them. notes:
- [ ] (F6.2, H1.4) **Walk to the plate's edge anywhere and try to climb the rim, straight and at an angle** → the ground rises steeply from about 180 m out and becomes a face; the body slides back down; nobody gets over it. notes:
- [ ] (F2.5) **East to the Wraith Gate, up its south ramp** → a long climb onto the flat top. notes:
- [ ] (F4.1) **From the plateau, walk off its west edge (x = 150)** → the fall: "You hit the ground hard for N damage." with N about 40% of max HP, and the HP bar drops by that. notes:
- [ ] (F4.2) **At the foot, try to walk back up the cliff, straight and at an angle** → it cannot be climbed either way; the body slides back. The way up is the south or north ramp. notes:
- [ ] (F4.3) **Below 40% HP, step off the edge again** → you die of the fall; the corpse lies at the foot of the cliff. notes:
- [ ] (F4.4) **Respawn and run back to the corpse** → it is at the foot; loot it as usual. notes:

## D — Two seats: the town and the flat ground
A is the seat being watched, B the watcher; swap as convenient.

- [ ] (O2.1, R1.1) **Both seats enter the world; B watches A; A right-drags to turn in place** → each sees the other move; B sees A's body turn smoothly to the new facing, no slide, no snap. notes:
- [ ] (R1.2) **A runs a circle** → B sees A face the way it runs throughout. notes:
- [ ] (R1.3) **A strafes left and right** → B sees A face forward while sliding. notes:
- [ ] (R1.4) **A walks backwards** → B sees A face forward while backing up. notes:
- [ ] (R1.5) **A left-drags (camera orbit only)** → B sees A's body stay put: the camera is not the body. notes:
- [ ] (R2.1) **A turns to face B, logs out, logs back in** → A faces the same way on both screens straight after the login. notes:
- [ ] (R2.2) **B logs in while A stands facing away** → A's body faces away on B's screen from the first frame. notes:
- [ ] (O2.4, O3.3) **Group the two seats, kill a mob, look at the group panel** → the XP share and the group panel bars; your own row is marked as you on both seats, and the leader sees the kick and leadership controls on the other member's row, not their own. notes:
- [ ] (H2.2) **A heal or buff on the group-mate at 25 to 30 m, on flat ground** → it lands; no "You cannot see your target.". notes:
- [ ] (O2.6) **Trade an item between the seats** → the commit lands on both. notes:
- [ ] (H4.4, F8.2) **One seat dies; the Cleric casts the resurrection on the corpse; accept** → you land beside the corpse, on the ground. notes:
- [ ] (H6.1) **A partner's body, pet and corpse** → drawn where they are, on the ground, as before. notes:

## E — Two seats: the hills
The Wraith Gate first (E.1 to E.7), then the Greywood ridge and the crypt's bowl (E.8 to E.10),
then anywhere. In the sight rows, A is whichever seat has a heal or buff on a group-mate (the
Cleric) and stands at the cliff's foot; B stands on the plateau.

- [ ] (F9.1, R3.1) **A partner walks up a hill, stands on it and jumps on it; runs; sits** → drawn on the ground all the way, the jump seen (the jump relay as before), running and sitting unchanged. notes:
- [ ] (F9.2) **The partner walks off the Wraith Gate's west edge** → seen falling and landing at the foot. notes:
- [ ] (F5.1) **B on the plateau near the west edge at about (158, 0); A, at the cliff's foot at about (138, 0), targets B and casts a heal (or any spell on a group-mate)** → "You cannot see your target." at once: no cast bar, no mana spent. (From the foot to the top is 27 m, inside every spell's 30 m, with the lip some 6 m above the line between them.) notes:
- [ ] (F5.2) **A walks round and up the south ramp and casts the same at B from the top** → it lands. notes:
- [ ] (F5.3) **B walks to the lip right above A, about (151, 0), and A casts again from the foot** → a steep line up the face: refused or landed, and the server agrees with the client (no `cannot see` in the journal after a cast the client let through). notes:
- [ ] (F5.4) **A bow at a mob the terrain hides, inside bow range** (if one is to hand) → the server answers "You miss" (bows have no client sight check yet; the swing goes out and misses). notes:
- [ ] (F9.9) **A pet that cannot reach its owner** (an owner with a pet at the cliff's foot walks round and up the ramp to the lip above it, or Gates to a bind on the plateau) → the pet stops at the foot, and about 8 s later appears beside its owner. notes:
- [ ] (F9.3) **A mob below a face that cannot reach you** (B walks onto the Greywood ridge from its east end and along the crest to its north edge at about (25, 89.7): the very edge, `/loc` z between 89.5 and 89.9, since a step back and the crest hides the foot. A, a GM, in the crypt's bowl below at about (25, 108), spawns a Test Panel mob, which turns on A; B nukes it once and takes it; A walks 20 m east) → the mob walks to the foot of the ridge under B (about z = 100) and stops there; about 8 s later it turns away, walks home and its HP bar refills to full when it gets there. notes:
- [ ] (F9.4) **The same, and B nukes it again once it has stood at the foot a second or two, and once more on its walk home** → "Your target is evading." each time, at once, no mana spent, the mob's HP bar unchanged. notes:
- [ ] (F9.5) **The same, but A hits the mob once as it walks to the foot, then stands beside it there and keeps swinging; B keeps the most hate** → from its first second at the foot every swing reads "<mob> evades your attack." and does nothing; when it gives up on B it turns on A (A's first hit put A on its list) and fights. notes:
- [ ] (F9.7) **Anywhere: both of you hit a mob, then the one it is fighting dies (Trigger Death on a GM) or Gates** → the mob turns on the other at once and fights; it walks home only when nobody who hit it is left. notes:
- [ ] (F9.8) **The same, but the one it is fighting runs until it turns away** → it turns on the other instead of walking home. notes:
- [ ] (O2.8, H1.6) **`/camp` one seat, close the other with the window X** → the camp logs out; the other lingers about 30 s, as before. notes:

## F — The record
- [ ] (O2.9, H7.1, F10.1) **The journal since the start time** (the grep above) → no `ERROR` and no panic; no `cannot see` or `no sight` line for a cast the client let through; a `fall damage` line for each fall taken (the cliff, the flings) and none on the flat ground; `dev_fling` rows only for the GM's Fling presses; `slope_refusals` on the `world health` line is a curiosity on the hills (a key held into a cliff counts), 0 while on flat ground; paste any `WARN`. notes:
- [ ] (O2.10) **Read a few journal lines from the sitting** → a line logged while a player's message is handled starts `client{char_id=N account_id=M}:`, and a buy, sell, bank or loot line names the player `char_id=N` (it said `owner=N` or `caster=N` before 2026-11-02). notes:
- [ ] (B3.3) **`admin_report` after the sitting** → `bank_in`, `bank_out` and `sell` rows for part A's moves, the check card balanced. notes:
- [ ] (O3.9) **The console over the whole sitting** → no red script error. notes:

## Notes / observations
-
