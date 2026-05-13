# Track 5 finish — sub-task 5 only (kill credit + XP)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client,
companion Rust server (auth WS + world UDP), Godot launcher,
standalone procedural dungeon generator. Four repos, four branches.

Tracks 1–4 closed the server-authoritative loop for **player state**.
Track 5 sub-tasks 1–4 closed it for **enemies** (spawn, AI, HP, death,
loot). What's left: **kill credit + XP grant**. Server already tracks
per-attacker damage in `entity.aggro: HashMap<EntityId, f32>`; sub-task
5 resolves "who killed it" and routes a private `XpGained` to that
client. Estimated half a session.

Track 6 (server-authoritative player stats + PvP HP) comes after this,
gets its own handoff.

## Four repos at handoff

| Repo | Path | Branch | Latest commit |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `master` | `cadd44e` (Session notes: 2026-05-13 — Track 5 server-authoritative enemies + loot) |
| Server | `F:\Projects\server\` | `main` | `7828f5d` (tests: bump AI-wait timeouts to ride out parallel-cargo contention) |
| Launcher | `F:\Projects\launcher\` | `main` | `18da871` (protocol.gd: add SW_ENEMY_SPAWN / SW_ENTITY_TARGET tags (mirror)) |
| Procedural dungeon | `F:\Projects\ProceduralDungeon\` | `master` | `dbb24e7` (Light placer: split DEBUG_LABELS into DEBUG_TORCH_LABELS / DEBUG_COMPASS) |

Run `git -C <each> log --oneline -5` before touching anything.

## Read these in order

1. `CLAUDE.md` — project conventions. **Do NOT modify.**
2. `docs/session_notes/session_2026_05_13.md` — full Track 5 close including
   the trust model and tick-loop phase ordering.
3. `crates/protocol/src/world.rs` — `ServerWorldMsg::XpGained { amount,
   current, to_next }` already exists from Track 4 scaffolding. Reuse
   it. **No protocol bump needed** — PD_W0004 stays.
4. `crates/projectdawn-server/src/world/entity.rs` — `Entity.aggro:
   HashMap<EntityId, f32>` field. Populated in `tick.rs` step 4h on
   every successful Attack apply. Cleared never (stays around for
   sub-task 5 read).
5. `crates/projectdawn-server/src/world/tick.rs` lines around 670–770
   — step 4h's enemy-death branch is where the EntityDied fan-out and
   loot roll already live. XP resolution goes here too.
6. `crates/projectdawn-server/src/world/handlers.rs` — existing
   `send_loot_granted` (private message, one recipient) is the exact
   pattern to mirror for `send_xp_gained`.
7. `crates/gdext-net/src/lib.rs` — top-of-file doc lists 21 decoded
   message types; `XpGained` is NOT among them. Falls through to
   `unhandled_server_message`. Add a typed signal.
8. `autoloads/net.gd` — re-emit handler pattern for new server-side
   signals. `_on_loot_granted` is the closest analog.
9. `autoloads/player_stats.gd` — `gain_xp(amount: int)` already
   exists and handles current-XP / to-next math + level-up cascade.
   Just call it.

---

## Scope

Solo XP only. Group XP migration off the legacy enet path is **out
of scope** — GroupManager still uses Godot's enet MultiplayerAPI for
local-LAN multi-player, which is a separate concern. Server only
knows about renet-connected clients. Killing solo grants the killer
XP; killing in a "group" (no real group in launcher mode) grants the
top damager XP. That's fine for the MVP.

## What's already in place

- `Entity.aggro: HashMap<EntityId, f32>` accumulates damage per
  attacker on every Attack apply in `tick.rs` step 4h. Look for:

  ```rust
  *entity.aggro.entry(intent.attacker).or_insert(0.0) += amount as f32;
  ```

- `MobTemplate.xp: i32` is the kill reward. Currently has
  `#[allow(dead_code)]` because sub-task 5 hadn't landed; remove the
  allow once you read the field.

- `ServerWorldMsg::XpGained { amount: i32, current: i32, to_next: i32 }`
  is defined in `crates/protocol/src/world.rs`. `current` and
  `to_next` are placeholders — the server doesn't track player XP
  state (that's client-authoritative until Track 6). Send `0` for
  both; the client ignores them and computes via PlayerStats.gain_xp.

- `PlayerStats.gain_xp(amount: int)` in
  `autoloads/player_stats.gd:148` is the existing single-player XP
  entry point. Drives level-up, signals, etc.

---

## Implementation plan

### Commit 5.5A — server (single commit)

**`crates/projectdawn-server/src/world/handlers.rs`** — add:

```rust
/// Track 5 sub-task 5 — private XP grant to the kill-credit recipient.
/// Mirror of send_loot_granted's shape; one client only, reliable
/// channel. `current` / `to_next` left as 0 because the server doesn't
/// track player XP state in Track 5 (client-authoritative); Track 6
/// will populate them.
pub fn send_xp_gained(
    server: &mut RenetServer,
    recipient_id: ClientId,
    amount: i32,
) {
    let msg = ServerWorldMsg::XpGained {
        amount,
        current: 0,
        to_next: 0,
    };
    if let Some(bytes) = encode(&msg) {
        server.send_message(recipient_id, CHANNEL_SYSTEM, bytes);
    }
}
```

**`crates/projectdawn-server/src/world/tick.rs`** — in step 4h's
enemy-death branch (the `if entity.hp <= 0.0` block), AFTER
`fan_out_entity_died` and BEFORE the loot roll, add top-damager
resolution and XP grant. Pseudocode:

```rust
// Top damager from aggro_table. Iteration order on HashMap is
// non-deterministic, so use max_by with a stable tiebreak (just take
// the first max — for solo play there's only one entry anyway).
if let Some((&credit_id, _)) = entity.aggro.iter()
    .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
{
    let xp = entity.mob.xp;
    if xp > 0 {
        let cid = credit_id as ClientId;
        if connections.contains_key(&cid) {
            handlers::send_xp_gained(&mut server, cid, xp);
            tracing::info!(
                killer = credit_id,
                mob = %entity.mob.name,
                xp,
                "kill credit granted"
            );
        }
    }
}
```

**`crates/projectdawn-server/src/world/zones.rs`** — remove the
`#[allow(dead_code)]` on `MobTemplate.xp` (it's read now).

**Integration test in `tests/world_two_clients.rs`** — extend the
existing `player_attack_kills_enemy_and_corpse_despawns` test or add
a new one. After the one-shot Attack on the Decrepit Skeleton,
assert `XpGained { amount = 10, .. }` arrives. Camp 0's authored
xp is 10. Generous timeout (5s) for parallel-cargo contention.

Run `cargo test --release` — expect 27 + 1 = 28/28 passing if you
add a new test, or 27/27 if you extend the existing one.

### Commit 5.5B — gdext-net (single commit)

**`crates/gdext-net/src/lib.rs`** — three additions:

1. New `#[signal] fn xp_gained(amount: i64, current: i64, to_next: i64)`
   declaration. Place near the existing `hit` / `miss` / `evade` signals.

2. New `Incoming::XpGained { amount: i32, current: i32, to_next: i32 }`
   variant in the enum.

3. New `classify` arm:
   ```rust
   ServerWorldMsg::XpGained { amount, current, to_next } => Incoming::XpGained {
       amount,
       current,
       to_next,
   },
   ```

4. New `fire` arm:
   ```rust
   Incoming::XpGained { amount, current, to_next } => {
       self.base_mut().emit_signal(
           "xp_gained",
           &[
               (amount as i64).to_variant(),
               (current as i64).to_variant(),
               (to_next as i64).to_variant(),
           ],
       );
   }
   ```

5. Top-of-file doc: bump "21 message types" → "22 message types"
   and add `XpGained` to the list.

Rebuild + copy:

```powershell
$env:RUSTFLAGS = "-C target-feature=+crt-static"
cd F:/Projects/server
cargo build -p gdext-net --release
Copy-Item -Path "F:\Projects\server\target\release\gdext_net.dll" `
          -Destination "F:\Projects\Project_Dawn\addons\gdext_net\gdext_net.dll" -Force
```

Note the build script issue from Track 3 still applies — use the
inline cargo + Copy-Item path, not `addons/gdext_net/build.ps1`.

### Commit 5.5C — Project_Dawn client (single commit)

**`autoloads/net.gd`** — three additions, all mirroring the existing
`world_loot_granted` shape:

1. `signal world_xp_gained(amount: int, current: int, to_next: int)`
   near the other Track 5 signals.

2. In `_ready`: `xp_gained.connect(_on_xp_gained)` next to
   `loot_granted.connect(_on_loot_granted)`.

3. New handler:
   ```gdscript
   func _on_xp_gained(amount: int, current: int, to_next: int) -> void:
       world_xp_gained.emit(amount, current, to_next)
       PlayerStats.gain_xp(amount)
   ```

   The direct PlayerStats call here is consistent with how
   `RemoteLootBagManager._on_loot_granted` calls `Inventory.add_item`
   — receive-side handlers may invoke autoloads directly.
   `current` / `to_next` are placeholders (0 from server); ignored
   because `PlayerStats.gain_xp` computes them internally.

**Where you do NOT need changes:** `enemy.gd` (no-modify; Test Room
flow stays untouched), `GroupManager` (legacy enet path; out of
scope), `RemoteEnemy` (server owns death lifecycle; no client-side
XP signal needed).

---

## Verification plan

Manual two-`.exe` test (after re-exporting the game):

- [ ] Two clients connect; both walk into camp 0; one client kills a
      Decrepit Skeleton with auto-attack. The killer's character
      window / HUD shows XP gain (10 XP for a Decrepit Skeleton).
- [ ] The non-killer client gets no XP (top-damager-only semantics).
- [ ] Level-up cascade still works (the existing
      `PlayerStats.gain_xp` handles `level_up` signal emission and
      stat recalc; verify by killing enough mobs to level).
- [ ] Logged-in solo (one .exe), kill a mob → XP grant. No
      regression.

Automated: `cargo test --release` 27+/27+ depending on whether you
add or extend a test.

---

## Hard rules (carry forward)

- `CLAUDE.md` and `addons/procedural_dungeon/` stay no-modify.
- `scripts/net/protocol.gd` MUST stay 1:1 between Project_Dawn and
  launcher. **No mirror needed for 5.5** because the wire only adds a
  send-side signal, not a tag the GDScript side encodes —
  `XpGained` is server-to-client and the GDScript protocol.gd is for
  client-to-server tag references. (Track 1–4 added SW_ENTITY_SPAWN,
  SW_ENEMY_SPAWN etc. as documentation-only mirror constants; you can
  add `SW_XP_GAINED := "XpGained"` to both if you want full
  consistency, but the wire doesn't depend on it.)
- The Rust `protocol` crate is canonical. **No `WORLD_PROTOCOL_ID`
  bump** — PD_W0004 already covers the Track 5 batch and `XpGained`
  is a pre-existing variant whose shape doesn't change.
- `PROJECTDAWN_NETCODE_KEY` is sacred. Never logged, committed, or
  in test fixtures.
- Re-export the game after the gdext-net DLL changes (5.5B) and
  client GDScript changes (5.5C) before multi-instance testing.

## Process

- Match commit-message tone per repo. `git log --oneline -5` before
  writing one. HEREDOC body, blank line, Co-Authored-By footer.
- One commit per repo per logical change (5.5A server, 5.5B gdext-
  net, 5.5C client = 3 commits total).
- After the session, write `docs/session_notes/session_YYYY_MM_DD.md`
  and update the index. (Today's was 2026-05-13; if you're on a new
  day, create a fresh file.)
- User wants terse responses; no end-of-task recaps.

## Open questions

None expected. The architecture is locked in:

- **Solo kill credit only** for sub-task 5. Group XP via the legacy
  enet path stays as-is.
- **Server sends amount; client owns current/to_next.** Carries
  Track 4's trust model unchanged.
- **No protocol bump.** XpGained variant pre-existed; only the
  receive-side gdext-net signal is new.

If anything in the implementation plan looks ambiguous, ask before
the first commit lands.

## When you're done

Write `handoff_track_6.md` for the next session — server-authoritative
player stats + PvP HP. That's the big architectural piece; biggest
remaining sub-task before the netcode is alpha-complete.
