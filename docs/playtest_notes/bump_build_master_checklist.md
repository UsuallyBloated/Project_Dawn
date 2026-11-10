# Bump Build Master Checklist — 2026-11-06

The five sheets written for the November bump build, compiled into one sitting order. The
build: the R720 at server `267065f` (boot line `build="267065f" dev_cmds=false
terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`) and the export from client
`da83ea8` (`builds/ProjectDawn-alpha-da83ea8.zip`), both live since 2026-11-05 evening.

**Fill this sheet only.** Every row carries a tag naming the row it stands for in its source
sheet, and a row that appears in two or three sheets is here once with every tag. When this
sheet comes back, Claude copies each mark into the five sheets, which stay the record the To-Do
cites. Mark `[x]` pass, `[-]` blocked or skipped, and write what happened after `notes:`.

**Status: COMPLETE 2026-11-09.** Parts A (2026-11-06), B, C, D and E (2026-11-09) filled and
copied into the five sheets, every row marked, the Setup rows and part F's journal and console
rows with them. The sitting ran on an export of `df4f29c`, whose game
files are byte-identical to the `da83ea8` zip's (only the stamp differs), so the marks stand
for the friends' build.

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
| Optional, marked "if you have one": a Bard (Aria of Dismay, a song), a bow, a Druid or Wizard (Succor), a caster at level for a point-blank AoE, an Enchanter or Bard for a charm, a Conjured Bread, a plain (non-GM) account | the rows that say so; mark `[-]` without them |

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
- [x] (HS.1, FS.1, RS.1, BS.1) **The R720's boot line and the client's stamp** → `build="267065f"` (or later), `dev_cmds=false`, `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`; the login screen's stamp and `/version` read `da83ea8` (or later) on both seats. notes: [the R720 at `267065f` (the 11-05 boot line, no restart since); both seats on the user's export of `df4f29c`, the same launcher (user, 11-09: "same build as first. same launcher"), whose game files are byte-identical to the `da83ea8` zip's.]
- [x] (HS.2, FS.2, RS.2) **On the client checkout, `.\tools\check_all.ps1`** → all 15 PASS, among them `check_terrain_lockstep.gd` (1681 heights, the collider rebuilt, 6 NPCs on the ground), `check_terrain_sight.gd` and `check_wire_layer.gd`. notes: [Claude, 11-09: all 15 PASS on the checkout at `4e4505c`.]
- [x] (HS.3, FS.3) **Note the start time** for the journal check in part F. notes: [15:21 UTC (B and C), 17:24 UTC (D and E).]
- [x] (BS.2) **The characters from the table above**, the main seat beside Thalia Mourne (the banker) and Brom with the loaves, the coin and the pouch. notes: [11-06, for part A.]

## A — One seat: the town (flat)
- [x] (O3.1) **The login screen** → no Offline button. notes:
- [x] (O3.2) **The lobby** → the character list and Enter World only (no Solo, Host, Join, Test Room, Test Dungeon or Delete Save). Create a character from it as usual. notes:
- [x] (F1.1) **Log in and look around the town** → flat as before; the hills visible in the distance, flat-shaded (faceted) and tinted green low, grey-brown high; the ground solid underfoot and from above (never seen through, never the far slopes from behind). notes:
- [x] (H5.1, F1.3) **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before; the NPCs stand on the ground. notes: NPCs appear half in the ground.  This isnt an issue now, but i want to make sure it wont be an issue when they get models.  Screenshot attached.
- [x] (O2.5, B3.1) **Buy from Brom, sell to him from a bag slot, right-click deposit from the bags with the bank open, withdraw** → coins and items move as before. notes:
- [x] (B1.1) **Open the bank, lift a stack of loaves onto the cursor, click an empty personal vault slot** → the loaves land in the personal vault (any slot; the server picks) and the hand is empty. notes:  This does not work the other way around:  I cannot lift a stack of loaves onto the cursor if the loaves are in the vault.
- [x] (B1.2) **Lift another stack of the same loaves, click any personal vault cell** → it merges into the vault's stack (up to the stack cap). notes: tested with rat meat
- [x] (B1.3) **Lift an item, click a shared vault slot** → it lands in the shared vault. notes:
- [x] (B1.4) **Lift an item, click an OCCUPIED vault cell holding a different item** → it deposits into a free slot of that vault; nothing is swapped. notes:  I would prefer the items swapped in this situation.
- [x] (B1.5) **With the personal vault full (10 slots), lift an item and click a cell** → "Your bank vault is full." and the item stays in hand. notes:
- [x] (B1.6) **Lift the pouch (with something in it), click a vault cell** → "Bags can't go in the bank vault." at once, nothing sent (no journal line), the pouch stays in hand. notes:  We need to allow bags in the bank.
- [x] (B1.7) **Right-click a vault item while holding something** → it still withdraws into the bags; the held item stays in hand. notes:
- [x] (B1.8) **Walk out of the banker's reach with the window open, lift an item, click a cell** → "There is no banker near you." (the proximity gate, unchanged). notes:
- [x] (B2.1) **Open Brom, SELL tab, with loaves in hand** → the list starts with "In hand: Bread Loaf (N)", then the bags' items. notes: Impresssive.  This is cool.  Nice work.
- [x] (B2.2) **Select it and sell 2** → "Offered Bread Loaf x2 to the merchant.", the coin arrives, the hand keeps the rest and the entry's count updates. notes:
- [x] (B2.3) **Sell the rest** → the hand empties and the "In hand" entry leaves the list. notes:
- [x] (B2.4) **Lift the pouch (with something in it), select "In hand: Small Pouch", sell** → "Empty the bag before selling it."; nothing sold. notes:
- [x] (B2.5) **Open the SELL tab empty-handed, and with a Conjured Bread (no vendor value) in hand** (if you have one) → no "In hand" entry either time. notes:
- [x] (B2.6) **Lift an item with the SELL tab already open** → the entry appears without reopening the window. notes:
- [x] (B3.2) **A click on the inventory, the paperdoll or the world while holding** → places, equips or drops as before; the bank and vendor windows take only their own clicks. notes:
- [x] (O3.6) **Open a bag window** → no Destroy button in it; destroying still works by holding the item over the inventory's trash cell. notes:
- [x] (O3.7, H1.6) **Eat by hand, drink by hand, sit to regen, stand, sing a song (a Bard, if you have one)** → all as before; the regen and buff bars follow the server. notes: WTF does "a Bard, if to hand" mean
- [x] (O3.8) **`/dismount`** → not a command any more (nothing can be mounted online). notes:
- [x] (O3.5) **The Test Panel (GM): Spawn Normal, Spawn Named, Despawn All, a GEAR give, Give 1,000 Copper, a faction slider, Take 20 dmg, Full Heal, Trigger Death** → each works as before. The removed buttons (the CHARACTER section, STATS OVERRIDE, ZONE TRAVEL, God Mode, No Cooldowns, Clear All Buffs) are gone. notes:
- [x] (R2.3) **Turn to face a new way, then Test Panel spawn a mob** → it lands in front of where you actually face (the stale yaw used to put it in front of your login facing). notes:
- [x] (F7.1) **Test Panel, Fling 5 m, anywhere** → the body goes up 5 m and drops: "You hit the ground hard for N damage." with N about 7.5% of max HP. notes:
- [x] (F7.2) **Fling 20 m** → about 45% of max HP, the line, the HP bar. Full Heal after. notes:
- [-] (F7.3) **On a plain account, the Test Panel's Fling** (if you have one: an account never granted GM; log in on it, open the Test Panel, press Fling 5 m) → nothing happens: the body stays put, no line, no HP lost, and the journal gets no `dev_fling` row for it. notes: do you mean "on hand"?  Not sure how to test. [Claude, 11-06: "if to hand" meant "if you have one"; the how-to is in the row now; not run yet, so marked `[-]`.]

