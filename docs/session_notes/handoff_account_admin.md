# Handoff — Account listing + housekeeping tooling

**For:** a fresh Claude session working in `F:\Projects\server` (Rust server repo).
**Written:** 2026-07-31. **Branch:** `fix/xp-leveling-overflow` (both repos).

---

## Part 1 — What already exists (no work needed)

The user asked "where can I see the list of registered accounts?" **That tool already exists** and
works today. Do not rebuild it.

### `admin_report` — read-only account + character viewer

```
cd F:\Projects\server
cargo run -p projectdawn-server --bin admin_report
```

Optional positional args: `[db_path] [output_html]` (defaults `world.db`, `world_report.html`).

- Opens the DB **read-only** (`?mode=ro`) — safe to run while the live server is up.
- Prints to console **and** writes a self-contained `world_report.html` you can open in a browser.
- Shows, per account: `id, username, email, is_gm, is_banned, ban_reason, created_at, last_login`.
- Shows, per character: name, level, race/class, zone, coins (carried + bank), inventory counts,
  and **soft-deleted characters** (`characters.deleted_at IS NOT NULL`), tagged `[DELETED <date>]`.
- Header line summarizes: `Accounts: N  Characters: N (N active, N deleted)  GM: N  Banned: N`.

Source: `crates/projectdawn-server/src/bin/admin_report.rs`.
Current state as of writing: **26 accounts, 135 characters (15 active, 120 soft-deleted), 1 GM, 0 banned.**

### `grant_gm` — the one existing write tool

```
cargo run -p projectdawn-server --bin grant_gm -- <username> on|off   # set per-account GM
cargo run -p projectdawn-server --bin grant_gm                        # no args = list accounts + GM flags
```

Takes an **account username**, not a character name. Source: `.../src/bin/grant_gm.rs`.

> Note on running these: the crate has 3 binaries, so `--bin` selects. Plain
> `cargo run -p projectdawn-server` still starts the server via the `default-run` manifest key.

---

## Part 2 — The actual gap (this is the work)

The user wants **housekeeping**, and that is genuinely missing. Two concrete gaps found by reading
the source:

### Gap A — `is_banned` is enforced but **unsettable**

`accounts.is_banned` / `ban_reason` exist in the schema (`migrations/0001_init.sql`) and **are
enforced at login**: `db::verify_login` returns `AuthError::Banned(reason)` when the flag is set
(`crates/projectdawn-server/src/db/mod.rs`, the `row.is_banned` early return). `admin_report`
displays them. But **no code anywhere writes them** — verified by grep: there is no
`UPDATE accounts SET is_banned` and no ban helper in the whole crate. So today a ban can be honored
but never applied (except by hand-editing SQLite).

### Gap B — no account delete / purge

There is no `delete_account` path anywhere. Characters have a **soft delete** (`deleted_at`), and
120 of 135 character rows are soft-deleted test junk. Accounts have no delete at all. The user's
playtests created disposable accounts (`first`…`seventh`, `one`…`eight`, ids 12-26) that they now
want to clean up.

---

## Part 3 — Proposed plan: a new `admin_account` bin

Add **one** new ops binary, `crates/projectdawn-server/src/bin/admin_account.rs`, modeled closely on
the existing `grant_gm.rs` (same arg-parsing shape, same sqlx usage, same "no args = list" habit).
Keep it an **offline ops tool**: no network surface, no live-server dependency, not part of the game
process.

### Subcommands

```
admin_account list                          # accounts + flags + char counts (overlaps admin_report; keep it terse)
admin_account ban    <username> [reason]    # set is_banned = 1, ban_reason = reason
admin_account unban  <username>             # set is_banned = 0, ban_reason = NULL
admin_account delete <username> --confirm   # delete the account + its characters + owned rows
admin_account purge-deleted-chars [--confirm]  # hard-delete soft-deleted character rows + their data
```

### Requirements / guardrails (important)

1. **Destructive ops must require an explicit `--confirm` flag** and print exactly what will be
   removed *before* doing it (account id, username, character names/levels, row counts). No
   interactive prompt — this tool runs non-interactively.
2. **Deletes must be transactional and complete.** Deleting an account has to clean every table that
   references it, or the DB is left with orphans. Enumerate the real FK/ownership graph from
   `migrations/*.sql` before writing the delete — at minimum: `characters`, `sessions`, `inventory`,
   `character_skills`, `corpses`, `bank_items`, `account_bank_items`, `completed_quests`,
   `active_quests`. **Do not trust this list — re-derive it from the migrations** (0001-0010) and
   check whether SQLite `FOREIGN KEY ... ON DELETE CASCADE` is actually enabled (SQLite enforces FKs
   only when `PRAGMA foreign_keys = ON`, which is off by default — verify what the pool sets).
3. **Refuse to delete a GM account** unless a second explicit flag is passed (protects the user's own
   account from a fat-fingered purge).
4. **Warn if the account has a live session** (`sessions` rows not expired) — deleting an account out
   from under a connected player is messy. Simplest safe answer: tell the user to stop the server, or
   revoke sessions as part of the delete.
5. **Ban should also revoke that account's sessions**, or a banned player stays logged in on their
   current session until it expires (the ban is only checked at *login*). Verify this against
   `db::verify_login` / `touch_session` before deciding.
6. `admin_report` stays **read-only** — do not add writes to it.

### Testing

- Follow the crate's existing test style. `db::` has sqlx tests (see `db/mod.rs`'s test module and
  `corpse_loot_tests`) — add tests for the ban/unban round-trip and, most importantly, that
  `delete_account` leaves **no orphan rows** in any referencing table.
- Run `cargo test -p projectdawn-server --lib` (currently **179 passing** — keep it green).
- Sanity-check against a **copy** of `world.db`, never the live file, until the delete is proven.

### Docs to update when done

- `docs/reference/commands.md` — the canonical command list; add the new subcommands next to
  `admin_report` / `grant_gm`.
- `CLAUDE.md` — the "Ops bins" bullet under **Commands** (it currently says the crate has 3 binaries;
  adding a 4th changes that line).
- `docs/concepts/architecture/systems_overview.md` — the "GM access + dev tooling" section.
- A session note in `docs/session_notes/` + its `README.md` index row.

---

## Part 4 — Suggested immediate housekeeping (once the tool exists)

The user's cleanup targets, visible in `admin_report` output:

- Playtest throwaway accounts: `first`, `second`, `third`, `fourth`, `fifth`, `sixth`, `seventh`
  (ids 12-18) and `one` … `eight` (ids 19-26) — created during the 2026-07-30 login-rate-limit
  playtest, all disposable.
- 120 soft-deleted character rows that no longer need to linger.
- **Keep** the user's real account(s) and the GM account. Confirm which those are with the user
  before deleting anything.

---

## Context / conventions for the incoming session

- Read `CLAUDE.md` first (project instructions, code style, the session workflow).
- Two repos: Godot client `f:\Projects\Project_Dawn`, Rust server `F:\Projects\server`. **This work
  is server-only** — no client change, no re-export, no wire-protocol change.
- Toolchain pinned to Rust 1.95.0. DB is SQLite (`world.db`, WAL), migrations auto-apply on boot via
  sqlx.
- Commit style: descriptive body explaining *why*; end with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Don't tick any To-Do item** without playtest evidence — that's the project's standing rule
  (`CLAUDE.md` → Session workflow step 6). For an ops tool, "evidence" = the user running it against
  a DB copy and confirming the output.
- Style: minimize em-dashes and left/right arrows in writing and UI text.
