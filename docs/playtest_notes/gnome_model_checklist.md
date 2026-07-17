# Gnome Race Model Playtest Checklist — 2026-07-11

Verifies the first per-race character model: a Gnome character should render as `gnome.glb`
instead of the default 2 m capsule, for the local player (no server needed) and for other
players who see a gnome (server needed). Cosmetic only — collision/camera/nameplates still
use the capsule.

**Build prerequisite:** client only — no server rebuild. Open the project in **Godot 4.4.1**
and let the import finish (`gnome.glb` re-imports on first open). Section 5 (remote view) also
needs the Rust server running + launcher mode.

Reference — what's under test:

| Thing | Expected | Where |
|---|---|---|
| Gnome model | short (~1.1 m) blocky figure, plain grey/white, **no animation** | in world, 3rd person |
| Other races | unchanged 2 m capsule | regression |
| Framework/reference nodes | hidden (no stray box/plane around the gnome) | `hide_nodes` in race_model.gd |

> **Expected rough edges (not bugs):** the model is an early blockout — no rig, no walk
> animation (it slides), no textures (default grey material). Camera sits a bit above the
> head because collision is still the 2 m human capsule. All known; see the session note.

## Setup
- [ ] Open project in Godot 4.4.1; wait for import to finish (Output panel settles). notes:
- [ ] Check the **Output / Debugger** panel is free of red script errors on load. notes:

## 1 — Local gnome appears (no server)
This is the core "i want to see" test. Uses the offline solo path, no server required.

- [ ] Click **Solo** → character creation → pick race **Gnome**, any class → enter world. notes:
- [ ] Scroll out to 3rd person → you are a **blocky gnome**, not a capsule. notes:
- [ ] Gnome is **short** (roughly waist-to-chest of a normal capsule), not 2 m tall. notes:
- [ ] **Feet sit on the ground** — not sunk into the floor, not floating above it. notes:
- [ ] **No stray box or flat plane** wrapping / next to the gnome (framework hidden). notes:

## 2 — Orientation
The one thing I couldn't verify headlessly. If it fails, it's a one-line fix (`yaw` → `PI`).

- [ ] Hold **W** to run forward → the gnome's **front faces the way it moves** (not moonwalking / running backward). notes:
- [ ] Turn with the mouse (right-drag) → body turns naturally, no weird tilt/lean. notes:

## 3 — First-person hide
- [ ] Scroll all the way **in** to first person → the gnome model **disappears** (camera isn't stuck inside/behind the body). notes:
- [ ] Scroll back out → model reappears. notes:

## 4 — Regression: other races unaffected
- [ ] Back to lobby → **Solo** → create a **Human** (or any non-gnome) → enter world → still the normal **capsule**, no errors. notes:
- [ ] **Test Room** button (defaults to a Troll) → spawns the normal **capsule**, no errors in Output. notes:

## 5 — Remote view (needs Rust server + launcher mode + 2 clients)
Confirms a gnome reads as a gnome to *other* players, via the server-authoritative path.

- [ ] Start the Rust server; launch **two** clients in launcher mode, each logged into a **Gnome** character; both **Enter World**. notes:
- [ ] Client A looks at Client B → B renders as a **gnome model**, not a capsule. notes:
- [ ] Nameplate still floats above B and targeting still works (click to target). notes:
- [ ] One gnome and one non-gnome character → each sees the other correctly (gnome model vs capsule). notes:

## Notes / observations
-
