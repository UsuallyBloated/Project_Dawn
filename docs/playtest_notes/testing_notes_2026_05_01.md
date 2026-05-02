## Dungeon World (dungeon_world.tscn) — test checklist

### Confirmed working
- [x] Dungeon geometry renders correctly (walls, floor, ceiling, torches)
- [x] Player spawns at entrance room (yellow orb marker)
- [x] Enemies present in other rooms
- [x] Enemy name labels visible through walls (intentional for now, fix before ship)
- [x] Skeleton enemies aggro on proximity

### Still need to test
- [x] Auto-attack fires on Tab-targeted enemy ✓
- [ ] Skills and spells work from hotbar — **BUG: skill/spell bar not loading in dungeon**
- [ ] HP/MP bars update correctly on HUD
- [ ] Combat log shows hit/miss/damage lines
- [ ] Enemy drops loot on death
- [ ] Loot window opens and items can be picked up
- [x] Death — death screen appeared, respawned at entrance room at 25% HP/MP (correct — no bind point, falls back to spawn position)
- [ ] Fall damage on stair ramps (if floor_count > 1)
- [x] Camera right-click control works while inventory open ✓

---

enemies are not dropping any loot

target's target needs to be adjustable.  right now it is huge and taking up too much space.  adjustable and movable


where are the pet commands?


 When i right click on an NPC, i should see an interaction screen.  If they operate a shop, if they dont have a shop nothing should happen.

 cannot target non-combative NPCs
 cannot target silver or tin veins
 cannot target crafting tables

 when i click on a bag in my inventory, it should open that bag in a new window

 Test Room window needs to be scalable and movable 

 Character Screen background does not extend far enough to cover Armor skill.  should this be a scroll window for the passive skill list?

 how can we test the food and drink system?  can you show a meter? just for testing.  it will be removed later

 bags dont seem to be receiving items in test mode with give food and water

 Give Crafting Materials does not work

 Give Bow button does not work

 Give Proc Weapon does not work

NPC names are visible through walls (not good)

holding right click doesnt allow camera movement while player is accessing inventory or character window.  other windows should be checked for the same issue.

status bars (HP, MP, STA) should be moved to top left corner
combat log defaults to lower left corner

player cant target themselves(their self?).  need this for buffing and healing

skill and spell bar arent loading in

right click camera works while inventory 

auto attack works on targetted enemy

New playtest using Host Game, OGRE, SHADOWKNIGHT:

enemies are not dropping loot

i can target myself

Bone Colossus dropped Bone Fragment, but "Take" and "Take All" buttons did not work

Debug from this session:

=== Session started 2026-05-01T15:18:42 ===
15:19:13 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:19:13 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:19:26 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:19:26 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:19:42 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:19:42 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:20:34 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:20:34 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:20:59 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:20:59 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:21:19 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:21:19 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:21:39 [WARN ] Loot: Decrepit Skeleton loot table has 0 entries
15:21:39 [INFO ] Loot: Decrepit Skeleton died — 0 item(s) rolled
15:22:36 [WARN ] Loot: Decrepit Skeleton loot table has 0 entries
15:22:36 [INFO ] Loot: Decrepit Skeleton died — 0 item(s) rolled
15:22:48 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:22:48 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:23:07 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:23:07 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:23:27 [WARN ] Loot: Rotting Skeleton loot table has 0 entries
15:23:27 [INFO ] Loot: Rotting Skeleton died — 0 item(s) rolled
15:23:43 [WARN ] Loot: Decrepit Skeleton loot table has 0 entries
15:23:43 [INFO ] Loot: Decrepit Skeleton died — 0 item(s) rolled
15:23:51 [WARN ] Loot: Decrepit Skeleton loot table has 0 entries
15:23:51 [INFO ] Loot: Decrepit Skeleton died — 0 item(s) rolled
15:24:24 [WARN ] Loot: Decrepit Skeleton loot table has 0 entries
15:24:24 [INFO ] Loot: Decrepit Skeleton died — 0 item(s) rolled
15:25:03 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:25:03 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:25:49 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:25:49 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:26:03 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:26:03 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:26:16 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:26:16 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:26:44 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:26:44 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:27:08 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:27:08 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:27:23 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:27:23 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:27:31 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:27:31 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:28:27 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:28:27 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:30:57 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:30:57 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:31:36 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:31:36 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:31:47 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:31:47 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:32:19 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:32:19 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:32:42 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:32:42 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:33:36 [WARN ] Loot: Bandit Scout loot table has 0 entries
15:33:36 [INFO ] Loot: Bandit Scout died — 0 item(s) rolled
15:34:39 [INFO ] Loot: Bone Colossus died — 1 item(s) rolled
15:34:39 [INFO ] Loot: bag spawned at (-134.2442, 1.298771, 14.51531)
=== Session ended 2026-05-01T15:36:24 ===

