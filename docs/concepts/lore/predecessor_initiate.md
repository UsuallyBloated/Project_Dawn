# The Predecessor Initiate
*What the archives say. What it costs to listen.*

## Overview

The Predecessor records can be read. This is not a settled scholarly position — the Soulcarvers of Ixareth-Kul believe it, the Ash Scribes consider it the most dangerous belief in the world, and the Bonewrights have no opinion because they consider information a less interesting category than material. The Initiate is the character who proves the Soulcarvers correct.

There is no class trainer for this. There is no spell that grants it. The archives were not designed to be read by people in general; they were designed to be read by the people who built them. Reading them requires assembling, in a single living person, the breadth of skill and lived experience that the Predecessors took for granted in their own kind. No two Initiates assemble the same breadth.

See [pre_history.md](pre_history.md) for the underlying lore.

---

## The Path

The Predecessor record-carvings are not a language. They are a layered notation — material, intentional, structural — that requires the reader to know what they are looking at across multiple unrelated disciplines simultaneously. A potter recognizes the pinch-marks in the ceramic-pattern lower courses. A tailor recognizes the weave-references in the fiber strata. A diplomat recognizes the negotiation-symmetries in how factions of carvers handed work off to one another. None of these readings alone yields meaning. All of them together begin to.

Each character pursuing the Initiate path develops a unique required set of masteries. The set is generated when the character first touches a Predecessor surface intentionally — by completing a relevant action in the Sunken Ziggurat, on the Bone Citadel approach, or in the Ixareth-Kul lower levels. The set is not revealed. The character learns it one entry at a time, through Rubbings.

### Rubbings

Rubbings are fragmentary records taken from Predecessor surfaces. They drop rarely from:

- Deep Sunken Ziggurat encounters
- The Bone Citadel exterior (the interior is not yet accessible)
- Soulcarver-controlled chambers in Ixareth-Kul
- Specific named mobs along the Predecessor thread (not ordinary thread bosses — particular ones)

A Rubbing, when studied (right-click in inventory), reveals one entry from that character's required set: *"You feel that you would understand this carving more clearly if you had spent more time at the loom."* The Rubbing is consumed in the reading.

A required set is exactly **five tradeskills**, randomized per character. Of those five:

- **Two must be mastered.** These are the deep readings — pinch-marks in the ceramic lower courses, weave-references in the fiber strata, alloy-ratios in the structural members — that only a master craftsman recognizes for what they are.
- **Three must be trained past a threshold.** These are the surface readings — pattern recognition that a competent practitioner has internalized but a master is not required for. The exact threshold value is TBD; somewhere between half and three-quarters of the per-class cap is the right neighborhood.

All fifteen crafts in `recipe_definitions.gd` are eligible: Smelting, Tanning, Leatherworking, Tailoring, Blacksmithing, Weaponsmithing, Woodworking, Fletching, Alchemy, Poison Making, Baking, Brewing, Jewelry Crafting, Pottery, Tinkering. The randomization does not respect class. A Warrior may need Master Pottery and Master Alchemy with threshold Tailoring, Brewing, and Tinkering. A Wizard may need Master Brewing and Master Leatherworking. The combinations are designed to be unlikely.

The Predecessors were a civilization with a different topology of knowledge from the current one. The carvings reflect that, and so does the cost of reading them.

### Completion

When all entries in the character's set are satisfied, the next Predecessor surface the character touches resolves. They read what is there. The transformation is not granted by an NPC; it is the consequence of the reading. No ceremony, no flash. The character was not an Initiate, and then they were.

---

## What Is Asked

- The character accepts that they now read continuously, whether they want to or not. Predecessor surfaces speak. The Initiate cannot unsee what is on them. Several existing zones contain Predecessor surfaces the character has been walking past without noticing; those surfaces will not be quiet anymore.
- The character accepts that the Ash Scribes will know. The Scribes' position is that the archives must remain unread, and a reader is, by their doctrine, the most dangerous possible thing. Standing with the Ash Scribes drops to hostile at the moment of completion and cannot be repaired.
- The character accepts that some part of what the Predecessors recorded was not meant for a living mind to hold. The Initiate experiences this as occasional involuntary intrusion — fragments of intention that are not theirs, surfacing in moments of stress.

## What Is Given

- The Initiate reads Predecessor surfaces. The contents of those surfaces are content this prestige is the access mechanism for — late-game thread resolution that no other character can engage with directly.
- Identification of Predecessor materials, structures, and intentions becomes automatic — no rolling, no lore checks.
- A slow passive insight regeneration that functions independently of mana and is consumed by reading. The Initiate can sustain longer readings than any other character.
- One additional ability is granted at the moment of completion. The ability is keyed to which discipline tipped the reading from incomprehensible to legible — different across Initiates. This is mechanically opaque on purpose.

---

## The Hunted Status

The Ash Scribes maintain contracts at the bounty stones in the lower city of Ixareth-Kul. Any character who completes Initiation appears on those contracts within the next reset cycle. The contracts do not pay gold — they pay in Bonewright favor, the only currency the Ash Scribes consider non-corrosive.

Contracts are visible to any character who has standing with the Ash Scribes faction (which includes most characters who have engaged with the Ixareth-Kul questlines at all). From completion onward, the Initiate is a target that other players can choose to pursue.

The Initiate is not flagged for general PvP. The Initiate is flagged for *the contract*, meaning contract-holders can engage them in zones where engagement is otherwise restricted, and only contract-holders can. This preserves the mythic-rarity dynamic without making the Initiate's life unmanageable in ordinary zones.

---

## Visibility

The Initiate is not visually distinct by default. The transformation does not glow.

However, certain actions produce visible cues that any sufficiently observant character can notice — reading a Predecessor surface in public, using the granted ability, being within proximity of an unread Rubbing. Initiates who want to remain mythical learn to read in private. Initiates who do not are usually not Initiates for very long.

---

## Three Sites, One Threshold

The three sites where Initiation can resolve — the Sunken Ziggurat, the Bone Citadel approach, the Ixareth-Kul lower levels — are the same three locations where the Unmarked Threshold surfaces for the [Revenant Ritual](revenant_ritual.md). This is not a coincidence. The geography is thin in the same places for related reasons. A character who has pursued both paths simultaneously is doing something the world has not previously seen attempted, and the consequences of that are not specified.

---

## Notes

This prestige exists to produce the same cultural artifact early SWG Jedi produced: a path so rare that seeing one in the world is an event, gated behind requirements so cross-disciplinary that meeting them is necessarily a long-term project, and visible enough once attained that the Initiate is part of the world's mythology even to characters who never become one.

The path is not balanced for power. It is balanced for scarcity. An Initiate is mechanically capable but not strictly stronger than a Master-tier conventional character; the value is in the content access and in the social position — you are the Initiate on your server.

If two Initiates exist simultaneously on the same server, this is correct. They will not have the same required set, the same granted ability, or the same reading. The Predecessors did not have one kind of mind.

---

## Open Design Questions

These are deferred until the rest of the design firms up. None of them block the lore; all of them block implementation.

1. **Threshold value for the three non-master entries.** Half the per-class cap is gentle; three-quarters is brutal. This is the primary scarcity dial after set size, and it interacts with how willing players are to grind crafts they would otherwise never touch.
2. **Whether faction standings, lived experiences, and named-NPC relationships return as a separate layer.** They were in the first draft and pulled when the set narrowed to five tradeskills. The flavor was strong — possible homes: a *second* unlock layer gated behind initial Initiation (Predecessor late-game content access), or world-state flags that color what the Initiate reads rather than what they need to read.
3. **Granted-ability pool.** One ability per Initiate, keyed to whichever tradeskill tipped the reading from incomprehensible to legible. Needs a candidate list — one per craft, or one per craft-family (metalworking / fiberworking / consumables / etc.). Abilities should feel Predecessor-flavored, not generic prestige bonuses.
4. **Bonewright favor as a currency.** Doesn't exist yet. Needs a one-paragraph definition in the factions doc when factions get a dedicated file: what it buys, who issues it, whether it decays.
5. **What "reading a Predecessor surface" actually does mechanically.** The lore answer is late-game content access — but no Predecessor surface content exists yet. Reading needs at least a placeholder: lore-flavor text on inspect, faction-state hooks, quest-step triggers, or some combination.
6. **Per-character set generation timing.** First intentional Predecessor touch (more mysterious; alts cannot be planned) versus character creation (alts can be planned; reduces in-world surprise but enables long-term character builds). The first-touch version is the current draft choice.
