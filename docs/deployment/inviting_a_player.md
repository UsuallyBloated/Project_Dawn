# Checklist: Inviting a New Player

Repeatable steps for getting one new tester onto the server. Work top to bottom.

Related: `server_operations.md` for running the server, `README_FOR_TESTERS.md` for what the
player receives.

---

## One-time prep (do once, not per player)

- [ ] **Discord invite is permanent.** Right-click the server, Invite People, Edit invite
  link, **Expire after: Never**, **Max uses: No limit**. The default expires in 7 days, which
  is useless in a document handed to people over months.
- [ ] **The build is current.** Compare the file dates in `builds/` against
  `git log -1 --format=%ad`. If commits are newer than the build, re-export from Godot first.
- [ ] **A zip is ready to send**, containing `ProjectDawn.exe` and `gdext_net.dll` from
  `builds/`. Both are required; the game will not connect without the DLL beside the exe.
  `ProjectDawn.console.exe` is optional and only useful for chasing a bug.

---

## Per player

### 1. Check the server is healthy first

Do not invite someone onto a server you have not looked at today.

- [x] `systemctl is-active projectdawn` reads `active`
- [x] `journalctl -u projectdawn -n 20 --no-pager` startup line shows **`dev_cmds=false`** and
  `world_endpoint=100.93.108.112:7777`
- [x] `ls -lt /data/projectdawn-backups/ | head` shows a backup from this morning

### 2. Share the machine (not your tailnet)

- [x] In the Tailscale admin console (`login.tailscale.com/admin`), open the **Machines**
  list, select `projectdawn`, and use **Share** to generate a share link.
- [x] Send them that link.

> **Share the node; do not invite them as a user of your tailnet.** A tailnet user can, subject
> to ACLs, see every device you own including your dev box. Node sharing scopes their access to
> the game server alone, from their own separate tailnet. A friend testing your game has no
> business being able to reach your desktop.

They will need a free Tailscale account to accept.

### 3. Send them the bundle

- [x] The Tailscale share link
- [x] The zipped build (`ProjectDawn.exe` + `gdext_net.dll`)
- [x] `README_FOR_TESTERS.md`
- [x] The server address: **`100.93.108.112:8765`**

A message template is at the bottom of this file.

### 4. Wait for them to register

They create their own account in the game. **Nothing is required from you server-side.**

Confirm they arrived:

```bash
sudo -u projectdawn env PROJECTDAWN_DATABASE_URL='sqlite:///opt/projectdawn/world.db?mode=rwc' /opt/projectdawn/src/target/release/grant_gm
```

Their account appears in the list. It must **not** have a `[GM]` tag.

### 5. Do not grant them GM

- [ ] Confirm the account list still shows exactly **one** `[GM]`, yours.

Every GM account can spawn mobs, grant XP and give itself items. There is currently **no kick
and no ban**, so GM handed out cannot be meaningfully contained if it is abused. Revoking it
with `grant_gm <name> off` only applies at their next login.

---

## If they cannot connect

Work down this list; it is ordered by how often each is the answer.

| Symptom | Cause |
|---|---|
| Nothing connects, no error detail | Tailscale not running or share not accepted. Have them run `ping 100.93.108.112`. Timeouts mean Tailscale, not the game. |
| "Cannot reach server" at the login screen | They left the Server field at the default `127.0.0.1:8765`. It must be `100.93.108.112:8765`. |
| Game will not launch, or launches then does nothing | `gdext_net.dll` is not beside `ProjectDawn.exe`. |
| Login works, character select works, **Enter World hangs** | Server-side: `world_endpoint` or UDP 7777. Check the startup line. **UDP failures are silent**, so suspect this first. |
| Login succeeds then everyone's world handshake fails | Server clock drift. `timedatectl status` wants NTP active. ConnectTokens live 30 s and the client checks against its own clock. |
| Character name rejected | Names accept **letters, apostrophes and backticks only**, 2 to 24 characters. |

Ask them to send `%APPDATA%\Godot\app_userdata\Project_Dawn\debug.log` and roughly what time
it happened, so it can be matched against `journalctl -u projectdawn --since "..."`.

---

## Before they play: things worth saying out loud

The README covers these, but people do not read READMEs.

- **Death drops everything.** Gear and coin stay on the corpse; you respawn naked and walk
  back. Corpses last 7 days.
- **The window X button is a deliberate crash simulation.** Use Options > Quit Game to log out
  cleanly, or the character lingers ~30 s and refuses their own re-login in that window.
- **Some spells silently do nothing.** Roughly 32 exist client-side but not on the server;
  casting spends mana with no effect. Worth knowing which ones they hit.
- **There is no sound at all.** Not broken, not built yet.

---

## After the session

- [ ] Skim `journalctl -u projectdawn --since "3 hours ago" --no-pager` for `WARN` or `ERROR`.
- [ ] Write up anything they reported into `docs/playtest_notes/`.
- [ ] If the session was significant, take a manual backup:

  ```bash
  sudo -u projectdawn env PROJECTDAWN_DB=/opt/projectdawn/world.db PROJECTDAWN_BACKUP_DIR=/data/projectdawn-backups /opt/projectdawn/src/scripts/backup.sh
  ```

One expected non-issue: a `WebSocket protocol error: Handshake not finished` warning is
produced by any TCP port check against 8765, including your own `Test-NetConnection`. It is
not a client fault.

---

## Message template

> Hey, want to try the thing I have been building?
>
> It is a pre-alpha multiplayer RPG, so expect rough edges and no sound yet. Your character
> can be wiped at any point.
>
> Three steps:
>
> 1. Click this link to get network access to my server, you will need a free Tailscale
>    account: `<share link>`
> 2. Unzip the game somewhere. Keep both files in the same folder.
> 3. Run `ProjectDawn.exe`. On the login screen, put `100.93.108.112:8765` in the Server
>    field, then Register an account and make a character.
>
> Read the README first if you can, especially the part about death, because you drop
> everything you are carrying and have to go and get it back.
>
> If anything breaks, tell me what you were doing and roughly when.
