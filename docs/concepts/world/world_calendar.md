# World Calendar and Time System
*In-game time, seasons, days, and the calendar that the world uses.*

---

## In-Game Time

**Time scale:** One real-world minute equals one in-game hour. One real-world day equals twenty-four in-game hours (one full in-game day).

This means the in-game world moves at 24x real time. A player who logs in at the same real-world time each day will encounter the same in-game time of day. Seasons and calendar progression are visible over weeks of play rather than requiring months.

**Day/Night cycle:** 24 in-game hours = one in-game day.
- Dawn: Hour 5–6
- Day: Hour 6–18
- Dusk: Hour 18–19
- Night: Hour 19–5

Specific mechanics tied to time (undead spawn behavior, certain NPC schedules, some spell and skill effects) use the in-game hour, not the real-world time.

---

## The Calendar

The world uses the **Common Reckoning** calendar — a system that emerged from the Greyveil Merchant Houses as a standardized trade dating system and has been adopted across the western territories. The eastern badlands and Kel`varath-heritage zones use a parallel Dominion calendar that still exists in historical texts; Common Reckoning year numbers do not match Dominion calendar year numbers.

**Current year (at game start):** Year 847 of the Common Reckoning.

The Dominion War ended in Year 547 CR. Three hundred years ago.

---

## The Year

**12 months. 30 days per month. 360 days per year.**

| Month | Common Name | Season | Notes |
|---|---|---|---|
| 1 | Firstthaw | Late Winter | Erindra's return festival; ice still on the ground |
| 2 | Seedmonth | Early Spring | Planting; Green Druid gathering |
| 3 | Greenrise | Spring | Longest of the spring months in most zones |
| 4 | Brightmonth | Late Spring | The warmest rains |
| 5 | Highsun | Early Summer | Longest days |
| 6 | Goldmonth | Midsummer | Harvest prep begins in agricultural zones |
| 7 | Harvestmonth | Late Summer | Primary harvest |
| 8 | Turnmonth | Early Autumn | Leaves change; Erindra's autumn festival |
| 9 | Ashmonth | Autumn | Named for the ash-fall in agricultural zones |
| 10 | Deepcold | Early Winter | First frost |
| 11 | Ironmonth | Midwinter | Solstice; coldest; Solrath's endurance vigil |
| 12 | Stillmonth | Late Winter | The waiting month; Vethis's accounting festival |

---

## The Week

**Six days per week. Five weeks per month.**

| Day | Common Name | Traditional Association |
|---|---|---|
| Firstday | The start of work |
| Secondday | — |
| Thirdday | Market day in most towns |
| Fourthday | — |
| Fifthday | — |
| Restday | Day of minimal commerce; temple day |

Merchants in Greyveil and Harrowmere observe Restday irregularly — ports and markets stay open. Agricultural communities observe it more strictly. The Vethis funerary temples are most active on Restday; death does not schedule around the work week, but Restday is when most communities hold services.

---

## The Day

**24 in-game hours.** Named periods:

| Period | Hours | Common Usage |
|---|---|---|
| Deepnight | 0–4 | Nothing legal happens in deepnight. Things happen. |
| Dawntide | 4–6 | Farmers, fishers, and those who never slept |
| Morninghour | 6–10 | Primary business hours begin |
| Noontide | 10–14 | Midday; some zones have a heat rest (Khala Savannahs) |
| Afternoonwatch | 14–18 | Second business session; guards change |
| Eventide | 18–20 | Merchants close; taverns open |
| Nightwatch | 20–24 | Taverns, guard patrols, and the things that come out |

---

## Seasonal Effects

### Spring (Months 1–4)
- Agricultural zone spawn tables shift to include more passive/non-hostile wildlife
- Green Druid quests and grove rituals available
- Snow and ice in mountain zones (Dwarven Holds, Breach passes) may restrict movement
- River crossing zones (Ardenmoor, Eastern Badlands) have flooded crossings

### Summer (Months 5–7)
- Maximum spawn density in outdoor zones — most animals are active
- Heat effects in Ashen Coast and Eastern Badlands (stamina drain passive)
- Fishing zones (Harrowmere, Southeastern Marshlands) have peak yields
- Khala Savannah's high-sun rest — certain NPCs unavailable midday

### Autumn (Months 8–9)
- Harvest festivals with temporary vendors in agricultural zones
- Blighted Wood's corruption patterns shift — slightly more aggressive spread visible
- Underground zones (Kobold Deeps, Underdark Crossing) unaffected — stable year-round
- Named mob spawn tables shift for some zones — different named mobs become rare in autumn

### Winter (Months 10–12)
- Undead spawn density increases across all zones (peak: Ironmonth and Stillmonth)
- Ashen Marches become significantly more dangerous — Third Army patrols extend further at night in winter
- Greyveil and Harrowmere have winter market events (merchant price adjustments)
- Some outdoor zones have weather effects (snowfall, blizzard) that reduce visibility
- Solrath's endurance vigil (Ironmonth 15): special quest available from Solrath temples; minor reward; significant RP content

---

## Festivals and Events

### Recurring Calendar Events

**Firstthaw Festival (Month 1, Day 15)**
Erindra's return — the light comes back. Agricultural communities celebrate outdoors regardless of weather. Green Druid public rituals. Seed blessing quests available.

**Solrath's Vigil (Month 11, Day 15 — the solstice)**
The longest night. Solrath temples hold all-night vigils — players who participate earn a temporary Solrath Standing bonus and a minor buff (passive fortitude) that lasts until the next in-game dawn. Paladin players receive additional dialogue.

**The Accounting (Month 12, Days 25–30)**
Vethis's calendar close. The final week of the year is associated with settling debts, acknowledging the dead, and the closing of accounts. The Vethis funerary temples hold the Naming — reading aloud the names of everyone who died in their district that year. Players who have completed notable deaths during the year (named mobs, dungeon bosses) may hear those names read.

**Market Week (Month 7, Days 1–7)**
Not religious — commercial. Greyveil and Harrowmere both run expanded market weeks with visiting merchants, temporary vendors, and auction events. Player stall fees are waived for the week.

### Server-Scale Events
Some calendar events are server-scale and require player participation to unlock:
- **Convergence Tide (Month 9, every year)** — The Ashen Marches' activity intensifies; the Nameless Commander's questline has expanded options; this is the canonical time to attempt the Final Encampment
- **The Gate-Warden's Watch (Month 11, every year)** — The Underbreach goes quiet for one night; the Gate-Warden does not leave its chamber; players who descend during this window find a different layout and a different encounter
- **The Architect Alignment (Month 3, every 7 years)** — The Architect sites' astronomical calibrations all point to the same configuration; the Residual in Varek's basement behaves differently; the survey terminus in the Vault is accessible from the surface without Vault authorization for 24 in-game hours

---

## Time-Keeping In-Game

The game UI shows the current in-game time in a small clock display. Players can track day/night by the sky. Key mechanic hooks:

- The **Ashen Marches night extension** (patrol range doubles at hour 19; returns at hour 5) is triggered by the TimeOfDay `hour_changed` signal
- **Undead spawn density** increases at hour 19 and decreases at hour 6 across all zones
- **Named mob windows** use real-world timers, not in-game time — the variance is against real-world minutes, not in-game hours
- **Meditation (sit-to-med)** is not time-of-day dependent but some meditation bonuses (food/drink stacking) are slightly stronger at Night (lore justification: quieter, less distraction)
- **NPC schedules** — shops open at Morninghour (in-game 6) and close at Eventide (in-game 18); guards change watch at Afternoonwatch (in-game 14) and Nightwatch (in-game 20)

---

## Historical Calendar Notes

The Dominion calendar begins from the founding of Ixareth-Kul. Year 1 of the Common Reckoning corresponds to approximately Year 3,200 of the Dominion calendar — the Common Reckoning was established long after the Dominion was active. The Dominion War occurred in Dominion years 4,047–4,058, or CR 547–558.

The discrepancy between the two calendar systems is the subject of significant scholarly dispute, primarily because some Dominion historical records suggest the Dominion calendar itself was reset at some point — there are records that reference events in "year 12,000+" that do not match what should be that far into the Dominion calendar's sequence. What reset it is not documented. The Order of the Sealed Record has opinions.
