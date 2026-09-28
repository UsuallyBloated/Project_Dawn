# /loc: The Location Command

*Design note, 2026-09-25. Raised alongside the zone-size research, which observed the
game has no minimap and no /loc. Small, client-only, EQ-authentic. Becomes genuinely
load-bearing once the big-world track starts: content authoring (`zone_camps.toml`,
`npcs.toml` positions are hand-written world coordinates), playtest triage ("where were
you when it broke"), and the height-model playtests (reporting Y) all want a way to
read a position off the screen.*

## What it does

Typing `/loc` in chat prints the player's current position to the System channel:

```
Your location is 142.6, 0.0, -87.3 (x, y, z). Facing north-east.
```

- Coordinates are Godot world units (meters), printed x, y, z to one decimal. We do not
  copy EQ's Y-first ordering; our authoring files are `[x, y, z]` and the printed order
  must match what someone pastes into `zone_camps.toml` or `npcs.toml`.
- The facing suffix reuses `SenseHeading`'s compass math (rotation-based, already
  built) so /loc doubles as a heading check without training the skill. Open call
  below on whether facing shows for everyone or only trained Sense Heading.

## What EverQuest actually did (verified 2026-09-25, sources below)

For the record, since this doc consciously departs from it: EQ's `/loc` printed
"Your Location is Y, X, Z", with the Y coordinate FIRST. The first number was
north/south (positive = north), the second west/east (positive = west), the third
altitude, each zone having its own origin. It was free and exact for everyone; the
*skill* was Sense Heading, and players navigated by pairing the two. Classic /loc
carried no zone name and no facing (MacroQuest later added a compass suffix).

We keep the spirit (a free, exact, self-only position print paired with the existing
Sense Heading skill) and drop the letter (Y-first ordering), because our authoring
files speak `[x, y, z]` and paste-ability is the whole point. Sources:
[RedGuides /location](https://www.redguides.com/docs/projects/everquest/commands/cmd-location/),
[EverQuest Location Guide](https://www.oocities.org/thelion78/eq/locate.html).

## Where it hooks in

- The chat-command router that already handles `/version`, `/console`, `/pvp` and
  friends: `scripts/hud.gd::_handle_chat_input` (the if-chain at ~:1295-1687). The
  exact model to copy is `/sense` (~:1410): client-only, reads the HUD's `_player`,
  prints one `CombatLog.add_line(..., MsgType.INFO)` line, returns. The server parses
  no chat text at all (verified: no slash-command checks anywhere server-side), so
  nothing changes there.
- Position source: the local player node's `global_position`. In launcher mode the
  server owns XZ and the client owns Y, so this is the honest "where my client thinks
  I am", which is what both authoring and triage want.
- Output: `CombatLog` System channel, unattributed, same as other command replies.

## Deliberately out of scope

- **No wire traffic and no server change.** The client already knows its position;
  /loc reveals nothing new. Zero exploit surface for the same reason.
- **No /loc of other players.** A "where is X" query would be new information and a
  tracking tool; that belongs to a future Track-skill or GM tool discussion, not here.
- **Not a minimap.** The minimap stays its own UI-polish item; /loc is the text
  stopgap that makes big-world work possible before a map exists.

## Nice-to-have (decide at build time, all cheap)

- A GM/dev extra: when the Test Panel is available, also print the server's last
  broadcast position for the local player, so client-vs-server drift is visible in one
  line. Gate on the same `is_gm` fact the panel uses; silent for everyone else.
- Clicking the printed line to copy coordinates, if the chat window supports meta text
  cheaply; otherwise skip.

## Calls, as built (2026-09-27)

Built client-only per this note (`sense_heading.gd` + the `hud.gd` router;
`commands.md` updated). The three calls landed as:

1. **Facing: free for everyone, and exact.** /loc exists for triage and
   authoring; a garbled position report defeats the point. The Sense Heading
   SKILL keeps its fuzzy roll on `/sense` (new `SenseHeading.exact_facing`).
2. **GM drift extra: not in v1** — add when someone actually wants it.
3. **North is +Z (USER DECIDED 2026-09-27), east stays +X.** The camp labels
   and quest dialogue stand; `sense_heading.gd`'s ring flipped to match
   (rotation.y = 0 now reads South). Audit result: the content was already
   consistent with +Z north / +X east (gnolls "east" at +X, wolves "south"
   at -Z, Ring 4 N at +Z); the only -Z-north code was sense_heading itself.
   Note the chirality: facing north, east is on your LEFT here — a mirrored
   compass, invisible in game, deliberately not "fixed" because all content
   is authored against it.

## Open calls for the user (superseded — kept for the record)

1. Facing suffix: for everyone, or only with Sense Heading trained (EQ made /loc free
   and heading a skill; splitting hairs may not be worth it)?
2. Should the GM drift extra ship in v1 or wait until it is wanted?
3. **Which way is north?** The codebase disagrees with itself (found during this
   research): `sense_heading.gd:61` treats **-Z as North** (rotation.y = 0, Godot
   forward), while `data/zone_data.gd`'s camp comments treat **+Z as north** ("Ring 4
   N" sits at z of about +118), and the server's `zone_camps.toml` was ported from
   those labels. The facing suffix makes one of them player-visible for the first
   time, so /loc forces the pick. Recommendation: **-Z = North**, since Sense Heading
   already ships it to players and it is the engine's forward; treat the zone_data
   comments as mislabeled internal notes. Whichever wins, audit the camp comments and
   any quest dialogue that gives compass directions in the same pass, so "north of
   town" in an NPC's mouth matches what /loc and /sense tell the player.

## When built

- Update `docs/reference/commands.md` (the standing rule for any new chat command).
- Playtest checklist rows: coordinates match a known landmark (Sister Maelis's authored
  position in `npcs.toml` is a good anchor), decimal format, facing correctness at the
  four cardinals, and the command working while dead (a corpse run is exactly when you
  want /loc).
