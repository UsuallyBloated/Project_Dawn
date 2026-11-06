# Client-authority audit, 2026-10-19

**The rule (user, 2026-10-19):** "Events happening on the client are a no-go." The client may
show or predict a number; the server decides every outcome. This audit looked for every place
where, online (launcher mode), the client decides or changes a game outcome that the server
either does not know about or computes differently.

**How it was done:** a read-only sweep of both repos (client autoloads and scripts, the
server's world module and the wire protocol), then the serious findings re-read by hand in
the code before this document was written. Line numbers are as of 2026-10-19 (client
`381e489`, server `33c7e28`). Paths: client under `F:\Projects\Project_Dawn`, server under
`crates/projectdawn-server/src/world/`.

Three kinds of finding:

- **(c) Trust hole:** the server applies a value the client chose. Exploitable by a modified
  client.
- **(b) Client-only:** a gameplay effect that exists only on the client; online it silently
  does nothing (or something different).
- **(a) Display-only:** the server's outcome stands; the client just shows a different number.

## (c) Trust holes

1. **Movement speed is client-chosen, and Spirit of Wolf counts twice.** VERIFIED.
   `scripts/player.gd:493` sends a direction of length `current_speed / 7.5`, where
   `current_speed` is 5.0 x `MountManager.get_effective_speed_mult()` (the mount's
   multiplier, or `BuffManager.get_speed_mult()`) x `Encumbrance.get_speed_mult()`. The server
   clamps the length to 1 (`handlers.rs` Move arm) and multiplies by `MAX_MOVE_SPEED` (7.5) x
   its own speed buff x snare (`tick.rs` ~9617). So a modified client runs at 7.5 m/s, 1.5x
   the honest 5; an honest client under Spirit of Wolf (1.4) gets it twice (about 9.8 m/s);
   mounts, carry weight and Selos' Melody work online only through the client's number; the
   server has no encumbrance and no mount model.
2. **Melee misses are rolled only on the client.** VERIFIED. `autoloads/combat.gd` rolls the
   weapon-skill miss chance (and the 0.5x wrong-weapon-type penalty, accuracy buffs) and simply
   does not send the Attack on a miss. The server "always lands the hit" (`combat.rs` header)
   and applies no weapon-skill multiplier. A modified client never misses.
3. **Forged combat text, and since 2026-10-14 a forged stand.** VERIFIED. `HitBroadcast`,
   `MissBroadcast` and `EvadeBroadcast` (`handlers.rs` ~683) are relayed to peers with a
   client-chosen target, amount and crit, ungated; only the Test Panel sends them. The victim's
   client stands on any incoming Hit (`remote_player_manager.gd::_on_hit`, the seated-combat
   client change `2495276`) and `regen.gd` forwards the Stand to the server, so a forged hit
   would cancel another player's seated regen and `/camp`. Not live: `2495276` rides the
   Oct 22 export.
4. **Spell gems are not checked by the server.** VERIFIED. The server has no memorized-spell
   state; the cast gate checks class and level only, and the memorize mana cost is spent only
   locally (`autoloads/memorize.gd:169`). A modified client casts any spell its class and level
   allow without memorizing it.
5. **Cast-bar length is client-chosen for display** (`CastStartBroadcast.duration`). The
   cast-time gate uses the server's own `spell.cast_time`, so this only draws a wrong bar.
6. **Attack speed (haste) is client-paced.** Known and documented since 2026-07-29: the swing
   limiter assumes full haste for everyone (`MAX_MODELED_HASTE`), a bounded residual.

## (b) Client-only effects

1. **Active skills** (`autoloads/skills.gd`): stamina and cooldown spent only locally,
   `UseSkill` never sent, damage multipliers discarded. Already the To-Do "Active skills partly
   do not work online".
2. **Bard song pulses** (`autoloads/bard_songs.gd`): Poet's Mending heals into PlayerStats
   unguarded; Mana Weave and Anthem do nothing online. Already the To-Do "Bard song rework".
3. **Heal and nuke stat bonuses.** VERIFIED. `autoloads/spells.gd:350-378` adds
   `WIS x 0.3` to heals (and pet heals) and `INT x 0.5` to nukes, times the alignment
   effectiveness; the server deals flat `base_damage` / `heal_amount`. The casting-skill
   multipliers (evocation damage, alteration duration, abjuration absorb) are client-only too.
4. **Alignment** (`autoloads/alignment.gd`): no server counterpart; `modify_alignment` has no
   callers, so the alignment multiplier is dormant at starting scores. The Fallen and Redeemed
   spell lists are unreachable.
5. **Weapon, armor and evasion skill effects**: trained on the server, applied only on the
   client.
6. **Nine client-only spells** run local effects before the server refuses them: Camouflage
   gives local stealth, Exsanguinate adds mana locally.
7. **Fall damage** sends the dev-gated `DamageSelf`, so online it does nothing while the chat
   says "You hit the ground hard".
8. **Sense Heading, Languages, Transformations**: client-only and reset each launch, or dead
   code.

## (a) Display-only

AOE damage numbers (`combat.gd` with the client's own INT and alignment math), self-buff
magnitudes and durations, the character sheet's AC (`equipment.gd` adds AGI/4 and the armor
skill), rubber-banding when snared (the server slows movement; client prediction does not),
and the client's own "not enough stamina" checks reading drifted values.

## The plan (user, 2026-10-19: "go ahead with recommendations")

| # | Fix | Where |
|---|---|---|
| 1 | The server stops relaying client-made hit, miss and evade messages; they become GM-only, gated and audited like the other dev commands | deploy branch, server only |
| 2 | Movement speed decided by the server; mounts and carry weight get server models or refuse online | deploy branch |
| 3 | Heal and nuke stat bonuses and the casting-skill multipliers computed on the server | deploy branch |
| 4 | The melee miss roll and weapon-skill damage on the server | deploy branch |
| 5 | Memorized spell gems tracked by the server | needs a wire message |
| 6 | Active skills, Bard songs, alignment, fall damage | their own builds |

Each fix gets a test written to fail on the code it replaces. Status lives in the CLAUDE.md
To-Do entry "Client-decided outcomes", never here.
