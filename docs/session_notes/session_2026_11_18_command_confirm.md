# Session 2026-11-18: command confirmations (the success lines said by the server)

## 1. What was asked

After R4 (same session), the review had left one finding for the user: `/kick`, `/invite`,
`/pvp` and `/autosplit` print a success line before the server has answered. The user: "Can
you change the success lines to send at the correct time?"

## 2. What was read first

Both sides, before deciding the shape: the client's command functions and
`GroupManager`; on the server `handlers.rs` (`PvpToggle`, `SetAutosplit`, the four group
intents), `tick/grouping.rs` whole (what each intent sends back) and `groups.rs`.

- The server answers these commands' refusals ("X isn't online.", "X isn't in your group.")
  and never their successes. A successful invite tells the invitee only; a kick, an accept, a
  leave and a loot-mode change re-send the roster (the panel changes, no line); the PvP and
  auto-split toggles answer nothing at all to the toggler.
- So "the correct time" did not exist on the wire for a chat line, and a client-only change
  could only have reworded the lines as requests.
- The same fault in more places than the review named: `/accept` ("Accepted the group
  invite."), `/leave` ("You left the group."), `/loot rr|ffa` ("Loot mode set to ..."), the
  group panel's Invite button, and `/damage` / `/heal` ("Dev damage self: 5").

## 3. What was built

On `feat/command-confirm` in both repos (side branches: both halves have to reach players
together, and the door zip is frozen), committed locally, not pushed.

**Server** (`F:\Projects\server-confirm`, `406b10c`): each success is said to the player
who gave the command, when it is done, through the existing System chat line
(`handlers::send_system_line`, no wire change):

| Command | The line |
|---|---|
| invite | "You invite <Name> to join your group." (the invitee's own spelling); inviting yourself: "You cannot invite yourself." (was silent) |
| accept | "You have joined the group."; no open invitation: "That invitation is no longer open." (was silent) |
| leave | "You have left the group."; no group: "You aren't in a group." (was silent) |
| kick | "<Name> has been removed from the group." |
| loot mode | "Loot mode set to Round Robin." / "Free-for-all." (`LootMode::name`) |
| auto-split | "Auto-split loot: on" / "off" to the toggler, whether or not the flag moved; the group notice to the others unchanged |
| PvP | "PvP override: on" / "off" |

**Client** (`F:\Projects\Project_Dawn-confirm`, `524e623`): the eight local success lines
removed (seven commands and the group panel's Invite); `/damage` and `/heal`, which the
server never answers by design, say what was asked ("Requested 5 damage to yourself from the
server."); `check_chat_commands.gd`'s rows follow (a sent command answers nothing locally and
is held by the function its table key names, the first-word table included; `/accept` and
`/leave` typed with an invitation and a group on file); `commands.md`; the two-seat sheet
`command_confirm_checklist.md` (26 rows).

## 4. Tests

- `the_server_confirms_a_group_command_when_it_is_done` (`tests/world/groups_and_quests.rs`):
  two clients through every command; each success told once to its giver; an invitation to
  nobody, a kick of nobody, a second accept, a leave with no group and a member's loot-mode
  request each get their refusal (or silence) and no success line. Run against the unchanged
  server source it fails at its first line ("never told PvP override: on").
- Server: 481 unit and 202 world tests, fmt and clippy clean.
- Client: `check_chat_commands.gd` 155 checks; all 20 checks (against the server branch) and
  all 25 probes green.

## 5. Why side branches, and what merging needs

The two halves are wrong apart: this client against the deployed server says nothing for
these commands, and the door zip against the new server says each line twice (its own, then
the server's). Neither is harmful, both are visible, so neither branch went onto a deploy
branch the day before the door. They merge at the bump after the door, both in the same step
as the export and the redeploy. No wire change, no DLL rebuild, no migration, no SQL.

## 6. Not built, flagged

- The other members of a group still get no chat line when someone joins, leaves or is
  removed (their panel changes). EQ told them; nobody asked, so it was left.
- `GroupManager.leave_group` still clears the group panel before the server answers.
- The invitee still gets no chat line for an invitation (the panel shows it).

## 7. The other question of the turn

"What call do I need to make about the parameter with no caller?" It is
`ChatWindowManager.show_chat_input(prefill)`: an optional text the chat line opens already
holding. Its one user was the `/r` reopen that R4 deleted as unreachable. The call is delete
or keep. Nothing in the To-Do waits on it; an EQ-style "/" key that opens the chat line with
the slash typed would use it. Answered to the user with a recommendation; not changed.

## 8. The slash key (the user's answer: "yes i want this")

So the prefill stays and has a user again. Client only, on the deploy branch (it does not
touch the files the confirmation branch changes).

- `hud.gd`'s key handler: the bare `/` key, with the chat line closed, calls
  `CombatLog.show_chat_input("/")`. Not with Shift, Ctrl, Alt or Meta held, so a chord on
  the key stays free. With the line open the key never reaches the handler (the line types
  it), and the same is true of any other focused text field.
- `CombatLog.show_chat_input` and its signal carry the prefill to
  `ChatWindowManager.show_chat_input`, which already took one. The HUD still reaches the
  chat line through `CombatLog` only.
- `/` is in `RESERVED_KEYS` with Enter and Escape: the keybind screen refuses it, and a
  saved binding on it falls back to its default at load.
- `tools/probe_slash_opens_chat.gd`: the real HUD and the manager's chat windows, key presses
  pushed into the root window. 11 checks; on the code before the change 5 fail (the line
  does not open, and the key is not reserved). All 20 checks and all 26 probes green.
- Docs: the controls README, `commands.md`, the tester README; five rows in
  `tell_reply_and_inspect_click_checklist.md` §4b (and its `/tell B` row corrected for the
  sticky channel and R4's bare `/tell`).
- What the probe cannot see: a real keyboard. The press that opens the line must not also
  be typed into it; the engine delivers one event per press and Enter has always opened the
  line the same way without submitting it, but the sheet's first row is the evidence.
