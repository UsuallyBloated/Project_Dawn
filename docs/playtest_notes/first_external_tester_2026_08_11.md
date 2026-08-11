# Playtest: first external tester (2026-08-11)

**The session that closed Phase 2.** The first time anyone other than the author has played
this game, on hardware that is not the author's dev box.

- **Tester:** the operator's wife, on her own Windows machine, over a Tailscale node share.
- **Server:** R720, `100.93.108.112`, systemd, `dev_cmds=false`.
- **Accounts:** `account_id=2` (hers), plus `account_id=3` (also hers, see Finding 2).
- **Evidence:** `journalctl -u projectdawn`, timestamps below are UTC.

This is a session report rather than a checklist. The evidence is the server log, not
tester-filled rows.

---

## 1. Definition of done: MET

The To-Do and `schedule.md` both define Phase 2 as *"somebody who is not you, from a machine
that is not yours, made an account, made a character, killed something, and logged out clean."*

| Requirement | Evidence |
|---|---|
| Not the author, not their machine | `client connected (transport) client_id=2 char_id=2 account_id=2` at 02:41:02, from her own PC over the tailnet |
| Made an account | `account_id=2` did not exist before this session |
| Made a character | `char_id=2` |
| Killed something | `kill credit granted killer=2 mob=Plague Rat base_xp=1050` at 02:42:26 |
| Logged out clean | `client requested disconnect char_id=2` at 02:48:34 |

Also confirmed: **no `GM account connected` line for her session.** The GM path logs that line
on connect, and it appears only for `account_id=1`. She held no elevated access, which is the
posture `inviting_a_player.md` step 5 exists to protect.

---

## 2. Systems exercised by a second player for the first time

Everything below had only ever run against one client on localhost.

**Grouping.**
```
02:44:06  GroupInvite recorded; GroupInvited forwarded inviter=1 invitee=2
02:44:08  GroupAccept — invitee joined invitee=2 inviter=1 gid=1
```

**Group XP split, including the bonus.**
```
02:44:34  kill credit granted killer=1 mob=Decrepit Skeleton base_xp=263 pool=315 per_member=157 members=2
02:46:28  kill credit granted killer=1 mob=Rotting Skeleton  base_xp=2363 pool=2835 per_member=1417 members=2
```
`pool` exceeds `base_xp` by ~20% in both cases before being halved. The group bonus is applied
to the pool, then split. Correct.

**Round-robin loot rights, enforced against a real second player.**
```
02:44:46  loot rejected: not your turn (round robin) looter=2 bag_id=2000000003 assigned=1
02:44:50  loot rejected: not your turn (round robin) looter=2 bag_id=2000000003 assigned=1
```
She tried twice and was refused both times. The bag was assigned to player 1.

**Coin split.** `coin looted looter=1 bag_id=2000000003 pot=31 recipients=2 do_split=true`

**Levelling.** `char_id=2` 1 to 2, `char_id=1` 2 to 3, `char_id=3` 1 to 2.

**Death and corpse creation.** Two corpses for `char_id=2`, both `item_stacks=0` (a new
character carrying nothing), which is correct rather than a loss.

---

## 3. FINDING: respawn death-loop

**Severity: high. This is now the worst experience available in the game.**

```
02:46:06  server-detected player death char_id=2 level=2
02:46:06  corpse created char_id=2 corpse_id=2000000006 item_stacks=0
02:46:11  player damaged by enemy attacker=1000000005 target=2 hp_after=41.25
02:46:14  player damaged by enemy attacker=1000000005 target=2 hp_after=27.25
02:46:26  player damaged by enemy attacker=1000000004 target=2 hp_after=0.0
02:46:26  server-detected player death char_id=2 level=2
02:46:26  corpse created char_id=2 corpse_id=2000000007 item_stacks=0
```

She died, respawned **on the spot** at partial HP beside the two mobs that had just killed her,
was taking damage again **five seconds** later, and was dead again twenty seconds after that.
Two corpses, twenty seconds apart, in the same place.

**Cause.** The existing To-Do item *"Respawn at bind / Soul Binder NPC + a real death state"*.
There is no server-authoritative bind, so respawn honours a client bind that does not exist,
which resolves to where you died. There is no death lock and no post-respawn invulnerability
window.

**Why this is worse than the To-Do implied.** It was recorded from a 2026-07-20 solo playtest as
a UX gap wanting a redesign pass. In the hands of a new player it is an **unwinnable loop**: no
gear to fight back with, no idea where they are, and no understanding of why it keeps happening.
It also lands hardest on exactly the people the friends build is for.

**Recommendation.** Promote it. Even the crudest mitigation (a few seconds of post-respawn
invulnerability, or respawning some distance away) would break the loop without needing the
full bind system.

---

## 4. FINDING: login rate limit forced a duplicate account

**Severity: medium. A security control producing a false positive on the only real user.**

```
02:48:34  client requested disconnect char_id=2                       (clean logout)
02:49:29  Login rejected — rate limited (too many attempts from this IP)
          ip=100.72.138.42 window_secs=60 max_attempts=5
02:51:37  client connected (transport) client_id=3 char_id=3 account_id=3
```

She logged out, tried to log back in, exceeded 5 attempts in 60 seconds, was refused, and
**created a second account rather than waiting**. Confirmed by the operator.

**The gate worked exactly as designed.** The Phase 1 login rate limiter did what it was built to
do. The problem is the threshold against a real human on their first evening with a new
password.

**The threat model has also moved.** That gate was written for a server exposed to the open
internet. Nothing can currently reach port 8765 without being on the tailnet, so brute-force
risk is close to zero while the usability cost is now demonstrated.

**Consequences beyond the annoyance:**
- Two accounts and two characters exist for one person.
- There is **no account-deletion tooling** (`deployment_linux.md` §9: no kick, no ban), so
  tidying this up means hand-written SQL against `world.db`.

**Options.** Raise to ~10 per 60 s, or keep 5 attempts over a 5-minute window. Either preserves
brute-force protection for a future public deployment. It is a server change
(`LoginRateLimiter`), so it needs a push, a pull on the R720, a rebuild and a restart.

---

## 4b. FINDING: group-mate stats never reach the group panel (found post-session)

**Severity: medium. Not spam, a broken feature.**

Surfaced afterwards by running the client from a console while grouped:

```
ERROR: Attempt to call RPC with unknown peer ID: 2.
   at: (modules/multiplayer/scene_rpc_interface.cpp:307)
```
repeated continuously.

That is **Godot's native multiplayer**, which this game does not otherwise use; it talks to the
server through `gdext_net` and renet. The client still carries a second, vestigial multiplayer
stack (`Network` autoload, the lobby's dead Host/Join buttons) and `GroupManager` is still wired
to it.

**Mechanism.** `GroupManager._ready()` connects `_sync_stats` to `PlayerStats.hp_changed`,
`mp_changed` and `stamina_changed` **without** the `Net.is_launcher_mode()` guard that the action
methods carry. The server-driven `_on_world_group_roster` sets `in_group = true` and fills
`members[].peer_id` with **server char_ids**. Combat fires those signals constantly, so
`_flush_stats` calls `_rpc_member_stat_delta.rpc_id(2, ...)` where `2` is char_id 2, against a
Godot peer list that has no peer 2.

A coincidence made it take the worst branch: `_my_peer_id` is `multiplayer.get_unique_id()`,
which is 1 with no peer assigned, and the leader's char_id was also 1, so the leader test passed
and it looped every member.

**The bug underneath the noise.** `members[].hp` is only written by `_update_member_entry`, which
is called from the RPC handler and from `_flush_stats` for the local player. There is **no
server-driven source for member stats**: `Net` exposes `world_group_roster` (seeds hp to `0.0`),
`world_group_invited` and `world_group_notice`, nothing more. So in launcher mode every
group-mate's HP/MP/stamina bars sit at zero.

**Confirmed by the tester, and worse than blank.** Her bars read zero on both clients, while the
operator's bars showed values on both. That asymmetry is the tell.

`_local_stats()` returns `peer_id: _my_peer_id`, and `_my_peer_id` is
`multiplayer.get_unique_id()`, which is **1 on every client** because no Godot peer is ever
assigned. `_update_member_entry` then merges into whichever member row has `peer_id == 1`. The
operator is char_id 1, so:

| Client | Leader branch taken? | Local stats written into |
|---|---|---|
| Operator (char_id 1) | yes, `1 == 1` | row `peer_id 1`, their own. Correct by coincidence. |
| Tester (char_id 2) | yes, `1 == 1` | row `peer_id 1`, **the operator's row, not hers** |

So on her screen the bar under the operator's name was **her own HP**. Her row was never written
and stayed at the roster-seeded `0.0`. `merge(stats, true)` overwrites `name` too, so the label
on that row is also unstable between roster fans.

**This only half-works because the operator is char_id 1.** With any other leader,
`_my_peer_id (1) == leader_peer_id (N)` is false on both clients, both take the `else` branch,
and **no** row is updated anywhere: every bar blank, including your own.

**Interim fix worth considering** alongside (a): in launcher mode, key the local player's own row
on `Net.get_player_id()` (the real char_id) instead of the Godot peer id. Each player then sees
their own row correctly and everyone else's blank, which is an honest failure rather than one
player's stats displayed under another's name.

**Why it hid until now.** It requires two players *in a group* on the launcher path, which had
never happened. The code comment at `group_manager.gd:31-34` asserts the legacy RPCs are dead
code in launcher mode "because the action methods route through Net early-return paths". True of
the action methods. `_flush_stats` is signal-driven and was missed.

---

## 5. Not covered by this session

Worth knowing what was *not* tested, so nobody assumes it was:

- **Corpse retrieval.** She died twice but never looted her own corpse, so the owner-only
  retrieval path has still only been exercised by the author.
- **Bank, vendors, trading, crafting.** Untouched.
- **Quests.** Untouched.
- **The bank Items-tab non-bug** (deposit appears to vanish). Not hit, so the pre-warning in
  `README_FOR_TESTERS.md` is still untested against a real reaction.
- **Client-only spells.** Not hit; she was level 1 to 2 throughout.
- **Reconnect after an unclean kill** (window X). She logged out cleanly both times.

---

## 6. Operational notes

- Server load stayed trivial throughout: two connected clients, tens of MB of RAM, seconds of
  CPU over the session.
- No `ERROR` lines, and no `WARN` lines other than the rate-limit rejection, which is logged at
  INFO by design for operator visibility.
- The client build in use was the 2026-08-10 15:49 export, which included the same day's
  `hud.gd` and remote-manager fixes.
