# Group Panel Stats & Tells Playtest Checklist — 2026-08-26

The two-player session that closes two long-stale To-Do items at once:

- **Group-mate HP/MP/stamina in the panel** — the 2026-08-11 first-group-session bug. The fix
  was built the same day (client `5bde067`) but has never been watched by two live players:
  member bars now ride the server's per-entity resource fan-outs (a swing bigger than 5% of max
  broadcasts immediately; idle regen ticks at least every half second), and rows are keyed by
  server char_id so stats land under the right names.
- **Incoming `/tell`** — built 2026-05-28 (`195891d`) and never exercised by two people.

**Needs two clients on the tailnet with two accounts** (one character per account — two-boxing
on one machine with a second account works). Any two characters.

---

## 1 — Setup

- [ ] **Form a group** (invite by name, accept) → both clients show the roster with both names
      correct. notes:
- [ ] **No RPC errors**: neither client's console/debug.log shows
      `Attempt to call RPC with unknown peer ID` (the old flood). notes:

## 2 — Member bars are live and correctly labeled

- [ ] **Player A takes a big hit** → B's panel row for A drops essentially immediately. notes:
- [ ] **Player A casts something expensive** → B sees A's mana dip. notes:
- [ ] **Idle regen** → each sees the other's bars creep up smoothly, not frozen. notes:
- [ ] **The stats sit under the RIGHT name** — A's HP under A's row on B's screen, and the
      other way around. (The 08-11 bug wrote her stats into his row.) notes:
- [ ] **Both directions** — leader sees the member's bars AND the member sees the leader's.
      notes:
- [ ] **One player logs out** → the other's roster updates cleanly; no stale ghost row. notes:

## 3 — Tells

- [ ] **A: `/tell <B> hello`** → B sees "A tells you, 'hello'" (Tells In); A sees their own
      outgoing echo. notes:
- [ ] **B replies with a tell** → same in reverse. notes:
- [ ] **Tell to a name that isn't online** → note what happens (message, silence, or error) —
      this row is reconnaissance, not pass/fail. notes:

## 4 — While two players are on anyway (cheap extras)

- [ ] **One player jumps** → does the other see it? (Known open item — expected result today is
      NO jump shown; this row just confirms the entry is still accurate.) notes:
- [ ] **Group kill** → XP splits, kill credit lands, no surprises in the log. notes:

---

## Result

- Client builds (`/version`, both seats):
- Server build (boot line):
- Overall:
