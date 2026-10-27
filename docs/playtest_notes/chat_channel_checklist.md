# Sticky Chat Channel Playtest Checklist (2026-10-26)

The chat line now works like WoW's: it always has a channel, shown in colour to the left of the
text (`[Say]`, `[Shout]`, `[OOC]`, `[Group]`, `[Tell: Bob]`). Typing a channel command at the
start of the line (`/say `, `/s `, `/shout `, `/sh `, `/ooc `, `/g `, `/group `, `/gsay `,
`/tell Bob `, `/t Bob `, `/r `) switches the line the moment its space is typed, and the command
leaves the text: it is never part of a message, even typed or pasted twice. The channel sticks
until another command moves it. Plain text always goes out on the line's channel (before, with no
default channel set, it was only echoed on your own screen and nobody heard it). Other commands
(`/sit`, `/loc`, `/camp`, `/pet ...`) still run as commands.

**Needs a client export** (client only; the server is unchanged). Two players for the
"the other side sees it" rows.

## Setup
- [ ] Both players on the new export (login screen build stamp). notes:

## 1 — Channel commands switch the line
- [x] **Press Enter** → the line opens showing `[Say]` on a window with no default channel.
  notes:
- [x] **Type `/sh ` (with the space)** → the text clears and the line shows `[Shout]` in
  orange. notes:
- [x] **Type `/say ` then paste `/say hello`** → the line is `[Say]` holding just `hello`;
  sent, both players see "hello" with no "/say" in it. notes:
- [x] **Type `/sit` and press Enter** → you sit; the channel did not change. notes:
- [x] **Type `/t <partner> ` (with the space)** → the line shows `[Tell: <partner>]` and is
  empty. notes:

## 2 — Sticky
- [x] **`/shout hi`, then open the line again and type `again`** → both lines are shouts; the
  line still shows `[Shout]`. notes:
- [x] **`/t <partner> hey`, then `more`** → both reach the partner as tells. notes:
- [x] **On a Tell line, type `/loc`** → your location prints; the line is still the tell.
  notes:
- [x] **Type `/s` and press Enter (no space)** → nothing is sent; the line is now `[Say]`.
  notes:
- [x] **Options: set a chat window's default channel to OOC** → its line starts on `[OOC]`.
  notes:

## 3 — The playtest line from the hotfix checklist
- [x] **Type `/say `, paste the long fox line, Enter** → the partner sees it cut at "jumps ov"
  with no "/say" in it, and nobody is disconnected (this is the hotfix checklist's §1 row, now
  testable however it is pasted). notes: screenshots attached.  Chat is not matching between players.  This needs to be fixed.  If the chat has to be cut off for safety, then we should have the chat cut off at 250 characters.  players arent allowed to type more than that, this  way we dont run into this truncated message problem?  What do you think?

## 4 — Regression
- [x] **TAB on an empty line after receiving a tell** → `[Tell: <sender>]` (the tell reply
  checklist's rows, updated for the label). notes:
- [x] **Group chat (`/g hi` while grouped)** → the group member sees it as group chat. notes:

## 5 — Social macros send for real
Macros used to print their lines on your own screen as `[Say] hello` and send nothing (a
macro's `/sit` printed "You sit down." without sitting). Each line now runs exactly as if typed.
- [x] **Make a social with `/say hello from a macro`, put it on the hotbar, press it** → the
  partner hears "hello from a macro". notes:
- [x] **A social with `/sit`** → you actually sit. notes:
- [x] **A social with two lines (`/shout ready` and `/t <partner> go`)** → the partner gets a
  shout and then a tell. notes:
- [x] **Pressing a say macro while your chat line is on `[Shout]`** → the macro's line is a
  say; your chat line stays on `[Shout]`. notes: Set channel default to shout, then ran the "A social with two lines" button again.

## 6 — The 250-character cap (server `0cf170d`, client `8b378b6`)
The sender saw the whole fox line while the partner saw it cut at "jumps ov" (§3). Chat now stops
at 250 characters on both sides, counted the same way, so what you type is what everyone sees.
- [x] **Paste the fox line into the chat line** → the line stops taking text at 250 characters
  (the paste is cut; the line holds no more). notes:
- [x] **Press Enter** → your own chat shows exactly what the partner's shows, ending at the same
  word. notes:
- [x] **A social macro with a line longer than 250** → you and the partner see the same cut
  line. notes:
- [x] **A line of accented letters (é) or emoji** → stops at 250 of them, and both screens agree.
  notes:

NOTES:

The range for /say should me much shorter.  This should be considered to be at the volume of a conversation.  Does this make sense?

Unrelated:  Dip does not see Bun's character models spinning, or looking in different directions.  The character model faces the same direction always on another player's screen.