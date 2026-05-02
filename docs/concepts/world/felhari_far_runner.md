# The Far-Runner Question — Design Record
*Canonical design decisions for the Far-Runner ancestral figure, the Ancestor's Mouth questline, and the Khala-Maren cross-continental ceremony.*
*Filed: Active Mystery Threads*

---

## Background

The Far-Runner appears in `khala_savannahs.md` as one of three formally recognized Felhari ancestors: *"An ancestor who walked the full perimeter of the Savannahs in a single season as a demonstration that the territory was real and theirs."* The existing description establishes behavior (appears in motion, at the edge of vision, always same direction), domain (boundaries and what is beyond them), and a passive buff for players in unmapped territory.

What the zone file does not resolve: which perimeter the Far-Runner walked, how the Far-Runner connects to the Ancestor's Mouth content, and why the Encroaching Silence is outpacing the current Spirit-Walkers' capacity to manage it. These questions have consequential implications for the Maren content and the Ancestor's Mouth dungeon's resolution path.

---

## Canonical Decisions

### 1. The Far-Runner Was Historical

The Far-Runner crossed from the Khala Savannahs to Maren approximately six hundred years ago — circa Year 247 CR, well before the Dominion War. The "single season" of the perimeter walk is accurate in the tradition's memory, but the tradition has compressed what happened: the Far-Runner reached the Felhari coastal edge, kept going, and did not stop at the water.

The crossing was deliberate. The Far-Runner understood there was something on the far side — the Maren continent's Vah'tharan clans practice the second half of a ceremony that the Khala Savannahs practice only the first half of, and the Far-Runner understood this distinction in a way that is now only partially preserved in the oral tradition. The tradition remembers the walking. It no longer fully remembers why the walking did not stop.

The Far-Runner did not return. Khala records describe this as an absence that became permanent, reframed over generations from "the one who left" to "the ancestor who walks the boundary." The reframing is not dishonest — the Far-Runner is still walking, and boundaries remain the domain. But it has obscured the specific content of what the Far-Runner left to complete.

### 2. The Shore Clans Are Descendants

Felhari Shore clans — the semi-nomadic groups living along the Felhari coast facing Maren, not present in the Khala Savannahs' three-major-clan structure — are the Far-Runner's direct descendants. They practice a modified form of Khala clan traditions adapted for people who live at a literal boundary and whose founding ancestor represents the act of crossing it.

Shore clan characters have a specific relationship to the Far-Runner that other Felhari characters do not: the Far-Runner appears to them facing toward Maren rather than in profile. This is the only documented variation in how the ancestor presents. The Shore clans understand what this means. They have been waiting for the context to become resolvable for a very long time.

A Shore clan Spirit-Walker or Shaman who reaches the Ancestor's Mouth has dialogue options that reflect this inherited knowledge — options that other characters cannot access and that the Gathering's senior Spirit-Walkers will not have seen before.

### 3. The Khala Ceremony Is Incomplete

The Ancestor's Mouth ceremony as practiced by the Khala clans is one half of a two-continent ancestral acknowledgment. The Vah'tharan Spirit-Walker tradition on Maren contains the other half.

The complete ceremony is called, in the oldest Vah'tharan records and in Shore clan oral tradition, the **Vah'tharan** — approximately "the full crossing." The Khala half practiced alone is called the **Vah'kal** in Khala scholarly works — the partial crossing, the turning-back version. Most Khala practitioners do not know this term because the distinction it marks has not been operationally relevant in six hundred years.

The incompleteness is not a ritual flaw. The ceremony was designed to be completed across the distance between the two continents, with both halves running simultaneously and acknowledged at their respective conclusion points. This requirement is embedded in the ceremony's structure in ways that Spirit-Walker practitioners recognize when they know to look: certain points in the Ancestor's Mouth ceremony produce a response clearly designed to be received by something, and no Khala Spirit-Walker has ever identified what receives it. The Vah'tharan Spirit-Walkers know: they are receiving it, and sending back a response that no Khala practitioner has ever been able to trace to its source.

### 4. The Encroaching Silence Is a Consequence of Incompleteness

The Encroaching Silence pushing inward through the Ancestor's Mouth's deeper sections is not an independent phenomenon. It is a structural consequence of running an incomplete ceremony in a space designed for a complete one.

The Ancestor's Mouth was built as a transmission point. When the ceremony runs fully on both ends, it routes the spiritual pressure that accumulates at the transmission point through the crossing, distributes it between continents, and closes the cycle. When only one half runs, the pressure accumulates at the Mouth without distribution. The Encroaching Silence is six hundred years of accumulated pressure.

The current Spirit-Walker generation can limit the pressure but cannot resolve it. They are patching a structural problem by working harder at the patch, and the structural problem is growing faster than the patches. The Far-Runner's appearances have been increasing in frequency for thirty years. The ancestor who stands at the boundary appearing more often is, in Khala interpretation, not a good sign.

### 5. Full Resolution Requires Maren Access and Vah'tharan Presence

The Ancestor's Mouth questline cannot be fully resolved through the Khala Savannahs alone. The resolution condition requires:

1. A player or party with Ancestor's Mouth progress sufficient to have reached the Encroaching Silence's source chamber
2. Maren continental access and established contact with the Vah'tharan Spirit-Walker tradition
3. A Vah'tharan Spirit-Walker present at the Maren ceremony point simultaneously with the Khala ceremony run at the Ancestor's Mouth

The simultaneity is required by the ceremony's design and the ceremony's design is not flexible. "Simultaneously" at server scale is handled as a paired encounter mechanic: Maren-side and Khala-side players trigger ceremony completion at their respective ends, and both conditions must be met. The ceremony completes when both ends have been properly run.

**Content scheduling implications:**
- The Ancestor's Mouth's partial resolutions — reducing the Encroaching Silence's pressure, limiting its advance — are available and completable through Khala-side effort alone. The full resolution is not.
- The Maren content requires a Vah'tharan Spirit-Walker tradition detailed enough to support this cross-continental ceremony. That content is downstream. This document pre-establishes the mechanic; the specific Vah'tharan design is deferred.

The Encroaching Silence's boss encounter should reflect this: it can be suppressed and returned to manageable levels by Khala-side effort, and the encounter can repeat. The full resolution — which ends the Encroaching Silence permanently — only happens via the two-continent mechanic, and the encounter should have a state change that reflects this distinction clearly.

### 6. The Far-Runner's Response at Completion

The Far-Runner, across the entirety of Khala Spirit-Walker testimony, has never looked directly at a Spirit-Walker or acknowledged an individual. The ancestor appears at the edge of vision, facing away, always in motion, always the same direction.

At ceremony completion — when both halves are successfully run — the Far-Runner stops.

Not at the edge of vision. In the Spirit-Walker's direct perception, wherever the Spirit-Walker is standing. The Far-Runner turns and looks at the player directly. Not for long, and not as a conversation — there is no dialogue, the ancestor does not speak. It is a look of recognition. It is the first time in six hundred years of Khala Spirit-Walker testimony that the Far-Runner has been recorded as looking at anyone.

This moment is silent, non-interactive, and unrepeatable for the character that triggers it. The Gathering's oldest Spirit-Walkers, told what happened, go very quiet. There is no recorded protocol for this. The tradition says what the Far-Runner knows is about boundaries and what is beyond them. What has just happened is that the boundary the Far-Runner has been walking for six hundred years has been closed.

---

## Cross-Document Implications

- **`khala_savannahs.md`** — The Far-Runner's existing description is accurate and should not be changed. The design record adds context that practitioners do not have until late questline. The Far-Runner buff in unmapped territory remains as written.
- **Shore clan character background** — The facing-Maren variation should be noted in character creation documentation when Shore clans are added as a background option.
- **Maren content** — This document pre-establishes the Vah'tharan ceremony requirement. Maren design should include a Spirit-Walker tradition whose ceremony mirrors and completes the Khala Vah'kal. The specific Vah'tharan design is deferred but the requirement is canonical.
- **`ancestor's_mouth` dungeon design** — The Encroaching Silence is a symptom, not an independent antagonist. Boss mechanics should reflect suppression vs. resolution as separate outcomes. Loot and encounter states should distinguish between partial-resolution runs and full-resolution (post Maren mechanic) completion.
