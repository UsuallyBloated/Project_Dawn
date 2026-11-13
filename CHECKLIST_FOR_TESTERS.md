# Project Dawn: the first evening checklist

A route through your first hour or two, with a box per step. Everything on it is something
we built this autumn and have only tested with two people. Four of you at once is new.

**How to use it.** Open this file in Notepad (or anything). Put an `x` in a box when the step
went the way the row says (`[x]`), a `-` if you could not try it (`[-]`), and when it did NOT
go that way write what happened after its `notes:`. At the end of the night paste the whole
file, or attach it, in our Discord. Rows are numbered, so "row 12 broke" works too.

```
Your character: ____________   Race and class: ____________   Level you reached: ____
Build (type /version in chat and copy the first word): ____________
```

**Controls you will need.** Right-click (a tap) talks, loots and opens things. Left-click only
targets. Hold right-click to turn the camera. WASD move, Space jump, Z sit, Q auto-attack, Tab
cycles targets, Enter opens chat. I bags, C character sheet, B spell book, J quest journal, Esc
menu. The hotbar is 1 to 0; the spell gems are Alt+1 to Alt+0. The full list is in
`README_FOR_TESTERS.md`.

---

## 1. Getting in

- [ ] **1. Tailscale is connected and `ping 100.93.108.112` answers** → replies, not timeouts. notes:
- [ ] **2. Set the server to `100.93.108.112:8765` and Register** → you are logged straight in, no error. notes:
- [ ] **3. Create a character, Play, then Enter World** → you stand in the town square wearing a ragged shirt, ragged pants and a trainee's weapon, every bar full. The town has a wall with a gate on each side and a road out of each gate. (The walls, houses and trees are placeholder scenery: you can walk through them, and that is not a bug.) notes:
- [ ] **4. Type `/version` in chat** → it prints the build; copy the first word to the top of this sheet. notes:

## 2. The first fight

- [ ] **5. Right-click Aldric the Guard (the row of NPCs a few steps north of where you appeared)** → a dialogue window; take The Wolf Threat; J shows it at 0/5. Brom, further east along the row, has Rat Infestation too. `/con` on either → "regards you indifferently." notes:
- [ ] **6. Go to the wolves: leave by the east gate (the one by the tall tower) and head south of the road, to about x 280, z -200; a little over a minute's run (`/loc` prints x, y, z; x grows going east, z grows going north). Left-click a Grey Wolf and type `/con`** → a line on how the fight reads, such as "Looks like an even fight." notes:
- [ ] **7. Fight it: press Q for auto-attack. Casters: sit (Z), open the book (B), click a spell, click a Spell Bar slot, stand, then Alt+1 casts it** → the wolf dies and you get an XP line. notes:
- [ ] **8. Right-click the wolf's corpse and press Loot All** → the drops land in your bags (I) and any coin in your purse. notes:
- [ ] **9. Kill five, then right-click Aldric again and turn it in** → XP, and a Tarnished Silver Ring. Right-click the ring in your bags → it goes on, and AGI on your character sheet (C) rises by 1. notes:
- [ ] **10. Buy a Bread Loaf (4 copper) and a Water Flask (3) from Brom: right-click him, Buy tab, pick the item, press Buy** → the coin leaves, the items arrive, and the hunger and thirst bars sit under your character bar. Keep some in your bags all night; the game eats and drinks from them on its own. notes:

## 3. Together

- [ ] **11. `/invite Name` (or target them and press Invite on the group panel)** → their panel reads GROUP (Invited); they press the button or type `/accept` → both of you see each other's health, mana and stamina bars. notes:
- [ ] **12. Kill something as a group** → each of you gets an XP line. With `/autosplit on`, looted coin splits across the group. notes:
- [ ] **13. `/g hello`, then `/tell Name hi`** → the group line reaches the group, the tell reaches only them, and their `/r` answers you. notes:
- [ ] **14. Jump where a friend can see you, up close and from far off** → they see the hop, as far away as they can see your body at all. notes:
- [ ] **15. Trade: left-click an item in your bags to pick it up, then left-click your friend** → a trade window on both screens; each of you adds items or coin, both press Accept → the goods swap, nothing lost and nothing doubled. notes:
- [ ] **16. Heal or buff a group-mate standing next to you, then from 40 m away** → it lands up close and is refused at range (30 m is the reach). notes:

## 4. The bank and the merchants

- [ ] **17. Right-click Thalia Mourne (the banker, east end of the row). With the bank open, right-click an item in your bags** → it moves to the vault; right-click it in the vault → it comes back. notes:
- [ ] **18. Leave something in the vault, Quit Game (Esc), log back in** → it is still in the vault, and you are standing where you quit. notes:
- [ ] **19. Sell a drop to Elara (Sell tab)** → the coin you get is the number the window showed. Try to sell the ragged shirt → refused: it is NO DROP. notes:

## 5. Die on purpose (once you have a few things in your bags)

- [ ] **20. Pick a fight you cannot win (the Gnoll Raiders' camp two minutes out along the east road, at about x 560, or the whole wolf pack at once)** → YOU HAVE DIED; about five seconds later you stand in the town square wearing nothing, with a little less XP. notes:
- [ ] **21. Run back to where you died (the world is big now, so it is a real run)** → your corpse lies there with your name on it. notes:
- [ ] **22. Right-click it and press Loot All** → your gear is back ON you (not just in the bags) and your coin is exact to the copper. notes:
- [ ] **23. If a Cleric or Paladin is on: die again and let them resurrect you** → an Accept prompt; you land at your corpse with a quarter of your health, no mana and "You are exhausted."; five minutes later "You feel your strength return." notes:

## 6. The hills

- [ ] **24. Leave by the north gate and follow the road about 500 m; Bat Hollow is a short way west of it (about x -130, z 540): a ring of raised ground, 9 m high, with a dip inside. Three Cave Bats live in it (level 4), so look from the rim unless you are grouped** → you walk the slope cleanly, nothing jitters, and a friend standing on it looks like they stand ON it, not in it. notes:
- [ ] **25. With a bat down in the hollow and the rim between you, try to cast or shoot at it** → refused (no line of sight); step up onto the rim and it lands. notes:

Long drops hurt now (a share of your health per metre past two), but there is no cliff near
town. The real ones are the ridge a kilometre north (the road goes through it by a pass) and
the Wraith Gate plateau far east, whose cliff kills. Both are a long way into high-level
ground. Look, do not climb.

## 7. Leaving

- [ ] **26. Sit (Z) and type `/camp`** → a 30-second countdown, then the game closes. Log back in → you are where you camped, with everything. notes:
- [ ] **27. Once, on purpose: close the window with the X, then log straight back in** → refused for up to about 45 seconds (that is the linkdead guard, not a bug), then it works and nothing is lost. notes:

## 8. Anything odd

- **Esc, then Report a Bug** opens our Discord. Say what you were doing, what you expected,
  roughly when, and paste your `/loc`. If the game did something strange, attach
  `%APPDATA%\Godot\app_userdata\Project_Dawn\debug.log` (paste that into the Explorer address bar).
- **The gold ones:** anything that **vanishes**, **doubles**, or **hands you something you should
  not have**. Those first, every time, with as much detail as you can remember.

## Three lines before you log off

- Best moment:
- Worst moment:
- Would you log in again tomorrow? Why, or why not:

Thanks. Break it.
