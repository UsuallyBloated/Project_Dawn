# Project Dawn — Pre-Alpha Tester Guide

Welcome, and thank you for kicking the tyres on **Project Dawn**.

This is a **pre-alpha multiplayer** build. There is a real server now: your character lives
on it, other players are actually there, and the world keeps running when you log off. The
rough edges are real and the point of this build is to find them.

**Your character can be wiped at any time.** Treat anything you build as throwaway.

---

## Step 0: Tailscale (you cannot connect without this)

The server is not on the public internet. It sits on a private network called a **tailnet**,
and you have to join it before the game can reach it.

1. Ask the operator for an invite to the tailnet. You will get an email or a link.
2. Install Tailscale from **https://tailscale.com/download** (Windows).
3. Sign in with whatever account the invite went to, and accept.
4. Leave it running. The tray icon should say you are connected.

To check it worked, open PowerShell and run:

```
ping 100.93.108.112
```

Replies mean you are on. Timeouts mean Tailscale is not connected, and nothing below will
work until it is.

> Tailscale only carries traffic to this tailnet. It is not a VPN for your general browsing
> and it does not route the rest of your internet through anything.

---

## System requirements

- **OS**: Windows 10 or 11 (64-bit). Mac and Linux builds will follow.
- **CPU**: Anything from the last decade. Single-threaded performance dominates.
- **GPU**: Discrete or modern integrated, supporting Vulkan / Forward+. Roughly 2017 onward.
- **RAM**: 4 GB free.
- **Disk**: ~250 MB.

---

## Install and launch

1. Unzip the build wherever you like. Desktop is fine.
2. Keep `ProjectDawn.exe` and `gdext_net.dll` **in the same folder**. The game will not
   connect without that DLL beside it.
3. Double-click `ProjectDawn.exe`.

No installer, no auto-update. For a new version, delete the folder and unzip the new one.

`ProjectDawn.console.exe` is the same game with a console window attached. Ignore it unless
you are asked for it while chasing a bug.

---

## First connection

You land on a **login screen**.

1. **Server**: it defaults to `127.0.0.1:8765`, which is wrong for you. Replace it with:

   ```
   100.93.108.112:8765
   ```

   It is remembered after the first time.
2. **Register** with a username and password. This creates your account and logs you
   straight in. Use **Login** on later visits.
3. **Create a character.** Names accept **letters, apostrophes and backticks only**, 2 to 24
   characters. Digits, spaces and punctuation are rejected.
4. Pick a race and class, create, then hit **Play**.
5. You land on a screen showing `Connected. Click Enter World to begin.` Click
   **Enter World**.

> **Ignore the other buttons on that screen.** `Host Game`, `Join Game`, `Test Room` and
> `Delete Save` are leftovers from before the server existed. They do nothing useful and
> some of them will misbehave. **Enter World** is the only one you want.

---

## Death works like EverQuest, and it will surprise you

This is the single biggest thing to know before you play.

- **When you die you drop everything.** Gear and coin stay on your **corpse** where you fell.
  You respawn with nothing.
- **You have to go and get it.** Walk back to your corpse and loot it. Only you can loot
  your own corpse.
- **Corpses last 7 days**, so you can log off and do the corpse run tomorrow.
- **You lose XP**, and enough deaths can drop you a level. There is a floor and a grace
  period at low level.
- **Clerics and Paladins can resurrect you** and refund part of the lost XP.

Looted gear returns to your bags, not to your body. You re-equip by hand.

---

## Default controls

| Key | Action |
|---|---|
| **W A S D** | Move |
| **Space** | Jump |
| **X** | Crouch |
| **Z** | Sit / Rest (boosts HP/MP regen; suppressed in combat) |
| **Right-click + drag** | Camera control |
| **Left-click** | Click-target an enemy or NPC |
| **Tab** | Cycle target |
| **F1** | Target self |
| **F** | Interact / Talk to targeted NPC |
| **Enter** | Open chat input |
| **C / I / P / K / B / J** | Character / Inventory / Paperdoll / Tradeskill / Spellbook / Quest Journal |
| **Esc** | Options menu |

Rebindable in **Options > Keybinds**, except Enter, Numpad Enter and Escape, which the chat
and menu systems own.

---

## Logging out properly

Your character lives on the server, so there is no save file to worry about. But **how** you
quit matters.

- **To log out cleanly:** use **Quit Game** in the Options menu.
- **The window X button is a deliberate crash simulation.** It kills the window with no
  clean logout, so the server keeps your character in the world for about 30 seconds,
  vulnerable, and refuses your own re-login during that window. This is intentional, for
  testing the linkdead system. It is not a bug.

Progress is written continuously, but up to about a minute of position, HP and XP can be
lost if the server is stopped while you are connected. A clean logout flushes immediately.

---

## Known rough edges

Please **do** still report these if you hit them, with any extra detail. Knowing they are
known just saves you writing them up from scratch.

- **Some spells do nothing.** Roughly 32 spells exist in the client but not yet on the
  server. Casting one spends mana and has no effect. Tell us which one.
- **Bags open on left-click**, where everything else uses right-click. Inconsistent, known.
- **Bard songs are half-built.** They apply once and do not sustain.
- **Named and boss mobs behave like ordinary mobs.** No enrage, no guaranteed drops yet.
- **No bind points.** You respawn where you died, and death does not lock your movement.
- **No sound at all.** Combat, spells, ambience and music are all coming.
- **No mounts, weather, swimming, faction or PvP** yet.
- **No player portrait or target-of-target frames.**

---

## What to hammer on

The most useful things you can do:

- **Group up** with someone and check XP split, loot rights and the group window.
- **Die on purpose**, then do the corpse run. Check your gear all came back.
- **Fill your bags**, use the bank, trade, buy from vendors, and see if any coin or item
  count goes wrong.
- **Take a quest to completion** and check the reward actually arrives.
- **Log out and back in** after anything significant, and confirm the world remembered.

Anything that vanishes, duplicates, or gives you something you should not have is the
highest-value bug you can find.

---

## How to report a bug

**Easiest path:** in-game, **Esc** then **Report a Bug**. That opens our Discord in your
browser:

> https://discord.gg/xpAv5Ra4aT

Please include:

1. **What you were doing** when it happened.
2. **What you expected** versus **what actually happened**.
3. **The debug log**, attached:
   - `%APPDATA%\Godot\app_userdata\Project_Dawn\debug.log`
   - Paste that into the Windows Explorer address bar and it opens the right folder.
4. **A screenshot or short clip** if it is visual.
5. **Roughly what time it happened**, which lets us match it against the server log.

Crashes, soft-locks, items disappearing, quests stuck, odd damage numbers, anything that
feels wrong. We want all of it.

---

## Troubleshooting

**Cannot reach the server / login fails immediately.** Tailscale is almost certainly not
connected. Check the tray icon and re-run the `ping` from Step 0.

**Login and character select work, then Enter World hangs.** That is the network path for
the game world specifically. Report it, and mention that login worked, which narrows it down
a lot.

**The game will not start, or connects but nothing happens.** Check `gdext_net.dll` is in
the same folder as `ProjectDawn.exe`.

**UI too small or too large.** **Esc > Options > Graphics > UI Scale**, drag between 75% and
150%, then **Apply**. The HUD scales, the 3D world does not. If the whole window is wrong,
change **Window Mode** and **Resolution** in the same panel.

---

Thanks for testing. Have fun, and break things.
