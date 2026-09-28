# /loc & The Settled Compass — 2026-09-27

Client-only (rides the next export). `/loc` prints position + exact facing;
the compass is now officially +Z north / +X east everywhere, which flipped
`/sense`'s labels (rotation.y = 0 reads South now).

---

- [ ] **`/loc` beside Sister Maelis** → the printed x/z match her `npcs.toml`
      row to within a couple of meters, one-decimal format, x, y, z order. notes:
- [ ] **Face each of the four ways and `/loc`** → walking toward the gnoll camp
      reads "Facing East", toward the Bonepile "West", toward the Wraith Gate /
      Ring 4 side "North", toward Wolf Run "South". notes:
- [ ] **`/sense` agrees with `/loc`** at max-ish skill (fuzzy at low skill is
      correct behavior, not a fail). notes:
- [ ] **`/loc` while dead** → still prints (a corpse run is when you want it). notes:
- [ ] **NPC directions read true**: Aldric/Brom dialogue compass words ("east
      to the gnolls", "south past the dire wolves") now match what /loc says
      while you walk there. notes:

---

## Result

- Client build (`/version`):
- Overall:
