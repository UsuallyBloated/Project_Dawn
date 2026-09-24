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

- [ ] **Take The Wolf Threat from Aldric, walk south of the eastern road** → Grey
      Wolves exist and kill-credit ticks the journal (was: no wolves in the world). notes:
- [ ] **Take Rat Infestation from Brom** → Plague Rats are right out the back of his
      shop, per his cellar dialogue, and credit ticks. notes:
- [ ] **Take Drive Back the Raiders at level ~3, go east** → level 3 Gnoll Raiders in
      the rocky flats (was: only the level 10 Brute matched, in Ring 4). notes:
- [ ] **Take Hunt the Beast, go south past the dire wolves** → Rotfang the Feared
      spawns at his den, hits harder than the wolves, enrages low, drops the Fang. notes:
- [ ] **Rotfang turn-in at Aldric** → the big XP payout + Hunter's Medal land. notes:

## 2 — The new rings and the ladder

- [ ] **Sweep outward: Bonepile (1), Wolf Run (1), Rats (2), Graves (3), Gnoll
      Raiders (3), Boars (4), Bats (4)** → every camp populated, levels con as
      listed, no camp aggros anyone standing in town or at the bank. notes:
- [ ] **Ring 3: Bandits (5), Dire Wolves (5), Festering Mound** → the Mound mobs are
      now "Plagued Zombie" (renamed from Ghoul) and drop zombie-table loot. notes:
- [ ] **Ring 4: Spider Copse (7)** → the new camp exists, spiders drop silk/venom;
      the 7-to-8 leveling wall this camp closes feels closed. notes:
- [ ] **The Broken Crypt (9)** → mobs are now "Skeleton Champion" (renamed) and drop
      skeleton-table loot. notes:
- [ ] **Ring 5: Gnoll War Camp (10), Sunken Barrow (12); Ring 6 unchanged** → all
      populated where the plan's map says. notes:

## 3 — The five named mobs (first ever placed)

- [ ] **Sable the Dark at the bat hollow's roost (north)** → visibly tougher than the
      bats, no enrage (by design), drops Sable Wing Membrane. notes:
- [ ] **Ancient Crawler at the burrow by the Spider Copse** → enrages, drops Pristine
      Venom Sac. notes:
- [ ] **Greth Bonecrusher at the war camp's tent** → boss-sized fight, drops the
      Gnoll Chief's Seal (25% War Axe — do not expect it first kill). notes:
- [ ] **The Undying at the barrow** → the hardest fight in the game (enrage at 40%);
      dying to it is a pass for this row too, note which. notes:
- [ ] **Kill a named, wait out its long respawn (5-10 min)** → it returns; the
      ordinary camps around it kept their short timers. notes:

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
- [ ] **Brom offers The Silk Harvest (L7)** → 10 Giant Spiders (the Crawler does NOT
      count — intended), Leather Vest on turn-in. notes:
- [ ] **Aldric offers Champion's Crypt (L9)** → 6 Skeleton Champions, Iron Chain
      Leggings on turn-in. notes:
- [ ] **Aldric offers The Undying (L12)** → kill it, turn-in pays big XP + FLAMEBRAND
      (the proc sword — swing it after and watch for Flaming Strike procs). notes:
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
- [ ] **Group up for one camp** → XP splits, loot rights, group bars all behave (also
      exercises the pending group-bars build if this is its first two-seat session). notes:
- [x] **Die somewhere honest, corpse-run** → death path unchanged by the layout work. notes:
      PASS 09-24 (two deaths at the spider copse area): penalty exact, corpse
      with 11 stacks, run back, loot + re-equip clean, empty corpse despawned,
      second corpse spawned empty as the res anchor — all under the new
      dead-state gate and death camera.

---

## Result

- Server build (boot line):
- Client build (`/version`):
- Overall:
