# /loc & The Settled Compass — 2026-09-27

Client-only (rides the next export). `/loc` prints position + exact facing;
the compass is now officially +Z north / +X east everywhere, which flipped
`/sense`'s labels (rotation.y = 0 reads South now).

---

- [x] **`/loc` beside Sister Maelis** → the printed x/z match her `npcs.toml`
      row to within a couple of meters, one-decimal format, x, y, z order. notes:
- [x] **Face each of the four ways and `/loc`** → walking toward the gnoll camp
      reads "Facing East", toward the Bonepile "West", toward the Wraith Gate /
      Ring 4 side "North", toward Wolf Run "South". notes:
- [x] **`/sense` agrees with `/loc`** at max-ish skill (fuzzy at low skill is
      correct behavior, not a fail). notes:  Appears to work.  I dont think there is a skill for "/sense" thought.  Seems to just function when ever the player inputs "/sense".  Also "/loc"  should only show coordinates, not direction facing.  thats what Sense heading is for.
- [x] **`/loc` while dead** → still prints (a corpse run is when you want it). notes:
- [x] **NPC directions read true**: Aldric/Brom dialogue compass words ("east
      to the gnolls", "south past the dire wolves") now match what /loc says
      while you walk there. notes:

---

## Result

- Client build (`/version`): the 10-05 export (`fc880df`)
- Overall: **PASS, all five rows (2026-10-09).** Server log corroborates row 1: the Soul
  Binder bind at `-1.8, 6.1`, 1.1 m from Sister Maelis's `npcs.toml` position. Follow-up from the
  notes, built same day: `/loc` now prints coordinates only.
