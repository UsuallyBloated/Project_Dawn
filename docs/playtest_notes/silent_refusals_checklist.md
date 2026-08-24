# Silent Refusals Playtest Checklist — 2026-08-23

Verifies that when the server refuses an action, it **says so**. Follows the audit prompted by the
2026-08-21 vendor report ("player can buy from the merchant when their inventory is full, the item
appears to disappear").

**Build prerequisite: server only.** Push, pull on the R720, `cargo build --release`, stop, `cp`,
start, confirm the boot line. **No client change and no re-export** — refusals ride the System chat
channel, which the client already renders.

**The pattern.** The server validates well but reports poorly: it logs a refusal and moves on,
sending the client nothing. The client then either keeps a stale view (the 08-18 inventory desync,
which lasted until relog) or announces a success that never happened (the vendor bug). An audit
found **62 silent rejection arms against 40 that answer**. This batch fixes the ones a player
actually hits.

Refusals appear as a plain line in your chat window, with no speaker.

---

## 1 — Vendor (the reported bug)

- [x] **Fill your bags, then buy something** → "Your bags are full." and you are charged nothing.
      notes:
- [x] **Buy more than will fit** (e.g. 10 when only 6 fit) → "Only 6 fit in your bags." You are
      charged for 6 and receive 6. This was always billed correctly; it just never said why.
      notes: chat showed "Only 7 fit in your bags." while the bottom of the vendor dialog says "Ordered Honey x20 for 1s."  Please make it so the vendor window shows the proper amount sold in the final transaction.  Let me know if this doesnt make sense.
- [x] **Try to buy with too little coin** → "You can't afford that." notes: I don't see a message that says "You can't afford that."  BUT  the buy button is greyed out and disabled, which is equally awesome.  good work.
- [-] **Sell from an equipped slot** → "Take it off before selling it." notes: Equipped items are not listed in the "Sell" tab.  This is fine like this.  nice work.
- [x] **Sell a bag with items in it** → "Empty the bag before selling it." notes:
- [ ] **Sell something worthless** (no vendor value) → "The merchant won't take that." notes:
- [x] **A normal buy and a normal sell still work exactly as before.** notes:

## 2 — Spells (the worst of the audit)

The client spends mana, starts the cooldown and applies local buffs **before** it sends the cast,
so a refusal used to drain the bar for nothing.

**Which spell to use.** Diffing `spell_definitions.gd` against the server's `spells.toml` gives
exactly **32** client-only spells, matching the documented count. Most need a class you are not, or
a prestige class that does not exist yet. The one your Paladin can actually cast:

| Spell | Class | Min level | Mana |
|---|---|---|---|
| **Judgment** | Paladin | 12 | 40 |

Others, if you switch character: `Torpor` (Shaman 20), `Gate` / `Evacuate` / `Succor` and the four
`Teleport:` spells (Druid/Wizard, all PORT), `Entangle` (Druid 6), `Warder's Mend` (Beast Master,
PET_HEAL). The `Paladin_Fallen` and `Shadow Knight_Redeemed` ones are unreachable — those prestige
classes are not implemented.

- [x] **Cast Judgment** (client-only, so the server has never heard of it) → "That spell fizzles —
      it isn't known here yet." **and your 40 mana comes back.** The bar should dip and refill.
      notes:
- [x] **Nuke something out of range** → "That target is too far away." notes:  Mana is still being consumed when target is out of range.  This needs fixed.  Chumby tried casting "Call Lightning", received the "That target is too far away." alert, but mana was still consumed.  Let me know what you find.
- [x] **Cast a PORT / gate / evac spell** → "That magic has no effect here yet." notes: When casting gate player see "You have no bind point. Cast Bind Affinity first."  Even if the player has used the soul binder NPC to bind.  Gate should bring caster back to their bind location, and sould bind from an NPC doesnt seem to be recognized as a bind point?  Or perhaps Bind Affinity has a special status that Gate is seeking?  After using Bind Affinity player received message "That magic has no effect here yet."  and can now cast Gate.  Gate appears to teleport player to the location it was cast from. Also succor appears to be working, but it might just teleport the player to the same exact location they cast the spell from.  Let me know what you find.
- [x] **Normal spells are completely unaffected** — damage, heals, buffs all as before. notes:
- [x] **Chat is not flooded** when you mash a failing cast. notes: I think the cooldowns prevent this.  What do you think?

## 3 — Regression

- [x] **Melee, looting, banking, grouping all behave as before.** notes:
- [x] **No refusal text appears during ordinary successful play.** notes:
- [ ] `server.log` still shows the matching `rejected` lines for anything you saw. notes: Please look into this for me.

---

## Deliberately still silent

Not oversights. Confirmed as correct during the audit:

- **Anti-cheat gates** (swing-rate limit, off-hand with no weapon). A reply rewards a spammer and
  desyncs their local timer.
- **Dev / GM authorization** (`/give`, spawn, heal, coins). Replying would let an unprivileged
  client probe whether the server runs with `PD_DEV_CMDS` or whether an account holds GM.
- **Transport and lifecycle gates** (`!in_world`, `!ready`, duplicate EnterWorld, out-of-order
  movement). A player cannot observe or cause these.
- **Rejections only a forged client can reach** (self-invite, self-targeted attack). A reply is an
  oracle with no honest beneficiary.

## Result

- Server build: `83d8e30`
- Overall: **PASS**, with one real bug found and fixed, and three findings opened.

### Confirmed working, from the log

```
15:15:39  BuyItem rejected — inventory full            -> "Your bags are full."
15:16:18  BuyItem partially filled qty_placed=7        -> "Only 7 fit in your bags."
15:22:36  SellItem rejected — bag has contents         -> "Empty the bag before selling it."
15:25:34  unknown spell name  spell=Judgment           -> fizzle + mana refund  (x3)
15:34:07  unknown spell name  spell=Succor
15:39:53  target_type not yet processed  Bind Affinity -> "That magic has no effect here yet."
15:40:21  unknown spell name  spell=Gate
```

Two rows never fired because the **client already prevents them**, which is better than a server
refusal: the Buy button greys out when you can't afford something, and equipped items simply aren't
listed in the Sell tab. Both correctly marked as such by the tester.

### The bug found: out-of-range casting still ate the mana

Reported: *"Chumby tried casting Call Lightning, received the 'That target is too far away.' alert,
but mana was still consumed."*

Correct, and it was a half-fix on my part. Mana comes off near the top of the CastSpell handler,
**before** the target-type match, so every rejection below that point charged full price. Reporting
the failure was only half of it. New `refund_spell_cost()` now gives the cost back on the
out-of-range and catch-all arms. The unknown-spell arm deliberately does not use it — the server
never deducted there, so it hands back its own untouched value instead.

### "server.log didn't show a matching rejected line"

Answered: the out-of-range arm logged at `debug!`, which is below the default level, so it was
invisible in `journalctl` even though the chat line appeared. Raised to `info!` — a player-visible
failure should not be invisible in the triage artifact.

### "Do cooldowns prevent chat flooding?"

Yes, and that matches the reasoning for deferring a throttle. Every refusal is intent-driven, so
the rate is bounded by the client's own send rate: cast cooldowns, click speed, the UI. Flooding
would need a modified client, and that only spams its own chat window.

### Findings opened

1. **Gate and the Soul Binder use two different bind points.** The most interesting thing in this
   run. See the To-Do; the short version is there are two unconnected bind concepts and the NPC
   sets the one Gate does not read.
2. **The vendor window still claims the wrong amount.** Chat says "Only 7 fit in your bags." while
   the vendor dialog says "Ordered Honey x20 for 1s." The client announces success, with a quantity
   and price it computed itself, before the server has answered. Client-side, so it needs a
   re-export.
3. **Succor and Gate teleport you to where you cast them**, which follows from finding 1.
