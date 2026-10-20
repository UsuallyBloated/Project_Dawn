# Handoff, 2026-10-15: the next builds, at the standard the last two days set

**Written for:** the Claude session that picks this project up next, on a smaller model than
the one that wrote it. Everything here was verified against the live source on 2026-10-15;
anchors are file paths and line numbers from that day, so re-check them with a grep before
editing (they drift). The user's own rules in `CLAUDE.md` outrank anything here.

Read in this order before touching code: `CLAUDE.md` (all of it, every session), this file,
`docs/session_notes/session_2026_10_14.md` and `session_2026_10_15.md` (the two days this
standard comes from), then `docs/playtest_notes/CHECKLIST_RUN_ORDER.md`.

---

## 1. The standard, as rules you can check yourself against

These are not style preferences. Each one was learned by getting it wrong once.

1. **Verify before you claim.** Read the real source before saying how anything behaves,
   before editing, and before reporting done. Never trust a subagent's recon or your own
   memory of a file. On 2026-10-14 a "ten to sixty stat scale" was written into three docs
   from memory; it was wrong, the user caught it, and a feature had to be rebuilt. If a claim
   is about the game's history (EQ, SWG, P99), fetch the source and quote it; the P99 wiki
   refuses WebFetch (certificate), so `curl -sk` it into the scratchpad and extract the text.
2. **Research first, build second, and say what you did not find.** When the research does
   not support the premise, report that and stop; do not build on a hunch. When it does,
   quote the rule in the commit and the checklist.
3. **The exploit lens on every change.** Before committing, write one paragraph answering:
   what can a modified client send here, and what does it get? The last two days' examples:
   free summoned food must not be sellable (vendor_price 0, the SellItem rule refuses it);
   seated-combat keys on the server's own flag, so lying about sitting only costs the liar;
   a relayed jump flag never reaches position. Put the paragraph in the To-Do entry.
4. **Edit by script, dry-run first.** Write a Python edit script to the scratchpad with the
   `Write` tool (not a Bash heredoc; see traps), with exact-text anchors and `assert
   s.count(old) == 1`. Run it on a COPY of the file first, `diff -u` the copy against the
   original, and read the whole diff before applying it to the real tree. The script must
   preserve CRLF (server files are CRLF, most client files LF): normalise to LF, edit, restore.
5. **Tests that fail on the old code.** Every behaviour change gets a test that fails without
   it, and you prove that by reverting the one line and running the test (then restoring). A
   test suite is the only evidence a refactor gets; a feature also gets a checklist.
6. **Both full suites green before a commit.** Server: `cargo test -p projectdawn-server`
   (about 277 unit, 99 integration as of 10-15; 60 to 90 s). Client: the two lockstep checks
   after any spell or item data change (`tools/check_spell_lockstep.gd`,
   `tools/check_item_lockstep.gd`, both exit 1 on drift) and a headless probe for any client
   logic (see traps for how to write one).
7. **Built is not done.** A To-Do item is ticked `[x]` only on a filled checklist in
   `docs/playtest_notes/`. You write the checklist (from `TEMPLATE_checklist.md`), the user
   fills it. Exceptions the user has accepted: a refactor with no behaviour change, and a tool
   or test with no in-game surface, tick on the suite with the reasoning written out.
8. **The records pass, every build, same day** (section 6 has the exact steps): the To-Do
   entry in `CLAUDE.md` (BUILT, shas, what exists, what is flagged, the exploit paragraph), the
   session note and its index row, planner rows, regenerate and republish the planner, commit,
   push both repos by branch name.
9. **Write for the reader.** Session notes and To-Do entries say what exists, why, and what
   was deliberately not built. Flag every number you chose without a user decision as a knob
   with its constant name. No em-dashes, no arrows (the checklist action/result arrow is the
   one allowed exception).
10. **Never touch** anything above `F:\Projects\`, the private key folder (see `CLAUDE.md`
    "Secrets"), the Meshy hook, or the art session's uncommitted files (section 3).

---

## 2. Where things stand (2026-10-15, evening)

**Branches.** Both repos deploy from `fix/xp-leveling-overflow`; push it BY NAME on both
(`git push origin fix/xp-leveling-overflow`); the defaults are stale. The server repo has a
pull-request rule on that branch; the user's account bypasses it ("Bypassed rule violations"
in the push output is expected). Feature branches, both repos: `feat/trade-window` (the
PD_W0028 bump: the trade window, and merged into it the hunger window and the charm
re-target), `feat/jump-relay` (branched from the trade tip; NOT yet merged into it; server
`4975e4d`, client `82cf979`), `feat/public-hosting` (off the deploy branches until cutover).

**The R720** runs server `5986f26` (deployed 2026-10-14). Everything built since is on the
deploy branch awaiting a redeploy: the cast-arm refactor `c377a66`, seated combat `d4f6b47`,
res-sickness `528ae23`, Summon Food and Drink `4577350`. The testers' client is the 10-13
export; client changes since then (seated stand `2495276`, res-sickness sheet `9c5e333`,
summon spells `ec4fff2`) need the next export.

**The Oct 22 bump day** (planner rows b6, o4): **since 2026-10-19 one branch carries it all**:
`feat/server-speed` (both repos) contains `feat/jump-relay` (which contains `feat/trade-window`
and the hunger window), Despawn All, the server-decided movement speed, and the deploy branch
up to fix 3, merged and green together (297 unit, 111 integration). If the trade session has
pushed to `feat/trade-window` since, merge it into `feat/server-speed` first. Then merge
`feat/server-speed` into the deploy branch in both repos, run both suites on the merged tree, rebuild the DLL with
`RUSTFLAGS="-C target-feature=+crt-static" cargo build -p gdext-net --release`, copy it into
`addons/gdext_net/`, run `tools/check_wire_layer.gd` (must list every signal OK), redeploy with
`PROJECTDAWN_MIN_CLIENT_VERSION=0.2.0` in `/opt/projectdawn/.env`, export, send the zip. The
user runs the host commands; you write them out exactly, including the `systemctl stop`
before the `cp`.

**Pending from the user:** nothing blocking. The pull-request rule is theirs to look at.
The playtests of every checklist in `CHECKLIST_RUN_ORDER.md` wait on the redeploy and export.

---

## 3. Traps this environment has, with the fix for each

- **Bash heredocs over about a hundred lines fail** with "unexpected EOF while looking for
  matching `'`" before running anything. Put scripts in the scratchpad with the `Write` tool
  and run them with `python -I <path>`. Short heredocs (under 40 lines) are fine.
- **Python on this machine does not understand `/c/...` paths.** Pass `C:/Users/...` to
  Python; Bash itself accepts either.
- **The art session has uncommitted edits** in `CLAUDE.md` (the "Secrets" section),
  `docs/reference/commands.md`, `docs/design/meshy_asset_pipeline.md`,
  `docs/design/art_assets_checklist.md`, `.claude/settings.json` and untracked files under
  `.claude/hooks/`, `tools/art_board/`. Never `git add` those. For `CLAUDE.md`, stage only
  your hunk: `git diff CLAUDE.md > x.diff`, split on `^@@`, keep the hunk containing your
  anchor text, `git apply --cached` it. The scratchpad scripts `*_docs.py` from 10-14 and 10-15
  show the pattern.
- **The session note of the day may already have a section from the art session.** Check
  `grep -n "^## " docs/session_notes/session_<date>.md` before numbering yours.
- **The session index row (`docs/session_notes/README.md`) is shared** with the art session;
  anchor an edit on a unique phrase inside the row, never on the row's end.
- **CRLF.** Server `.rs` and `.toml` files are CRLF; most client files are LF; some are mixed.
  Normalise in the edit script, restore on write.
- **Godot headless probes:** `extends SceneTree`, the entry point is `_initialize()`, start
  with `await process_frame` or autoloads are not in the tree yet, reach autoloads with
  `root.get_node("Name")` (a bare `Net` does not compile in a script outside the project),
  `quit(1)` on failure. Run: `"<godot exe>" --headless --path /f/Projects/Project_Dawn -s
  "C:/.../probe.gd"`. Run `--import` once after adding resources.
- **The integration harness** (`tests/world_two_clients.rs`): after `send_attack` or any
  intent, service the sender's own transport (`pump_both_for`) or the message never leaves its
  socket; `pump_both_for` asserts both clients connected, so never call it after
  `send_disconnect` (use per-client `pump_for`); regen fans HealthUpdate and ManaUpdate on its
  own schedule, so look for the value you expect in a window, never the last message; a timed
  cast is `send_cast_start(name, secs)`, pump `secs + 0.2`, then `send_cast_spell`; dying is
  `set_account_gm` + a fresh token + `send_damage_self(1_000_000)`; a level is seeded with
  `set_char_level` before login. No flaky test exists; a failure is real, and "passes alone"
  means find the timing race.
- **`cast_target_refusal` is the one home of cast eligibility** (reach, presence, liveness,
  PvP gates, bag room for summons). A new target kind gets an arm there returning a
  `ResolvedTarget`, and an arm in the tick's `match spell.target_type.as_str()`; the arms carry
  no checks of their own.
- **The lockstep TOML parser** (`tools/check_spell_lockstep.gd`) reads strings, numbers,
  bools, string arrays and inline tables only. A new field on a spell must appear on both
  sides or be absent from the client dict (absent keys are not compared).
- **Planner ids** are taken through `b18` and `v25`; the next build row is `b19`, the next
  verify row `v26`. The planner page is republished at the URL in `docs/schedule_detail.toml`
  (`published_url`); read it with the Artifact tool once per session before publishing, or the
  publish is refused.

---

## 4. The queue, in order, with what is known about each

**Progress (2026-10-15, later the same day, on Opus):** 4.1 and 4.2 are BUILT and recorded
(client `fc0042f` + `1159a79`, server `33c7e28`; session note 2026-10-15 §4 and §5; planner
b19/v26, b20/v27). 4.3 is DEFERRED FAR OUT by the user (2026-10-16); do not build it. The
deferral covers that operator tool only: the user was explicit the same day that development
stays vigilant for hacks, dupes and cheats in every build (rule 3 above is unchanged).

**Progress (2026-10-19, Opus):** the R720 runs `33c7e28` (redeployed the same day; planner
o11). 4.4 is BUILT on `feat/jump-relay` (server `9500051`, client `827de57`; session note
2026-10-19 §3; planner b21/v28), so the jump branch now carries it into the Oct 22 merge.
A trial merge of that branch into the deploy branch conflicts in two expected places: the
server's `world_two_clients.rs` end of file (both sides append tests) and the client's
`check_wire_layer.gd` `SIGNALS` line; keep both sides of each. Next is 4.5, which needs the
user's answers before any build. Next planner ids: `b22`, `v29`.

**Progress (2026-10-19, later, Opus):** 4.5's questions were answered (the To-Do entries carry
them: WIS heals server-side, dual wield 13 / 15 / 20 with Monks at 1, per-spell ranges on a
30 m baseline, conjured food NO RENT, +1 per level to 10), and the user set a rule: "Events
happening on the client are a no-go." The client-authority audit
(`docs/security/client_authority_audit_2026_10_19.md`) and fixes 1 to 3 are built (session note
2026-10-19 section 6; planner b22, b23, v29). **Next, in order:** audit fix 4 (the melee miss
roll and weapon-skill damage on the server), fix 5 (memorized spell gems, a wire message, so
it rides the Oct 22 bump only if done before it), then the decided builds: dual wield levels,
per-spell ranges, conjured food (+1 per level to 10, NO RENT with the no-drop flag). Next
planner ids: `b24`, `v30`.

**Progress (2026-10-19, later still):** fix 4, dual wield, per-spell ranges and the conjured food
count are BUILT on `feat/server-speed` (session note section 7; planner b24, b25). **Waiting on
the user:** one migration (`0015`) for fix 5 (a server-side spell bar: MemorizeSpell intent,
CastSpell refused for a spell not memorized) and the NO RENT flag (a per-character logout time
for the 30-minute rule). Both ride Oct 22 only if approved and built before it. Next planner
ids: `b26`, `v30`.

**Progress (2026-10-19, last):** the migration was approved and fix 5 and NO RENT are BUILT on
`feat/server-speed` (session note section 8; planner b26). **Every client-authority fix is
built**; the decided builds are done except the no-drop / no-trade binding flag (not decided).
**Oct 22 now carries migration 0015** with everything else: the merged build must deploy as one
(an older binary cannot boot on a migrated `world.db`). When `feat/public-hosting` merges, add
the four spell-bar intents to its per-connection intent budgets. Next planner ids: `b27`, `v30`.

**Progress (2026-10-19, later still):** active skills are on the server (audit item 6's first
part; session note section 9; planner b27 and v30; `active_skills_checklist.md`), on
`feat/server-speed`, riding Oct 22. Still client-only from that item: Bard songs, alignment,
fall damage. `UseSkill` joins the intent-budget note for `feat/public-hosting`. Next planner
ids: `b28`, `v31`.

**Progress (2026-10-20):** Bard songs are on the server (audit item 6's second part; session
note 2026-10-20 §2; planner b28 and v31; `bard_songs_checklist.md`), on `feat/server-speed`,
riding Oct 22. `StopSong` joins the intent-budget note for `feat/public-hosting`. A Sneak skill
is decided and not designed (its own To-Do entry). Still client-only from item 6: alignment,
fall damage. A standing rule from the day: flag any number far above P99's. Next planner ids:
`b29`, `v32`.

### 4.1 Nameplates visible through walls (client only; the user said "fix before ship")

What is known: name labels are `Label3D` nodes named `NameLabel`.
`scenes/remote_player.tscn:27` has `no_depth_test = true` (drawn over everything);
`scenes/remote_enemy.tscn:47` has `no_depth_test = false`; `scripts/friendly_npc.gd:18`
fetches a `NameLabel` whose scene flag is unverified. The complaint names NPC and enemy labels,
so first verify in play or by reading each scene which labels really show through geometry
(a Label3D with `no_depth_test = false` can still show through if `render_priority` or
`alpha` settings differ; read the whole node block). Likely fix: `no_depth_test = false` on
every nameplate, keeping the own target's plate readable (EQ drew no names through walls;
the target's plate stayed because you had line of sight to target it). Probe: instantiate the
three scenes headless and assert the flag. Checklist: four or five rows (a mob behind the
town wall, an NPC behind the bank, your target walking behind a wall, a group-mate's plate).
Records: To-Do "Nameplate and targeting polish" (a).

### 4.2 Live relogin countdown (DLL + client; no protocol bump)

What is known: the wire carries `reconnect_after_secs: Option<u32>` on the kick
(`crates/protocol/src/world.rs:980`); the DLL's signal is `kicked(reason: GString, code:
GString)` (`crates/gdext-net/src/lib.rs:96`) and drops the seconds; `autoloads/net.gd:990
_on_kicked(reason, code)` surfaces the reason. Shape: add a third argument to the signal
(`reconnect_after_secs: i64`, -1 for none), connect it BY NAME in `Net` with a fallback to the
two-argument form for an older DLL (the `player_jumped` and `rtt_ms` pattern: `has_signal` /
`has_method` checks so a stale DLL costs the feature, not the client), carry it to the lobby,
and tick a countdown there. Add the signal name to `tools/check_wire_layer.gd`. Needs the DLL
rebuild the Oct 22 export already carries. Records: To-Do "Camp / kick return-to-lobby flow +
live relogin countdown" part (2).

### 4.3 Kick by account, the password-reset half (server; needs a migration, so a user yes)

The design in the To-Do entry: a `sessions_valid_from` column (or equivalent) that the reset
writes and the world's ban sweep reads. Forward-only migration (`0015_...`); an older binary
will not boot on the migrated DB; say so in the deploy note as 0013 and 0014 did.

### 4.4 Test Panel "Despawn All Enemies" leaves enemies invisible (dev tool; wire change)

Needs a `DevDespawnAll` intent handled like `DevSpawnMob` (dev-gated through
`authorize_dev_cmd`, so it is audited). A protocol change: build it on a branch off
`feat/trade-window` only if it can ride Oct 22, otherwise wait for the next bump day.

### 4.5 Decisions to ask the user before building

Heal magnitude drift (port the WIS term server-side or delete it client-side); dual wield as
an unlockable passive (which level); per-spell ranges (heals share the nuke's reach today);
whether journal ticks should be range-gated like XP shares; whether summoned items should be
no-rent (vanish on logout) once a no-drop flag exists; the Summon Food level step (ten levels
per extra item is a knob the user has not confirmed).

---

## 5. The recipe for one build (follow it in order)

1. Read the To-Do entry and every doc it names. Grep the anchors; read the real code around
   them, not only the lines quoted.
2. Research the game-history question if there is one; quote sources in the commit.
3. Decide the exploit paragraph before writing code.
4. Write the edit script to the scratchpad (`Write`), dry-run on a copy, read the diff.
5. Apply. Build. Write the test that fails on the old code; prove it fails; make it pass.
6. Full suite(s). Lockstep checks if data changed. Headless probe if client logic changed.
7. Write the checklist from the template: setup rows naming the server sha and whether the
   export is needed, numbered sections, a regression section, `notes:` on every row.
8. Commit the server (message: what, why, the rule's source, the exploit note, the tests, the
   suite counts), then the client (code + checklist). Attribution lines per the session's
   system reminder.
9. The records pass (section 6). Push both repos by branch name. Republish the planner.
10. Report to the user: what exists, the evidence, what is flagged, what rides which deploy.
    Short. Lead with the outcome.

---

## 6. The records pass, exact steps

1. `CLAUDE.md`: append to the item's To-Do entry a paragraph beginning `**BUILT <date>,
   pending the redeploy, the export and the playtest** (server \`<sha>\`, client \`<sha>\`;
   \`<checklist>.md\`, N rows; ...)`, then what exists, the knobs with constant names, what is
   flagged not built, the tests, the suite counts, the exploit paragraph. Never tick.
2. `docs/session_notes/session_<date>.md`: a numbered section (check existing headings first).
3. `docs/session_notes/README.md`: the day's row (create it above the previous day's row if
   the day is new; else append a bold phrase to the existing row).
4. `docs/schedule_detail.toml`: a `[[row]]` for the build (`lane = "build"`, `who = "Claude
   unattended"`, `days`, `done_when`, `todo` = the To-Do entry's exact title) and one for the
   verify sitting (`lane = "verify"`, `hours`, `needs`, `checklist`, `waits_on = ["o4"]` for
   anything that needs the Oct 22 export, `todo`, `done_when = "Every row filled."`).
5. `python tools/schedule_detail.py` (its warnings about unscheduled checklists are known).
6. Stage only your `CLAUDE.md` hunk (section 3), plus the five doc files; commit; push.
7. Republish `docs/schedule_detail.html` to the artifact URL in the toml with the Artifact
   tool (`action: publish`, `url`, `file_path`, a short `label`).

---

## 7. What "Fable standard" meant in practice, so you can tell when you are below it

- A claim with no source behind it was corrected the same evening, in the docs, with the
  correction recorded as a correction rather than silently overwritten.
- A test's first draft that could pass on the old code, or that read the wrong message, was
  fixed as a test and the lesson written into the session note.
- A design the user chose was built whole, with the parts deliberately left out named and
  given a home (a To-Do entry or a knob), never quietly dropped.
- Every number the user did not decide was named as a knob with its constant.
- The checklist told the tester which build each section needs and where to look in
  `server.log` when a row fails.
