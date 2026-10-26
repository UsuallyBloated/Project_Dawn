# Fall damage on the server (design, 2026-10-23)

Housekeeping audit Phase 4, item 1 (`docs/security/housekeeping_audit_2026_10_23.md`, B1). The
user decided on 2026-10-23 that falls get a server model and `DeathBroadcast` goes away when it
lands. This is the design pass that decision called for. Nothing here is built. Section 7 lists
the calls that belong to the user.

## 1. What exists today (verified 2026-10-23 on `feat/server-speed`, both repos)

**Client.** `scripts/player.gd` runs gravity (`GRAVITY = -20` m/s²), tracks the peak downward
speed while airborne, and on landing calls `_on_land()`: no damage at or below
`FALL_DAMAGE_THRESHOLD` (9 m/s, a 2.0 m drop), otherwise `(peak - 9) x FALL_DAMAGE_MULT (5)` HP
through `Combat.receive_player_damage(dmg, null, "Fall")`. That function rolls AGI evasion,
applies armor, drains absorb shields, and then, **online**, sends `DamageSelf`.

**Server.** `DamageSelf` is a dev command (`handlers.rs`, `dev_cmd_allowed`): for an ordinary
player it is silently ignored. For a GM it applies and writes a `gm_actions` row
(`damage_self ... via=gm`) on every fall.

So, today, online:
- **An ordinary player takes no fall damage at all.** The client prints "You hit the ground
  hard for N damage." and a damage number; the server never moves the HP bar. This has been so
  since `DamageSelf` was dev-gated, and nothing recorded it.
- **A GM takes fall damage**, and each fall is audited as a GM action.
- **A fall can never cause a death** for an ordinary player, so the reason `DeathBroadcast`
  exists ("death causes the server doesn't simulate (e.g. client-side fall damage)", its own
  comment) does not apply online.

**`DeathBroadcast`.** Ungated; it runs `kill_player` on the sender if not already dead: an
instant death on demand (B1: a free trip to the bind point, wiping every mob's hate, at no XP
cost below level 5). Online the client sends it only from `PlayerDeath._die()`, which fires when
HP reaches 0, and online HP comes only from the server, whose death sweep has already processed
that death; the honest send is always a no-op. **One honest dependant:** the Test Panel's
"Trigger Death" button (`test_panel.gd`, `_trigger_death`) sets HP to 0 locally, and the death
reaches the server only through `DeathBroadcast`. It is a GM testing tool for the corpse and
resurrection path and must keep working.

**Server Y.** None. The Move handler zeroes Y ("server does not simulate gravity or jumping"),
`step_toward` keeps a mob's spawn Y, and the world is a flat 400 x 400 m mesh with every height
0.0. A fall can only happen off scene geometry today. Real falls need the server height model
(`docs/session_notes/handoff_server_height_model.md`, not built), whose invariant 4 already
names fall damage as the open question this doc answers.

No Levitate or Feather Fall spell exists on either side.

## 2. How other games do it

- **EverQuest (EQEmu's server, `zone/client_packet.cpp`, `Handle_OP_EnvDamage`).** The client
  computes the damage and sends it in `OP_EnvDamage`; the server applies it after its own
  modifiers (fall-damage reduction from spells, items and AAs; no damage in water; GMs and
  invulnerable characters take 1). The server never checks the height. A client that does not
  report a fall takes nothing.
- **World of Warcraft (TrinityCore's server, `Player::HandleFall`).** The server computes the
  damage itself from the height between where the fall began and where it ended:
  `damage% = 0.018 x (drop - safe_fall) - 0.2426` of max health, zero below 14.57 yards
  (13.3 m), all of it by about 69 yards (63 m); Feather Fall, hover, flying and physical
  immunity skip it; GMs are immune. The heights are still the client's reported positions
  (WoW movement is client-reported), so the formula is the server's but its inputs are not.
- EQ also had a **Safe Fall** skill (Monk, Rogue, Bard) and fall-reducing items; WoW has Safe
  Fall auras. Both reduce a fall rather than decide one.

Neither model fits this project's rule ("Events happening on the client are a no-go"): the
client here never sends a position, only a direction, so the server can own both the formula
and its inputs, which neither reference does.

## 3. The design

### 3.1 Slice 0: close B1 now, without the height model

The fall model needs the height model, which is weeks out. `DeathBroadcast` does not have to
wait for it (section 1). Two small changes:

1. **Server:** `DeathBroadcast` becomes a dev command. Keep the existing early return for an
   already-processed death first (so an honest client's redundant send writes nothing), then
   `dev_cmd_allowed(..., "death_broadcast", ...)`. A GM's Test Panel "Trigger Death" keeps
   working and is audited; an ordinary player's forged death is ignored. No wire change, no
   client change needed, works with every client testers hold.
2. **Client, next export:** online, `_on_land()` no longer calls `receive_player_damage`. It
   is dead for ordinary players already, and for a GM it lets AGI "evade" a fall, lets armor
   reduce it, drains absorb shields client-side, and writes an audit row per fall. Online a fall
   then does nothing until slice 1 (exactly what ordinary players get today), and the Test
   Panel's "Trigger Death" moves to a dev `DamageSelf` of the full HP, so the death runs through
   the server's own sweep. After that export, `DeathBroadcast` has no honest sender and its
   handler can be deleted (the variant stays as a positional placeholder until the next bump's
   wire hygiene, B6).

### 3.2 Slice 1: the server simulates the fall (rides height model slice 1)

The server already integrates each player's XZ every tick from the Move direction. With a ground
sampler `ground(x, z)` from the height model, it adds a vertical state per connection:
`airborne: bool`, `y: f32`, `vy: f32`.

Each tick, after the XZ step:
- **Grounded:** if the new ground is at most `max_drop` below the current Y, follow it
  (`y = ground`). `max_drop` is what the client's `CharacterBody3D` follows without leaving the
  floor: the horizontal step times `tan(floor_max_angle)` (55° in `player.gd`) plus
  `floor_snap_length` (0.5 m). Otherwise the player walked off an edge: `airborne = true`,
  `vy = 0`.
- **Airborne:** `vy -= 20 x dt`, `y += vy x dt`. When `y <= ground`, land: `y = ground`,
  `airborne = false`, impact speed `-vy`, and damage by the formula (section 3.3).

The landing damage is environmental: no attacker, no XP or kill credit to anyone (PvP included),
the ordinary seated and camp rules through `note_damage_taken`, death through the ordinary death
sweep with the corpse where the body landed. The player is told with a system line, "You hit the
ground hard for N damage.", and the HP bar moves by the server's `HealthUpdate`. The client
keeps its own gravity for drawing its body and stops computing damage online.

**Teleports land standing.** Gate, Succor, Evacuate, respawn, resurrection and entering the
world set `y = ground` and `airborne = false`, so a move onto lower ground is never a fall. A
fall already in progress is resolved before the move (ledger row 6).

**Mobs and pets do not take fall damage.** They stay pinned to the ground by the height model's
`step_toward` change; a mob chasing off a cliff simply follows the ground (straight-line pathing
is unchanged by design, per the height model handoff).

**The jump stays cosmetic.** The server does not add the jump's 1.2 m to a fall. Counting it
could only add damage, so a client that hides its jump flag gains at most 1.2 m of drop; not
counting it keeps the server free of a client-supplied vertical input (the height model's
invariant 1).

### 3.3 The formula (a user call, section 7)

Today's client formula is flat HP by impact speed. Its numbers against the EQ parity pools
(2026-10-20):

| Drop | Impact speed | Damage | |
|---|---|---|---|
| 2.0 m | 9.0 m/s | 0 | the safe drop |
| 5 m | 14.1 m/s | 25 | |
| 5.3 m | 14.6 m/s | 28 | kills a level 1 Warrior (28 HP) |
| 10 m | 20.0 m/s | 55 | |
| 20 m | 28.3 m/s | 96 | |
| 50 m | 44.7 m/s | 178 | a level 50 Warrior (1,886 HP) shrugs it off |

A share of max HP (WoW's shape) instead hurts every level alike: under TrinityCore's numbers,
0 at 13.3 m and all of it at 63 m.

## 4. Exploit ledger

| # | Attempt | Answer |
|---|---|---|
| 1 | Decline to report a fall (today's hole: a modified client never sends `DamageSelf`; EQ's hole too) | Slice 1: the server decides from its own XZ and its own ground. Nothing to report. |
| 2 | Forge a death for a free trip home and a hate wipe (B1) | Slice 0: `DeathBroadcast` is a dev command; then deleted. |
| 3 | Forge or hide the jump flag to change a fall | The jump never enters the fall (3.2). |
| 4 | Log out mid-fall to skip the landing | An airborne `Disconnect` is treated as an unclean exit: the body stays in the world, finishes the fall on the server, takes its damage, then reaps (the linkdead path, which already lingers 30 s). The character is never saved in mid-air. |
| 5 | Crash or window-X mid-fall | Already the linkdead path: the server keeps simulating the body. |
| 6 | Teleport onto low ground and take damage, or a teleport cancelling a fall in progress | Teleports land standing (3.2). A port that lands on an airborne player first resolves the fall where it is (impact speed from the current `vy` and height above the ground, `sqrt(vy² + 2 x 20 x h)`), then moves them, so a port mid-fall cannot erase the landing. |
| 7 | Non-finite position feeding the sampler | The NaN Move gate (built 2026-09-27) plus the height model's total sampler (refuses non-finite, clamps to the edge). |
| 8 | Server ground disagreeing with the client's collision mesh (phantom falls, or missed ones) | The heightmap lockstep check the height model plan requires; `max_drop` errs on staying grounded. |
| 9 | A fall used to kill another player or farm credit | Environmental: no attacker, no credit. |
| 10 | Evading, armoring or shielding a fall | No evasion or armor roll on a fall (today's client applies both); whether absorb shields soak it is a user call (section 7). |

## 5. Lockstep pairs this creates

Gravity (20 m/s²), the damage threshold and multiplier (or the percentage constants), the
client's `floor_max_angle` (55°) and `floor_snap_length` (0.5 m). After slice 1 the client keeps
gravity and the floor values only for drawing its own body, so a mismatch shows as the body
landing a frame early or late, never as different damage; they still belong in a check (the
Phase 4 lockstep item, B4).

## 6. Tests

- Slice 0: an ordinary player's `DeathBroadcast` leaves them alive with no XP change; a GM's
  kills them and writes one `gm_actions` row; an honest send after a real death writes no row
  (each fails on the current handler).
- Slice 1, unit: walking down a 55° slope stays grounded; a step past `max_drop` goes airborne;
  the landing speed for a 10 m drop matches `sqrt(2 x 20 x 10)` within a tick's error; a
  teleport lands standing. Integration: a dev-spawned ledge (or a test heightmap) where a player
  walks off 10 m and the `HealthUpdate` shows the formula's damage; a disconnect mid-fall still
  takes it; a fall to 0 HP leaves a corpse at the landing spot.

## 7. Decisions for the user

**ALL FIVE DECIDED 2026-10-24 (user): "follow your recommendations."** So: slice 0 now; a
share of max HP with the safe drop near 2 m; absorb shields do not soak a fall; GMs take falls
with no audit row; Safe Fall later as its own entry. **Slice 0 BUILT the same day** (server
`779a033` on the deploy branch, merged into `feat/server-speed` as `062ca07`; client `99f649b`
on `feat/server-speed`; `fall_damage_slice0_checklist.md`), **playtested 2026-10-26**. Slice 1
waits on the server height model, and its constants (the percentage slope against a ~2 m safe
drop) are set with it; its fling tool for testing is a server-side GM command, built with it.

1. **Slice 0 now?** It reverses the agreed order (falls first, then `DeathBroadcast`), because
   the reason for that order turned out not to hold online. Recommended: yes, the server half on
   the deploy branch (one handler, works with every client), the client half with the Oct 22
   export.
2. **The formula:** flat HP by impact speed (today's client, harsh at level 1, nothing at 50) or
   a share of max HP (WoW's shape, the same for every level). No EQ formula was found in a
   source, so EQ cannot settle it. Recommended: a share of max HP, with the safe drop kept
   near today's 2 m.
3. **Absorb shields** (Holy Shield, Rune): do they soak a fall? EQEmu and TrinityCore both
   treat a fall as its own damage type; recommended: no.
4. **GMs:** take falls (they test the game) or immune (EQEmu, TrinityCore)? Recommended: they
   take them, with no audit row.
5. **Safe Fall** (EQ's Monk, Rogue and Bard skill) and fall-reducing items: later, as their own
   entry.