## B — One seat: the flat ground (the first two rings of camps)
- [x] (H1.1) **Walk and run in every direction, turn in place, strafe** → the speed and the feel as before; no rubber-banding, no pull forward or back. notes:
- [x] (H1.3) **Jump while running** → as before (the jump stays cosmetic; nothing on the server reads it). notes:
- [x] (H1.5) **Jump about, run off the town's steps and bumps, Quit Game mid-jump and log back in** → never a "You hit the ground hard" line, HP untouched, the relogin ordinary (on flat ground the server's fall never begins: a drop needs more than the body's half-metre snap). notes: The town has no steps.  These poor people have no homes or structures.
- [x] (H1.2) **Run under Spirit of Wolf or Selos' Melody** (if a caster is to hand) → the buffed speed as before. notes:
- [x] (R3.2) **`/loc` before and after a minute of turning in place** → the position reads the same: turning moves nobody. notes:
- [x] (F1.4, H3.1) **Walk the first two rings' camps** → flat ground; mobs stand on the ground where they spawn, notice you at their aggro radius, chase, fight and walk home as before. notes:
- [x] (O2.2, H2.1) **Melee a camp mob to death, loot the corpse** → swings land, the kill pays XP, the loot window takes items. notes:
- [x] (O2.3, H2.2) **Cast a nuke at 25 to 30 m and a heal; let one fizzle or get interrupted** → they land, mana and lines as before; no "You cannot see your target." anywhere on the flat ground. notes:
- [x] (H2.3) **A bow at range** (if one is to hand) → arrows land as before. notes: Bow fires and does damage, currently does not consume ammo. I also dont think we have an arrow item to act as the ammo.
- [x] (H2.4) **A point-blank AoE** (a caster at level: Nature's Wrath, Ice Storm, Inferno; if you have one) → every mob inside the radius is hit. notes:
- [x] (H2.5) **A Bard: Aria of Dismay on a mob** (if you have one) → the slow pulses as before. notes:
- [x] (H3.2, O3.4) **Summon a pet (or the warder), attack a mob, watch the console** → it appears beside you on the ground, follows, and attacks on `/pet attack`; no red line on each hit (online it used to error on every mob hit). notes:
- [x] (H3.3) **Charm a mob and let the charm end** (an Enchanter or a Bard, if you have one) → the mob comes back where it stood. notes:
- [x] (F9.6) **Pull a mob, run until it turns for home, then hit or nuke it on its walk back** → "<mob> evades your attack." or "Your target is evading."; it heals to full at home and fights normally when pulled again. notes:
- [x] (O2.7, H4.1, H4.2, F8.1) **Die (to a mob, or Trigger Death), respawn, walk back and loot the corpse** → the corpse lies at the death spot; the respawn lands at the bind, on the ground; gear goes back on. notes:
- [x] (H4.3, F8.2) **Gate (and Succor, if a Druid or Wizard is to hand)** → the arrival at the bind or the town square, on the ground, the pet along. notes:

## C — One seat: the hills
A loop: north to the bandit knoll, the ridge, the pass and the crypt; west to the Barrow, the
Ossuary and the rim; south to the old rocks and the war camp's shelf; east to the spiders' rise
and the Wraith Gate. The first five rows span the loop and tick when every place named is done.

- [x] (F1.2) **Walk onto a hilltop (the bandit knoll is the first) and stand still, then jump** → you stand on the surface (feet on it, not sunk into it) and jump from it as on flat ground. notes:
- [x] (F2.1) **Walk from the town to the bandit knoll, the old rocks, the spiders' rise and the war camp's shelf** → uphill is slower (a 30° slope costs about a quarter of the speed), downhill full speed; no rubber-banding, no pull forward or back. notes:
- [x] (F3.1) **Fight at the bandit knoll, the spiders' rise and the war camp's shelf** → mobs stand on the slope where they spawn, chase you up and down it, fight and walk home as before. notes:
- [x] (F3.3) **Pull a mob from above or below a slope and run** → it follows over the ground and leashes home as before. notes:
- [x] (F8.3) **Summon a pet and walk it over the hills** → it follows, standing on the ground. notes:
- [x] (F2.2) **North to the Greywood ridge, then into its side** → the ridge cannot be walked up: the body slides back and stays at its foot. notes: Player can push into geometry if they walk continuously against the wall, when player stops walking they are pushed out of the wall.  Player cannot climb steep areas in most places, but is able to climb the side of the wall at touches the bandit knoll
- [x] (F2.3) **Through the pass at x = 0 to the Broken Crypt** → a flat way through at walking speed; the crypt in its bowl beyond. notes:
- [x] (F2.4) **West to the Sunken Barrow and the Ossuary** → up the western hills, down into the pit and out again (its walls are steep but walkable), on up to the Ossuary. notes:
- [x] (F3.2) **Fight in the Sunken Barrow** → the zombies come up out of the pit after you. notes:
- [x] (F6.1) **Stand on the Sunken Barrow's rim and look in** → the zombies below; nukes from the rim land where the rim does not hide them. notes:
- [x] (F6.2, H1.4) **Walk to the plate's edge anywhere and try to climb the rim, straight and at an angle** → the ground rises steeply from about 180 m out and becomes a face; the body slides back down; nobody gets over it. notes:
- [x] (F2.5) **East to the Wraith Gate, up its south ramp** → a long climb onto the flat top. notes:
- [x] (F4.1) **From the plateau, walk off its west edge (x = 150)** → the fall: "You hit the ground hard for N damage." with N about 40% of max HP, and the HP bar drops by that. notes:
- [x] (F4.2) **At the foot, try to walk back up the cliff, straight and at an angle** → it cannot be climbed either way; the body slides back. The way up is the south or north ramp. notes:
- [x] (F4.3) **Below 40% HP, step off the edge again** → you die of the fall; the corpse lies at the foot of the cliff. notes:
- [x] (F4.4) **Respawn and run back to the corpse** → it is at the foot; loot it as usual. notes:

## D — Two seats: the town and the flat ground
A is the seat being watched, B the watcher; swap as convenient.

- [x] (O2.1, R1.1) **Both seats enter the world; B watches A; A right-drags to turn in place** → each sees the other move; B sees A's body turn smoothly to the new facing, no slide, no snap. notes:
- [x] (R1.2) **A runs a circle** → B sees A face the way it runs throughout. notes:
- [x] (R1.3) **A strafes left and right** → B sees A face forward while sliding. notes:
- [x] (R1.4) **A walks backwards** → B sees A face forward while backing up. notes:
- [x] (R1.5) **A left-drags (camera orbit only)** → B sees A's body stay put: the camera is not the body. notes:
- [x] (R2.1) **A turns to face B, logs out, logs back in** → A faces the same way on both screens straight after the login. notes:character appears to login facing the correct direction then is suddenly rotated a small amount.  Can you look into this?
- [x] (R2.2) **B logs in while A stands facing away** → A's body faces away on B's screen from the first frame. notes:
- [x] (O2.4, O3.3) **Group the two seats, kill a mob, look at the group panel** → the XP share and the group panel bars; your own row is marked as you on both seats, and the leader sees the kick and leadership controls on the other member's row, not their own. notes:
- [x] (H2.2) **A heal or buff on the group-mate at 25 to 30 m, on flat ground** → it lands; no "You cannot see your target.". notes:
- [x] (O2.6) **Trade an item between the seats** → the commit lands on both. notes:
- [x] (H4.4, F8.2) **One seat dies; the Cleric casts the resurrection on the corpse; accept** → you land beside the corpse, on the ground. notes: [Claude, from the journal (the row came back blank): PLUG died at 17:57:06, CLARK's first Resurrection fizzled, the second was offered at 25% and accepted at 17:57:29, the gear came back off the corpse at 17:58:22. PLUG landed at a quarter HP beside the skeleton that had killed it and died again twelve seconds later: the P99 landing, by design.]
- [x] (H6.1) **A partner's body, pet and corpse** → drawn where they are, on the ground, as before. notes: hard to tell facing of a pet. 

## E — Two seats: the hills
The Wraith Gate first (E.1 to E.7), then the Greywood ridge and the crypt's bowl (E.8 to E.10),
then anywhere. In the sight rows, A is whichever seat has a heal or buff on a group-mate (the
Cleric) and stands at the cliff's foot; B stands on the plateau.

- [x] (F9.1, R3.1) **A partner walks up a hill, stands on it and jumps on it; runs; sits** → drawn on the ground all the way, the jump seen (the jump relay as before), running and sitting unchanged. notes:
- [x] (F9.2) **The partner walks off the Wraith Gate's west edge** → seen falling and landing at the foot. notes:
- [x] (F5.1) **B on the plateau near the west edge at about (158, 0); A, at the cliff's foot at about (138, 0), targets B and casts a heal (or any spell on a group-mate)** → "You cannot see your target." at once: no cast bar, no mana spent. (From the foot to the top is 27 m, inside every spell's 30 m, with the lip some 6 m above the line between them.) notes:
- [x] (F5.2) **A walks round and up the south ramp and casts the same at B from the top** → it lands. notes:
- [x] (F5.3) **B walks to the lip right above A, about (151, 0), and A casts again from the foot** → a steep line up the face: refused or landed, and the server agrees with the client (no `cannot see` in the journal after a cast the client let through). notes:
- [x] (F5.4) **A bow at a mob the terrain hides, inside bow range** (if one is to hand) → the server answers "You miss" (bows have no client sight check yet; the swing goes out and misses). notes: this appears to be true

- [x] (F9.9) **A pet that cannot reach its owner** (an owner with a pet at the cliff's foot walks round and up the ramp to the lip above it, or Gates to a bind on the plateau) → the pet stops at the foot, and about 8 s later appears beside its owner. notes: This appears to work.
- [x] (F9.3) **A mob below a face that cannot reach you** (B walks onto the Greywood ridge from its east end and along the crest to its north edge at about (25, 89.7): the very edge, `/loc` z between 89.5 and 89.9, since a step back and the crest hides the foot. A, a GM, in the crypt's bowl below at about (25, 108), spawns a Test Panel mob, which turns on A; B nukes it once and takes it; A walks 20 m east) → the mob walks to the foot of the ridge under B (about z = 100) and stops there; about 8 s later it turns away, walks home and its HP bar refills to full when it gets there. notes:
- [x] (F9.4) **The same, and B nukes it again once it has stood at the foot a second or two, and once more on its walk home** → "Your target is evading." each time, at once, no mana spent, the mob's HP bar unchanged. notes: tested with physical attack isntead of nuke.
- [x] (F9.5) **The same, but A hits the mob once as it walks to the foot, then stands beside it there and keeps swinging; B keeps the most hate** → from its first second at the foot every swing reads "<mob> evades your attack." and does nothing; when it gives up on B it turns on A (A's first hit put A on its list) and fights. notes:
- [x] (F9.7) **Anywhere: both of you hit a mob, then the one it is fighting dies (Trigger Death on a GM) or Gates** → the mob turns on the other at once and fights; it walks home only when nobody who hit it is left. notes: When a charmed mob vanishes and the player who charmed it hasnt engaged with the enemy, the enemy does not aggro the player when the charm wears off.  Does this make sense?
- [x] (F9.8) **The same, but the one it is fighting runs until it turns away** → it turns on the other instead of walking home. notes:
- [x] (O2.8, H1.6) **`/camp` one seat, close the other with the window X** → the camp logs out; the other lingers about 30 s, as before. notes:

## F — The record
- [x] (O2.9, H7.1, F10.1) **The journal since the start time** (the grep above) → no `ERROR` and no panic; no `cannot see` or `no sight` line for a cast the client let through; a `fall damage` line for each fall taken (the cliff, the flings) and none on the flat ground; `dev_fling` rows only for the GM's Fling presses; `slope_refusals` on the `world health` line is a curiosity on the hills (a key held into a cliff counts), 0 while on flat ground; paste any `WARN`. notes: [Claude, 11-09, both sittings (15:21 to 16:17 and 17:24 to 18:40 UTC): no `ERROR`, `WARN` or panic; no `cannot see` or `no sight`; `fall damage` only for the cliff and the flings, none on flat ground; `dev_fling` only on part C's presses; one `slope_refusals=1` line on the hills at 18:08, every other line 0. PASS.]
- [x] (O2.10) **Read a few journal lines from the sitting** → a line logged while a player's message is handled starts `client{char_id=N account_id=M}:`, and a buy, sell, bank or loot line names the player `char_id=N` (it said `owner=N` or `caster=N` before 2026-11-02). notes: [Claude, 11-09: `client{char_id=48 account_id=2}: ... spell memorized char_id=48`; `corpse loot put worn gear back on ... char_id=36`. PASS.]
- [x] (B3.3) **`admin_report` after the sitting** → `bank_in`, `bank_out` and `sell` rows for part A's moves, the check card balanced. notes: [Claude, 11-09: PASS. `admin_report` run on the R720 after both seats were out (11-09, about 19:00 UTC): `Item ledger check: the books balance (every account's rows match its stores)`, 759 rows. The newest 50 are the 11-09 sitting's: `bank_out` and `sell` rows (PLUG emptying the vault to Brom at 17:46, the copper on each sale), a `bank_exchange`, every `death` row answered by a `corpse_loot` row and `death_coins` -125 by `corpse_coins` +125, a `drop` by one seat and the `pickup` by the other, `gm_give`, `loot` and `starter` rows; part A's `bank_in` rows of 11-06 are older than the window and are in the balanced 759. Every GM action row reads `via=gm`, so the host ran with dev commands off.]
- [x] (O3.9) **The console over the whole sitting** → no red script error. notes: [user, 11-09: "no red script" on either seat through parts D and E; 11-06: "Not that i saw."]

## Notes / observations
- Selos appears to start working before the spell has completed casting

