# Charm Return Playtest Checklist — 2026-10-06

A charm that ends now hands the mob back instead of deleting it: the pet vanishes and the same
creature stands in its place, hostile, with the HP it had, and it goes straight for the one who
charmed it (EQ's rule; asked for on the ported-spells sheet the same evening). The camp slot
stays occupied for the charm's life, so a charm no longer makes the camp respawn a replacement
early. **Server-only: needs the R720 on `e3a6fa8` or later. No client export needed.**

Who: Mirelle (Enchanter 20, Charm, 60 s) on the `spelltest` account (password in
`CHECKLIST_RUN_ORDER.md`). Caderyn cannot help here: Siren's Song is Bard level 14 and he is 10.
Log anchors in the journal: `enemy charmed into pet`, `charm expired — mob returned hostile`,
`charm broken by owner leaving — mob returned`. A dead charmed pet logs `pet killed by enemy`.

## Setup
- [x] Redeploy the server (boot line shows `build=` at `e3a6fa8` or later, `dev_cmds=false`)

## 1 — The mob comes back
- [x] **Mirelle: charm a Decrepit Skeleton and stand near it for the full minute** → when the charm ends the blue capsule goes and a Decrepit Skeleton stands where it was, with the HP it had (a pet that took damage comes back hurt, not healed). notes: Used Dire Wolf as target.  
- [x] **...and it comes for you** → the returned skeleton targets you and attacks without being provoked. notes:
- [x] **Charm one, then walk about 40 m away before the minute is up** → it still comes back where the pet was; being past its 30 m leash it either chases briefly and turns home or stands hostile. Either is fine; it must not vanish. notes: Charmed Decrepit Skeleton, used "/pet guard" then ran 40m away and waited for charm to expire.  Charm expired, Decrepit Skeleton returned to hostile, Decrepit Skeleton returned to it's position.  This is cool, I like this.  I didnt do any damage to the skeleton, just used charm.  

## 2 — The camp does not grow
- [x] **Count the Decrepit Skeletons at the Bonepile, charm one, wait out the charm, count again** → the same number: no replacement appeared during the charm, and the returned one fills its old place. notes: Skeleton Champion as target.  Appears to work as intended.
- [x] **Charm one and let it die as your pet (send it into the Plagued Zombies with /pet attack)** → it dies as a pet (no XP or loot for you), and the camp respawns one in its place on the camp's own timer, not before. notes:  

## 3 — The charmer leaves
- [x] **Charm one, then quit with the window X** (a second seat watches, or read the journal after relogging) → `charm broken by owner leaving — mob returned`; the skeleton is back, hostile but idle, since nobody is there to hate. notes:  Confirmed in log:

Oct 07 16:54:45 projectdawn projectdawn-server[21141]: 2026-10-07T16:54:45.368482Z  INFO projectdawn_server::world::tick: client disconnected (transport) client_id=7 reason=DisconnectedByServer
Oct 07 16:54:45 projectdawn projectdawn-server[21141]: 2026-10-07T16:54:45.368544Z  INFO projectdawn_server::world::tick: charm broken by owner leaving — mob returned owner=7 pet_id=3000000005 mob_id=1000000064

Shouldn't mob act the same as when the character walked away 40m?  The skeleton remained in place and attacked the character upon login.  This confirms the test though, correct?

**Triage 10-07:** yes, it confirms the row, and the difference you noticed was real. With a charmer to hate the mob chases, finds you past its leash, and walks home; with nobody to hate it was simply placed where the pet stood and left idle there, which is why it was waiting when you logged back in nearby (inside its aggro radius). Changed the same day, server `3e1c200`: a returned mob with nobody to hate walks home like one that lost its target. Pending redeploy; the re-check row below.
- [ ] **After the redeploy of `3e1c200`: charm one away from its camp, quit with the window X, log back in** → the returned mob is back at its spawn (or walking there), not standing where the pet was. notes:
## 4 — Regression
- [x] **Charm, then fight alongside the pet for the full minute: /pet attack, the pet panel, following** → unchanged from before. notes: Does the pet panel open upon charm success?  Or how do i open the pet panel?  Buttons for attack, guard, etc. would be terrific.  I dont remember what we had set up for the pet panel.  Thanks for the help. **Triage 10-07:** it opens by itself: a small draggable panel at the top left (name, level, HP bar) whenever you have a pet, charm included, and hides when the pet goes. It had no buttons. It has them now (client, next export or the editor): Attack, Back, Guard, Follow, Sit, each the same call as the `/pet` command. Rows in `chat_wrap_and_pet_buttons_checklist.md` §2.
- [x] **Charm the returned skeleton again** → it is a fresh target (re-target it first) and the charm lands as usual. notes:
- [x] **Charm one at the edge of range and one in the middle of a camp** → the usual "too far" refusal and the usual landing; nothing new. notes:

- Pet becomes new target after charm wears off, even if the charmed creature is targeted when the charm expires, the player must re-target the creature when charm wears off. **Triage 10-07:** true, and EQ keeps your target through a charm break because there the mob is one entity throughout. Here the returned mob is a fresh enemy id, so the client sees a pet vanish and an enemy appear and has no link between them. Recorded in the To-Do (the "Playtest asks from the charm-return sitting" entry) as a client follow-up.
## Notes / observations
Just notes that can be added to the to-do list, not expecting instant development.
-  Drinking multiple Water Flask does not increase the mana regen.  This is good.  I also think that Water Flask should have a cool down that matches the length of the mana regen effect. Water Flask's cool down would be 180 seconds.  Does this make sense? **Triage 10-07:** it makes sense, and it is the clean rule (a consumable is on cooldown exactly while its effect lasts, so drinking again never wastes one). Filed on the Consumables entry in the To-Do; it belongs with the server-side consumables pass, since consumable effects are not server-modelled yet.

-  Mobs like bandits and gnolls (generally not animals, but anthropamorphic shit would probably wear clothes, use tools, carry weapons, and money.  If the mob has a history in the lore and isnt something like a rat) should have gear tables.  They should be equipped accordingly.  We can iron this out later.  animals dont carry money.  Perhaps we need classifications for the NPCs in the world?  Do other games do this? **Triage 10-07:** yes, other games do exactly this. EQ keys loot by creature, so a gnoll drops gnoll things and a rat drops rat things, and humanoids carry coin while animals do not; WoW tags every creature with a type (humanoid, beast, undead, elemental) and the type drives both loot and what spells work on it (its charm only works on humanoids and beasts, for instance). Filed on the loot-plumbing entry: the data-driven loot table format is the prerequisite, and a creature type on the template is the hook.

-  Does sitting and meditate have any effect on a character's mana regen? **Triage 10-07, from `regen.rs`:** yes, both. Standing you regain 1 mana per 6 s tick; seated AND out of combat you regain 2 plus one more per 12 points of Meditate skill. The seated rate is suppressed for a few seconds after dealing or taking damage. Sitting also raises HP regen.

-  Max range of each spell should be listed in the tool tip for that spell, along with MP, CD, description. **Triage 10-07:** filed on the UI entry. Today every spell shares one reach (24 m on the client, 25 m on the server; heals are decided to move to 30 m), so the tooltip can show the one number now and a per-spell number when the content pass gives spells their own ranges.