# Claude Usage Optimization Report

Date: 2026-07-09. Written in response to the usage analysis tips you pasted. For review
before any changes are made. Facts below were verified against the official Claude Code
docs (code.claude.com/docs) and the current model pricing reference, not recalled from
memory.

## TLDR

1. **You do not need to build anything.** "workflow-subagent" is the agent type that
   Claude Code's built-in Workflow tool spawns when we run multi-agent passes (the
   adversarial reviews, /code-review at high effort, the research fan-outs). The advice
   is "make the subagents you already run cheaper," not "build a subagent system."
   Building a new orchestration layer would spend more, exactly as you suspected.
2. **The 84% long-context item is the big one, and it is mostly habits, not config.**
   The subagent items (28% and 10%) are secondary. Fixing session hygiene first gives
   the largest saving for zero risk.
3. **Every subagent currently inherits this session's model, which is the most
   expensive tier.** One env var or a few small config files fixes that where it is
   safe to fix.
4. There is one real trade-off to decide: cheaper models on *verification* work is how
   you get plausible-but-wrong review results. I recommend cheap models for mechanical
   work only, and keeping the full model for anything exploit- or correctness-critical.

## Why usage is high right now

Model pricing per million tokens (input / output):

| Model | Input | Output | Relative to Fable |
|---|---|---|---|
| Fable 5 (current session model) | $10 | $50 | 1x |
| Opus 4.8 | $5 | $25 | ~1/2 |
| Sonnet 5 | $3 | $15 (intro $2/$10 to Aug 31) | ~1/3 |
| Haiku 4.5 | $1 | $5 | ~1/10 |

Subscription limits are consumed in proportion to what the tokens cost, so these ratios
apply to your rate limit too, not just dollar billing.

Three multipliers stack in this project's sessions:

- **Long sessions (84% of usage above 150k context).** Every turn re-reads the whole
  conversation. Past 150k, even cached turns are expensive, and cache expires after 5
  minutes of inactivity, after which the entire context is re-read at full price. Our
  big slice sessions (corpse epic, quest phase 1) routinely live in this zone.
- **Subagents inherit the session model.** Subagents default to `model: inherit`, so
  every Explore agent, review finder, and workflow verifier runs at Fable pricing with
  its own context. A 10-agent review pass is roughly 10 extra conversations.
- **Everything runs on the top tier.** Fable is the right tool for exploit-critical
  design and the hard multi-system work, but it is 2x Opus and roughly 3x Sonnet for
  every routine turn as well.

## Recommendations, ordered by impact

### 1. Session hygiene (targets the 84% item, no quality risk)

- **`/clear` between unrelated tasks.** New bug, new task, new session. The main habit
  change. Cost: re-establishing context, which the next point solves.
- **Keep doing handoff docs.** The "build-ready handoff plans" pattern from commit
  c2d3185 is exactly the recommended workflow: end a session by writing the plan to a
  doc, `/clear`, start the next session by reading the doc. A 2k-token doc replaces
  150k tokens of history.
- **`/compact` with focus instructions mid-task.** It accepts arguments, e.g.
  `/compact keep the corpse-loot persistence details and open playtest items`.
  Summarizes history but keeps rules and memory. Use it when a session is long but you
  are not done.
- Optional: the `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env var triggers automatic compaction
  earlier than the default threshold. Worth trying if you tend to forget to compact.

### 2. Match the main model to the session (large lever, your call per session)

`/model opus` or `/model sonnet` mid-session, or set a default in settings.json.
A reasonable split for this project:

- **Fable:** exploit reviews, wire-protocol / persistence design, the hard multi-system
  slices (the corpse epic class of work), anything where a subtle bug undoes the
  project.
- **Opus 4.8:** most implementation sessions. Half the cost, still a top-tier model.
- **Sonnet 5:** routine playtest-fix batches, doc updates, checklist authoring.

This is the single biggest dial because it multiplies with the long-context item: 84%
of usage at high context *on the most expensive model* is the worst corner of the grid.

### 3. Cheaper subagents (targets the 28% and 10% items)

Two mechanisms, use either or both:

- **Global:** set the `CLAUDE_CODE_SUBAGENT_MODEL` env var (alias like `sonnet`, a full
  model ID, or `inherit`). Blunt: it changes every subagent, including review
  verifiers. I would set it to `sonnet` at most, never `haiku`, if you use it at all.
- **Per-agent (recommended):** define agents in `.claude/agents/*.md` with a `model:`
  frontmatter field (`haiku`, `sonnet`, `opus`, `fable`, or `inherit`). This project
  currently has none, so everything inherits. Good candidates for a cheap model:
  - a `log-scanner` (haiku): grep server.log / debug.log for a pattern and summarize
    hits. Mechanical, verifiable, high volume during playtest triage.
  - a `doc-sweeper` (sonnet): "find every doc that mentions X" style sweeps.
  - Explore-style breadth searches (sonnet): locating code, not judging it.

- **Inside Workflow scripts** (the "workflow-subagent" line): each `agent()` call takes
  `model` and `effort` options. The pattern I would adopt when authoring workflows for
  you: mechanical stages (enumerate files, collect call sites, format findings) at
  `effort: 'low'` and a cheaper model; finder and verifier stages stay on the session
  model. Also: fewer, better-scoped finders instead of maximal fan-out unless you ask
  for "thorough."

- **Spawn discipline:** no subagent for a single-file lookup; one Explore agent instead
  of three when the question is narrow. This is on me and costs you nothing.

### 4. Where NOT to cheap out

- **Adversarial verification.** The pre-commit adversarial review caught a real
  data-loss window in the corpse-loot persist path (Slice 2). That class of catch is
  the whole point of paying for review passes; a haiku verifier saying "looks fine" is
  worse than no verifier.
- **Recon you will trust without re-checking.** House rule since 2026-06-22 is that
  recon claims get verified against the real source. Cheaper recon models make wrong
  claims more often; only use them where the output is mechanically checkable.
- **Exploit surface reviews.** Per the project's standing rule, any exploit slips
  through and the project is undone. Full model, always.

### 5. Smaller items

- **Trim CLAUDE.md over time.** It loads into every session. Moving the completed
  history and long reference sections out (they already live in systems_overview and
  session notes) shrinks the fixed per-session cost. Official guidance is to move
  specialized instructions into skills that load on demand.
- **/code-review effort levels.** Default to `low` or `medium` for routine passes
  (fewer, high-confidence findings); reserve `high`+ and the big multi-agent passes for
  core systems (combat, inventory, spells, PlayerStats, networking, persistence), which
  matches what CLAUDE.md already says about when to review.
- **Specific prompts.** "Fix the HP rollback in player_stats.gd" starts a session
  cheaper than "look into the stats bug" because it skips a discovery phase.

## Proposed actions (pick any, nothing done yet)

1. Add 2 or 3 agent definitions under `.claude/agents/` with cheap models for
   mechanical work (log-scanner on haiku, doc/code sweeps on sonnet).
2. I adopt the workflow-authoring pattern (cheap mechanical stages, full-price
   verification) and save it as a standing memory so it applies in every future
   session.
3. You adopt the session habits: `/clear` per task with handoff docs, `/compact` with
   focus instructions, `/model` matched to the session's stakes.
4. Optionally set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` globally. My recommendation is to
   skip this and rely on 1 and 2, so verification agents keep full capability.
5. A later, separate pass to slim CLAUDE.md (low urgency, small win).
