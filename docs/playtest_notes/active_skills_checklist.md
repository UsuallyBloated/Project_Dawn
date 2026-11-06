# Active Skills on the Server Playtest Checklist — 2026-10-19

Active skills (Backstab, Shield Bash, Hide, Feign Death, Evade, Holy Shield, Warder's Fury and
the rest) run on the server now: it owns the class gate, the cooldown, the stamina, the swing
times the skill's multiplier, and the effect. Client-authority audit item 6; the standing rule
"Events happening on the client are a no-go." **Needs the Oct 22 bump** (both sides together:
the wire message changed under PD_W0028 and the DLL carries the new send).

| Skill | What the server does | Where to look |
|---|---|---|
| Backstab, Slash, Harm Touch, Aimed Shot, Flying Kick, ... | the ordinary swing times the multiplier (Backstab x3), outside the auto-attack limiter | `skill used` and `Attack applied` in `server.log`; the hit number over the mob |
| Shield Bash | 3 s stun on the target: no move, no swing | `mob stunned`; "Stunned" on the target frame |
| Evade, Primal Instinct | every melee swing at you is deflected for 5 s | MISS floats over you with no HP loss; the buff bar's Evade icon |
| Holy Shield | a 60-point absorb pool | the buff bar's shield icon; hits of 0 until it is spent |
| Hide | idle mobs do not notice you while you stand still; a step, a swing or a hostile cast ends it | "You have hidden yourself from view."; the Hidden icon |
| Feign Death | 80% on the server; a success wipes you from every mob and holds until you move | "You feign death successfully." / "Your feign death fails!"; `feign death succeeded` |
| Warder's Fury | your blow, then the warder is sent at the target | the warder's hits following yours |

A refusal costs nothing and says why: "You cannot use that yet." (cooldown), "You are too
tired.", "You cannot use that skill.", "You have no target.", "That target is too far away.".
Diagnostics: the in-game console (backtick) for the chat lines; `grep "skill used\|UseSkill
rejected" server.log` for the server's side of each use.

## Setup
- [ ] The Oct 22 build on both sides (the login screen's build stamp; the server's boot line)
- [ ] A GM account for the Test Panel's mob spawns; a second seat for §2 and §6 (two-boxing works)
- [ ] One character each of Rogue, Warrior, Paladin, Monk and Beast Master (Level Up tool as needed)

## 1 — A damage skill is the server's
- [ ] **Rogue: put Backstab on the bar, target a mob beside you, use it** → one hit about three times an ordinary swing (or a MISS), and the stamina bar drops by 20 at once. notes:
- [ ] **Use it again straight away** → "You cannot use that yet.", nothing spent, the gem's cooldown goes on counting from the first use. notes:
- [ ] **Use it with no target** → "You have no target." and nothing spent. notes:
- [ ] **Use it on a mob 10 m away** → "That target is too far away." and nothing spent; walk in, it works. notes:
- [ ] **Drain stamina below 20 (sprint or skills), use Backstab** → "You are too tired." and the cooldown is not drawn. notes:
- [ ] **Auto-attack a mob and fire Slash mid-swing-cycle** → Slash lands as its own hit; no `swing-rate limit` line in `server.log` for it (it used to be dropped for nothing). notes:

## 2 — The stamina shows for the group (second seat)
- [ ] **Grouped, the partner watches your panel while you use a skill** → your stamina bar drops on their screen at the moment you use it. notes:

## 3 — Shield Bash stuns
- [ ] **Warrior: Shield Bash a mob that is hitting you** → the hit lands, "Stunned" appears on its frame, and it neither moves nor swings for about 3 s, then carries on. notes:
- [ ] **Hit the stunned mob again** → the stun holds (damage does not wake it; only mez breaks on damage). notes:

## 4 — Evade and Holy Shield
- [ ] **Rogue: use Evade while a mob is hitting you** → for 5 s every swing shows a MISS over you and the HP bar does not move; after, they land again. notes:
- [ ] **Paladin: use Holy Shield while a mob is hitting you** → the shield icon appears and the hits land for 0 until 60 damage is absorbed, then the icon goes and the hits land. notes:
- [ ] **Use Holy Shield again while the icon is still up (after its 15 s cooldown)** → "Your shield still holds." and nothing spent; once the pool is gone it works again. notes:

## 5 — Hide and Feign Death
- [ ] **Rogue: use Hide, stand still, and have the GM spawn an aggressive mob beside you (Test Panel)** → it does not turn on you; the Hidden icon shows. notes:
- [ ] **Swing at it** → it turns on you and the Hidden icon goes. notes:
- [ ] **Hide again (after the 10 s cooldown), spawn another mob beside you, then press a movement key** → the step ends the hide and the mob turns on you. notes:
- [ ] **Use Hide while already hidden (cooldown over)** → "You are already hidden." and nothing spent. notes:
- [ ] **Hide, then cast a nuke at a mob** → the hide ends with the cast (hostile casts count). notes:
- [ ] **Monk: with two mobs on you, use Feign Death** → one of the two lines. On success the mobs drop you (they walk home or stand), you lie unnoticed, and the stamina went by 20 either way. notes:
- [ ] **After a success, press a movement key** → the mobs notice you again. notes:
- [ ] **On a failure** → the mobs keep hitting; the cooldown (60 s) runs regardless. notes:

## 6 — Warder's Fury and the rest
- [ ] **Beast Master: `/pet guard`, then Warder's Fury on a mob** → your hit lands and the warder goes for the mob (it would not have on its own in guard). notes:
- [ ] **Any skill from a sitting character** → "You cannot use skills while sitting." before anything is sent. notes:
- [ ] **A Cleric with Backstab on a social (/skill or a hotkey)** → "You cannot use that skill." notes:

## Notes / observations
-
