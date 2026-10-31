# Handoff: race model sheets, the Art Board and the Blender references (written 2026-10-29)

The art thread of 2026-10-22 to 10-26 (2D model sheets through our Meshy client, the Art
Board, the `.blend` reference images) stopped on the user's word of 2026-10-26: "im going to
make the current approved image work. we can stop working on the halfling." This document is
what a fresh session needs to pick the thread up without re-learning it. Every fact below was
read from the files on 2026-10-29, not from memory; where something was only ever in chat it
is quoted here so it survives.

## 0. The rules this work runs under

From `CLAUDE.md` and memory; they decide more than any technique.

1. **Meshy money.** Every paid call waits for the user's go (a Pro sheet is 9 credits). The
   spend gate hook enforces it; never work around it, never name the key folder, never call
   Meshy outside the Meshy tools. Live balance on 2026-10-29: **2,613 credits** (100 monthly,
   resetting 2026-10-31, the rest permanent).
2. **Say before doing.** State the plan, wait for the go. "check it" means download and
   show the result on the board; "go" means run what was just proposed.
3. **Edits are out.** The user, after two failed arm edits: "Any time we try to edit an image
   it comes back dog shit." Do not propose `input_task_id` edits again; re-roll, or hand the
   user a prompt for another tool.
4. **Nothing nude.** Every sheet wears plain grey fitted shorts (and a top on the female).
5. **No em-dashes, no arrows**, in prompts, docs and replies. Terse replies.
6. **Verify, never fabricate.** Read the sheet, the ledger or the file before saying what is
   in it. Check the in-use sheet's date before using it as a reference roll (see section 2).
7. **Git hygiene.** Stage only your own files; never commit `docs/deployment/` or any
   `tools/*.gd.uid`; nothing above `F:\Projects\` is touched.

## 1. Where every race's sheet stands

"In use" means the file `F:\Projects\ref_art\ModelPack_<Race>.png`, the one the Art Board's
**Use this** writes (the old one goes to `ref_art\_replaced\` with a timestamp). "Candidate"
means a sheet downloaded to
`F:\Projects\Project_Dawn_Source\meshy_downloads\<subject>\<task>\image_1.png` that has no
decision in `Project_Dawn_Source\art_board\sheets.json` (neither used nor discarded), so it
is still showing on the board waiting for the user. Task ids are cut to 13 characters; the
folder name is the full id.

| Race | In use | Candidates with no decision | Notes |
|---|---|---|---|
| Human | May sheet (`Gemini_..._rppsrz`), 05-19 | none | |
| Gnome | May sheet (`Gemini_..._fg4xb8`), 05-19 | none | the wiry end of a future build slider |
| Dwarf | May sheet, 05-26 | `01a169a9-2e82` (10-23) | user on 10-23: "dwarves looking good", but the roll was never marked Use this; ask |
| Halfling | `01a1793d-8ac4`, used 10-26 11:29 | `01a169a9-379a`, `01a169c8-4de2` (10-23, the "between the two builds" rolls) | the May sheet is in `_replaced\ModelPack_Halfling_20261026_112901.png`; see section 2 |
| Elf | `01a16597-cad5`, used 10-22 | none | |
| Dark Elf | `01a16645-c69c`, used 10-22 | none | |
| Wood Elf | `01a16645-e329`, used 10-23 | none | |
| Half-Elf | `01a15c8f-30df`, used 10-23 | none | |
| Half-Ogre | `01a15ba0-7578`, used 10-20 | none | |
| Kobold | `01a169c8-69e7`, used 10-23 11:35 | none | the "slightly smaller head, slightly taller" roll; prompt and history in `concept_art\kobold\prompt.md`; a plumper re-roll was floated, not asked for |
| Newtfolk | `01a169a9-1eb0`, used 10-23 | none | user: "salamanders looking good"; a brainstorm race, not one of the 16 (section 5) |
| Troll | `01a16a8b-0dd5`, used 10-23 16:09 (the bog beast) | `01a16a8a-786e` (10-23) | the May sheet is in `_replaced\ModelPack_Troll_20261023_160930.png` |
| Ogre | May sheet (the bearded male "Gorg"), 05-19 | `01a16aaa-0b0b` (10-23 15:28, first redesign) and `01a16ab5-ebb4`, `-f1b3`, `-f7e9` (10-23 15:41, the cleaned prompt) | the female redesign; the user liked "the more hunched look. looks scary"; a re-roll carrying the hunch through the side view was discussed and never ordered |
| Fae | none in ref_art | `01a16597-b8c1` | |
| Felhari | none in ref_art | `01a169a7-26f3` | |
| Kel`varath | none in ref_art | `01a15c8f-8250`, `01a16999-6bf6`, `01a169a7-2cfe` | two prompt variants exist: `concept_art\kel_varath_muzzle` and `kel_varath_short` |
| Minotaur | none in ref_art | `01a15c8f-64b1`, `01a16999-4973` | |

