# docs/concepts/alignment — Directory Index

The alignment system tracks the cumulative moral weight of a character's choices on a score from −2000 to +2000.
For the full system — tiers, drift mechanics, spell effectiveness, NPC recognition, and triggered transformations — start with `alignment.md`.

---

## Master Reference

| File | Contents |
|---|---|
| [alignment.md](alignment.md) | **System overview** — five tiers, score ranges, starting alignment by class, drift mechanics, spell effectiveness by alignment, NPC recognition, implementation notes; start here |
| [events.md](events.md) | **Alignment event table** — specific actions and their delta values; what moves the score up and by how much, what moves it down and by how much |

---

## Tier Files

One file per tier. Each covers: what the world looks like from this tier, what changes mechanically, and what NPCs do.

| File | Tier | Score Range |
|---|---|---|
| [exalted.md](exalted.md) | Exalted | ≥ 1500 |
| [good.md](good.md) | Good | 300 to 1499 |
| [neutral.md](neutral.md) | Neutral | −299 to 299 |
| [bad.md](bad.md) | Bad | −1500 to −300 |
| [evil.md](evil.md) | Evil | ≤ −1501 |

---

*Alignment-triggered transformations are documented in `docs/concepts/transformations/`. The `alignment_changed` signal and `modify_alignment()` implementation are in `autoloads/alignment.gd`.*
