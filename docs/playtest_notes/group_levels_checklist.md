# Group-mates' Level and Class Playtest Checklist — 2026-11-17

Group-mates now see each other's level and class on the group panel, as "12 WAR" beside the
name (the user, 2026-11-17: "Players should see the class and level of their group mates.
Class should be abbreviated by using three letters"). It replaces the "Lv 0" every other
member's row used to show. The roster is re-sent to the group when a member's level moves,
up or down. **Build prerequisite:** the R720 running the `feat/group-levels` server
(PD_W0031) AND the matching zip, together; an older zip cannot connect to it.

| Class | Shown | Class | Shown | Class | Shown |
|---|---|---|---|---|---|
| Warrior | WAR | Paladin | PAL | Shadow Knight | SHD |
| Cleric | CLR | Druid | DRU | Shaman | SHM |
| Beast Master | BST | Rogue | ROG | Monk | MNK |
| Ranger | RNG | Witch Hunter | WHT | Bard | BRD |
| Magician | MAG | Wizard | WIZ | Sorcerer | SOR |
| Enchanter | ENC | Necromancer | NEC | Blood Mage | BLM |

Diagnostics: the server logs `level change` with `from` and `to` on every level move; the
group roster itself writes no log line.

## Setup
- [ ] **The R720 runs the new server** → boot line `dev_cmds=false`, the new `build=`. notes:
- [ ] **Two seats on the new zip, two different classes** → both at the login screen with
  the new stamp. notes:

## 1 — The panel
- [ ] **Group the two characters** → each sees the other's row with level and class ("3 CLR"),
  and their own row the same way. No "Lv 0" anywhere. notes:
- [ ] **Look at the bars when the group forms** → both rows' HP, mana and stamina fill at once,
  as before. notes:

## 2 — A level change reaches the partner
- [ ] **One seat levels up (a kill, a quest, or the Test Panel's Level Up on a GM)** → the
  partner's row shows the new level within a second, without regrouping. notes:
- [ ] **The leveller's own row** → shows the new level too. notes:
- [ ] **The bars during that re-send** → no blink to empty on either row. notes:
- [ ] **A character at level 6 or higher dies** → after the death, the partner's row shows the
  level the death left (one lower when it de-levels). notes:

## 3 — Who sees it
- [ ] **A third character, not in the group, stands beside the pair while one levels** →
  nothing changes on the outsider's screen; they have no group panel rows for the pair.
  notes:

## 4 — Regression
- [ ] **Leave the group, then a kick, then pass leadership and change the loot mode** → every
  roster change still shows on both panels as before (the panel clears on a leave and a
  kick; the leader's gold border moves; [RR] and [FFA] switch). notes:
- [ ] **Log one seat out while grouped** → the other's panel drops the row, as before.
  notes:
