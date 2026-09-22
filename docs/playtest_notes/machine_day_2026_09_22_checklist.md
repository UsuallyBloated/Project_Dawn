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
- [ ] **Register a fresh account in the launcher** → account creates, character
      creates, you land at the town spawn in the NEW world. notes:
- [ ] **Re-grant GM** (full `grant_gm` invocation from the ops doc, with the
      `PROJECTDAWN_DATABASE_URL` env — the defaults trap) → next login shows the
      GM tools working (`/give` or a dev spawn lands). notes:
- [ ] **`/version` on your fresh login** → client `ae30557` (fresh export this morning superseded the c3e215a one), and no UNSTAMPED
      BUILD banner. notes:

## 3 — Ship it

- [ ] **Send `builds/ProjectDawn-alpha.zip` (rebuilt 09-22 from the ae30557 export) to testers**
      → with the word: the world is new, EVERYONE re-registers, and the README's
      fresh-world callout covers the bar-file cleanup. notes:

## 4 — First lap (GM, before inviting the second seat)

- [ ] **Walk the town row** → Hadrik (blacksmith shop opens, sells iron chain +
      weapons), Elara now TALKS (dialogue first, shop via "Let me see your
      wares"), Aldric / Brom / Maelis / Thalia unchanged. notes:
- [ ] **Run `phase4_content_checklist.md` §1** (the repaired starter book: rats
      behind Brom's, wolves south of the east road, level 3 gnolls east, Rotfang's
      den) → all four quests offerable AND completable. notes:
- [ ] **Nothing aggros town** → stand at the bank and the plaza a minute; no camp
      reaches you. notes:

## 5 — The playtest queue (evenings, in order)

- [ ] **`phase4_content_checklist.md`** in full (six sections; §3 named mobs and
      the high rings want GM leveling). notes:
- [ ] **`bagspace_groupbars_checklist.md`** (§2 needs the second seat). notes:
- [ ] **`cursor_slice15_checklist.md` retest rows** → equip-from-hand swap no
      longer blanks the held item; drop-confirm dialog no longer re-prompts. notes:

---

## Result

- Server boot line (paste): `starting projectdawn-server build="a34af47" ...
  dev_cmds=false rate_limit=false` (2026-09-22T15:48:38Z)
- Client build (`/version`):
- Overall:
