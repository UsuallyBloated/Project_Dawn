# Map Commission Briefs — Painted Impressions of the Atlas Annex

Out-of-world working document. These briefs distill the twelve plates in `docs/concepts/world/maps/` into prompts an image model (Gemini / Nano Banana) can execute. The in-world style authority is [drafting_standards.md](../concepts/world/maps/drafting_standards.md); each plate's `Visual Character — for the Chief Artist` section carries its palette; the IX-series `.i` vignette volumes carry close-up subjects.

## How to use these briefs

- **One brief = one commission.** Don't paste a whole plate file at a model; it will drown. Each brief below is sized to what a model can actually hold: a style line, a palette, 8–12 must-render features, and negatives.
- **Two-pass workflow.** Pass 1: the full plate from the brief. Pass 2: vignette crops (buildings, landmarks, objects) from the `.i` volumes — those sections are already written as single-subject prompts with color/dimension/atmosphere notes; lift them nearly verbatim.
- **Standard style line (all Hall plates):** *"Hand-inked fantasy atlas plate on aged broadsheet parchment, double-ruled sepia border, letterspaced capitals for region names, muted regional watercolor washes, iron-gall line work, small gold-leaf accents reserved for marked sites, red wax seal at lower right breaking the border. No modern typography, no photorealism, no saturated colors."*
- **Standard negatives:** modern fonts, glossy rendering, lens effects, neon, English UI elements, character close-ups on map plates.
- **Resolution note (dual use):** commission at the highest available resolution, landscape. These images are also candidates for the in-game zone map / map UI (open To-Do item), so zone names must stay legible when the long edge is downscaled to ~1024 px. Avoid detail that only reads at full size for anything gameplay-critical.
- **Consistency anchors to repeat in every prompt:** the six-fingered-handprint gold site icon; the six-fingered compass rose (north finger longest, single gold tip); the quartered Hall seal in red wax; the empty-parchment treatment for uncharted areas.

---

## Volume I — Regional and Topical Plates

### Plate I — Surface Continental Survey of Valdis
- **Style:** standard Hall style line; the most formal plate of the set.
- **Palette:** cold grey-blue north sea, warm blue-green south-east sea, honey/green heartlands, rust-red badlands, black-stippled volcanic west coast, grey-violet blight stain, bare parchment for the uncharted east.
- **Must render:** the Valdis coastline (Greymere north, Remnant south-east); the Dwarven mountain range across the north; Cogsworth and Aelindra below it; Greenshire–Ardenmoor–Greyveil in the west with the blight stain east of the forest; Harrowmere on its sheltered strait with the Drowned Hold offshore; the red Badlands east with three mesas; the Khala savannah and the southern marshlands; the volcanic Ashen Coast with the Rising Shell offshore; ten small gold handprints tracing an arc across the continent; the six-fingered rose in the Greymere; roads as fine lines (Iron Way, Northern Road, East Trunk).
- **Marginal quotes:** "The cartographer's office has instructed all current field teams to assume there are more."
- **Aspect:** wide landscape (≈3:2).
- **Omit:** all settlement interiors, the second continent, faction territory lines.

### Plate II — The Western Heartlands
- **Palette:** study in greens with one grey-violet wound (the blight). Pale gold ploughland, hedge green, deep canopy green, silver-green at Aelindra.
- **Must render:** Greenshire's patchwork farmland with Sable's Run steaming faintly; Ardenmoor's forest mass with four canopy villages as subtle platforms; Aelindra's six spires in a hexagonal court around a central tree; the blight's hard western edge with bare grey trunks inside; the Greyfen's peat bog with four half-sunken gold-outlined outcrops; Greyveil at the river confluence with the three-span bridge and six-gated wall; the east road threading it all together.
- **Marginal quotes:** "Six inches per month, and the Wood Elves are still counting."
- **Aspect:** wide landscape.
- **Omit:** Blighted Wood interior landmark labels beyond Rotwood Hollow and the Heartwood; Greyveil street detail.

### Plate III — The Eastern Territories
- **Palette:** maritime grey-blue north half, rust-red dry south half; the split at the plate's waist is the composition.
- **Must render:** Harrow Strait sheltered inside the stormy Greymere; Harrowmere's wharf-city (six distinct dock areas, lighthouse on a spit); the Drowned Hold as a dark fortress silhouette on a seamount, garrison banner still raised; a six-floor vertical-section inset of the Hold darkening downward to a gold-marked unreached bottom floor with the words "PENDING: FINAL CALIBRATION"; Auroch's Rest grassland with circular earthwork halls beside cemetery grounds; the Breach — two siege camps with trebuchets and bombards facing across a neutral strip with a single tower; the red Badlands with Durrath's Mesa (temple carved in its face), the flat Skullback, the lightning-scarred Cracked Crown; Ashfang's lone black tower in the south.
- **Marginal quotes:** "Purposeful in a way that undead are not, ordinarily, purposeful."
- **Aspect:** wide landscape.
- **Omit:** the uncharted eastern scrub (bare parchment + note), Gate-Key lore text.

### Plate IV — The Southern Reaches
- **Palette:** five hard-contrast regions — fae silver-green, volcanic black/red/white surf, ash-grey battlefield, gold savannah, green-black marsh; gold site-marks gathering toward the south-east.
- **Must render:** Fae Mere's forest with twin gateway trees and reflective pools (let reflections be subtly wrong); the Ashen Coast with black sand beach, three vent plumes, glasswright coves, the Tide Marks carved into sea cliffs; the Rising Shell offshore — a vast curved structure part-surfaced from the sea; the Ashen Marches with three standing banners (two faded military standards and one unidentifiable third); the Khala Savannahs with a great kopje, a stone circle, and acacia clusters; the marshlands with the stepped shadow of a ziggurat beneath still black water and one pale causeway thread reaching it; the jungle-swallowed Bonecourt; Ixareth-Kul's ruined ring-city with an intact roofless hall at its core.
- **Marginal quotes:** "Something sits the throne." · "The Ziggurat's patience."
- **Aspect:** wide landscape.
- **Omit:** the three Order Houses' positions, Revenant mechanics.

### Plate V — The Northern Industrial Belt
- **Palette:** metal and mountain — snow-grey range, brass/copper city glow, forge orange, industrial haze.
- **Must render:** the high mountain range with three carved hold-gates (king's seat, mason's hall, working forge); the Iron Way descending through a pass with a stone bridge, a lit hostel at midpoint, and a snow-watchers' hut; Cogsworth as a terraced industrial city — clock tower crown, foundry district, brass manufactories, steam venting from a lower square; a vertical cross-section inset of six tiers descending into Kobold tunnels; Sable's Run leaving the city warm (faint steam-line).
- **Marginal quotes:** "The bells have been slightly off for eighty years; nobody has fixed them."
- **Aspect:** wide landscape.
- **Omit:** Hold interiors (Plate VI's business), valve-dispute governance text.

### Plate VI — The Underdark, in Vertical Section
- **Style override:** geological strata illustration, not terrain map. Horizontal bands of darkness descending, each band keeping its own light.
- **Palette:** lantern-warm browns (upper), mixed market glow (middle), violet-black with pale spell-light (Vel'Sharath), and near-total black at the bottom with one thin under-glow.
- **Must render:** four surface entry points at the top edge; the Kobold Deeps band (warm, domestic); the Crossing band split into three sectors (Kobold north / neutral market centre / Dark Elf south); a sealed side-branch with a gold mark behind the seal (the Quiet Dig); two isolated side-chambers that don't touch the main trunk (a softly green-lit grove; a sealed vault); Vel'Sharath as a deep city band; and at the foot, a vast black volume — the Lit Space — lit faintly from below its far side.
- **Marginal quotes:** "Too large to see across, and the far side of it is lit from below."
- **Aspect:** tall landscape or portrait — vertical is the subject.
- **Omit:** any detail inside the Lit Space; the seal stays whole.

### Plate VII — Maritime Routes & Sea-Lanes
- **Style override:** portolan chart — the sea is the subject, the continent a bare outlined coast; rhumb lines radiating from a wind rose with named wind-faces (unfriendly expressions); dashed seasonal lane-lines connecting the ports.
- **Must render:** the lane chain drawn as actual routes: Harrowmere → Cinder Docks → Bonewright Wharves → Cape Bonewright → the Bone Reach (massed wreck marks in a shallow strait) → the long lonely Vah'tharan Passage south; the Drowned Hold and Rising Shell offshore with gold marks; three approximate survey-licence marks in the open Remnant; storm-cell spirals in the Greymere; the Maren coastline entering from the bottom edge and fading to nothing.
- **Marginal quotes:** "We have not found a corner."
- **Aspect:** wide landscape; lower third mostly open water (keep it lonely).
- **Omit:** all interior terrain; lane licensing text (table lives beside the plate, not on it).

### Plate VIII — The Predecessor Arc (network diagram)
- **Style override:** scriptorium working diagram — ink and chalk-line on dark slate or heavy drafting linen; labelled node-boxes and ruled edges; pinned notes and corrected lines showing 41 years of use. NOT a landscape.
- **Must render:** eleven labelled nodes with one small gold handprint each; one node (the Convergence Point) with edges to every other — an unmistakable starburst; a terminus node (the Roofless Hall) with a gold throne glyph and a sealed vault beneath; one node carrying legible alien script reading "PENDING: FINAL CALIBRATION"; a five-stage flow strip (trigger → intensify → transmit → process → conclusion) with the final stage conspicuously blank; one dashed speculative node (the Deep Rooms).
- **Marginal quotes:** "The Architects documented the method exhaustively and the conclusion not at all."
- **Aspect:** landscape.
- **Omit:** terrain, color washes, anything cheerful.

---

## Volume II — Starting-Zone Plates

### Plate IX-A — Greenshire
- **Palette:** soft pastoral — honey wheat, hedge green, grey-blue stone, chimney smoke; one red building (the mill).
- **Must render:** patchwork fields with stone walls and hedgerows; the red three-storey watermill on a steaming river; the Three Ponds village (green, maypole, inn, six conical kilns smoking); four hamlet clusters and a great hollow oak with doors in it; a tall granite waystone at a three-road junction (one face blank); the toll station at the east gate; southern downs rising to sea cliffs with a forty-foot waterfall off the edge and a hidden cove below.
- **Marginal quotes:** "Gentle, readable, and not entirely honest about what comes next."
- **Tone instruction:** honour the gentleness; nothing on this plate is foregrounded as a threat.
- **Vignette pass:** 13 vignettes already scripted in `09a_greenshire.md` (Plate IX-A.i).

### Plate IX-B — Ashfang Hold
- **Palette:** pale-iron — bleached straw scrub, rust-red rock, dried-blood hide tents, one black basalt vertical.
- **Must render:** the squat black three-storey tower alone on bleached ground (banner raised); concentric rings of hide tents a half-league away with a perpetual central fire's smoke column; six trophy poles in a half-arc; the circular sand-floored fighting pit ringed by an earthwork with a bone-yard beside it; eight uniform stake-pens in two rows; one dead-straight road marked by bleached-skull milestone poles running from the camp's west edge to the tower.
- **Marginal quotes:** "A working culture on bad ground, and the bad ground is the ground the Good civilizations did not want."
- **Tone instruction:** render the harshness with respect — a community, not scenery.
- **Vignette pass:** 6 vignettes scripted in `09b_ashfang_hold.md` (Plate IX-B.i).

### Plate IX-C — The Bonecourt
- **Palette:** layered green and weathered pale — green-black cypress canopy, luminous grey-white cypress-wood halls, lacquer-black water, ash-grey old stone under vines, thin pale pyre smoke.
- **Must render:** a cloister of seven pale wooden halls around a flagstone court (no wall, no gate); a circular court of seven low stone fire-platforms burning at ground-glow; a winding path of twelve mismatched cairns; an overgrown dark-stone temple with a carved four-handed figure at its entrance; one giant cypress crowning above the canopy; black-water channels with a punt and pole.
- **Marginal quotes:** "The Bonecourt is named for the Bone Court, not the other way around."
- **Tone instruction:** a discipline-house, not a horror set; the pyres are classrooms.
- **Vignette pass:** 6 vignettes scripted in `09c_bonecourt.md` (Plate IX-C.i).

### Plate IX-D — The Kobold Deeps
- **Style note:** hybrid plan-and-section, underground; tiers stacked vertically.
- **Palette:** warm lantern browns vs. cool steady blue-green fungal light; grey Dominion masonry; black unlit passages.
- **Must render:** a carved licensing arch at the top with one lantern in an alcove; four den-camps in two tiers, each with a small polished stone on a pedestal at its entrance; a great oval council chamber with eight wall lanterns and a central fire; a domed chamber ceiling-lined with glowing blue-green fungus; a waterfall into a clear quartz-lined pool; one dead-straight masonry tunnel running east to a raw digging face with a single lantern — and real darkness past it.
- **Marginal quotes:** "The Pack does not have a destination, only a working programme."
- **Tone instruction:** Kobold-scale architecture throughout — doorways low, tools small; a Human must stoop.
- **Vignette pass:** 6 vignettes scripted in `09d_kobold_deeps.md` (Plate IX-D.i).

---

## Special Commissions (different hands on purpose)

### The Maren / Vah'thara Sketch (from the Atlas)
- **Style:** deliberately rougher — a compiled second-hand chart, not a Hall plate. Partial northern coastline in confident line, interior fading to blank, marginal annotations in two different hands (Compact log captain + travelling Seeker), no gold, no seal.
- **Must render:** a northern coast with one headland ruin and one shore landing; a vast blank interior with a single dashed savannah suggestion; the coastline running off both edges unfinished; "we have not found a corner" lettered where the coast gives out.

### The Drathis Vehn Appendix Pages (two pages)
- **Style:** a traveller's field journal in ink — cramped travelling hand, diagrams that almost parse: part star-chart, part tide-table, part something with no genre. The Hall's marginal note "filed, not incorporated" in a different, tidier hand.
- **Intent:** these are the art equivalent of a mystery box; they should reward staring and resolve nothing.

### The Hall's Seal + Six-Fingered Rose (asset sheet)
- **One commission:** the quartered wax seal (book / chain / tree / deliberately empty quarter) and the six-fingered compass rose at several sizes, on neutral parchment. Produced first, then referenced in every other commission for consistency.

---

## Suggested commission order

1. Asset sheet (seal + rose) — consistency anchor for everything after.
2. Plate IX-A Greenshire (most vignette support, friendliest test of the style).
3. Plates IX-B/C/D (starter zones; doubles as in-game map art for the four tutorial zones).
4. Plate I (the continental statement).
5. Plates II–V (regional).
6. Plates VI, VII, VIII (the three style-overrides).
7. Maren sketch + Drathis pages (the different hands).
8. Vignette passes per zone as needed by the game's art checklist (`art_assets_checklist.md`).
