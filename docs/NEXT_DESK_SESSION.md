# Next desk session

A disposable queue of the things waiting on hands-at-the-machine, in order.
Rewrite or delete freely; the To-Do in CLAUDE.md stays the real feature list.

*(Last updated 2026-09-17, after the phase 4 build + fresh-world decision.)*

1. **R720: deploy phase 4 + wipe the world in one downtime window.** The exact
   command block is in `docs/deployment/server_operations.md`, section "Fresh
   world reset" (snapshot, pull + build, stop, cp, retire `world.db`, start).
   Boot line must show `dev_cmds=false`, `build=e8aa8ba` (docs-only commit on
   top of the phase 4 code, same binary behavior), and the migrations applying.
2. **Re-provision yourself**: register your account fresh in the launcher, then
   re-grant GM with the full `grant_gm` invocation from the ops doc (the wipe
   removed every `is_gm` flag).
3. **Clear stale local bars on your machine**: delete
   `social_hotkeys_c*.json` / `spell_bar_c*.json` (and optionally the legacy
   `social_hotkeys.json` / `spell_bar.json`) from
   `%APPDATA%\Godot\app_userdata\Project_Dawn\` before first login, or the new
   character inherits the old one's hotbars.
4. **Ship the new client build**: the zip from `builds/` (stamped `c3e215a`),
   with the word that everyone re-registers and should clear the same stale
   files on their machines.
5. **GM lap before inviting anyone**: `phase4_content_checklist.md` §1 (the
   repaired starter book) with a fresh character, so any world-data surprise
   surfaces cheap.
6. **Playtest queue**, in order:
   - `phase4_content_checklist.md` (the full six sections; §3 and late §2 want
     GM leveling).
   - `bagspace_groupbars_checklist.md` (§2 needs the second seat).
   - The two RETEST rows on `cursor_slice15_checklist.md`: equip-from-hand swap
     no longer blanks the held item, and the drop-confirm dialog no longer
     echo-re-prompts.
