# Bard Song Rework (design note, not built) — 2026-06-22

Captured while triaging a Slice 0 playtest note ("bard heal songs are a self-cast one-shot; I want
them to work like Selo's and show in the buff window"). Bard is a **subsystem rework**, not a bug fix,
so it gets its own track. This note records what exists, why it's half-built, and what "doing it
right" needs, so the next session starts from facts.

## The defining feature: weaving

Bards keep several songs' effects up at once by **rapidly cycling** (twisting) 3-4 songs. Each song
"pulses" its effect every `PULSE_INTERVAL` (3s) and the effect **lingers** `PULSE_INTERVAL + 0.5s`,
so cycling fast enough keeps all of them live. This timing-and-linger dance is the bard's identity, so
any rework has to model it deliberately, not as a side effect.

## What exists today (and why it bounces)

- **Client:** `autoloads/bard_songs.gd` holds one `_active_song`, auto-pulses `_pulse()` every 3s.
  `_pulse` applies the song's fields: speed/haste/mana-regen/accuracy/crit/absorb all go through
  `BuffManager` (lingering buffs that DO show in the buff window), but `heal_amount` does a raw
  `PlayerStats.set_hp(+heal)` — a one-shot, no buff-window entry, and in launcher mode it fights the
  server (the HP-bar bounce). Songs are `is_song: true`, `target_type: SELF`, cast_time 0, cooldown
  0.5 (`data/spell_definitions.gd`: Selos' Melody, Poet's Mending, Anthem of the Hunt, Wanderer's
  Chord, Mana Weave, Aria of Dismay).
- **Server:** has HoT infra (`world/tick.rs` applies `hot_hps`/`hot_duration` as `ActiveBuff::new_hot`
  on cast; `world/buffs.rs`), BUT a song's auto-pulse **never re-broadcasts**, so the server applies a
  song's effect exactly **once** on the initial cast. There is NO server-side notion of an "active
  song" or a pulse clock. So every song's sustain is faked client-side; the server-side effect decays
  after one duration unless the player manually re-casts.

Net: the heal song bounces because the client pulse-heals locally while the server doesn't pulse. The
other effects "work" only because their lingering buff is re-applied client-side each pulse, and (for
movement) the server speed buff likely also decays between manual re-casts but is less noticeable.

## What a proper rework needs

1. **Server-authoritative active-song state.** The server tracks the bard's current song + a pulse
   clock and applies the effect each pulse (so heal/speed/etc. are real and sustained, no bounce). A
   light-touch alternative is a dedicated low-cost "song pulse" intent the client sends each tick that
   re-applies the effect without re-charging full mana/cooldown — decide which.
2. **Weaving model.** Per-effect linger durations + the timing window, server-side, so cycling songs
   stacks their buffs the way the mechanic intends. Mana drain over time is part of the feel — decide
   the cost cadence.
3. **Heal as a HoT buff.** Make heal songs register a HoT (buff-window-visible, like the other song
   effects) rather than a raw `set_hp`; the server pulses it. This is the piece the playtest asked for.
4. **Buff window:** every active song's effect should appear (heal included), with its lingering timer.
5. **Wire:** likely a song-state or song-pulse message (bump the protocol); keep client→server to
   primitives (gdext can't encode tagged enums).
6. **Scope spans both repos:** data (spell defs + `spells.toml`), `bard_songs.gd`, `buff_manager.gd` +
   the buff window UI, server tick/buff handling, and the wire.

## Decisions to make with the user before building

- The **feel**: how fast should weaving be, how punishing is dropping a song, how much mana does
  sustaining cost? (The "general vibe" the user wants to define.)
- Server-pulse-every-tick vs a re-cast/pulse intent (cost + wire trade-off).
- Whether Selo's-style movement already decays server-side and should be fixed in the same pass.

See also: [[project-launcher-clientonly-gaps]] (bard songs + other client-only systems) and the
Slice 0 playtest follow-up in `docs/session_notes/session_2026_06_22.md`.
