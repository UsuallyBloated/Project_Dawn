# Track 6 Post-Fix Playtest Checklist — 2026-05-15

Covers the five fixes landed in commits `9ab261f` (server) and `27f2549` (Project_Dawn). Re-export Project_Dawn and restart the server with the new build (`PD_W0006` protocol) before running.

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server (release build)
- [x] Two clients logged in: A (leader) and B

## Fix 1 — Stat-buff + damage-shield HUD icons
Earlier: Bless / Valor / Spirit of the Bear / Brilliance applied stats but no icon appeared. Damage shields (Thorns, Spellshield) had the same gap.

- [x] Cast **Bless** on self → gold-bordered "primary_stat" icon shows with countdown
- [x] Cast **Valor** → icon appears; max_hp rises by 50
- [x] Cast **Spirit of the Bear** (Shaman) → icon + STR/CON rise
- [x] Cast **Brilliance** (Enchanter) → icon + INT/WIS rise
- [x] Cast **Thorns** → orange "damage_shield" icon shows with countdown
- [x] Cast **Spellshield** → same icon kind, different name
- [x] All five icons disappear when their countdown reaches 0

## Fix 2 — Dispel HUD sync (Antimagic Ward / Expose)
Earlier: dispel removed the server-side buff but the caster's HUD icon lingered until logout. Reconciler now clears local buffs missing from the server snapshot.

- [x] `/pvp on` on both clients
- [x] A casts **Spirit of Wolf** on A → A sees speed icon
- [x] B casts **Antimagic Ward** on A → A's speed icon disappears within ~1 tick; speed buff effect ends
- [x] Repeat with **Expose** instead of Antimagic Ward → same result
- [x] Repeat with a stat buff (Bless) being dispelled → icon clears and stats revert

## Fix 3 — Full Heal test panel button
Earlier: clicking Full Heal made HP jump to max then snap back to original within one server tick.

- [x] In Test Panel, take damage to drop HP (use Damage Self or get hit)
- [x] Click **Full Heal** → HP rises to max and stays there
- [x] MP and Stamina also fill (these stay local — may briefly flicker if a regen tick lands)

## Fix 4 — Group roster on /leave and /kick
Earlier: 2-person groups dissolving via /leave or /kick left the surviving member's HUD showing the old roster.

- [x] A invites B; B accepts; both clients show the 2-person roster
- [x] B types `/leave` → B's HUD clears (already worked); **A's HUD now clears too** (this is the fix)
- [ ] Repeat with 3-person {A, B, C}, then C `/leave` → A and B still see a 2-person roster (group survives)
- [x] In a 2-person {A, B}, A `/kick B` → both A's and B's HUDs clear
- [ ] In a 3-person {A, B, C}, A `/kick C` → A and B see updated 2-person roster, C's HUD clears

## Fix 5 — Absorb HUD sync (Rune / Primal Bond)
Earlier: absorb icon ("Shield 40hp") never drained in launcher mode because incoming damage arrived via HealthUpdate rather than consume_absorb. The local pool was a cosmetic lie; protection actually worked server-side. Now icon clears when the server depletes the absorb buff.

- [-] Cast **Rune** (Enchanter) → "Shield 40hp" icon appears. note: Doesnt appear to work.
- [-] Take enough damage to exhaust the pool → icon disappears
- [x] Cast **Primal Bond** (Beast Master) → icon appears
- [x] Take damage → HP doesn't drop while absorb is active; icon clears when pool is gone; damage starts hitting HP after

## Fix 6 — Buff duration drift (thorns reflect after expire)
Earlier: local timer ticked at 60Hz, server at 20Hz, so the local buff icon could expire ~50ms before the server stripped the buff. Players observed "thorns reflected after I lost the buff." Reconciler now syncs each named buff's remaining time to the server's value every snapshot.

- [x] Cast **Thorns** with a long duration (e.g. 60s)notes: Duration 600s
- [ ] Watch the HUD countdown next to the server's expected timer. The local countdown should not race ahead of the server.
- [ ] Let the buff expire naturally → no reflect damage to attackers after the icon disappears (within a single tick)

## Fix 7 — Damage-shield combat log line
New: when a shield reflects damage, the defender's combat log shows `"<attacker> has been hit by N damage from <shield_name>."` and a floating number renders on the attacker.

- [x] Cast **Thorns** on A. Have an enemy (or B with /pvp on) attack A.
- [x] A sees combat log line e.g. `"Greth has been hit by 8 damage from Thorns."`
- [x] Floating damage number appears on the attacker
- [x] Same for **Spellshield** (label reads "from Spellshield")

## Fix 8 — Spellbreak silence feedback
Earlier: silenced player cast spells locally with mana drain but nothing happened; no feedback. Now server fans CastFail with a reason.

- [x] B casts **Spellbreak** on A (with /pvp on)
- [x] During the 4-second silence, A tries to cast any spell → combat log shows `"Cast failed: Silenced."`
- [x] Local cast bar cancels (if a slow-cast spell was attempted)
- [x] After 4s, casting works normally again
- [x] Same flow for **Mesmerize** → log shows `"Cast failed: Mesmerized."`

## Fix 9 — Debuff HUD bar
New panel to the right of the buff bar. Subscribes to BuffSnapshot and renders icons for incoming CC (mez / root / snare / attack_slow / silence).

- [x] B casts **Mesmerize** on A → A sees a purple-bordered "Mesmer" debuff icon with countdown
- [x] B casts **Ensnare** on A → brown "Ensnare" icon
- [x] B casts **Snare** on A → orange "Snare" icon (and A moves slower)
- [x] B casts **Slow** on A → blue "Slow" icon (and A's attacks slow)
- [x] B casts **Spellbreak** on A → yellow "Spellb" icon
- [x] All icons disappear when their countdown reaches 0
- [x] Multiple debuffs can show simultaneously (e.g. Snare + Slow)

## Open items (not yet addressed)
- **Peer-target heals**: healing spells still self-cast only. Needs `ALLY` target_type design (RemotePlayer as target, server routing).
- **Primal Bond effectiveness**: server-side absorb is confirmed identical to Rune. If after this patch Primal Bond still feels weaker than Rune, capture the server log lines around the cast and the next few hits.
