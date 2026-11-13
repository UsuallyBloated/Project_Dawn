# Project Dawn: Server Operations

Day-to-day running of the live server. This is the "something is wrong and I need to fix it"
document.

- **How the machine was built:** `r720_host_setup.md` (same folder).
- **How the app was first deployed:** `server/docs/deployment_linux.md`.
- **This file:** running it, updating it, recovering it.

---

## Quick reference

Everything below runs on the server, over SSH from your PC:

```
ssh wrightt@100.93.108.112
```

| I want to | Command |
|---|---|
| See if it is running | `systemctl status projectdawn --no-pager` |
| Watch the log live | `journalctl -u projectdawn -f` |
| See the last 50 log lines | `journalctl -u projectdawn -n 50 --no-pager` |
| Start it | `sudo systemctl start projectdawn` |
| Stop it | `sudo systemctl stop projectdawn` (read the warning below first) |
| Restart it | `sudo systemctl restart projectdawn` (same warning) |
| Check who is online | `journalctl -u projectdawn -n 100 --no-pager \| grep -i "login\|connect"` |

The service is `enabled`, so it starts itself after a reboot or power cut. You do not need to
do anything after the machine comes back.

**To watch the log while doing something else**, open a second PowerShell window and SSH in
again. Two independent sessions to the same machine is normal and costs nothing: one tails,
one runs commands.

> **Possible future addition: `tmux`.** A `journalctl -f` in a plain SSH session dies when the
> connection drops or the laptop sleeps. `tmux` keeps it alive on the server: start it with
> `tmux`, run the tail inside, detach with `Ctrl+B` then `D`, and reattach later with
> `tmux attach`. Worth it for leaving a tail running through a long test session or overnight;
> overkill for watching for ten minutes. Not installed as of 2026-08-10.

---

## Where everything lives

| What | Path |
|---|---|
| Service account | `projectdawn` (system user, no login) |
| Install root | `/opt/projectdawn` |
| Source checkout | `/opt/projectdawn/src` (branch `fix/xp-leveling-overflow`) |
| Running binary | `/opt/projectdawn/projectdawn-server` |
| Config | `/opt/projectdawn/.env` (mode 600, holds the netcode key) |
| Live database | `/opt/projectdawn/world.db` |
| Backups | `/data/projectdawn-backups/` |
| systemd unit | `/etc/systemd/system/projectdawn.service` |
| Backup schedule | `/etc/cron.d/projectdawn-backup` (04:00 daily) |
| Tailnet address | `100.93.108.112` |
| Ports | TCP 8765 (auth), UDP 7777 (world) |

`/opt/projectdawn` is mode `750` and owned by the service account, so your own user cannot
read anything inside it. Every command touching it needs `sudo` or `sudo -u projectdawn`.
That is the isolation working, not a fault.

---

## Stopping safely: read this before your first restart

**From build `6c2bc45` on, a `stop` or `restart` is clean.** systemd sends SIGTERM; the server
saves every character in the world (retrying a failed save for up to 12 s, inside the 20 s
`TimeoutStopSec`), then tells each player "The world is being restarted. Your progress has been
saved; please log in again in a minute." and closes. The journal shows
`stop signal: saving everyone and closing the world` and `world closed saved=N unsaved=0`. If
any character could not be saved, the line says so, those players are told "Your last few
moments could not be saved", and the process exits non-zero. A second SIGTERM (or Ctrl-C
twice locally) quits at once without finishing the save.

**Before that build** (anything older than `6c2bc45`), there is no SIGTERM handler: a stop or
restart discards up to **60 seconds** of position, HP, MP, XP, inventory and coins for every
player online.

**The rule is still: tell people, let them log out, then stop.** A clean shutdown costs nothing,
but a heads-up is courteous, and an old build is not clean. A crash (power, kernel, `kill -9`)
is never clean; the 60 s checkpoint bounds what it can lose.

---

## Checking it is healthy

```
systemctl status projectdawn --no-pager
```

Wants `active (running)`.

```
journalctl -u projectdawn -n 20 --no-pager
```

The startup line is the important one. **Check it after every start**, because several silent
misconfigurations are only visible here:

```
starting projectdawn-server auth_bind=0.0.0.0:8765 world_bind=0.0.0.0:7777
  world_endpoint=100.93.108.112:7777 db=sqlite:///opt/projectdawn/world.db?mode=rwc
  min_client=0.1.0 dev_cmds=false
```

| Field | Must read | If it does not |
|---|---|---|
| `dev_cmds` | `false` | **Every player has `/give`, mob spawning and instant levels.** Stop the server. |
| `world_endpoint` | `100.93.108.112:7777` | Remote players will log in fine and then hang on Enter World. |
| `db` | `sqlite:///opt/projectdawn/world.db?mode=rwc` | You are running against the wrong database and nobody's characters exist. |

The presence of the `dev_cmds` field at all also tells you the build is recent. It arrived in
commit `a765573`; a binary without it predates every Phase 1 exploit gate.

Confirm the ports are actually open:

```
sudo ss -tulnp | grep -E '8765|7777'
```

Wants `tcp 0.0.0.0:8765` and `udp 0.0.0.0:7777`, both owned by `projectdawn-ser`.

---

## Deploying an update

After pushing server changes from your dev box:

```
sudo -u projectdawn -H bash
cd /opt/projectdawn/src
git pull
cargo build --release
exit
```

Then stop, copy, start — in that order, remembering the state-loss warning above.
**The stop comes BEFORE the copy**: Linux refuses to overwrite a running executable
("Text file busy", hit for real 2026-08-27), so a `cp` while the service is up fails.

```
sudo systemctl stop projectdawn
sudo -u projectdawn cp /opt/projectdawn/src/target/release/projectdawn-server /opt/projectdawn/projectdawn-server
sudo systemctl start projectdawn
journalctl -u projectdawn -n 20 --no-pager
```

**Check the startup line again**, especially `dev_cmds=false` and the new `build=` sha.

Two things that go wrong here:

- **`git pull` says "Already up to date" when you expected changes.** You pushed a different
  branch than the one deployed. Check with `git branch --show-current` inside
  `/opt/projectdawn/src`; it should be `fix/xp-leveling-overflow`.
- **The build succeeds but nothing changes.** You forgot the `cp`. systemd runs
  `/opt/projectdawn/projectdawn-server`, not the one in `target/release/`.

---

## Managing GM

`grant_gm` does **not** read `.env`, and it defaults to `world.db` relative to the current
directory with `mode=rwc`. Run it from the wrong place and it silently creates an empty
database, reports no accounts, and leaves a stray file. Always pass the path.

**List every account and its GM status:**

```
sudo -u projectdawn env PROJECTDAWN_DATABASE_URL='sqlite:///opt/projectdawn/world.db?mode=rwc' /opt/projectdawn/src/target/release/grant_gm
```

**Grant or revoke:**

```
sudo -u projectdawn env PROJECTDAWN_DATABASE_URL='sqlite:///opt/projectdawn/world.db?mode=rwc' /opt/projectdawn/src/target/release/grant_gm <username> on
```

`off` to revoke. Changes take effect at that account's **next world login**, so tell them to
re-log.

**Audit with the no-argument form after any change.** Exactly one account should have GM.
Every GM account can spawn mobs, grant XP and give themselves items.

---

## Backups

Automatic at **04:00 daily** into `/data/projectdawn-backups`, 7 days retained, on a
different physical array from the live database.

**Check they are happening:**

```
ls -lt /data/projectdawn-backups/ | head
```

The newest file should be from this morning. If it is not:

```
journalctl -u cron --since "2 days ago" --no-pager | grep -i projectdawn
```

**Take one right now**, for instance before a risky change:

```
sudo -u projectdawn env PROJECTDAWN_DB=/opt/projectdawn/world.db PROJECTDAWN_BACKUP_DIR=/data/projectdawn-backups /opt/projectdawn/src/scripts/backup.sh
```

Safe to run while the server is live. It ends with `backup complete: <path>`.

If it instead prints only `find: Failed to restore initial working directory: ... Permission
denied` (hit 2026-10-02), the backup WAS written and only the confirmation line was lost: you
ran it from a directory the `projectdawn` account cannot enter (your own home), and the old
script's pruning step exits on that. Confirm with the `ls -lt` above. The script is fixed in the
repo to prune from inside the backup directory; until the host has pulled that fix, run
`cd /tmp` first.

**Verify a backup actually contains data**, rather than being a file of the right size:

```
sudo -u projectdawn sqlite3 /data/projectdawn-backups/world-<timestamp>.db "SELECT COUNT(*) FROM accounts;"
sudo -u projectdawn sqlite3 /data/projectdawn-backups/world-<timestamp>.db "SELECT name, level FROM characters;"
```