Non-race sheets with no decision: `blacksmithing\01a15b7e-362e` and the two
`mnm_ledger_art` sketches. Everything else downloaded is marked discarded (the files move to
`Project_Dawn_Source\discarded\<race>\`).

Meshy's own copies of a result expire after three days, so for every 10-23 sheet the local
download is the only copy. The downloads are the record; do not delete a folder the board
still shows.

## 2. The Halfling arc, and what it taught

1. 10-23: two "between the fit May sheet and the plump roll" candidates (`379a`, `4de2`).
2. 10-26 11:24: `01a1793d-8ac4`, an image-to-image roll referencing `ModelPack_Halfling.png`,
   approved by the user on the board ("Cool, i approved the previous one.") and copied over
   the May sheet at 11:29.
3. 10-26 11:34: `01a17946-c909`, a "ROUND" re-roll that came back nearly identical to the
   sheet just approved, because its reference was that sheet. **Lesson, committed to:** read
   the in-use sheet's date before a reference roll; a reference to the sheet you just
   replaced reproduces it.
4. The user then found the arm lengths inconsistent between the front and side views and
   asked for the A-pose in every view. Measured: the arms are consistent at about 42% of the
   height in all three views; what differs is the side view's pose (the arm hangs instead of
   angling toward the camera). Pro cannot draw a foreshortened A-pose arm in a strict
   profile; it hung the arm on every attempt of every race (the kobold prompt file records
   the same).
5. 12:55 and 13:17: two edits of `01a1793d` through `input_task_id` (`01a17991-326a`,
   `01a179a5-818d`), both bad (one broke the sheet, one changed nothing). 18 credits. The
   first edit prompt also described the arm wrongly (reaching forward). Edits are out
   (rule 3).
6. 13:24: two text-to-image re-rolls with no reference (`01a179ac-1115`, `-1719`): "bleh".
7. The user took the prompt to another tool and iterated it there: that tool first hung the
   arms and drew round ears, then read "raised 45 degrees" as arms UP from the torso. The
   wording was fixed to "angled downward and outward", the capital letter A, hands below the
   shoulders at hip height. The user also shared a Gemini critique; taken from it: "low
   A-pose", positive phrasing (say what to draw, not what to avoid), splitting the sexes.
   Rejected from it: it misnamed the model (Nano Banana Pro is Google's image model, not a
   Banana.dev SDXL) and it injected a 1987-paperback / Larry Elmore style we never asked for.
   The user then asked for one combined male-and-female prompt; it is in the appendix.
8. User facts stated along the way: the height scale on a sheet "means nothing in reality",
   the model's height is set in Blender; the arm thread ended with "We will need to start
   over with the halfling renders. our sample is spoiled." and then, on 10-26 late: "im going
   to make the current approved image work. we can stop working on the halfling."

Six Halfling Pro calls on 10-26, 54 credits, one approved sheet. Nothing is owed on this
thread unless the user reopens it; if they do, the appendix prompt is the starting point and
it is for text-to-image with NO reference image.

## 3. The Blender reference images

The character `.blend` files (Blender 5, zstd-compressed) carry their reference image by
relative path `//..\..\..\..\ref_art\<name>`, which resolves to `F:\Projects\ref_art\<name>`.
The Art Board renames sheets to `ModelPack_<Race>.png`, which left four files pointing at
names that no longer existed (pink planes, reported 10-26). Fixed by COPYING each sheet back
under its old name; nothing was moved, nothing in any `.blend` changed:

| `.blend` | Name it looks for | Copied from |
|---|---|---|
| `models/characters/ogre/ogre.blend` | `Gemini_Generated_Image_b7kxnbb7kxnbb7kx (1).png` | `Gemini_Generated_Image_b7kxnbb7kxnbb7kx.png` (the beardless "Grog"; if the plane shows the wrong ogre, copy `ModelPack_Ogre.png` over it instead) |
| `models/characters/human/human.blend` | `Gemini_Generated_Image_rppsrzrppsrzrpps.png` | `ModelPack_Human.png` |
| `models/characters/gnome/gnome.blend` and `gnome_backup_2026_10_16.blend` | `Gemini_Generated_Image_fg4xb8fg4xb8fg4x.png` | `ModelPack_Gnome.png` |
| `models/characters/halfling/halfling.blend` | `HalflingModelPack_01.png` | first the May sheet, then OVERWRITTEN 10-26 11:29 with the approved `ModelPack_Halfling.png` at the user's request (both MD5 `f89d6507f38c4f663503c0d2e624ee60`, verified 10-29) |

The other eleven character `.blend` files (dated 2026-05-12/13) reference no image. The user
confirmed the restore: "This is excellent. thank you and good work!"

How the paths were read: Blender 4.0.1 (`C:\Program Files (x86)\blender.exe`) cannot open
these files ("not a blend file"); Node 24's `zlib.zstdDecompressSync` decompresses only the
first zstd frame of a multi-frame `.blend`, so a small script walked the frame headers and
decompressed each frame, then grepped the image paths. The script lived in `/tmp` and was
not kept; the approach is a few lines to rewrite.

## 4. Tooling facts the next session needs

- **The Art Board**: `python tools/art_board/art_board.py` from `F:\Projects\Project_Dawn`
  (or `tools\art_board\open_art_board.bat`); it serves `http://127.0.0.1:8790/` and is NOT
  running now. `/api/state` returns the races, candidates and states. A tab left open across
  a restart holds a stale token and its buttons fail: reload the page. Step approvals would
  go to `Project_Dawn_Source\art_board\progress.json`, which does not exist yet (no race has
  had a workflow step approved). The board never calls Meshy.
- **Meshy tools**: `meshy_text_to_image` and `meshy_image_to_image` (reference paths or an
  `input_task_id`), Nano Banana Pro, 16:9, 9 credits a sheet; `meshy_download_model`
  REQUIRES `folder` (the subject), and saves to
  `Project_Dawn_Source\meshy_downloads\<folder>\<task>\image_1.png`. `meshy_check_balance`
  is free. Results expire after three days.
- **The ledger**: `Project_Dawn\.claude\hooks\meshy_task_ledger.json`, a dict keyed by task
  id with `subject`, `type`, `ai_model`, `prompt`, `expected`, `consumed`, `created`. 70
  entries, 638 credits consumed in all. It is the only home of the prompts for the Dwarf,
  Halfling, Ogre and Troll sheets: `concept_art\<subject>\prompt.md` exists for fifteen
  subjects (elf, dark_elf, wood_elf, half_elf, fae, felhari, minotaur, the two kel_varath
  variants, kobold, gnome, human, half_ogre, blacksmithing, plus `_style_bible` and
  `_overnight_run_list.md`) and not for those four. If a prompt matters, copy it from the
  ledger into a `prompt.md` in the kobold file's shape before it is needed.
- **Pro's habits, learned the expensive way**: it copies a reference sheet heavily (section
  2, item 3); it cannot foreshorten a profile arm; numbered lists in a prompt get PRINTED on
  the page (write layout as prose); labelled sections (PAGE / LAYOUT / CHARACTER / CLOTHING
  AND POSE / STYLE) cut the layout slop; roll-to-roll variation outweighs any reference-set
  effect (the kobold feet: one identical prompt gave correct feet once and human feet next).

## 5. Open items, none started

1. **Board decisions waiting on the user** (section 1): the Dwarf roll, the second Troll,
   the four female Ogres, and the Fae, Felhari, Kel`varath and Minotaur candidates. Each is
   a click on the board, or a discard.
2. **Female Ogre**: the user wanted her less pretty, cleaner prompts, and liked the hunch;
   a re-roll that keeps the hunch through the side view was offered and not ordered. The
   last prompt is ledger `01a16ab5-f7e9` (2.50 m, about 570 lb, hunched matriarch, tusks
   outward, grey-green hide, the Removed Armor Pieces panel).
3. **Kobold**: a plumper re-roll was mentioned, not asked for. The lore kobold is
   dog-muzzled (`docs/concepts/races/kobold.md`); scaled kobolds were only a test.
4. **Uncommitted in the client repo**: `docs/design/race_expansion_brainstorm.md` carries a
   six-line "newt or salamander-folk" idea (user 2026-10-22: "sounds rad, keep that as an
   idea"; not decided: playable or NPC, or whether it takes the Kobold's niche). Commit it on
   its own or drop it; it has sat unstaged since 10-22. `scenes/login.tscn` is also modified
   (Godot added `uid=` attributes to the scene and its script reference; not from the art
   thread): read its diff before staging anything.
5. **The Halfling**: closed by the user. The appendix prompt exists only in case it reopens.

## Appendix: the combined Halfling prompt (the last thing written, 2026-10-26)

For text-to-image, 16:9, no reference image. Prose layout on purpose (numbered lists print).

```
Character model sheet for a fantasy video game, 16:9, a clean orthographic turnaround reference for a 3D modeller.

Page: a dark title band reading "Halfling Male & Female 2D Model Pack" in serif small capitals. A plain grey-blue page with faint horizontal rule lines and a simple height scale down the left edge. Both rows are drawn at the same scale. No other text, no numbers, no logo, no watermark, no signature.

Top row, labelled "Male Halfling": from left to right, a full-body front view, a full-body side view in strict left profile, and a full-body back view of the same male halfling, all standing on the same ground line at the same size; then a small column holding exactly four close-ups: the head from the front, the head in profile, one open hand and one bare foot; then a panel labelled "Weapon Reference" holding a plain short sword and a sling. Each item appears exactly once, with no frames or boxes around the figures.

Bottom row, labelled "Female Halfling": the same layout for the female halfling: front view, side view in strict left profile, back view, then a small column holding exactly four close-ups (head from the front, head in profile, one open hand, one bare foot), then a panel labelled "Removed Armor Pieces" holding a plain waistcoat, two bracers and a belt pouch. Each item appears exactly once, with no extra small figures.

Pose: a low A-pose, identical in every view for both figures, with the arms angled downward and outward. Each arm hangs from the shoulder and swings out 45 degrees from the side of the body, halfway between hanging straight down and sticking straight out, so the body and arms form the shape of a capital letter A. The hands sit below the shoulders, level with the hips, with a clear gap between each hand and the hip; elbows straight, palms facing the floor. Each arm is the same length in every view. Front and back views: both arms angle down and out from the sides of the body, hands at hip height. Side views: the near arm angles out toward the camera, so it is foreshortened: it comes down from the shoulder, looks shorter than in the front view, and the hand sits beside the hip at the same hip height. The arms never point up, never reach forward or backward, and never hang down to the thigh. Legs straight, feet slightly apart.

Character: adult halflings, small, sturdy and comfortable, with fully adult proportions. A stocky build with a light, soft belly over a solid frame, rounded shoulders, a thick waist with little taper, and solid arms and legs. Soft, smooth, non-muscular torsos, shoulders and arms, plain and unsculpted. Round faces with full cheeks, smooth bald heads, clean-shaven faces, and long pointed ears that sweep up and back, clearly not human ears, in every view and in every head close-up. Short sturdy legs, large broad bare feet, a head about one sixth of the height. The male is about 65 lb. The female is about 53 lb, slightly shorter, and just as stocky and solid as the male. Calm neutral faces, mouths closed, eyes ahead. Unglamorous and endearing, standing plainly.

Clothing: plain grey fitted shorts on both; the female also wears a plain grey fitted top, in every view. Barefoot.

Style: clean digital painting, soft even shading, matte skin, thin dark outlines, light from the upper front, a soft contact shadow under each figure, muted earthy palette.
```
