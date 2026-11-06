# The Monsters and Memories item log: what it records, who sees it, and what ours would be

**Researched 2026-10-29** at the user's request (hotfix checklist notes, 2026-10-26: "We need to
take a look at the Item Log that Monsters and Memories uses."), written the night before the
user's calls. This is the research and a proposal, not a decision. Claims marked *verified*
were read on the named page; claims from the fan tools' own documentation say so, since those
authors reverse-engineered the files and disagree with the wikis in places.

## 1. What M&M has: the ledger

Monsters and Memories (Niche Worlds Cult, in early access since 2026-09-19) has no combat log
and says it never will. What it has instead is the **ledger**: a record of what each character
did with items and with their party, kept by the server and handed to the client.

**Where it lives** (*verified*, both community wikis): the client downloads the files on launch
and deletes them on exit. "When you exit the game, the local copies of ledger files are removed
from disk." They "re-download upon game launch and appear to cache for the last 7 days" (the
7 days marked as needing verification). On disk they sit under
`AppData\LocalLow\Niche Worlds Cult\Monsters and Memories\<server>\<character>\Ledger\`, one
JSON file per character per day. The game also moves the oldest rows out of a dated file into an
`Archive\` folder, 500 at a time (the companion tool's notes).

**Two files per character per day** (*verified*):

| File | Holds |
|---|---|
| `<Name>_Character_<date>.json` | the character's own actions: loot, coin purses, drops, pickups, destroys, both sides of a trade, vendor sales and purchases, harvests, level-ups, the character's own deaths |
| `<Name>_Social_<date>.json` | what the party and the people nearby did: their loot and the party's membership events; the owner's own rows appear here too as twins |

**The record** (the companion tool's notes, read against real files; the wikis agree on the
names they cover): a file is an envelope `c01` to `c06` (the row list, first and last write
times, the character). A row is `f01` to `f10`:

| Field | Meaning |
|---|---|
| f01 | the action code |
| f02 | a name or reference, prefixed `name_`, `zone_` or `ref_`, Base64 |
| f03 | a JSON string of detail fields `d01` onward, values Base64 |
| f04 | the time with offset, in 100 ns units |
| f05 | the zone, Base64 |
| f06 | the actor's level |
| f07 | the actor |
| f08 | 0 for a Character file, 2 for a Social file |
| f09 | the file's owner |
| f10 | the actor's class (added in 0.30.3) |

**The action codes:**

| Code | Meaning | Details carried |
|---|---|---|
| act_01 | level up (the wikis guessed "zone change?"; the companion reads d21 new level, d22 old) | |
| act_02 | the player's own death (zone, level; the cause always empty) | |
| act_11 / 12 / 15 | an item dropped / picked up / destroyed | d03 `user_confirmed_drop` or `user_confirmed_destroy` |
| act_13 | an item looted | d02 the kind of mob, d04 the item's name, d05 its id, d01 a quantity that is always 1 |
| act_14 | a coin purse looted | d12 the coin as `pp,gp,sp,cp`, d13 the mob, d14 `npc_corpse` or `party_split`, d15 the owner's share of a split |
| act_16 / 20 | a trade given / received | `partner` (a number, never a name), `currency`, `items` [id, name, quantity], a summary |
| act_24 / 28 | sold to / bought from a vendor | d03 the coin for the whole stack |
| act_27 | a harvest | d04 the item, d01 the quantity |
| act_31 to 36 | party created, joined, left, leader changed, disbanded, invite received | d62 the member count after, d63 the event name |

Codes the client defines but no file has ever shown: act_04, 05, 17 to 19, 21 to 23, and a guild
ledger type with no files behind it.

**What it leaves out, on purpose** (*verified* for combat; the rest from the fan tools, each
stated as a limit they hit): combat of any kind ("Ledger files DO NOT contain any combat related
logging by design"; "As of 2026-09-10, there are no plans to allow a log file that captures
combat activity"), spell casts, kills and spawns (only loot, so an unlooted corpse never
appears), positions, zoning itself, which corpse an item came from (only the kind of mob), which
vendor bought or sold, the trade partner's name, the items left on a corpse, quest hand-ins,
coin dropped or destroyed, chat, and everything another player did that is not loot or party
membership: not their sales, harvests, trades or drops, and not the amounts they received in a
split.

**Who sees whose business.** A player sees their own actions in full, and of the people around
them only what they looted from what kind of mob and the party's membership changes. A
groupmate's loot row logs your exact coin share; your own loot row logs the whole pile. Names and
zones are Base64, which is obfuscation for the casual reader and nothing more.

**Is there an in-game view? Unverified.** The developer's 0.22.0.0 note (April 7, 2026) is
written as if there is: under UI, "The social ledger is now active, all party related actions
should show up here in the log" and "Improvements made to the character ledger - you can now see
when you sell items to a merchant ... harvesting action (mining, gathering, etc.)". But the
official new player guide's full window list (I, Ctrl+I, Shift+B, B, P, O, J, Y, Shift+G) names
no ledger, and neither wiki nor any fan tool mentions one. The only readers in the wild are the
fan tools. The 0.30.3.2 note (October 19, 2026) says only "Ledger updates and fixes."

**What people built on it** (the reason it is worth copying): a loot splitter that divides each
item's value between the members who were in the group when it was looted and settles the
difference in coin; a loot meter with drop alerts for the group; a merchant price book; drop
tables per mob from the social feed. The game forbids third-party parsers and data mining (the
spawn-timer README's reading of the Play Nice Policy; not verified on the policy itself), and
the ledger is the one feed it hands out on purpose: it answers the questions groups argue about
(who got what, is the split fair, what does this mob drop) without exposing combat numbers or
anyone's inventory.

## 2. What Project Dawn has today

Read from the source on 2026-10-29.

- **The journal.** Thirteen item-movement lines go to the server log, one per handler:
  `MoveItem applied`, `SplitStack applied`, `EquipItem applied`, `UnequipItem applied`,
  `DestroyItem applied`, `UseConsumable applied`, `GmGive applied`, `BuyItem applied`,
  `SellItem applied`, `trade committed`, `DropItem spawned loot bag`, `loot bag spawned`, and
  the corpse-loot and refund lines. Operator-only, unstructured text, keyed by char id, in a
  file per run on the dev box and in journald on the R720.
- **`gm_actions`** (`migrations/0001_init.sql`): the one persisted audit table, one row per
  authorized dev or GM command (actor account, target account and character, command, args,
  time). It records `/give` and the Test Panel; it records nothing a player does.
- **`admin_report`**: a snapshot of every character's coins and inventory plus the newest
  fifty GM rows. A snapshot shows what is held now, not how it got there.
- **The client**: chat lines ("Trade complete.", the loot lines) and `debug.log`, which rotates
  at 2000 lines. Nothing a player can look back through.

So the hotfix's dupe hunts (H2, H3) were done by reading journals by hand, and the public-host
plan's "nightly dupe-detection query" has nothing to query. A player who dropped a pouch on the
ground, sold the wrong sword, or traded a stack away has no way to find out which, and neither
do we without the journal and a timestamp.

## 3. What an item ledger would be here

The useful part of M&M's design is not the files; it is the rule that **every item action is one
row, written by the server, visible to its owner, and the only thing the group sees of each
other is loot and membership.** Three sizes:

**A. The audit table (server only, no wire).** An `item_events` table: time, character, action,
item path, count, location, the counterparty (the mob kind, the vendor, the trade partner's
char id, the corpse or bag id), the coin where coin moved. One insert inside the transaction
that makes the move, so a row exists exactly when the move does (the hotfix's H2 lesson: a row
written outside the transaction is a second thing to disagree). Read by a new `admin_report`
card ("the last 50 item events for character N") and by the nightly dupe query, which becomes
possible for the first time: for each character and item path, created (loot, buy, quest,
summon, GM give, trade in, bank out) minus removed (sell, destroy, eat, drop, trade out, bank in,
death) must equal what the stores hold; a mismatch is a dupe or a loss with a date on it.

**B. The owner's history.** On top of A, a `/history [n]` chat command that answers from the
table (the last n rows for your own character, as chat lines). No window, no new message type:
a `ChatMessage` on the System channel, the silent-refusals precedent. Answers "where did my
sword go" in game.

**C. M&M's full shape.** A per-character feed sent to the client and kept there, a social half
of what the group looted, a window. Needs a wire message and a DLL rebuild, a window, and the
group-visibility rules. It is what the loot-split and drop-alert tools were built on; nobody at
friends scale has asked for them.

**Recommendation: A now-ish, B after the door, C only if a group asks for it.** A is a small
server build (a migration, one insert per handler, a report card, one query) and it is the tool
every dupe hunt so far has wished for. It pairs with the public-host checklist's dupe query and
Phase 6's observability. B costs almost nothing once A exists.

## 4. Exploit lens

- **The row is written by the server inside the move's transaction, or it is not evidence.**
  Nothing the client sends is ever a ledger row; the client cannot write, correct or delete one.
- **Reading is not an oracle.** A `/history` answers only about your own character. It never
  names whether another player is online, where they are, or what they hold (the 10-02 rule:
  far, offline and never-existed look the same). A later group feed sends what M&M sends and no
  more: who looted what kind of item from what kind of mob, and party membership. Never
  another player's sales, trades, drops, split amounts or bank.
- **A player-facing read is an intent and gets a budget** (housekeeping M4) so it cannot be used
  to make the server do database work on demand.
- **Conservation needs no per-instance item id.** Items are registry entries plus counts, so the
  ledger cannot follow one sword; it can follow the count of swords per character, which is what
  a dupe changes. A per-instance id (the gem-sockets item's open question) would sharpen it
  later, not block it.
- **Size.** One row per action; the hotfix's drop-persist rule already bounds drops at four a
  tick. Prune by age (M&M keeps about a week on the client); the operator copy can keep longer.

## 5. What this is not

Not a combat log (we already have more combat lines than M&M will ever write, and nothing here
changes that), not a change to any item rule, not a player-visible window in the friends build.

## 6. Calls for the user

1. **Build A (the server-side audit table)?** Recommended: yes, as a small server-only build;
   before any public exposure at the latest, sooner if a dupe hunt is wanted.
2. **Which actions.** Recommended: every server item mutation, one row each (loot, corpse loot,
   coin purse, drop, pickup, destroy, eat by hand, both sides of a trade, buy, sell, both vaults
   in and out, quest reward, summoned item, GM give, the death strip). Nothing cosmetic.
3. **Who sees it.** Recommended: the operator (`admin_report`) first; the owner by `/history`
   after the door; a group loot feed only if asked for.
4. **Retention.** Recommended: 30 days, pruned at the checkpoint, with the dupe query run
   against the full window; the operator can export before the prune.

## Sources

- Logfiles, the Miraheze wiki (last updated 2026-09-13 for build 0.29.0.1):
  https://monstersandmemories.miraheze.org/wiki/Logfiles
- Logfiles, the second community wiki (the same page with the field detail):
  https://monstersandmemories.wiki/guides/logfiles
- Patch 0.22.0.0, Beta Patch 3, April 7, 2026 (the social ledger goes live; merchant sales and
  harvests join the character ledger): https://account.monstersandmemories.com/community/patch_notes/9
- Patch 0.30.3.2, Module 1 Patch 13, October 19, 2026 ("Ledger updates and fixes."):
  https://account.monstersandmemories.com/community/patch_notes/62
- The official new player guide (the window and key list; no ledger named):
  https://monstersandmemories.com/new-player-guide
- Commands, the Miraheze wiki (no ledger command): https://monstersandmemories.miraheze.org/wiki/Commands
- MnMCompanion and its `docs/ledger-notes.md` (the record format read against real files):
  https://github.com/ExploreTheFloor/MnMCompanion
- MnM Loot Splitter (the group split built on act_13): https://github.com/FrantzCr/mnm-loot-spliter
- MnM Spawn Timer (the loot meter, drop alerts, the f10 note, the no-combat-log statement):
  https://github.com/jessemlay/mnm-spawn-timer