---

## Fresh world reset (wipe all accounts and characters)

*(First used 2026-09-17 with the phase 4 world replacement: characters wake where
they logged out, and the map had changed under them.)*

The clean mechanism is a database reset, not hand-written DELETEs: the server's
sqlx layer applies every migration on first boot against a missing database, which
is the same tested path a fresh install takes. Everything goes at once — accounts,
characters, items, banks (including account-shared slots), corpses, quest
progress, sessions, and **every `is_gm` flag**.

```
# 1. Snapshot the world as it is (safe while live):
sudo -u projectdawn env PROJECTDAWN_DB=/opt/projectdawn/world.db PROJECTDAWN_BACKUP_DIR=/data/projectdawn-backups /opt/projectdawn/src/scripts/backup.sh

# 2. Stop, then move the database aside (never delete; -wal/-shm may not exist, that's fine):
sudo systemctl stop projectdawn
sudo -u projectdawn mv /opt/projectdawn/world.db /opt/projectdawn/world.db.retired-<date>
sudo -u projectdawn rm -f /opt/projectdawn/world.db-wal /opt/projectdawn/world.db-shm

# 3. Start; sqlx recreates the schema from migrations:
sudo systemctl start projectdawn
journalctl -u projectdawn -n 20 --no-pager   # dev_cmds=false, the expected build=, migrations applied

# 4. Re-provision yourself: register your account in the launcher, then re-grant GM
#    (the wipe removed every is_gm flag — the grant_gm defaults trap above applies):
sudo -u projectdawn env PROJECTDAWN_DATABASE_URL='sqlite:///opt/projectdawn/world.db?mode=rwc' /opt/projectdawn/src/target/release/grant_gm <username> on
```

Three follow-ons, all client-side and per-machine:

- **Stale hotbar seeds.** Character ids restart at 1, so each machine's existing
  `social_hotkeys_c<id>.json` / `spell_bar_c<id>.json` under `user://` will load
  an OLD character's bars onto a new character with the same id. Harmless but
  confusing; clear them (and optionally the legacy `social_hotkeys.json` /
  `spell_bar.json` seed files) from
  `%APPDATA%\Godot\app_userdata\Project_Dawn\` before first login.
- **Every tester re-registers** — send the word along with the build, or they will
  assume their password broke.
- The `PD_NO_RATE_LIMIT` kill-switch and everything else env-shaped is untouched;
  only the database resets.

Rolling back is the restore procedure below with the `.retired-<date>` file (or
the step 1 snapshot), same as any backup.

### Off-box copy

A scheduled task on the dev box pulls the backups into Google Drive weekly, which puts a copy
outside the building.

| | |
|---|---|
| Script | `G:\My Drive\ProjectDawnBackups\fetch-backups.ps1` |
| Destination | `G:\My Drive\ProjectDawnBackups` (Google Drive syncs it off-site) |
| Schedule | Windows Task Scheduler, weekly, task `Project Dawn backup copy` |

The script is two lines:

```powershell
$dest = "G:\My Drive\ProjectDawnBackups"
scp wrightt@100.93.108.112:/data/projectdawn-backups/*.db "$dest"
```

`"$dest"` must stay quoted: `My Drive` contains a space, and unquoted it splits into two
arguments and the copy fails. It runs without a password prompt because of the SSH key set up
in Stage H7.

**Check it is still running:** Task Scheduler shows **Last Run Result**, where `0x0` is
success. Or look at the `LastWriteTime` on the files in that folder; `scp` stamps them with
the copy time, so they should be within a week.

This gives three copies of the world: VD0 (live), VD1 (nightly backup), and Google Drive
(weekly, off-site). The first two are in one chassis; the third is what survives a fire,
theft, or the machine dying.

### Restoring

Only when the live database is lost or corrupt. This overwrites the current world.

```
sudo systemctl stop projectdawn
sudo -u projectdawn mv /opt/projectdawn/world.db /opt/projectdawn/world.db.broken
sudo -u projectdawn cp /data/projectdawn-backups/world-<timestamp>.db /opt/projectdawn/world.db
sudo systemctl start projectdawn
journalctl -u projectdawn -n 20 --no-pager
```

Keep `world.db.broken` until you are certain the restore is good. Note the restore is taken
as the service user throughout, so ownership stays correct.

Everything since that backup is gone. Tell players what they lost.

---

## Adding a tester

1. Invite them to the **tailnet** from the Tailscale admin console. They cannot reach the
   server at all without this.
2. Send them the build and `README_FOR_TESTERS.md`.
3. They register their own account in-game. You do nothing server-side.
4. **Do not grant them GM.**

To confirm they arrived:

```
sudo -u projectdawn env PROJECTDAWN_DATABASE_URL='sqlite:///opt/projectdawn/world.db?mode=rwc' /opt/projectdawn/src/target/release/grant_gm
```

Their account appears in the list without a `[GM]` tag.

---

## Triage: symptom to cause

| Symptom | Look here first |
|---|---|
| Nobody can connect at all | `systemctl status projectdawn`. Then whether your Tailscale is up. |
| One person cannot connect, others can | Their Tailscale, not your server. |
| Login works, Enter World hangs | `world_endpoint` in the startup line, then UDP 7777. **UDP failures are silent**, so suspect this before anything else. |
| Login succeeds then the world handshake fails for everyone | Clock drift. ConnectTokens live 30 s and the client validates against its own clock. `timedatectl status` wants NTP active and synchronized. |
| Service restarting over and over | Bad config. `sudo systemctl stop projectdawn` **first**, then read the log. `Restart=on-failure` fills the journal faster than you can read it. |
| `X is required` for a config value that is clearly in `.env` | Check the spelling of the **variable name**, not the value. A typo in the name looks identical to a missing file. `sudo cut -c1-32 /opt/projectdawn/.env` shows every name without exposing the key. |
| Players report items vanishing from the bank | **Fixed 2026-08-17** (client `8ad7f39`+). Vault slots could only draw an icon, and no item has one, so a stored item rendered blank. Nothing was ever lost. Ask for their `/version` — a build older than `8ad7f39` still shows it and needs a fresh client. |
| A spell does nothing but spends mana | Known: roughly 32 spells exist client-side but not on the server. Note which one. |
| Disk filling up | `df -h`, then `sudo journalctl --vacuum-time=30d` and check `/data/projectdawn-backups`. |

---

## Things you cannot do yet

Know these before you need them.

- **No kick, no ban, no shutdown warning.** `accounts.is_banned` is read at login but nothing
  writes it. Removing a disruptive player means stopping the server and running SQL, and even
  then it only blocks their next *login*: a live session keeps playing.
- **A crash is not a clean shutdown.** `stop` and `restart` save everyone from build `6c2bc45`
  on (see "Stopping safely"); a power loss or `kill -9` still loses up to the last 60 s.
- **The database is not in WAL mode**, despite code comments claiming otherwise. Running
  `admin_report` against a live server can block its writes for up to a 5 s busy timeout.
  Switching to WAL is cheap hardening but needs an exclusive lock, so do it while stopped.
- **Backups depend on the dev box being on.** The off-site copy is a weekly scheduled task on
  the dev box, so a machine that is off all week silently skips it. Check **Last Run Result**
  in Task Scheduler occasionally.
- **The hot spare only covers VD0.** If a 1.2TB drive dies, `/data` runs degraded with no
  redundancy until you physically fit a replacement. If a 300GB drive dies, it rebuilds
  itself.

---

## Read-only inspection

`admin_report` gives accounts, characters, coins and inventory, to console and to a local
`world_report.html`. It is read-only, but see the WAL note above before running it against a
live server with people on.

```
sudo -u projectdawn -H bash          # /opt/projectdawn/src is the service account's; a plain cd is refused
cd /opt/projectdawn/src
./target/release/admin_report /opt/projectdawn/world.db
exit
```

`admin_report` takes the database as its first argument (default `world.db` in the current
directory) and ignores `PROJECTDAWN_DATABASE_URL`, which only the four writing bins read; the
old line here set the variable and the tool looked in `src/` and found nothing (2026-11-09).
The page lands as `world_report.html` beside the binary's working directory.

---

## Routine maintenance

**Monthly, at a time nobody is playing:**

```
sudo apt update && sudo apt full-upgrade
ls /var/run/reboot-required && sudo reboot
```

Security updates apply automatically via `unattended-upgrades`, and it is configured **not**
to reboot on its own. So kernel updates queue up and wait for you, which is what you want:
you pick the moment.

**Occasionally, check the disks are still healthy.** The 300GB drives were manufactured in
2013 and are well past their design life. The controller battery status is also still
unverified; the easiest route to both is the **iDRAC** web interface, which needs no software
on the host.
