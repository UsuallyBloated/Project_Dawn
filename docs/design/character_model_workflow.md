# Character model workflow (hand-built)

How the playable races' bodies are made, and what the Art Board (`tools/art_board/`) reads to
track them. Adopted 2026-10-19, when Meshy stepped back from being the plan (see the status note
at the top of `meshy_asset_pipeline.md`): the user's own Blender bodies are the base.

## The steps

One card per playable race (the table in `docs/reference/creature_heights.md`), with a male and
a female line. Each line walks seven steps. The board detects each from the files; the user then
approves it on the page. A step can be approved only when it is detected and every step before
it is approved.

| Step | Detected when | Where |
|---|---|---|
| Model pack | the race's 2D model pack sheet exists (one sheet holds both sexes) | `F:\Projects\ref_art\ModelPack_<Race>.png` (`DarkElf`, `HalfOgre`, `Kelvarath` style names) |
| Body built | the race's `.blend` holds meshes in a collection named for the sex: "Male" or "Female" somewhere in the name (`GnomeMale`, `Halfling_male`); scaffolds and `Exported*` collections are left out | `Project_Dawn_Source/models/characters/<race>/<race>.blend` |
| Exported | the GLB exists; the card shows its height against the race's range, its triangles against the 2,000 bare-body budget, and whether it faces Blender's Front view | `<race>.glb` or `<race>_male.glb`, and `<race>_female.glb`, beside the `.blend` |
| UV unwrap | the export's UVs are a real unwrap: inside the square, and pieces piling no more than about two deep on average (stacked mirror halves are fine) | the export |
| Texture | the export carries a base-colour texture | the export |
| Rig | the export carries a skeleton | the export |
| In game | the GLB `scripts/race_model.gd` mounts is byte-identical to this export | `assets/models/characters/<race>/` |

Approving "In game" ticks the race and sex's row in `art_assets_checklist.md` §5; undoing it
unticks the row.

## Approvals and changes

Approvals live in `Project_Dawn_Source/art_board/progress.json` (not in git), each with a
fingerprint of the file it approved. When that file changes afterwards (a fresh export, a new
pack), the step turns amber, "changed since you approved", until it is approved again. Only the
latest approval on a line can be undone; the shared pack only once neither line has a later
approval.

## Notes

- **One export per sex.** `race_model.gd` mounts one model per race today, so only the male line
  can reach "In game" until it learns to choose a model by sex.
- **Facing.** Export facing Blender's Front view; `race_model.gd` turns every model to the game's
  forward with `MODEL_FACING_YAW`. The board flags an export whose feet point the other way.
- **Looking inside a `.blend` and rendering the lineup need Blender.** The board's background
  worker runs it read-only (`--factory-startup --disable-autoexec`, never saving), opens a
  `.blend` again only after it has been saved, and caches scans and renders in
  `Project_Dawn_Source/art_board/cache/`. `PD_BLENDER` overrides Blender's path.
- **Correction, 2026-10-19.** The 2026-10-16 note that the blockouts' UVs were "824 islands"
  came from Blender splitting a flat-shaded GLB on import. Read from the file, each blockout has
  17 pieces (one per body part), each spread over the whole square and stacked about 11 deep.
  The conclusion (no real unwrap yet) stands.
