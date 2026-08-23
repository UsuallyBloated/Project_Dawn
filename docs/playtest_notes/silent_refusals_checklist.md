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

- [ ] **Fill your bags, then buy something** → "Your bags are full." and you are charged nothing.
      notes:
- [ ] **Buy more than will fit** (e.g. 10 when only 6 fit) → "Only 6 fit in your bags." You are
      charged for 6 and receive 6. This was always billed correctly; it just never said why.
      notes:
- [ ] **Try to buy with too little coin** → "You can't afford that." notes:
- [ ] **Sell from an equipped slot** → "Take it off before selling it." notes:
- [ ] **Sell a bag with items in it** → "Empty the bag before selling it." notes:
- [ ] **Sell something worthless** (no vendor value) → "The merchant won't take that." notes:
- [ ] **A normal buy and a normal sell still work exactly as before.** notes:

## 2 — Spells (the worst of the audit)

The client spends mana, starts the cooldown and applies local buffs **before** it sends the cast,
so a refusal used to drain the bar for nothing.

- [ ] **Cast a spell the server doesn't know** — one of the ~32 client-only spells — → "That spell
      fizzles — it isn't known here yet." **and your mana comes back.** The bar should visibly
      refill. notes:
- [ ] **Nuke something out of range** → "That target is too far away." notes:
- [ ] **Cast a PORT / gate / evac spell** → "That magic has no effect here yet." notes:
- [ ] **Normal spells are completely unaffected** — damage, heals, buffs all as before. notes:
- [ ] **Chat is not flooded** when you mash a failing cast. notes:

## 3 — Regression

- [ ] **Melee, looting, banking, grouping all behave as before.** notes:
- [ ] **No refusal text appears during ordinary successful play.** notes:
- [ ] `server.log` still shows the matching `rejected` lines for anything you saw. notes:

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

- Server build (`build=` on the boot line):
- Overall:
