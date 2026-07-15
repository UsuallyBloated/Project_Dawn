# Quest Slice D — Brom's Dialogue — Playtest Checklist — 2026-07-11

Brom is now a **dialogue NPC that also vends**, so his authored quests (`rat_infestation` +
`gnoll_raiders`) are finally reachable in-world. Interacting with Brom opens his **dialogue**
(the HUD routes dialogue NPCs ahead of vendors); his "Show me what you have." option opens his
vendor. Completes the quest epic's last root problem.

**Client-only change → re-export / reload the client. NO server rebuild, NO DLL rebuild.**
(The server already knows the rat/gnoll quests + the boots reward from slices A/B.)

## Setup
- [x] Re-export / reload Project_Dawn in Godot; restart the server (or keep it running — no
      server change)
- [x] A character in the world near Brom (the "Provisioner", town hub). Server.log anchors:
      `quest accepted`, `quest completed`, `quest turn-in rejected`.

## 1 — Brom opens DIALOGUE, and vending is inside it
- [x] **Target Brom and interact** → his **dialogue** opens ("Hail! Brom's Provisions…"), NOT
      the vendor window directly. His nameplate reads **"Brom"**. notes:
- [x] **Pick "Show me what you have."** → the **vendor window opens** (Brom still sells; buy/sell
      still work). Close it. notes:
- [x] **Interact with Brom again** → dialogue reopens (the vendor is reached only through it). notes:

## 2 — gnoll_raiders end-to-end (the full loop, with the slice-B item reward)
gnoll_raiders needs level 3 (Test Panel "Level Up" a couple times if needed).
- [x] **In Brom's dialogue pick "Any more work?" → accept the gnoll quest** → it appears in the
      journal (J); server.log `quest accepted … quest_id=gnoll_raiders`. notes:
- [x] **Test Panel: spawn Gnolls and kill 8** → the objective ticks to 8/8 and the quest goes
      **"Ready"** (return-to-Brom line). notes:
- [x] **Return to Brom, "The gnoll raiders are dealt with."** → turn-in pays out: **Scout's
      Leather Boots** land in your bag (AGI +2, Armor +6) + the XP; server.log `quest completed
      … quest_id=gnoll_raiders`. notes:
- [x] **Equip the boots** → AGI/armor apply on the character sheet (gear-stat fix). notes: AC appears to be raised by 7 when the item says AC +6.  Is there something going on in the background?  Maybe the AGI +2 has an effect on AC?  let me know what you think.
- [x] **Talk to Brom again** → the gnoll turn-in option is gone (quest COMPLETED). notes:

## 3 — rat_infestation accept (kill/turn-in awaits a Rat mob — see note)
The Test Panel doesn't spawn "Rat" yet (coming with the dev-panel task), so the kill + turn-in
aren't fully testable this round — but the accept + dialogue gating are.
- [x] **In Brom's dialogue pick "You look capable. Got a problem…" → accept the rat quest** →
      it appears in the journal; server.log `quest accepted … quest_id=rat_infestation`. notes:
- [x] **Talk to Brom again while rat is ACTIVE** → the "Still clearing out those rats." check-in
      line shows (and the accept offer is gone). notes:
- [x] **Abandon it from the journal, re-open Brom** → the accept offer is back. notes:

## 4 — Regression: other NPCs unchanged
- [x] **Aldric the Guard** (dialogue-only, no vendor) → interact opens dialogue; there is NO
      "Show me what you have" option; wolf_threat/rotfang still work. notes:
- [x] **Elara — General Merchant** (vendor-only) → interact opens the **vendor window directly**
      (she's not a dialogue NPC), unchanged. notes:
- [x] **Thalia the Banker** → still opens the bank, unchanged. notes:

## Notes / observations
-
