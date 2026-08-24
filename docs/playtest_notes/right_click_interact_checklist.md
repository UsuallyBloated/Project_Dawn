# Right-Click Interact Playtest Checklist — 2026-08-24

Verifies the new mouse grammar: **right-click (tap) = interact, left-click = target only**,
everywhere in the world. Requested 2026-08-24, partly as bot resistance — the old proximity-F
path interacted with anything nearby with **no cursor work at all** (walk near, mash F), which is
the easiest possible thing to automate. Now every interaction needs the cursor on the object.

**Build prerequisite: client re-export only.** (Ships together with the tradeskill guard.)

**What changed.**
| Object | Old | New |
|---|---|---|
| NPC (dialogue / vendor / banker) | target + F within 6 m | **right-click** (also targets) |
| Corpse | left-click targeted AND looted | left-click targets only; **right-click** targets + loots |
| Loot bag | left-click | **right-click** |
| Ore vein | F near it | **right-click** |
| Crafting station | F near it | **right-click** |
| Dead skinnable mob | F near it | **right-click** |
| F key | interact chain | **retired** (does nothing) |

A right-click **tap** interacts; a right-click **drag** is still the camera — the split uses the
same 6-pixel threshold left-click already uses to separate targeting from orbiting.

---

## 1 — The verb works on everything

- [ ] **Right-click Sister Maelis / a vendor / Thalia Mourne** → dialogue / vendor / bank window
      opens, and the NPC becomes your target. notes:
- [ ] **Right-click an NPC from across the camp (>6 m)** → "You are too far away." and no window.
      notes:
- [ ] **Kill a mob, right-click its corpse/bag** → loot window opens. notes:
- [ ] **Die, right-click your own corpse** → loot window opens (and the corpse is targeted).
      notes:
- [ ] **Right-click a crafting station** → crafting window opens. notes:
- [ ] **Right-click an ore vein** → the mining refusal ("isn't available online yet") — proving
      the click lands and the guard holds. notes:

## 2 — The camera is unharmed

This is the regression that would actually hurt: every camera drag starts with the same button.

- [ ] **Right-click-drag to steer, starting with the cursor over an NPC or corpse** → the camera
      drags normally and NO window opens. notes:
- [ ] **Normal camera feel** — spin the camera around for a minute; no accidental dialogues, no
      loot windows. notes:
- [ ] **A quick right-tap on empty ground** → nothing happens (no error, no message). notes:

## 3 — Left-click is target-only

- [ ] **Left-click a corpse** → it becomes your target and NO loot window opens. (A Cleric needs
      exactly this to cast Reclaim Soul.) notes:
- [ ] **Cast a res on a left-click-targeted corpse** → still works end to end. notes:
- [ ] **Left-click an enemy** → targets, as always. notes:

## 4 — F is really gone

- [ ] **Stand next to an NPC / vein / station and press F** → nothing happens. notes:
- [ ] **Right-click something while a UI window is under the cursor** → the UI handles it (e.g.
      inventory right-click still equips); the world does NOT also interact through the window.
      notes:

---

## Result

- Client build (`/version`):
- Overall:
