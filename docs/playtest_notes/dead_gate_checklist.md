# While Dead: One Line, Not a Flood Playtest Checklist (2026-10-26)

After Trigger Death the chat filled with "You cannot do that while dead." (eight times): the
server refused each message the client sent while dead, once each. Now the line is said once
per death, targeting is allowed while dead, and the journal names every refused message.
**Server only** (`8127a70`): needs the R720 redeploy, works with the current export.

Diagnostics: `journalctl -u projectdawn | grep "refused while dead"` shows the first refused
message of each death by name (`refused="Sit"`, `refused="UseSkill"`, ...).

## Setup
- [ ] R720 redeployed; boot line shows `build="8127a70"` and `dev_cmds=false`. notes:

## 1 — One line per death
- [ ] **GM: Test Panel, Trigger Death, then press hotbar keys, sit, and click things during the
  5 s before respawn** → "You cannot do that while dead." appears once at most. notes:
- [ ] **Left-click other players, mobs and your corpse while dead** → each becomes your target;
  no line for it. notes:
- [ ] **Respawn, die again, press a hotbar key while dead** → the line appears once again (a
  new death is told afresh). notes:
- [ ] **Read the journal** → one `refused while dead` line per death, naming the message.
  notes:
