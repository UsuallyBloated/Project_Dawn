# Seeing other players' levels

Status: a design note, 2026-11-16. Nothing built. Three decisions for the user in section 5.

Asked for by the user on 2026-11-02 (`overnight_2026_11_01_checklist.md` §3: "We cant currently
see eachother's levels in game"). The To-Do entry is "Other players' levels" under UI polish.

## 1. What exists today (read in both repos on the deploy tips, server `a3b226d`, client `c294d37`)

- **The group panel shows a level, but always the wrong one for anyone else.**
  `GroupManager._on_world_group_roster` (`autoloads/group_manager.gd:126`) builds every member row
  with `"level": 0`, and `hud_group_panel.gd:159` draws `"Lv %d"`. Your own row is right
  (`_local_stats` reads `PlayerStats.level`); every other row reads **Lv 0** for the whole session.
  That is a visible bug, not just a missing feature.
- **The wire never carries a group member's level.** `ServerWorldMsg::GroupRoster` carries
  `members: Vec<(EntityId, String)>`, ids and names only (`protocol/src/world.rs:1454`).
- **A level reaches other players once, when they first see you.** `EntitySpawn` carries `level`
  (`world.rs:1206`), and the client keeps it on the remote player (`remote_player_manager.gd:538`).
  Nothing updates it afterwards: `LevelUp` goes to the levelling player alone
  (`handlers.rs:2785`, one recipient). So a level gained, or lost to a death, while someone watches
  you is never shown to them until you leave their view and come back.
- **The target frame hides a peer's level on purpose.** `hud.gd::_setup_peer_target` clears the
  level label, "per user feedback" (session note 2026-05-12: "peer level not surfaced in the target
  frame"). That decision is still in force; nothing here reverses it unless you say so.

## 2. What EverQuest did (only what could be checked)

- `/who` showed a player's name, level, class and guild, and a player set to **anonymous** showed
  their name only (Allakhazam's [EQ:Commands](https://everquest.allakhazam.com/wiki/EQ:Commands)).
  So EQ treated a level as public by default and gave players a way to hide it.
- Whether the stock classic group window showed member levels could **not** be confirmed. The one
  hint is indirect: a third-party group window ([MyGroup on RedGuides](https://www.redguides.com/community/resources/3080/))
  advertises levels in its tooltips as a feature. Treat "EQ's group window had no levels" as
  unverified.

## 3. Shapes

**A. Group members see each other's levels (recommended).** The roster carries a level per member,
`members: Vec<(EntityId, String, u32)>`. The server re-sends the roster to the group whenever a
member's level changes, up from `progression::award_xp` or down from a death's de-level. The
roster fan already exists for membership changes, so this is one more caller. The group panel
reads the level from the roster. This fixes the Lv 0 rows. It tells nothing to anyone who did not
choose to group, so it is the smallest change in what players can learn.

**B. A plus a level in the target frame for players in view.** Reverses the 2026-05-12 call. It
needs a `PlayerLevel { id, level }` sent on every level change to the players who can see the
leveller (the Position fan's audience, `aoi.entities_visible_from`), because `EntitySpawn`'s copy
goes stale. EQ-shaped would also need an `/anon` toggle that hides the level from everyone outside
the group.

**C. A `/who` command.** EQ's way of asking. It needs a server-side lookup by name, the anonymous
flag, and a decision on who `/who` reaches (the zone; everyone online). It is its own small
feature, and best left until after the door.

**A no-wire stopgap, if one is wanted before the next bump:** the group panel shows a member's
level from their remote-player node while they are in view (its `EntitySpawn` level), and nothing
at all, rather than "Lv 0", when they are not. It is client-only and a few lines. Its flaw is
that a level gained in view stays stale until the member leaves view and comes back. It needs a
new zip.

## 4. Cost and exploit lens

- A, and B's relay, change the protocol (the roster's shape for A, a new message for B). That
  means a protocol bump, a DLL rebuild, an export and a redeploy together. It rides the next bump
  day, after the door.
- A level is the server's own value, so no client can forge one, and nothing reads it back from a
  client. The only exposure is what other players learn. A tells group-mates only. B tells
  everyone in view, which is real PvP information: a flagged player learns who is weaker before
  engaging. That is why EQ had anonymous.
- A level change must re-send on the way down too (a death that de-levels), or a group-mate's row
  would overstate a member who died. The server test should cover both directions: a member levels
  up and the partner's roster carries the new level; a member is de-levelled by a death and the
  partner's roster drops.

## 5. Decisions for the user

1. Which shape: A (group only), B (A plus the target frame and `/anon`), or A now with C later?
2. The stopgap: build it into a zip before the next bump, or wait for A?
3. If B: does the 2026-05-12 rule (no peer level in the target frame) give way?
