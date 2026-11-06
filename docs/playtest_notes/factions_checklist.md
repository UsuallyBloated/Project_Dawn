# Factions and Alignment Playtest Checklist — 2026-10-23

Slice 1 of `docs/design/factions_and_alignment.md` (all nine decisions of 2026-10-23): six
factions; a kill's hits paid to everyone on the mob's hate list; quest hits; standing
persisted and conned at EQEmu's nine levels; merchants and the banker refuse at Dubious,
quest givers at Apprehensive; alignment owned by the server (kills, quests, and spells at
0.001% of their mana), the prestige kits and the Paladin and Shadow Knight off-side penalty
decided there; `/con`, `/factions` and the GM faction sliders. **Both sides move together**
(`feat/server-speed`, server `5efd45d` + `30c270a`, client `22ebde7`): migration 0016 runs at
boot, and a binary without it will not boot on the migrated `world.db` afterwards.

| Thing | Value | Where to see it |
|---|---|---|
| A kill's hit | 4 + the mob's level off its faction; half of that to each faction listing it as an enemy; x3 for a named mob | `/factions`, chat lines |
| Who pays | everyone the mob hated (damage or threat), grouped or not; the alignment move goes to the top damager only | chat lines on each client |
| Links | gnolls, bandits and the dead are enemies of the town and the Watch; wildlife has no links | `factions.toml` |
| Levels | Ally 1100, Warmly 750, Kindly 500, Amiable 100, Indifferent 0, Apprehensive below 0, Dubious below -100, Threatening below -500, Scowls below -750 | `/factions`, the GM panel labels |
| Refusals | merchants and Thalia at Dubious or worse: "X will not deal with you."; quest givers at Apprehensive or worse: "X has nothing to say to you." | chat |
| Alignment starts | Paladin 500, Cleric 400, Monk and Witch Hunter 100, Blood Mage -500, Shadow Knight and Necromancer -1600, the rest 0 | debug console |
| Alignment moves | a bad kill +10, an undead +20 (named +50), wildlife 0; quests +20 to +40; spells 0.001% of their mana; a move away from 0 is scaled by 1 - abs(score)/2000 | debug console |
| Off-side penalty | Paladin Neutral 0.7, Bad 0.4; Shadow Knight Neutral 0.7, Good 0.4 | combat log numbers |

Diagnostics. The in-game console (backtick) shows `Alignment: server score <n> (<tier>)` and
`Faction: <name> <n> (<level>)` for every update the client receives. `server.log` anchors:
`faction standing changed` (delta, applied, standing, level), `alignment tier changed`,
`quest turn-in rejected — faction`, `quest accept rejected — faction`,
`BuyItem rejected — faction`, `SellItem rejected — faction`, `bank op rejected — faction`,
`GM set own faction standing`.

## Setup
- [ ] **Redeploy the server from `feat/server-speed` and export Project_Dawn from it** (the rebuilt DLL) → the boot line shows the new build sha; `/version` on the client shows `22ebde7` or later. notes:
- [ ] **A GM account (`grant_gm`) and a plain second account** → the GM sees FACTIONS (GM) in the Test Panel. notes:

## 1. Entering the world
- [ ] **Log in a fresh Cleric, open the console, type `/factions`** → console shows `Alignment: server score 400.0000 (Good)`; chat says "You have moved no faction's standing yet." notes:
- [ ] **Log in a fresh Necromancer** → `Alignment: server score -1600.0000 (Evil)`. notes:
- [ ] **An existing character from before the bump** → its score is its class start (seeded once at this login) and it is told so on entering. notes:

## 2. `/con`
Use the Test Panel's Spawn Normal for the mobs; a level 1 character unless the row says.
- [ ] **Target Brom, type `/con`** → "Brom regards you indifferently." notes:
- [ ] **Target Thalia, then Hadrik, `/con` each** → "Thalia Mourne regards you indifferently." and "Hadrik regards you indifferently." (the role after the dash is not part of the name). notes:
- [ ] **A level 1 character cons a Plague Rat (level 1)** → "Plague Rat regards you indifferently. Looks like an even fight." notes:
- [ ] **Cons a Grey Wolf (level 2)** → "...Looks like quite a gamble." notes:
- [ ] **Cons a Gnoll Raider (level 5)** → "...What would you like your tombstone to say?" notes:
- [ ] **Level Up to 4, con a Plague Rat** → "...Looks like you would have the upper hand." notes:
- [ ] **Level Up to 10, con a Plague Rat** → "...Looks like a reasonably safe opponent." notes:
- [ ] **Target the other player, `/con`; then clear the target and `/con`** → "You cannot consider that."; then "You must target something to consider it." notes:

## 3. Kills
- [ ] **Kill a Plague Rat** → "Your faction standing with Wildlife has gotten worse." and nothing else; `/factions` reads Wildlife: -5 (Apprehensive). notes:
- [ ] **Kill a Gnoll Raider** → gnolls worse, The Folk of Greyveil better, The Greyveil Watch better; `/factions`: The Gnoll Raiders -9, the town and the Watch 4 (4.5 shown rounded). Alignment for a Cleric 400 goes to 408 in the console. notes:
- [ ] **Two players: one only heals the other (or casts a single nuke) while the second kills a Gnoll Raider** → both get the three lines; only the killer's alignment moves. notes:
- [ ] **Con a Gnoll Raider after the kill** → "Gnoll Raider looks your way apprehensively. ..." notes:
- [ ] **Spawn Named Greth Bonecrusher (level 10) and kill it** → gnolls -42, the town and the Watch +21 each (three times a plain mob of its level). notes:
- [ ] **Kill a Decrepit Skeleton with a Cleric** → restless dead worse, the town and the Watch better; alignment rises by 20 times the momentum factor. notes:

## 4. Quests
- [ ] **Take wolf_threat from Aldric, kill five Grey Wolves, turn in** → "Your faction standing with The Greyveil Watch has gotten better." and the town line; `/factions` shows the Watch +25 and the town +10 more than before; a Cleric's alignment rises by 20 x the momentum factor. notes:
- [ ] **A second account watches the turn-in** → gets no faction or alignment line. notes:

## 5. The GM panel and the refusals
- [ ] **GM: set The Folk of Greyveil to -50, press Set** → "Your standing with The Folk of Greyveil is now -50 (Apprehensive)."; the panel label agrees; `server.log` has `GM set own faction standing`. notes:
- [ ] **At -50, ask Brom for rat_infestation** → refused: "Brom has nothing to say to you."; the quest leaves the journal. notes:
- [ ] **At -50, buy from Brom** → the sale goes through (Apprehensive still trades). notes:
- [ ] **Set the town to -200, buy from Brom, sell to Elara, deposit with Thalia** → each refused, naming the first refusing merchant in range in `npcs.toml` order (Brom whenever he is within 15 m), then "Thalia Mourne will not deal with you."; no coin or item moves. notes:
- [ ] **At -200, bind at Sister Maelis** → the bind works (the soul binder serves everyone). notes:
- [ ] **Set the town to 600, `/con` Brom** → "Brom kindly considers you." notes:
- [ ] **Relog** → `/factions` and the panel still show 600 for the town. notes:
- [ ] **Set the town back to 0** → Brom trades and offers quests again. notes:
- [ ] **The plain account moves a slider and presses Set** → nothing changes, nothing is printed by the server; `server.log` has no `GM set own faction standing` line for it. notes:

## 6. Alignment and the prestige kits
There is no GM tool for alignment; set it by hand on a stopped server or a local one:
`UPDATE characters SET alignment_score = <n>, alignment_seeded = 1 WHERE name = '<name>';`
- [ ] **A level 20 Paladin set to -1600, relog** → console reads Evil; the spell book shows the Fallen kit (Death's Embrace, Blood Price, Shadow Flame, Condemnation) and not Righteous Fire. notes:
- [ ] **That Paladin casts Death's Embrace on a target** → lands for 80 (more on a crit). notes:
- [ ] **That Paladin tries to memorize or cast a Paladin spell (if still on the bar)** → refused: "You cannot memorize that spell." / "Your class cannot cast that." notes:
- [ ] **A Paladin set to 0, relog, cast Crusader's Mend on themself and Righteous Fire on a mob** → heals 7 (not 10) and hits 4 (not 7) when not a crit. notes:
- [ ] **A Shadow Knight set to 1600, relog** → console reads Exalted; the book shows Sacrificial Mend, Radiant Bolt, Holy Mantle. notes:

## 7. Persistence and the log
- [ ] **Note `/factions`, log out, restart the server, log in** → the same standings and the same alignment. notes:
- [ ] **Scan `server.log` for the sitting** → a `faction standing changed` line for every chat line seen; `alignment tier changed` where a tier flipped. notes:
