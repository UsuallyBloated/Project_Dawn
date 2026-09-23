# Machine Day Checklist — 2026-09-22

The whole desk session in order: phase 4 deploy, fresh-world wipe, re-provision,
ship, then the playtest queue. Ops reference: `docs/deployment/server_operations.md`
("Fresh world reset" has the full command block).

---

## 1 — Deploy + fresh world (on the R720)

- [x] **Run the pre-wipe snapshot** (backup.sh line from the ops doc) → a new
      `world-<timestamp>.db` appears in `/data/projectdawn-backups/`. notes:
      `world-20260922-153451.db` landed (15:34). One cosmetic warning (find
      could not restore cwd because it ran from /home/wrightt); the copy was
      unaffected. Nightlies verified healthy all week.
- [x] **Pull + build** (`git pull && cargo build --release` as projectdawn) → pull
      ends at `a34af47`, build completes with no errors. notes: fast-forward
      22837b9 to a34af47 (confirming the bag-space/group-bars builds ship for
      the FIRST time today); release build 1m54s, only the five known
      dead-code warnings.
- [x] **Stop, cp, retire the db, start** (stop BEFORE cp; `mv world.db
      world.db.retired-2026-09-22`; `rm -f` the -wal/-shm) → service starts. notes:
      clean sequence, no Text-file-busy; stopped 15:44:52, started 15:48:38.
- [x] **journalctl tail shows the three proofs** → `dev_cmds=false`,
      `build=a34af47`, and migration lines from the fresh database. notes:
      dev_cmds=false and build="a34af47" on the boot line; sqlx migrations do
      not log via tracing, so the fresh-db proof was taken directly:
      `SELECT COUNT(*) FROM accounts` = 0 on the new world.db. The
      rate_limit=false WARN fired as designed (permanent, by decision).
- [x] **Old world retired, not gone** → `world.db.retired-2026-09-22` exists next
      to the new `world.db`. notes: retired file 184 KB (last written Sep 6,
      the last play session) beside the new 151 KB world.db born 15:48.

## 2 — Re-provision yourself

- [x] **Stale local bars cleared** → all 22 `social_hotkeys*` / `spell_bar*` files
      moved to `stale_bars_backup_2026-09-22` in app_userdata. notes: done by
      Claude before the deploy; recoverable from the backup folder.
- [x] **Register a fresh account in the launcher** → account creates, character
      creates, you land at the town spawn in the NEW world. notes: account
      tyler_mkee (id 1), character Splenda — the first citizens of the new
      world.
- [x] **Re-grant GM** (full `grant_gm` invocation from the ops doc, with the
      `PROJECTDAWN_DATABASE_URL` env — the defaults trap) → next login shows the
      GM tools working (`/give` or a dev spawn lands). notes: bin reported
      "Set GM for tyler_mkee (id 1): was false, now true"; after the relog the
      Test Panel is available on Splenda — the whole flag/token/gate chain
      proven.
- [x] **`/version` on your fresh login** → client `ae30557` (fresh export this morning superseded the c3e215a one), and no UNSTAMPED
      BUILD banner. notes: login screen screenshot shows
      `ae30557` bottom-right, no banner.

## 3 — Ship it

- [ ] **Send `builds/ProjectDawn-alpha.zip` (rebuilt 09-22 from the ae30557 export) to testers**
      → with the word: the world is new, EVERYONE re-registers, and the README's
      fresh-world callout covers the bar-file cleanup. notes:

## 4 — First lap (GM, before inviting the second seat)

- [x] **Walk the town row** → Hadrik (blacksmith shop opens, sells iron chain +
      weapons), Elara now TALKS (dialogue first, shop via "Let me see your
      wares"), Aldric / Brom / Maelis / Thalia unchanged. notes: ONE FIND —
      Hadrik was unreachable, the Forge stood 1 m from him. Fixed same
      sitting at the user's call: all 5 stations + 3 ore veins removed from
      world.tscn (dead furniture since the online guards; To-Do notes their
      return with server positions). New export `8eb56e7`, zip repacked.
      Elara works as intended, shop behind "Let me see your wares.".
- [x] **Run `phase4_content_checklist.md` §1** (the repaired starter book: rats
      behind Brom's, wolves south of the east road, level 3 gnolls east, Rotfang's
      den) → all four quests offerable AND completable. notes: 4 of 4 PASS.
      Rat/wolf/gnoll per the user's lap; Rotfang proven in the server log
      2026-09-22 23:05-23:15: accept REFUSED at level 4 (server-side level_req
      gate, previously undocumented), accepted at 5, den respawned on its
      300 s timer, named enrage fired both fights (308 hp = 3.5x, damage
      18 to 25 raw = 1.4x), turn-in REFUSED with full bags (the new
      can_accept pre-flight) then paid reward=48800 + the 5-to-6 ding after
      making room. Kill-before-accept correctly paid no credit. Also
      exercised: GM connect line, Maelis bind, swing-rate limiter dropping
      the known client double-Attacks.
- [ ] **Nothing aggros town** → stand at the bank and the plaza a minute; no camp
      reaches you. notes:

## 5 — The playtest queue (evenings, in order)

- [ ] **`phase4_content_checklist.md`** in full (six sections; §3 named mobs and
      the high rings want GM leveling). notes:
- [ ] **`bagspace_groupbars_checklist.md`** (§2 needs the second seat). notes:
- [ ] **`cursor_slice15_checklist.md` retest rows** → equip-from-hand swap no
      longer blanks the held item; drop-confirm dialog no longer re-prompts. notes:

## 6 — Same-day finds, fixed this sitting (verify on the next build/deploy)

- [x] **Startup window** → opens at 1280x720, centered, instead of a
      display-scaled 1920x1080 (login.gd sets it in code; the project's
      window override was being ignored in exports). notes: PASS 09-23, and
      the follow-up content pass landed the same sitting: the form became a
      640-wide centered panel (M&M launcher reference) and the launcher flow
      got its own scale dial (LOGIN_UI_SCALE, user-tuned 1.15 to 1.4 to 2.0
      to 1.8 to settle at 1.6, "This looks good"), deliberately separate
      from the HUD's GAME_UI_SCALE (1.0). Ship build + zip: `45356f2`.
- [x] **Chat seeds as "Chat 1"** → your stale layout was cleared surgically
      from settings.cfg (backup beside the bars backup), so next launch
      seeds one window named Chat 1; keybinds/audio settings untouched. notes:
      PASS 09-23 ("looks good").
- [x] **Shooting an idle mob provokes it** (needs the `3e98553` redeploy) →
      attack any camp mob from beyond its aggro circle; it comes for you.
      A target beyond leash range still stands (by design, no state flap). notes:
      PASS 09-23 ("appears to work as intended").
- [x] **Quest XP flow question answered, no change** → quest XP already pays
      only at NPC turn-in (log: reward=48800 at Aldric); the XP at the kill
      was ordinary kill XP, a separate system. notes: user to confirm this
      reading matches what they meant.
- [ ] **UI layout "pretty busted"** → FILED, not fixed: needs a screenshot
      pass, belongs to the deferred theming/layout pass (To-Do, UI polish). notes:

## 7 — The death find (09-23, fixed both sides, verify after redeploy + relaunch)

- [ ] **A corpse cannot loot itself** (server `59f2fa1`, needs redeploy) → die,
      then try to loot your corpse or move items during the respawn window:
      "You cannot do that while dead." for everything but chat, respawn, res
      accept, and group management. Integration test pins the exact exploit
      sequence. notes:
- [ ] **The EQ death** (client `6156d05` export) → on death: no menu, camera
      eases out and tilts down over your body (look-around still works),
      "You have died. Returning to bind point." lands in chat instantly,
      auto-respawn after 5 s, camera eases back. Dead right-clicks interact
      with nothing. notes:

---

## Result

- Server boot line (paste): `starting projectdawn-server build="a34af47" ...
  dev_cmds=false rate_limit=false` (2026-09-22T15:48:38Z)
- Client build (`/version`): `ae30557` at first login (screenshot); superseded same day by `8eb56e7` (town declutter export)
- Overall:
