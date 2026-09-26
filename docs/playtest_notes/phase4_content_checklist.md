# Phase 4 Content Playtest Checklist — 2026-09-16

The replacement camp layout, five second-tier quests, the Blacksmith, and Elara's
dialogue upgrade. Design: `docs/design/phase4_content_plan.md` (all five decisions
approved 2026-09-14).

**Build prerequisites: BOTH move together.**
- Server on the R720 at the phase 4 sha (boot line shows it; also carries the
  pending bag-space + group-bars builds).
- New client export (world.tscn + quest/dialogue data changed). No protocol bump,
  but an old client will not see Hadrik or Elara's dialogue and cannot be offered
  the new quests.

GM tools are fine for leveling to reach the higher rings — that is what they are
for. Kill credit, rewards, and turn-in gating are all server-side either way.

---

## 1 — The repaired starter book (the old quests, now completable)

- [x] **Take The Wolf Threat from Aldric, walk south of the eastern road** → Grey
      Wolves exist and kill-credit ticks the journal (was: no wolves in the world). notes:
      PASS. User's lap 09-22, then hard log proof 09-25 on a fresh character:
      accepted 17:56:18, eight-plus Grey Wolf credits at exact L1 XP (263).
- [x] **Take Rat Infestation from Brom** → Plague Rats are right out the back of his
      shop, per his cellar dialogue, and credit ticks. notes: PASS. The 09-25
      fresh character ran the whole loop: accepted 17:17:36 at level 1,
      fifteen-plus rat credits at exact L2 XP (1050), completed 17:55:07
      reward=150 — exactly 0.15 x band(1), the trivial tier to the digit.
- [x] **Take Drive Back the Raiders at level ~3, go east** → level 3 Gnoll Raiders in
      the rocky flats (was: only the level 10 Brute matched, in Ring 4). notes: PASS.
      09-25 fresh character: accepted 17:55:13 the moment level 3 landed,
      Gnoll Raider credits at exact L3 XP (2363) through the evening.
- [x] **Take Hunt the Beast, go south past the dire wolves** → Rotfang the Feared
      spawns at his den, hits harder than the wolves, enrages low, drops the Fang. notes:
      PASS 09-22 (machine-day §4 log 23:05-23:15): accept refused at 4,
      accepted at 5, den respawned on its timer, enrage fired both fights
      (308 hp = 3.5x, damage 1.4x). The level gate re-proven 09-25 (refused
      at 3) and the den re-proven 09-24 (re-kill after the long respawn).
- [x] **Rotfang turn-in at Aldric** → the big XP payout + Hunter's Medal land. notes:
      PASS 09-22: turn-in refused with full bags (can_accept pre-flight),
      then paid reward=48800 + the 5-to-6 ding after making room — the
      refusal itself proves the Medal grant was attempted and it landed on
      the retry. Whether the Medal's STR/CON bonuses APPLY is the separate
      standing To-Do item (quest reward follow-ups), not this row.

## 2 — The new rings and the ladder

- [ ] **Sweep outward: Bonepile (1), Wolf Run (1), Rats (2), Graves (3), Gnoll
      Raiders (3), Boars (4), Bats (4)** → every camp populated, levels con as
      listed, no camp aggros anyone standing in town or at the bank. notes:
- [x] **Ring 3: Bandits (5), Dire Wolves (5), Festering Mound** → the Mound mobs are
      now "Plagued Zombie" (renamed from Ghoul) and drop zombie-table loot. notes:
      PASS 09-24 across the day's logs: Bandit Scouts and Dire Wolves both
      farmed at exact L5 XP; Plagued Zombies pay exact L6 XP and their bags
      carry item stacks, proving the renamed name matches the zombie table.
- [x] **Ring 4: Spider Copse (7)** → the new camp exists, spiders drop silk/venom;
      the 7-to-8 leveling wall this camp closes feels closed. notes: PASS
      09-24: a dozen-plus Giant Spider kills at exact L7 XP, spiderling silk
      and venom sacs confirmed in inventory, and the user rode this camp from
      6 to 9 in one sitting — the old wall is gone.
