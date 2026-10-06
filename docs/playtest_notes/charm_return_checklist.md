# Charm Return Playtest Checklist — 2026-10-06

A charm that ends now hands the mob back instead of deleting it: the pet vanishes and the same
creature stands in its place, hostile, with the HP it had, and it goes straight for the one who
charmed it (EQ's rule; asked for on the ported-spells sheet the same evening). The camp slot
stays occupied for the charm's life, so a charm no longer makes the camp respawn a replacement
early. **Server-only: needs the R720 on `e3a6fa8` or later. No client export needed.**

Who: Mirelle (Enchanter 20, Charm, 60 s) on the `spelltest` account (password in
`CHECKLIST_RUN_ORDER.md`). Caderyn cannot help here: Siren's Song is Bard level 14 and he is 10.
Log anchors in the journal: `enemy charmed into pet`, `charm expired — mob returned hostile`,
`charm broken by owner leaving — mob returned`. A dead charmed pet logs `pet killed by enemy`.

## Setup
- [ ] Redeploy the server (boot line shows `build=` at `e3a6fa8` or later, `dev_cmds=false`)

## 1 — The mob comes back
- [ ] **Mirelle: charm a Decrepit Skeleton and stand near it for the full minute** → when the charm ends the blue capsule goes and a Decrepit Skeleton stands where it was, with the HP it had (a pet that took damage comes back hurt, not healed). notes:
- [ ] **...and it comes for you** → the returned skeleton targets you and attacks without being provoked. notes:
- [ ] **Charm one, then walk about 40 m away before the minute is up** → it still comes back where the pet was; being past its 30 m leash it either chases briefly and turns home or stands hostile. Either is fine; it must not vanish. notes:

## 2 — The camp does not grow
- [ ] **Count the Decrepit Skeletons at the Bonepile, charm one, wait out the charm, count again** → the same number: no replacement appeared during the charm, and the returned one fills its old place. notes:
- [ ] **Charm one and let it die as your pet (send it into the Plagued Zombies with /pet attack)** → it dies as a pet (no XP or loot for you), and the camp respawns one in its place on the camp's own timer, not before. notes:

## 3 — The charmer leaves
- [ ] **Charm one, then quit with the window X** (a second seat watches, or read the journal after relogging) → `charm broken by owner leaving — mob returned`; the skeleton is back, hostile but idle, since nobody is there to hate. notes:

## 4 — Regression
- [ ] **Charm, then fight alongside the pet for the full minute: /pet attack, the pet panel, following** → unchanged from before. notes:
- [ ] **Charm the returned skeleton again** → it is a fresh target (re-target it first) and the charm lands as usual. notes:
- [ ] **Charm one at the edge of range and one in the middle of a camp** → the usual "too far" refusal and the usual landing; nothing new. notes:

## Notes / observations
-
