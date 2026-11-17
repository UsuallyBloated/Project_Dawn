# Obstacle Collision Playtest Checklist — 2026-11-17

Trees, rocks, walls, buildings and everything else solid in the zone now stop a body, block a
cast, and stop the camera. The server decides all of it; the client only draws the same thing
early. This sheet checks that the two agree in play and that nothing can be walked or cast
through.

**Both sides must move together.** A new client on the old server is pulled through every
tree; an old client on the new server is pulled back at every tree. Build prerequisite:
the zip `ProjectDawn-alpha-a1a154e.zip` (or later) on every seat, and the R720 redeployed on
`87c58fe` (or later). No wire change of its own, no migration, no SQL.

| Thing | Where to see it |
|---|---|
| The server holds the obstacles | boot line: `obstacles=33199 prisms (19580 walk, 31012 sight), hash f97d25964ce4`, then `what stands on the ground` |
| The client holds the same file | `debug.log`: `ZoneObstacles: 33199 prisms, hash f97d25964ce4` (the same twelve digits) |
| Every boundary, drawn | Test Panel, **Obstacle Outlines**: red stops a body, blue blocks sight only |
| A cast refused for sight | chat: "You cannot see your target." |
| A mob that cannot reach you | chat: "<mob> evades your attack." / "Your target is evading." |

Tip: turn **Obstacle Outlines** on first and leave it on. A boundary that does not sit on
its tree, rock or wall is the finding; note where (`/loc`).

## Setup
- [ ] The R720 redeployed on `87c58fe` or later; every seat on the zip `a1a154e` or later (`/version`). notes:
- [ ] Boot line shows `dev_cmds=false` and the `obstacles=` hash; `debug.log` shows the same hash. notes:
- [ ] A GM character (for the Test Panel) and, for sections 5 and 7, a second seat. notes:

> **Known gotcha:** a body run square into a flat face stops dead until you steer, on a
> trunk as on a wall. The trees are low-poly, so a trunk has five or six flat faces. That is
> the boundary following the object's own shape, not a bug. Note it if it feels bad.

## 1 — Walking: the town
- [ ] **Run at the town wall from outside, anywhere along it** → you stop at the wall and slide along it; no rubber-banding, no snap through. notes:
- [ ] **Run through each of the four gates, both ways** → all four are open; the open door leaves do not catch you. notes:
- [ ] **Run at a house, then along its wall, then round its corner** → stop, slide, round the corner smoothly. notes:
- [ ] **Walk under a house's eaves and under a gate's lintel** → nothing overhead stops you. notes:
- [ ] **Run at a tower, the mill and the well** → each stops you at its own shape. notes:
- [ ] **Walk up to each of the six NPCs and use them** (vendor, banker, soul binder, quests) → all reachable; nothing in the square blocks the way to them. notes:
- [ ] **Run at the small things in the square** (barrels, crates, the stall, the shrine stone, signposts, banner poles) → each stops you. notes:
- [ ] **Walk into a fenced field through its gateway, and at the fence elsewhere** → the gateway (on the town side) lets you in; the fence stops you everywhere else. notes:

## 2 — Walking: the wilds
- [ ] **Run through the Greywood for a minute** → trunks stop you and you slide round them; you can walk under every crown. notes:
- [ ] **Run at bushes, scrub, boulders of several sizes, and bones** → all stop you; anything under about shin height (0.3 m) is stepped over. notes:
- [ ] **Hold forward into a trunk's flat face** → you stop until you steer; steering a little slides you round. Does this feel acceptable? notes:
- [ ] **Walk the camps' set pieces**: tents, palisades, standing stones, the crypt's walls, the spires, the wagon wreck → each stops you at its own shape. notes:
- [ ] **Walk between palisade stakes where there is room** → a body fits between stakes that stand a body's width apart, and not between closer ones. notes:
- [ ] **Walk onto the Ossuary's dais, the Wraith Gate's steps and the crypt's steps** → these are floors: you walk through them as before (they are drawn, not solid). notes:
- [ ] **Run for five minutes anywhere, watching for a snap or a pull** → none. A pull at one spot means the client and server disagree there: note `/loc` and what stands there. notes:

## 3 — Nothing is jumped over or stood on
- [ ] **Jump at a fence, a gravestone, a low wall** → you do not get over; the jump is cosmetic. notes:
- [ ] **Jump at a boulder from uphill of it** → you do not land on top. notes:
- [ ] **Walk off the Wraith Gate cliff above something solid** → you land beside it, never on or in it; fall damage as before. notes:

## 4 — Sight
- [ ] **Cast at a mob with a house or the town wall between you** → refused before the bar, "You cannot see your target.", no mana spent. notes:
- [ ] **Step so the corner is clear and cast again** → it lands. notes:
- [ ] **Cast at a mob with a single trunk exactly between you** → refused; a step to either side and it lands. notes:
- [ ] **Cast at a mob with a tall bush or a big boulder between you** → refused; over a gravestone, a fence or a small rock it lands. notes:
- [ ] **On flat ground in the wood, cast at a mob 20 m off under the trees** → lands (the line passes under the crowns). notes:
- [ ] **From high ground, cast down at a mob under a tree's crown** → refused when the crown is in the line. Does this feel right, or too strict? notes:
- [ ] **Stand right beside a small tree on a slope, uphill of its trunk, and cast at something in the open** → it casts (your eye is inside the crown there; you see out of the tree you stand under). notes:
- [ ] **Fire a bow at a mob behind a wall** → the arrow misses (and is spent); no damage. notes:
- [ ] **Stand behind a house from an idle mob, inside its aggro range** → it does not notice you until it can see you. notes:

## 5 — Mobs and pets (second seat helps)
- [ ] **Pull a mob and run behind a single tree** → it slides round the tree and keeps coming; your hits on it land (no "evades"). notes:
- [ ] **Pull a mob and stand directly behind a house from it** → it walks along the wall, comes round the corner and attacks. While it is going round, attacks on it may read "evades". notes:
- [ ] **Pull a mob and stand a few metres behind the middle of a long fence or wall** → it goes along it by the shorter way and comes round; it does not dither in front of you. notes:
- [ ] **Run from a mob through the wood for half a minute, staying just ahead** → it keeps chasing past the trees; it does not give up a few seconds after bumping one. notes:
- [ ] **Pull a mob to the town wall from outside and stand inside, away from a gate** → it cannot reach you: after about a second it is evading, after about eight it gives up and walks home, healing. It is never killed through the wall. notes:
- [ ] **Fight a camp's mobs in among their own tents and walls** → fights work; mobs do not hang on their own scenery for long. Note any camp where they do. notes:
- [ ] **Watch the camps for a few minutes** → no mob stands inside a tent, a rock or a wall. notes:
- [ ] **Watch wandering animals in the wood** → they walk round trunks; none stands inside one. notes:
- [ ] **Summon a pet while standing against a wall** → it appears on your side. notes:
- [ ] **Run round a house with a pet following** → it follows round; if it loses you for eight seconds it warps to you. notes:
- [ ] **`/pet attack` a mob with a wall between pet and mob** → the pet goes round or gives the target up; it never passes through. notes:

## 6 — Being put somewhere
- [ ] **Log out against a wall, log in** → you stand where you were, outside the wall. notes:
- [ ] **Bind at Sister Maelis, die, respawn** → you arrive on free ground. notes:
- [ ] **Gate (a caster of level 8 or more)** → you arrive on free ground at your bind. notes:
- [ ] **Be resurrected at a corpse lying beside a wall or a tree** → you arrive beside it, not inside. notes:
- [ ] **GM: Fling 20 m while standing beside a house** → you come down beside it. notes:
- [ ] **GM: spawn a mob (Test Panel) while facing a wall at arm's length** → it appears on free ground. notes:

## 7 — The camera
- [ ] **Stand with your back to a house, the town wall, a tent** → the camera comes in front of it instead of looking through it. notes:
- [ ] **Stand in the wood with trunks behind you** → the camera does not jump in at trunks. notes:
- [ ] **Zoom out and orbit beside a building** → the camera slides along it; no flicker bad enough to bother. notes:
- [ ] **Left-click a mob standing beyond a building's corner, visible past it** → it is targeted as before (clicks are unchanged). notes:

## 8 — The second seat's view
- [ ] **Watch your partner run at a wall and round a tree** → they stop and slide as they do on their own screen; no body is drawn inside anything. notes:
- [ ] **Both run through the wood for a minute, grouped** → positions agree on both screens. notes:

## 9 — Regression
- [ ] **Hills, slopes, the pass, the cliff's fall damage** → as before. notes:
- [ ] **Melee, casting, looting, trading, banking in the square** → as before. notes:
- [ ] **`/camp` and the window X** → as before. notes:
- [ ] **The journal after the sitting** → `world health` lines show tick times near what they were (median under 1 ms, none over budget); no panic, no error. notes:

## Notes / observations
-