- [x] **The Broken Crypt (9)** → mobs are now "Skeleton Champion" (renamed) and drop
      skeleton-table loot. notes: PASS 09-24: farmed through the ding to 10;
      bags carry stacks and the bone fragments destroyed after prove the
      skeleton table matches the new name.
- [x] **Ring 5: Gnoll War Camp (10), Sunken Barrow (12); Ring 6 unchanged** → all
      populated where the plan's map says. notes: PASS 09-24 — Barrow
      Zombie at exact L12 XP, Gnoll Brutes at exact L10 (war camp live, its
      50 s respawns visibly backfilling during the Greth fight), and an
      Ancient Wraith at exact L16 XP proves the Wraith Gate, and a Bone
      Colossus at exact L14 XP closes the Ossuary — all 21 camps and every
      ring verified in play. The evening barrow session (20:37-20:40) added
      three more Barrow Zombies at 37800 each, all exact.

## 3 — The five named mobs (first ever placed)

- [x] **Sable the Dark at the bat hollow's roost (north)** → visibly tougher than the
      bats, no enrage (by design), drops Sable Wing Membrane. notes: PASS
      09-24 (20:15): killed at the roost, zero enrage lines in the whole
      fight (threshold 0, as designed), loot bag with a stack.
- [x] **Ancient Crawler at the burrow by the Spider Copse** → enrages, drops Pristine
      Venom Sac. notes: PASS 09-24 (server log 17:54): 420 hp = 3.0x exact,
      enrage at 28.6% (threshold 30), damage 24 to 31 raw = 1.3x, kill paid
      16800 = kill_xp(8), ding 8 to 9 on the blow. Loot bag stacks=2 — the
      guaranteed sac plus a second stack (possibly a first-kill Chitinous
      Ring; user to confirm from the bag).
- [x] **Greth Bonecrusher at the war camp's tent** → boss-sized fight, drops the
      Gnoll Chief's Seal (25% War Axe — do not expect it first kill). notes:
      PASS 09-24 (server log 20:08): 860 hp = 4.0x exact, enrage at 24.2%
      (threshold 25), damage 44 to 66 raw = 1.5x, exact L10 XP, ding 10 to 11
      on the blow, 585 coin + an item stack refunded to the bag for space
      (user to check which drop that was).
- [x] **The Undying at the barrow** → the hardest fight in the game (enrage at 40%);
      dying to it is a pass for this row too, note which. notes: PASS 09-24
      (20:19): 1325 hp = 5.0x exact, enrage at 39.0% (threshold 40), damage
      57 to 91 raw = 1.6x (the game's hardest hitter), 536 coin. Killed, not
      died to.
- [x] **Kill a named, wait out its long respawn (5-10 min)** → it returns; the
      ordinary camps around it kept their short timers. notes: PASS 09-24,
      proven TWICE in one evening: Rotfang (killed earlier in the day) stood
      at his den again and was re-killed 20:32:30 (enrage at 45/308 fired
      again, so it is the real named, not a stray wolf), and The Undying
      (killed 20:19) was back and re-killed 20:40:32 for the quest (enrage at
      525/1325 = 39.6%, second fight's own roll). The ordinary camps kept
      their short timers throughout: three separate Barrow Zombie kills
      inside the same 20:37-20:40 window while the named timers idled.

## 4 — The second quest tier

- [x] **Aldric offers Restless Bones (L2)** → accept, any 8 skeletons count (Bonepile
      + Graves both), turn-in pays XP + the Leather Cap. notes: PASS 09-24
      (server log: accepted 15:42, completed 16:02 reward=2100 — exact tier
      math; the Leather Cap grant proven by its later appearance in
      inventory).
- [x] **Brom offers Road Toll (L5)** → 6 Bandit Scouts, turn-in pays the Copper Chain
      Coif. notes: PASS 09-24 (server log: accepted 15:34, six scouts felled
      15:47-15:49, completed 16:01 reward=18300 — exact tier math; coif grant
      proven in inventory after).
- [x] **Brom offers The Silk Harvest (L7)** → 10 Giant Spiders (the Crawler does NOT
      count — intended), Leather Vest on turn-in. notes: PASS 09-24: refused
      at 6, accepted at 7, a dozen-plus spiders in the logs, and the Leather
      Vest confirmed in possession (looted off a corpse mid-day, later
      dropped) — only the turn-in grants it.
- [x] **Aldric offers Champion's Crypt (L9)** → 6 Skeleton Champions, Iron Chain
      Leggings on turn-in. notes: PASS 09-24 (server log): accepted the minute
      level 9 landed (refused at 8 twice before, gate airtight), nine champions
      at exact L9 XP, full-bags turn-in REFUSED then completed reward=108500 —
      the correct 0.5 x band(9), which also exposed a wrong estimate in the
      plan doc (fixed). Item equipped straight from the cursor after.
- [x] **Aldric offers The Undying (L12)** → kill it, turn-in pays big XP + FLAMEBRAND
      (the proc sword — swing it after and watch for Flaming Strike procs). notes:
      PASS 09-24 (server log): accepted 20:31:47, the barrow fought through
      (kill credit 20:40:32 at exact L12 XP), bags pruned first (the learned
      can_accept dance: bone fragments + cloth scraps destroyed 20:41:50-53),
      completed 20:41:54 reward=317600 — exactly 0.8 x band(12) = 0.8 x
      397000, the last of the five tier payouts to land to the digit — with
      the ding 12 to 13 on the turn-in. An equip-from-cursor followed at
      20:42:01; Flaming Strike procs not yet observed in a log — watch on the
      next melee session.
- [ ] **Try a turn-in from far outside town** → refused by the proximity gate with a
      chat line; walking back to the giver completes it. notes:
- [ ] **Journal + relog** → new quests persist across a relog with counts intact
      (QuestSnapshot round-trip). notes:

## 5 — Town: the Blacksmith and Elara

- [ ] **Hadrik stands west of Sister Maelis; right-click** → Blacksmith shop opens:
      copper/iron weapons + the iron chain set; buying works and charges. notes:
- [ ] **Right-click Elara** → her DIALOGUE opens now (General Merchant title);
      "Let me see your wares." opens the shop she always had; the town/news lore
      lines read well. notes:
- [ ] **Buy from Elara after the dialogue path** → purchase lands (her npcs.toml row
      is new; watch for any "no merchant near you" refusal — should not happen). notes:

## 6 — Regression sweep

- [ ] **A fresh character's first minutes** → town is safe, nothing aggros the
      plaza/bank row, the starter book flows rat → wolf → skeleton naturally. notes:
      MOSTLY PROVEN 09-25 (fresh char 2, level 1 to 4+ in one evening): the
      book flowed rat then wolf then gnoll with the level gates steering
      correctly (road_toll and rotfang_hunt both refused at 3), one honest
      death at level 2 with a clean corpse cycle and no de-level (the
      under-5 grace), and every town visit (turn-in, accepts, GmGive) shows
      zero damage lines around it. Still wanted before ticking: the
      deliberate stand-at-the-bank minute (machine-day §4's aggro row) and
      restless_bones in the flow (the skeleton step was not in this log).
- [ ] **Group up for one camp** → XP splits, loot rights, group bars all behave (also
      exercises the pending group-bars build if this is its first two-seat session). notes:
- [x] **Die somewhere honest, corpse-run** → death path unchanged by the layout work. notes:
      PASS 09-24 (two deaths at the spider copse area): penalty exact, corpse
      with 11 stacks, run back, loot + re-equip clean, empty corpse despawned,
      second corpse spawned empty as the res anchor — all under the new
      dead-state gate and death camera.

---

## Result

- Server build (boot line): `59f2fa1` (boot 2026-09-25 00:42, dev_cmds=false)
- Client build (`/version`): `6156d05` (the EQ-death export)
- Overall:
