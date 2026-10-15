# Meshy asset pipeline

How we plan to use Meshy (meshy.ai) to produce 3D models for Project Dawn, starting
with 2D reference packs that lock the aesthetic before any credits go into 3D.
Drafted 2026-10-12 from the 2026-09-24 research conversation. Nothing is wired up yet.

The art wish list this serves is [art_assets_checklist.md](art_assets_checklist.md);
target heights are in `docs/reference/creature_heights.md`.

**Low poly, detail in the textures (user, 2026-10-15):** "We want to use low poly models
with cool textures. So lets be sure not to go nuts with polygons." Every model this
pipeline produces is kept to a small triangle budget, and the look comes from the texture
rather than the geometry. For scale, the user's own blockouts are 1,442 (Human), 1,542
(Halfling), 1,666 (Gnome) and 1,868 (Ogre) triangles. Meshy defaults to 30,000 polygons when
it remeshes, and does not remesh at all by default with `meshy-7.1`, so the budget has to be
asked for on every generation. **The budget (user, 2026-10-15): 2,000 triangles for a
character's bare body.** Equipment is not part of that number; it gets its own budget later,
on top. Models are built from **four-sided polygons** (user, same day), and the game draws each
as two triangles, so Meshy is asked for **1,000 polygons** (user: the 2,000 counts triangles, as
the game draws them, not Blender faces; the blockouts are 730 to 960 Blender faces).
`meshy_client.py` enforces it (`TRIANGLE_BUDGET`, `POLY_BUDGET = TRIANGLE_BUDGET // 2`): every
generation and remesh is reduced (`should_remesh` always on, so the budget cannot be switched
off; `topology` always `quad`), `target_polycount` defaults to 1,000, and anything above is
refused.
Meshy's result can land somewhat off the target, so `measure_glb.py`'s triangle count is part
of the model review.

## Stage 1: 2D model packs (the style lock)

**Decided 2026-10-12 (user):** we start with 2D packs, to confirm the look we want
before generating any 3D.

A 2D model pack is the set of reference images for one subject (a race, a mob
archetype, a boss). It serves two purposes:

1. **Style approval.** We judge the aesthetic on cheap 2D images, where iterating costs
   little, instead of on 3D generations that cost credits.
2. **Meshy input.** Image-to-3D from our own reference sheets gives far tighter control
   than text prompts. Keeping 16 races in one consistent style is the hardest part of
   using any generator, and the packs are how we manage it.

### Who makes the images

**Decided 2026-10-12:** Grok and Gemini generate the 2D images. The images are internal
reference only and are not used commercially; they never ship in `assets/`.

### What a pack contains (proposed)

- **Separate male and female packs** for every race (decided 2026-10-12), so 32 race
  packs in all.
- **Turnaround:** front, side, back and three-quarter views (Meshy takes at most four),
  neutral A-pose, arms clear of the body (the auto-rigger needs this), plain background,
  flat even lighting. The same character, outfit and scale in every view, or Meshy has
  to guess at what does not match.
- **Height bar** drawn from `creature_heights.md`, so proportions between races stay correct.
- **Callout sheet:** skin tones, racial markings, silhouette notes.
- **The bare base body** (user, 2026-10-15): plain form-fitting undergarments, barefoot,
  **bald and beardless, no accent colour, a neutral expression and otherwise void of
  character** (user, same day), so the body's true shape is visible. Every piece
  of equipment, boots and helmets included, is later built to fit this body; clothes in the
  pack would hide the shape it has to follow. Hair, beards, markings and accent colours are
  left off because **players will be able to change their appearance in game at any time**
  (user, same day): those become separate, swappable pieces, made later on top of the body.

### Style bible

Before the first pack, write a one-page style bible. It sets the shared rules every pack
follows: palette range, level of detail, proportion style, line and shading treatment,
and one or two reference images. **Proportions are stylized (decided 2026-10-12)**; how
far to push them is the first thing the bible settles (see "The look of the model
packs" below).
The bible also holds the exact prompt template used in Grok and Gemini, so every pack
is generated from the same wording. The packs are judged
against this one page, which is what keeps Gnome #1 and Troll #16 looking like they
belong in the same game.

### Order

1. Style bible.
2. **Pilot: Gnome, male and female.** It is the only race with a mounted model today
   (`assets/models/characters/gnome/gnome.glb`, via `scripts/race_model.gd`'s `MODELS`
   table), so the pack can be compared directly against the current blockout and later
   carried through to 3D on a path that already works.
3. Review the pilot. Adjust the style bible if needed.
4. Remaining 15 races, then the mob archetypes (art checklist §8).

### Where files live

- Packs and style bible: `../Project_Dawn_Source/concept_art/<subject>/` (empty today).
- Mood boards and outside reference: `../Project_Dawn_Source/reference/`.
- Nothing from this stage goes into `assets/`.

## The review loop (agreed 2026-10-14)

Every subject (one race and sex, one mob, one boss) goes through these six steps in order.
**No step starts until the one before it is approved**, so a pack that fails review never
reaches the paid step and no credits are spent on a bad input.

1. **Style bible.** Written once, with the user's approved reference images. Every later
   review is measured against it.
2. **The user generates the pack** in Grok or Gemini and saves it to
   `../Project_Dawn_Source/concept_art/<race>/<male|female>/` (mobs and bosses under their
   own name).
3. **Claude reviews the pack** by viewing each image: the views agree with each other
   (same character, outfit and scale front, side, back and three-quarter, since a
   mismatch is what makes Meshy invent), the body matches its race file (`docs/concepts/races/<race>.md`), its height in
   `creature_heights.md` and the style bible,
   A-pose with arms clear, flat even lighting, plain background, no text. Findings go in
   a short note per pack (`review.md` beside the images).
4. **The user approves the pack** or re-rolls it. Back to step 3 after a re-roll.
5. **Meshy.** Claude sends the approved pack to multi-image-to-3D: one paid call, shown to
   the user for approval at the spend gate's prompt. Claude then checks the result two
   ways: by eye, from Meshy's preview image and renders from several angles; and by
   measurement, a script reading the model's height and proportions against
   `creature_heights.md`, since numbers judge scale better than a picture does. The user
   approves the 3D result, or it is regenerated (another paid call, approved again).
6. **Into the game.** Export into `assets/models/characters/<race>/`, add the
   `race_model.gd` entry, and take an in-game screenshot beside an existing model for
   scale. Claude checks the screenshot; the user signs off.

**The Art Board** (`tools/art_board/`, built 2026-10-14) shows this loop: a card per
subject with its step, pack images, Claude's review as pass/fail chips, Meshy's previews,
and the user's buttons (Approve pack, Re-roll, Approve 3D, Regenerate, Sign off). Each
subject's state lives in `review.json` beside its images; Claude writes the `review`
block at step 3 and the `model` block (the download folder) at step 5, the buttons write
the decisions, and sign-off ticks the subject's row in `art_assets_checklist.md`, which
stays the only list. A re-roll moves the old images into `_old/`, never deletes them.
Also on the board (added 2026-10-14): the **style bible** banner (step 1), read from
`concept_art/_style_bible/bible.json` (`status` draft or approved, `summary`,
`prompt_template`) plus the reference images in that folder; the **prompt** each pack
was made with (saved from the card, with a copy button); each card's **history** with
the user's notes; **credits per subject** and spent in total, from the Meshy client's
task log (the client records the subject from the pack's folder, and what each task
really cost); **measured height against the target** from
`docs/reference/creature_heights.md`; and the **lineup**, every pack's front view
scaled to height side by side, the check for keeping sixteen races in one style. Claude
writes `review` (`at`, `summary`, `checks`) at step 3 and `model` (`dir`, `task_id`,
`measured_height_m`) at step 5. `python tools/art_board/art_board.py --demo` shows all of
it on sample subjects in a throwaway folder.
Its look is a night sky at dawn (black, amber and rose glow, gold hairlines); the user's
plan (2026-10-14) is to decorate it with the project's own art as that art is made, for
example the logo in place of the CSS sun and approved portraits on the cards.

**State of the user's Blender models (reviewed 2026-10-14 with `blender_review.py`, read-only;
re-exported by the user 2026-10-15).** Bodies exist for four races, all low-poly A-pose
blockouts with no materials: Human (1.79 m, 1,442 triangles), Halfling (0.96 m, 1,542), Ogre
(2.54 m, 1,868) and Gnome (0.98 m, 1,666; a rigged `gnome.blend` and a `JoinedGnome.blend`).
The other twelve `.blend` files hold only their `*_Framework` height bar. On 2026-10-15 all
four GLBs were re-exported as one whole mesh each (mirror applied), facing Blender's Front
view, which `race_model.gd` turns to the game's forward with one constant
(`MODEL_FACING_YAW`). Only the Gnome is mounted in the game. Renders and `summary.json` are
in `Project_Dawn_Source/reference/blender_review/`; the four front views are the style
bible's proportion references.

**What Claude can and cannot judge.** Claude can view still images (PNG, JPG), so it can
review 2D packs and model renders and flag anything that departs from the written
direction. It cannot view a 3D file directly or turn a model around, which is why step 5
works from renders and measurements. Whether a result feels like Project Dawn is the
user's call at every step.

## Stage 2: 3D through Meshy (after the style is approved)

Per approved pack: **multi-image-to-3D** (`POST /openapi/v1/multi-image-to-3d`, 1 to 4
images; with model `meshy-7.1` or `latest` the first image is the front view and the
order of the rest does not matter; `pose_mode: "a-pose"`). Feeding every view at once
leaves Meshy less to invent than a single image would. Then remesh to a game triangle budget, then texture,
then rig, then export GLB into `assets/models/characters/<race>/`, then add one entry to
`race_model.gd`'s `MODELS` table (which already handles feet offset, yaw and hiding the
scaffold nodes).

### How Claude would drive Meshy

- **Our own client** (built 2026-10-14, replacing Meshy's npm server the same day):
  `.mcp.json` runs `python .claude/hooks/meshy_client.py`, described in "Our own Meshy
  client" above. The key comes from the private key folder (see CLAUDE.md, "Secrets and
  paid services"). Seven tools: `meshy_check_balance`, `meshy_get_task_status`,
  `meshy_list_tasks`, `meshy_download_model` (free) and `meshy_multi_image_to_3d`,
  `meshy_remesh`, `meshy_rig` (paid). It does not wait on tasks itself; check status when
  the review loop needs it. Results land in
  `../Project_Dawn_Source/meshy_downloads/<folder>/<task_id>/` with front, right, back and
  left preview images.
- **The guard around it** (`meshy_spend_gate.py`, every tool call): the private key folder
  is never named; the key and the client are reached only through the Meshy tools, never
  from a shell command or a new script; Meshy's API address may appear only in
  `meshy_client.py` (the user's exception); paid calls need the live balance, the
  worst-case price and the user's approval; and the price tripwire is the user's alone.
- **Meshy's REST API**, which the client calls, at `https://api.meshy.ai/openapi/v1`, bearer auth
  (`POST /image-to-3d`, `GET /image-to-3d/:id`, `/rigging`, `/animation`). Tasks report
  progress, then `SUCCEEDED` or `FAILED`, and return signed URLs for GLB, FBX, OBJ,
  USDZ and STL.

### Our own Meshy client (decided 2026-10-14)

The user chose to replace Meshy's MCP server with our own: one Python file using only the
standard library, `.claude/hooks/meshy_client.py`, registered in `.mcp.json` under the same
server name (`meshy`) and the same tool names, so the spend gate keeps working unchanged.
Only the tools the pipeline uses: free (check balance, task status, list tasks, download)
and paid (multi-image-to-3D, remesh, rig; animate later). Images go to Meshy as base64
data URIs read from disk (up to 4 images, 20 MB each, PNG / JPG / WebP, per Meshy's
multi-image-to-3D docs), so nothing has to be hosted. Built in: its own balance check
before any paid call (a second barrier behind the hook), no automatic retry of a paid
request, downloads only into one folder under `../Project_Dawn_Source/`, and the key never
appears in anything it returns. Meshy's task result carries front, right, back and left
preview images, which is what the review loop's step 5 looks at.

### When Meshy changes something (the standing rules, not guesswork)

1. **Before every batch:** read Meshy's API docs and pricing page for changes (free).
   Never start a batch on remembered behaviour.
2. **The model is pinned by name** (`meshy-7.1` today), never `latest`. A model change
   alters the look, so it happens only by the user's decision, between batches, never
   in the middle of one.
3. **New features are ignored** until the user chooses to adopt one.
4. **A breaking change fails loudly.** A call that errors is never retried
   automatically and never "fixed" by guessing: read the error, read Meshy's current
   docs, make the smallest fix in `meshy_client.py`, show the user the change, then run.
   After a timeout or server error on a paid request, list the tasks first: the task may
   exist and be charged already.
5. **Price changes have a tripwire.** Every finished task reports `consumed_credits`; if
   that exceeds the price the gate assumed, the client refuses all further paid calls
   until the user has looked and `COST_CEILING` in `meshy_spend_gate.py` is updated with
   the user's say-so. Credits are prepaid and Meshy refuses a call the balance cannot
   cover, so a stale price list can surprise but cannot overdraw.
6. **Meshy's own server program updates no longer touch us**: none of its code runs here.

### Spending rule (absolute)

**Claude may never spend more Meshy credits than the account holds, and every spend is
approved by the user (user, 2026-10-12).** This is enforced by a hook, not by Claude's
good behaviour: `.claude/hooks/meshy_spend_gate.py` runs before every Meshy tool call.

- Free tools (balance, task status, listings, downloads, cancel) pass.
- Any tool not on its cost list is refused.
- A spend is refused when its worst-case price (the highest Meshy lists for that
  operation) is more than the live balance, read from Meshy at that moment, minus
  what the gate approved in the last 15 minutes.
- A spend that passes still waits for the user to approve it, with the price and
  balance shown.
- No API key, a network error or a crash in the gate all refuse.

Account side (the user's to check): make sure no auto-recharge or automatic credit-pack
purchase is turned on in Meshy's subscription settings. Meshy documents its credits as
prepaid and answers a shortfall with HTTP 402, but its docs do not say whether
automatic top-ups exist, so that switch is the one thing the hook cannot see.

### Plan and cost (as researched 2026-09-24; recheck before buying)

- The API needs Pro or above: about $20/month for 1,000 credits, private, fully
  commercial assets. The free tier has no API, and its outputs are CC BY 4.0
  (attribution required).
- Approximate credits per task: mesh 20, image-to-3D 20 to 30, texturing 10 to 15,
  remesh or rig 5, animation 3, format convert 1. A rigged, textured, animated character
  costs about 40 to 50, so Pro covers roughly 20 to 25 characters a month.
- **Generated files are deleted after 3 days** on non-Enterprise plans. Download every
  result into `../Project_Dawn_Source/models/` the same day.

## Caveats

- **Rigs:** each Meshy character comes with its own rig. The art checklist wants one
  shared master humanoid rig plus a shared animation library (§5, §7). Retargeting onto
  that rig, in Blender or Godot, stays our job.
- **Topology:** generated meshes need remeshing to meet our low-poly budget (see the top of
  this page). Meshy's docs (read 2026-10-15) say `target_polycount` (100 to 300,000, default
  30,000) and `topology` apply only when `should_remesh` is on, that the result "may deviate
  from the target", and that they recommend remeshing off "for the highest-quality model".
  They do not say whether a separate remesh task keeps the texture. A newer
  `decimation_mode` option exists; by rule 3 it stays unused until the user adopts it.
- **Textures are usually baked,** which makes paperdoll armor swaps and tier recolors
  awkward. Armor likely needs a separate approach: separate meshes or a material scheme
  decided before the first armor pack.

## What is already decided (read these first)

The aesthetic was worked out before this pipeline existed. The style bible builds on
these documents rather than replacing them:

- **[portraits/prompts.md](../concepts/lore/portraits/prompts.md):** the Gemini prompt
  pack and its **style anchor** (oil on canvas, 1987 paperback-cover). **The oil-painting
  medium is NOT used for the model packs (user, 2026-10-12).** What carries over is
  its restraint: earthy palettes built around a single saturated accent, no anime, no
  airbrushed CG sheen. It also holds workflow lessons that carry over (re-roll rather than
  reword; Edit mode for small changes; race disambiguation such as "anthropomorphic
  reptilian humanoid, NOT a dragon" for Kel`varath).
- **[characters.md](../concepts/lore/characters.md):** the same direction written out as
  art direction for each race and class combination.
- **Each race's own file** (`docs/concepts/races/<race>.md`, "Physical Description"):
  weight, build and distinctive features per sex. This is the brief for every male and
  female pack (Kel`varath dimorphism is reversed: the females are larger).
- **[creature_heights.md](../reference/creature_heights.md):** the one home for race
  heights, matching the user's Blender height chart, which shows each race at the middle
  of its range (decided 2026-10-14; the old `races.md`, whose feet figures had drifted,
  is retired). The pack's height bar and the board's lineup use it.
- **[map_commission_briefs.md](map_commission_briefs.md):** the maps' style line (hand-inked
  atlas). It covers maps only, not characters.

## The look of the model packs

**Direction (user, 2026-10-12): EverQuest-like, without the oil painting.**
Semi-realistic anatomy, a muted earthy palette, and strong size differences between
races. The stylization lives mostly in the scale between races (towering Ogres and
Minotaurs, squat Dwarves and Gnomes) rather than in exaggerated hands and heads. The
EverQuest feel comes from those shapes, the palette and the costume design, not from
the painting medium.

A model pack is a construction document, not an illustration. Meshy builds the
texture from these images, so whatever is in them ends up on the model: brushstrokes
become muddy texture, and painted-in light and shadow become baked shading that
fights Godot's own lighting and the day/night cycle. The pack style therefore has to
be clean and evenly lit.

**Rendering options (pick one with the side-by-side test):**

- **A. Clean concept-art model sheet (recommended).** Digital concept art with soft,
  even shading, matte materials and a crisp silhouette: the standard look of an
  industry character turnaround. Enough rendering to judge the look, little for Meshy
  to misread.
- **B. Line art with flat colour.** Ink outlines and flat colour fills, almost no
  shading. The least ambiguous geometry, but it shows less of the final feel.
- **C. Clay-style 3D render.** Looks like a sculpt under studio light. Closest to
  what Meshy outputs, but drifts toward the CG sheen the old anchor rules out.

Base style line for option A:

> *Fantasy character concept art turnaround model sheet, clean digital painting with
> soft even shading, semi-realistic anatomy, muted earthy palette, matte materials,
> crisp silhouette, plain light-grey background, flat even studio lighting, no cast
> shadows, no brushstroke texture, no text.*

The test: generate the same male Human and male Gnome front view in A, B and C with
the same subject wording, put them side by side, and pick. The winner becomes the style
bible's rendering rule and reference image.

## Decisions (2026-10-12)

- 2D images come from Grok and Gemini; reference only, not commercial.
- Meshy builds each model from several views at once (multi-image-to-3D).
- Stylized proportions, EverQuest-like: semi-realistic anatomy with strong size
  differences between races and a muted earthy palette.
- No oil painting in the model packs. The rendering style (A, B or C above) is chosen
  with the side-by-side test.
- Separate male and female bodies for every race (this settles art checklist §5's open
  choice).
