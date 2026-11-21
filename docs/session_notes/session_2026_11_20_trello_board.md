# Session 2026-11-20: the Trello board, kept in sync

## 1. What was asked

The user wanted a real Trello board for the project on their own account (asked 2026-11-11; a
Trello-style artifact page came first, then a one-off board built from a temporary script on
11-13), kept up to date "along with the schedule.html" as the work goes on. On 11-20 they shared
the Monsters and Memories roadmap board (https://trello.com/b/wjN4owwf/monsters-and-memories-roadmap)
and asked for its layout, and for the features it lists that our To-Do does not.

## 2. What was built

`tools/trello_board.py` (in the repo; the 11-13 scripts lived in a temporary folder since cleared).
It syncs https://trello.com/b/b8iQBiSH/project-dawn (private, the "Pandora's Box" workspace) from
the CLAUDE.md To-Do, the session notes index and the long `session_2026_10_25.md`,
`docs/schedule.md` section 7 and `docs/schedule_detail.toml`.

- **Lists in the order a player meets the game**, as M&M's are: Welcome, Accounts & Login,
  Character Creation, The World, Movement & Exploration, Chat & Social, Items & Inventory, NPCs,
  Quests & Factions, Classes, Spells & Abilities, Combat, Pets & Charm, Death & Corpses, Grouping &
  Loot, Tradeskills, Food & Consumables, UI, HUD & Audio, Security & Anti-cheat, Server, Hosting &
  Tools. Each To-Do entry is placed by the start of its title (`JOURNEY`); one no prefix claims
  falls back to its To-Do section and is reported on every run (none today).
- **Status as a label**, read from the To-Do's own words: Done (playtested) for a ticked entry;
  Built, awaiting playtest (BUILT, DEPLOYED or MERGED); Ongoing (partly built, when the entry also
  names a part still open); Decided, not built; To Be Discussed (DESIGNED, or a decision waiting on
  the user); Backlog.
- **A "^^ FRIENDS BUILD ^^" divider in each list**, M&M's proof-of-concept line: done, built and
  ongoing above it, the rest below.
- **A Welcome list**: how to read the board, the current goals (the planner's latest week and the
  after-the-door strip, with the planner page's link), phases and milestones, then one card per
  month of sessions, newest first (eight months, April to November).
- **One board, updated in place.** Each card ends with a `pd-id:` line; a re-run updates a changed
  card, creates a new one and archives one whose entry is gone. Cards, lists and labels from an
  older layout are archived or deleted. Hand edits are overwritten; comments survive.
- **Credentials** from `F:\Projects\trello.local.env` (outside both repos), never printed; the
  token is a 30-day one, expiring 2026-12-20.

The first run made 189 cards in 17 lists and archived the 11-13 board's 369 cards, 16 lists and 13
labels (610 writes); a second dry run found nothing to change.

## 3. Records

- CLAUDE.md, Session workflow step 4: sync the board in the same sessions that regenerate the
  planner; an expired token is reported, not a blocker.
- `docs/reference/commands.md`: the tool's row beside `schedule_detail.py`.
- `docs/design/mnm_roadmap_gap_list.md`: the M&M features no To-Do entry covers, by area, each
  with what we have and an empty column for the user's add / later / no. Nothing goes on the
  To-Do until the user sorts it.

## 4. The review pass (the user out walking: "review for any changes you might see")

- **Hand-made cards are left alone.** The first version archived every card without a `pd-id:`
  line, so a card the user or the planner added would have vanished at the next sync. Now only
  the sync's own cards are touched, and an old list or label is removed only when no hand-made
  card uses it; the run lists any hand-made cards it saw.
- **Card positions never settled.** Trello renumbers a position that collides with another
  card's, so setting exact numbers left 17 cards "changed" on every run. Lists and cards are now
  compared as an order, and a list out of order is renumbered above its highest position.
- **Statuses:** "pending playtest" without the word BUILT now reads as built (the chat-tab
  entry), and four entries whose words read as wholly built while only part is (EQ keybinds, the
  UI layout, factions, camp and kick) are Ongoing by a small override table, each with its
  reason. Five Done cards had no date (their entries say PLAYTESTED, RE-TESTED, Ticked or BUILT);
  all have one now.
- **Card text:** the To-Do's 100-column wrapping is joined back into paragraphs, a new paragraph
  starts at each bold stage ("**BUILT ...**", "**DECIDED ...**"), tables get the blank lines
  markdown needs, and a dash ending a line is dropped (it read as " , ").
- **The divider's wording** no longer claims everything above it is in the friends' build: some
  built work is on a branch or waits on a zip, and its card says so.
- **A paused milestone** shows "no date (paused)" instead of 11-19.
- **Nothing private on the board:** every card scanned for addresses, passwords, keys and the
  user's paths; none.
- The gap list's two "check" rows settled from the code: there is a 20% group XP bonus
  (`GROUP_XP_BONUS`), and no attribute allocation at creation.

After it: a sync rewrote 174 cards and reordered two lists; a second run found nothing to change.

## 5. Not done

- The gap list is unsorted (the user's call).
- The board is private: the planner needs a board invite to see it (the user's, from Share).
- Committed and pushed on the user's word (2026-11-21).
