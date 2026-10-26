# While Dead: One Line, Not a Flood Playtest Checklist (2026-10-26)

After Trigger Death the chat filled with "You cannot do that while dead." (eight times): the
server refused each message the client sent while dead, once each. Now the line is said once
per death, targeting is allowed while dead, and the journal names every refused message.
**Server only** (`8127a70`): needs the R720 redeploy, works with the current export.

Diagnostics: `journalctl -u projectdawn | grep "refused while dead"` shows the first refused
message of each death by name (`refused="Sit"`, `refused="UseSkill"`, ...).

## Setup
- [x] R720 redeployed; boot line shows `build="8127a70"` and `dev_cmds=false`. notes:

## 1 — One line per death
- [x] **GM: Test Panel, Trigger Death, then press hotbar keys, sit, and click things during the
  5 s before respawn** → "You cannot do that while dead." appears once at most. notes:
- [x] **Left-click other players, mobs and your corpse while dead** → each becomes your target;
  no line for it. notes:
- [x] **Respawn, die again, press a hotbar key while dead** → the line appears once again (a
  new death is told afresh). notes:  Hot bar skills appear in chat as normal.  screen shot attached.
- [x] **Read the journal** → one `refused while dead` line per death, naming the message.
  notes: Both deaths' refused message was `EquipUpdate`: the client sent one per gear slot as the death stripped the gear (eight slots, the eight lines first seen), a message the server already ignored.

## 2 — Client half (the next export: client `EquipUpdate` removed, dead guards)
The line came from an automatic message, not from anything the player did, and skills
announced "You use Slash." while the server refused them. Now the client sends no
`EquipUpdate` (the server works out armor itself), and skills, spells and switching
auto-attack on are refused on the client while dead, before anything is sent, announced or put
on cooldown, with the line said once per death.
- [x] **Trigger Death and do nothing** → no "You cannot do that while dead." line at all.
  notes:
- [x] **Die, then press hotbar skills, cast a spell, press the auto-attack key** → the line
  appears once; no "You use ..." or "You cast ..." lines; no hotbar cooldowns start. notes:
- [x] **Read the journal** → no `refused while dead` line for that death (nothing reached the
  server). notes: Only the two §1 `EquipUpdate` lines (21:35:59, 21:37:31); nothing since.
- [x] **Respawn and equip or unequip a piece of armor** → the character sheet's armor changes as
  before (the server works it out). notes:
