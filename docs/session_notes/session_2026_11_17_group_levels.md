# Session 2026-11-17: group-mates' level and class

The user, on `docs/design/peer_levels.md`'s first question: "Players should see the class and
level of their group mates. Class should be abbreviated by using three letters. Warrior = WAR
and Necromancer = NEC are a couple examples." Then: "Lets get it all knocked out." That is the
note's shape A with the class added. Shapes B (a level in the target frame) and C (`/who`) were
not asked for and are not built; the 2026-05-12 rule (no peer level in the target frame)
stands.

Built on `feat/group-levels` in both repos (new worktrees `F:\Projects\server-levels` from the
server deploy tip `f388b96`, `F:\Projects\Project_Dawn-levels` from the client tip `6337a98`).

## 1. What changed

**Protocol (PD_W0031).** `GroupRoster`'s members are `GroupMember { id, name, level, class }`
(the class is the server's full base class name). A shape change inside the Vec, so a protocol
bump; both sides move together.

**Server.**
- `handlers::fan_current_roster` is the one home for "the group changed, tell the group": it
  builds the rows (`group_member_rows`, level and class from each connection), sends the
  roster, then the panel-row resource seed. It replaces the closure in `tick/grouping.rs` and
  the copy on the logout path in `tick/session.rs`. `handlers::fan_group_ended` replaces the
  five hand-written empty-roster sends (leave, kick, dissolve, logout).
- `progression::award_xp`, the single choke point for XP and levels, sets
  `PerConnection::group_roster_stale` on any level move. A new tick step,
  `grouping::refan_rosters_on_level_change`, runs right after the death sweep (so a death's
  de-level is caught in the same tick), and re-sends one roster per affected group.
- The DLL's `group_roster` signal gains `member_levels` and `member_classes`, after
  `loot_mode`.

**Client.**
- `CharacterData.CLASS_ABBREV` and `class_abbrev()`: EverQuest's three letters where a class
  has an EQ counterpart (WAR, PAL, SHD, CLR, DRU, SHM, BST for the Beast Master as for EQ's
  Beastlord, ROG, MNK, RNG, BRD, MAG, WIZ, ENC, NEC), ours for the rest: Witch Hunter WHT,
  Sorcerer SOR, Blood Mage BLM. A class not in the table falls back to its first three
  letters.
- `GroupManager` reads each member's level and class from the roster, and a re-sent roster
  keeps a known member's bars (they used to be rebuilt empty and refilled by the seed). Your
  own row carries your class too.
- The group panel shows "12 WAR" beside the name, nothing before the server has said a level
  (the old "Lv 0" is gone), and the level alone if a class is ever missing.
- `tools/check_wire_layer.gd` checks `group_roster`'s argument count (7), so a stale DLL
  emitting the old 5 is reported (it was, against the deploy DLL) instead of failing at every
  emit.
- `CHECKLIST_FOR_TESTERS.md` row 11 now expects the level and class.

## 2. Tests

- Server: `group_mates_see_each_others_level_and_class_both_ways`. The roster that forms the
  group names both classes at level 1. A GM's XP grant to exactly level 6 plus one point
  reaches the partner's roster at 6. A death drops the GM to 5, and the partner's roster
  follows. An ungrouped third player beside them is sent no roster. It fails at the level-up
  with the re-send step removed, and at the outsider with the roster sent to every
  connection. The whole suite: 445 unit, 196 world, fmt and clippy clean.
- Client: `tools/probe_group_levels.gd` (every class three capitals and unique; WAR and NEC;
  the roster's level and class on the rows; a re-sent roster moving the level down and keeping
  the bars; the panel's "11 WAR" in a built row; no "Lv 0"). All 17 checks pass against
  `server-levels`, and a headless boot is clean.

## 3. Review pass

`/code-review` on the server branch, seven findings. Fixed: the roster helper's unused return
value; the empty-roster send copied five times (`fan_group_ended`); no test that the audience
stays the group (the outsider, now in the test); rows rebuilt empty on every re-sent roster
(the client keeps known bars). Left as they are: the stale-flag scan visits every connection
each tick (tens of players, one boolean each); a level change sends each member's resources
to the group (at most 108 small messages, on a rare event); an `award_xp` after the step in
the tick order would be picked up a tick later (none exists today: upkeep, regen and the
position fan never award XP).

## 4. Exploit lens

The level and the class are the server's own values; nothing reads either back from a client.
The roster reaches the group's members only (the test pins it). What a player learns is what
their group-mates are, which they chose to group with. A GM's repeated XP grants could
re-send rosters, but those go through the dev-command bucket, and only to the GM's own group.

## 5. Deploy shape

Both sides together: the server redeploy (the boot line's `build=` names the merged sha) and
a new zip. Neither works with the other's previous build. No migration and no SQL. The DLL
must be rebuilt for the export (`check_wire_layer.gd` refuses the old one).
