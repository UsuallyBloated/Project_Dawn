# The public hosting sitting (slice 4): every command, in order

The runbook for the one evening the R720 moves from the tailnet to the public internet.
Plan: `docs/design/public_hosting_plan.md`. The server and client halves are built on
`feat/public-hosting` in both repos (2026-10-12). Nothing here runs until slice 0 (your
router) is done: the router's WAN address is the public one, the R720's LAN address is
reserved (H6), the DuckDNS name exists, and you know whether the router hairpins.

Claude never touches the router. Steps marked **(router)** are yours in its admin page.
Everything else is typed on the R720 over SSH (which stays on Tailscale throughout).

Placeholders to replace as you go: `NAME.duckdns.org` (the DDNS name), `TOKEN` (the DuckDNS
token), `LAN_IP` (the reserved address, 192.168.x.x).

## 0. Before anything changes (five minutes)

```
# on the R720
tailscale ip -4                       # the SSH address you are using stays valid
curl -4 -s ifconfig.me; echo          # the public IPv4 the router shows must match this
ip -4 addr show | grep inet           # LAN_IP: this is what the router forwards to
sudo ufw status numbered              # today: OpenSSH, and 8765/tcp + 7777/udp on tailscale0
cat /opt/projectdawn/.env             # note PROJECTDAWN_WORLD_ENDPOINT and PD_NO_RATE_LIMIT
```

Nobody online for the rest of this: `sudo -u projectdawn env PROJECTDAWN_DB=/opt/projectdawn/world.db PROJECTDAWN_BACKUP_DIR=/data/projectdawn-backups /opt/projectdawn/src/scripts/backup.sh` first, so there is a copy from the last minute before the migration.

## 1. DuckDNS (ten minutes)

1. At duckdns.org, the name `NAME` pointing at the public IPv4; copy the token.
2. The updater, as a systemd timer (every five minutes, the same cadence as the server's own
   address watch):

```
sudo mkdir -p /opt/duckdns
sudo tee /opt/duckdns/update.sh >/dev/null <<'EOF'
#!/bin/sh
curl -4 -s "https://www.duckdns.org/update?domains=NAME&token=TOKEN&ip=" >/opt/duckdns/last.txt
EOF
sudo chmod 700 /opt/duckdns/update.sh
sudo tee /etc/systemd/system/duckdns.service >/dev/null <<'EOF'
[Unit]
Description=DuckDNS address update
[Service]
Type=oneshot
ExecStart=/opt/duckdns/update.sh
EOF
sudo tee /etc/systemd/system/duckdns.timer >/dev/null <<'EOF'
[Unit]
Description=DuckDNS address update, every five minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now duckdns.timer
sudo systemctl start duckdns.service && cat /opt/duckdns/last.txt   # must print OK
dig +short NAME.duckdns.org                                           # the public IPv4
```

The token sits in a root-only file; it is the only secret in this step.

## 2. Caddy (ten minutes, no certificate work by hand)

```
sudo apt install -y caddy
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
NAME.duckdns.org {
	reverse_proxy 127.0.0.1:8765
}
EOF
sudo systemctl enable --now caddy
```

Caddy gets its certificate from Let's Encrypt through the TLS-ALPN challenge on 443, so port
80 is never opened and renewals never touch the game. Until the router forwards 443 (step 4)
the certificate cannot be issued; `journalctl -u caddy -f` shows it succeed after the forward.
Caddy sets `X-Forwarded-For` to the client's address on every proxied request; the server
believes that header only because the TCP peer is Caddy on loopback.

## 3. The server (fifteen minutes; the world goes down for about two)

Build the hosting branch and change the `.env`. The migration in this branch (`0012_invites`)
is forward-only: once this server has booted on `world.db`, the old binary will not start on
it, which is why the backup in step 0 matters.

```
sudo -u projectdawn -H bash
cd /opt/projectdawn/src && git fetch && git checkout feat/public-hosting && git pull && cargo build --release
exit
sudo -u projectdawn nano /opt/projectdawn/.env
```

In `.env`:

```
PROJECTDAWN_AUTH_BIND=127.0.0.1:8765              # the auth port is Caddy's alone now
PROJECTDAWN_WORLD_ENDPOINT=NAME.duckdns.org:7777   # a name; the server resolves it at boot
PROJECTDAWN_REQUIRE_INVITE=1
# delete the PD_NO_RATE_LIMIT line entirely
```

Then the usual stop, copy, start:

```
sudo systemctl stop projectdawn
sudo -u projectdawn cp /opt/projectdawn/src/target/release/projectdawn-server /opt/projectdawn/projectdawn-server
sudo systemctl start projectdawn
journalctl -u projectdawn -n 30 --no-pager
```

The boot line must read `rate_limit=true require_invite=true dev_cmds=false`, followed by
`world address resolved` naming `NAME.duckdns.org:7777` and the public IPv4. If it instead
says the name did not resolve, DNS has not caught up; `dig +short NAME.duckdns.org` and start
again when it answers.

Mint the invites now, one per tester, and keep the output (they are shown once):

```
cd /opt/projectdawn && sudo -u projectdawn /opt/projectdawn/src/target/release/invite new 1 for <tester name>
```

## 4. The firewall and the router (ten minutes)

```
sudo ufw allow 443/tcp comment 'projectdawn auth via caddy'
sudo ufw allow 7777/udp comment 'projectdawn world'
sudo ufw status verbose
```

Leave the old `tailscale0` rules for 8765 and 7777 in place for tonight (the auth socket is
on loopback now, so 8765 answers nobody anyway); they come out after the cutover playtest.
SSH stays as it is: nothing forwards port 22, so it is reachable from the LAN and the tailnet
only.

**(router)** Forward **TCP 443** and **UDP 7777** to `LAN_IP`. Nothing else. If the router
offers "UPnP" or "DMZ", leave both off.

If the R720 has a global IPv6 address (it did on 2026-10-08, `2601:...`), the router does not
NAT it and UFW is the only thing in front of it: the two rules above apply to IPv6 as well
(UFW adds both families by default). Keep the DuckDNS name IPv4-only unless you decide to
publish an AAAA record; the server resolves a name to its first IPv4 address either way.

## 5. The outside test, before anyone is told (fifteen minutes)

From a phone hotspot (the laptop tethered, NOT on the house Wi-Fi), with the new client
build and an invite code:

1. Server field: `NAME.duckdns.org` and nothing else. Register with the code.
2. Create a character, Play, Enter World, walk, cast.
3. From the same machine: `nmap -Pn -p 22,80,443,8765,7777 NAME.duckdns.org` and
   `nmap -Pn -sU -p 7777 NAME.duckdns.org`. Only 443/tcp and 7777/udp may answer.

On the R720 meanwhile: `journalctl -u projectdawn -f` shows the login with a public source
address, never `127.0.0.1`.

If the house itself cannot reach `NAME.duckdns.org` (the hairpin question from slice 0),
the operator's machine gets one line in `C:\Windows\System32\drivers\etc\hosts`:
`LAN_IP NAME.duckdns.org`. Caddy still serves the right certificate for the name.

## 6. Cutover for the testers (the announced evening)

- Send each tester the new zip and their invite code, and the one-line server name.
- Raise `PROJECTDAWN_MIN_CLIENT_VERSION` in `.env` to the new client's version and restart
  (the October 9 zip is then refused at login with a clear line).
- In the Tailscale admin console, remove the machine shares for the four testers. Your own
  node stays: SSH rides it.
- Run `docs/playtest_notes/public_hosting_checklist.md` with one tester outside the house.

## 7. Afterwards

- `sudo ufw delete <rule number>` for the two `tailscale0` game-port rules once the checklist
  passes.
- Merge `feat/public-hosting` into `fix/xp-leveling-overflow` in both repos (it carries the
  only copy of migration 0012, so the deploy branch must not fall behind the running server).
- `docs/deployment/server_operations.md` and `inviting_a_player.md` lose their Tailscale
  steps; `README_FOR_TESTERS.md` on the hosting branch is already written for the new world.

## If something goes wrong

- **Caddy has no certificate** (`journalctl -u caddy`): 443 is not reaching the R720. The
  router forward, or the ISP blocking 443 inbound (rare; a different port would need the
  Caddyfile to say `NAME.duckdns.org:8443` and the testers to type `NAME.duckdns.org:8443`).
- **The server refuses to start on the name**: resolve first (`dig +short`), or put the
  public IPv4 in `PROJECTDAWN_WORLD_ENDPOINT` for the night and go back to the name later.
- **Back out entirely**: restore the step 0 backup over `world.db`, check out
  `fix/xp-leveling-overflow`, rebuild, restore the old `.env`, stop Caddy, remove the two UFW
  rules and the router forwards. The testers' October 9 zip works again over the tailnet.
