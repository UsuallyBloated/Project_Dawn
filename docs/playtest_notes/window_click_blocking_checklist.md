# Clicks Stop at Windows — 2026-10-29

A click on any part of an open window stops at that window: it never reaches a window under
it, the HUD, or the world (user, 2026-10-26, on the bank: "the clicks are going THROUGH the
window and effecting the windows/interface below"; scope: every window). The cause was not a
mouse filter: every window stops clicks on its own rect. It was the stacking. Godot picks the
control under the mouse by tree order and ignores `z_index`, and `hud.gd` raised the bank,
vendor, crafting and options windows with `z_index = 20` (the dialogue window 25) while the
spell book, journal, inspect, trade and group windows come later in the tree, so those four
drew on top of whatever was open and the clicks went to the window underneath. Now no window
carries `z_index`; a window comes to the front of the tree when it opens and when anything in
it is pressed, so the window you see on top is the one that gets the click; bag windows live beside
the inventory window under the HUD, so a bag and its destroy confirm can come to the front
too; the debug console and the disconnect notice follow the same rule. Two more things the
check found: the disconnect notice was 0 by 0 when shown (it dimmed nothing and blocked
nothing) and fills the screen now; the loot window skipped its base constructor and so the
raise-on-show hook.

**Needs the next export** (client only; the server is untouched).
`tools/check_window_click_blocking.gd` runs the real HUD headless and holds every rule here;
this sheet is the eyes-on half.

| Thing | Where | Notes |
|---|---|---|
| The window on top gets the click | the window reacts, nothing beneath does | nothing is logged; watch the screen |
| The ESC stack | ESC closes the window clicked last | `hud.gd` closes the highest closable window in the tree |
| The disconnect notice | the whole screen dims, the panel centred | `debug.log` `World connection ended` |

## Setup
- [ ] Both seats on the new export (login screen build stamp). notes:
- [ ] A character near Thalia (the banker) carrying a bag with a few items in it. notes:

## 1 — The bank over other windows (the reported case)
- [ ] **Open the quest journal, then right-click Thalia** → the bank opens on top of the journal. notes:
- [ ] **Click the bank's Items tab, its cells and its empty background where the journal is underneath** → only the bank reacts; the journal never changes, scrolls or closes. notes:
- [ ] **Click a part of the journal still showing** → the journal comes to the front over the bank. notes:
- [ ] **With the bank on top again, click a quest line or a button inside the journal's visible part, not its bare background** → the journal comes to the front just the same. notes:
- [ ] **Open the spell book and the bank so they overlap; click back and forth** → whichever was clicked last is on top and takes the clicks. notes:

## 2 — Bags and the destroy confirm
- [ ] **Open a bag, then the bank over it** → the bank is on top; clicks on the bank where a bag cell is underneath do nothing to the bag. notes:
- [ ] **Click the bag's visible edge** → the bag comes to the front over the bank. notes:
- [ ] **With the bank open, destroy an item from a bag (the Trash cell)** → the confirm appears centred; Yes and No work; the bank under the confirm does not react. notes:
- [ ] **Close the inventory window** → its open bags close with it, as before. notes:

## 3 — The world and the HUD
- [ ] **With the bank open, click the ground beside it** → the ground click targets or does nothing, as before (a click that is not on a window still reaches the world). notes:
- [ ] **Hold an item on the cursor and click the bank's background** → no ground-drop prompt (a click on a window never reaches the world). notes:
- [ ] **Click the player bar, the target frame, a hotbar** → they still work; a window overlapping one comes to the front when clicked and goes behind it when the bar is clicked. notes:

## 4 — The console and the notice
- [ ] **Open the debug console (backtick) with the bank open** → the console is on top; clicks on its panel stay on it; clicks beside it on the bank go to the bank; clicks on open ground still reach the world. notes:
- [ ] **Click the bank, then the console's panel** → each comes to the front when clicked. notes:
- [ ] **Have the operator restart the server, or pull the network** → the whole screen dims and the Disconnected panel sits centred with the reason, a relogin hint and Quit; nothing behind it can be clicked. notes:

## 5 — ESC and chat
- [ ] **Open the journal and the bank, click the journal, press ESC** → the journal closes (the window clicked last); ESC again closes the bank. notes:
- [ ] **Two chat windows overlapping; click each** → the clicked one comes to the front. notes:
- [ ] **`debug.log` after the sitting** → no script errors. notes:

## Notes / observations
-
