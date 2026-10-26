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
- [ ] **Press Enter** → the line opens showing `[Say]` on a window with no default channel.
  notes:
- [ ] **Type `/sh ` (with the space)** → the text clears and the line shows `[Shout]` in
  orange. notes:
- [ ] **Type `/say ` then paste `/say hello`** → the line is `[Say]` holding just `hello`;
  sent, both players see "hello" with no "/say" in it. notes:
- [ ] **Type `/sit` and press Enter** → you sit; the channel did not change. notes:
- [ ] **Type `/t <partner> ` (with the space)** → the line shows `[Tell: <partner>]` and is
  empty. notes:

## 2 — Sticky
- [ ] **`/shout hi`, then open the line again and type `again`** → both lines are shouts; the
  line still shows `[Shout]`. notes:
- [ ] **`/t <partner> hey`, then `more`** → both reach the partner as tells. notes:
- [ ] **On a Tell line, type `/loc`** → your location prints; the line is still the tell.
  notes:
- [ ] **Type `/s` and press Enter (no space)** → nothing is sent; the line is now `[Say]`.
  notes:
- [ ] **Options: set a chat window's default channel to OOC** → its line starts on `[OOC]`.
  notes:

## 3 — The playtest line from the hotfix checklist
- [ ] **Type `/say `, paste the long fox line, Enter** → the partner sees it cut at "jumps ov"
  with no "/say" in it, and nobody is disconnected (this is the hotfix checklist's §1 row, now
  testable however it is pasted). notes:

## 4 — Regression
- [ ] **TAB on an empty line after receiving a tell** → `[Tell: <sender>]` (the tell reply
  checklist's rows, updated for the label). notes:
- [ ] **Group chat (`/g hi` while grouped)** → the group member sees it as group chat. notes:
