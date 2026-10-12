#!/usr/bin/env python3
# Generates the week-by-week detail schedule for the planner:
#   docs/schedule_detail.md  and  docs/schedule_detail.html
# from docs/schedule_detail.toml (the hand-written plan), the CLAUDE.md To-Do, and the
# checklists in docs/playtest_notes/.
#
# The plan file carries dates, sequence, owner, needs and dependencies. Everything that
# could drift is read from its real home at generation time:
#   - a row's `todo` phrase must appear in CLAUDE.md, or the run fails;
#   - a row's `checklist` must exist (in the tree, or on the branch it names), or the run
#     fails; its open-row count and two-seat sections are read, never typed;
#   - every checklist with open rows that no row schedules is listed on the page, so a new
#     checklist cannot be forgotten and a stale one cannot hide.
# The page carries no status. Verdicts live in the checklists and the To-Do.
#
# Run from the repo root:   python tools/schedule_detail.py
# Exit 1 on a broken reference (nothing is written). Warnings print and still write.

from __future__ import annotations

import datetime as dt
import html
import math
import re
import subprocess
import sys
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PLAN = REPO / "docs" / "schedule_detail.toml"
OUT_MD = REPO / "docs" / "schedule_detail.md"
OUT_HTML = REPO / "docs" / "schedule_detail.html"
CLAUDE_MD = REPO / "CLAUDE.md"
NOTES = REPO / "docs" / "playtest_notes"

LANES = ["decide", "build", "operate", "verify", "people"]
LANE_LABEL = {
    "build": "Build",
    "operate": "Operate",
    "verify": "Verify",
    "people": "People",
    "decide": "Decide",
}
LANE_WHO = {
    "build": "Claude, often unattended on days the user is away",
    "operate": "the user at a desk: redeploy, export, zip, send",
    "verify": "the user running a checklist, sometimes with a second seat",
    "people": "friends: onboarding, the rehearsal, the evening itself",
    "decide": "the user or the planner; each carries the date it starts to block",
}

OPEN_RE = re.compile(r"^\s*- \[ \]", re.M)
PASS_RE = re.compile(r"^\s*- \[[xX]\]", re.M)
SKIP_RE = re.compile(r"^\s*- \[-\]", re.M)
HEADING_RE = re.compile(r"^##+\s+(.*)$")
TWO_SEAT_RE = re.compile(r"two seats?|second seat|two accounts|two-seat", re.I)


def sh(*args: str) -> str:
    return subprocess.run(args, cwd=REPO, check=True, capture_output=True, text=True,
                          encoding="utf-8").stdout


def read_checklist(name: str, branch: str | None) -> str | None:
    if branch:
        try:
            return sh("git", "show", f"{branch}:docs/playtest_notes/{name}")
        except subprocess.CalledProcessError:
            return None
    p = NOTES / name
    return p.read_text(encoding="utf-8") if p.exists() else None


def count_rows(text: str) -> dict:
    """Open, passed and skipped rows overall, plus how many open rows sit in a section
    whose heading says it needs two seats."""
    sec_two_seat = False
    open_two_seat = 0
    for line in text.splitlines():
        m = HEADING_RE.match(line)
        if m:
            sec_two_seat = bool(TWO_SEAT_RE.search(m.group(1)))
            continue
        if OPEN_RE.match(line) and sec_two_seat:
            open_two_seat += 1
    return {
        "open": len(OPEN_RE.findall(text)),
        "pass": len(PASS_RE.findall(text)),
        "skip": len(SKIP_RE.findall(text)),
        "open_two_seat": open_two_seat,
    }


def hours_for_rows(open_rows: int, minutes_per_row: int) -> float:
    if open_rows <= 0:
        return 0.0
    raw = open_rows * minutes_per_row / 60.0
    return max(0.5, math.ceil(raw * 2) / 2)


def fmt_hours(h: float) -> str:
    if h == 0:
        return ""
    return f"{h:g} h"


def fmt_date(d: dt.date) -> str:
    return d.strftime("%a %b %d").replace(" 0", " ")


def week_range(start: dt.date) -> str:
    end = start + dt.timedelta(days=6)
    if start.month == end.month:
        return f"{start.strftime('%B')} {start.day} to {end.day}"
    return f"{start.strftime('%B')} {start.day} to {end.strftime('%B')} {end.day}"


# --------------------------------------------------------------------------------------
# Load and verify


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    plan = tomllib.loads(PLAN.read_text(encoding="utf-8"))
    meta = plan["meta"]
    today = dt.date.today()
    errors: list[str] = []
    warnings: list[str] = []

    claude_md = CLAUDE_MD.read_text(encoding="utf-8")
    weeks = {w["id"]: w for w in plan["week"]}
    milestones = {m["id"]: m for m in plan["milestone"]}
    rows = plan["row"]
    ids = {r["id"] for r in rows}
    if len(ids) != len(rows):
        errors.append("duplicate row ids")

    scheduled_checklists: set[str] = set()
    for r in rows:
        if r["week"] not in weeks:
            errors.append(f"{r['id']}: unknown week {r['week']}")
        if r["lane"] not in LANES:
            errors.append(f"{r['id']}: unknown lane {r['lane']}")
        for dep in r.get("waits_on", []):
            if dep not in ids:
                errors.append(f"{r['id']}: waits_on names unknown row {dep}")
        if "milestone" in r and r["milestone"] not in milestones:
            errors.append(f"{r['id']}: unknown milestone {r['milestone']}")
        if "todo" in r and r["todo"] not in claude_md:
            errors.append(f"{r['id']}: To-Do phrase not found in CLAUDE.md: {r['todo']!r}")
        if "checklist" in r:
            text = read_checklist(r["checklist"], r.get("checklist_branch"))
            if text is None:
                where = f" on branch {r['checklist_branch']}" if r.get("checklist_branch") else ""
                errors.append(f"{r['id']}: checklist not found{where}: {r['checklist']}")
                continue
            counts = count_rows(text)
            r["_counts"] = counts
            scheduled_checklists.add(r["checklist"])
            if counts["open"] == 0:
                warnings.append(f"{r['id']}: {r['checklist']} has no open rows; the row is "
                                "probably done and should leave the plan")
            if "hours" not in r:
                r["hours"] = hours_for_rows(counts["open"], meta["minutes_per_checklist_row"])
                r["_hours_derived"] = True

    # Checklists with open rows that nothing schedules.
    unscheduled: list[dict] = []
    for p in sorted(NOTES.glob("*checklist*.md")):
        if p.name.startswith("TEMPLATE") or p.name in scheduled_checklists:
            continue
        counts = count_rows(p.read_text(encoding="utf-8"))
        if counts["open"] == 0:
            continue
        mtime = dt.date.fromtimestamp(p.stat().st_mtime)
        age = (today - mtime).days
        unscheduled.append({"name": p.name, "mtime": mtime, "age": age, **counts})
        if age <= meta["stale_checklist_days"]:
            warnings.append(f"{p.name}: {counts['open']} open rows, touched {age} days ago, "
                            "and no row schedules it")
    unscheduled.sort(key=lambda u: u["mtime"], reverse=True)

    if errors:
        print("schedule_detail: NOT written. Fix these first:")
        for e in errors:
            print("  error:", e)
        return 1

    # Per-week totals.
    for w in weeks.values():
        w["_rows"] = [r for r in rows if r["week"] == w["id"]]
        w["_user_hours"] = sum(r.get("hours", 0) for r in w["_rows"] if "user" in r["who"])
        w["_claude_days"] = sum(r.get("days", 0) for r in w["_rows"])
        w["_range"] = week_range(w["starts"])

    verify_rows = [r for r in rows if "_counts" in r]
    debt_rows = sum(r["_counts"]["open"] for r in verify_rows if r["week"] == "w1")
    debt_files = sum(1 for r in verify_rows if r["week"] == "w1")
    debt_two_seat = sum(r["_counts"]["open_two_seat"] for r in verify_rows if r["week"] == "w1")
    build_days = sum(r.get("days", 0) for r in rows)
    tentative_days = sum(r.get("days", 0) for r in rows if r.get("tentative"))
    user_hours = sum(r.get("hours", 0) for r in rows if "user" in r["who"])
    summary = {
        "debt_rows": debt_rows, "debt_files": debt_files, "debt_two_seat": debt_two_seat,
        "build_days": build_days, "tentative_days": tentative_days, "user_hours": user_hours,
        "weeks": len(weeks),
    }

    head = sh("git", "rev-parse", "--short", "HEAD").strip()
    ctx = {"plan": plan, "meta": meta, "weeks": weeks, "milestones": milestones, "rows": rows,
           "unscheduled": unscheduled, "today": today, "head": head, "summary": summary}

    OUT_MD.write_text(render_md(ctx), encoding="utf-8", newline="\n")
    OUT_HTML.write_text(render_html(ctx), encoding="utf-8", newline="\n")

    print(f"schedule_detail: wrote {OUT_MD.relative_to(REPO)} and {OUT_HTML.relative_to(REPO)}")
    print(f"  reconciled {today}, repo {head}: {len(rows)} rows across {len(weeks)} weeks; "
          f"verification debt {debt_rows} open rows in {debt_files} checklists "
          f"({debt_two_seat} need a second seat); build lane {build_days:g} Claude days "
          f"({tentative_days:g} tentative); user time {user_hours:g} h")
    for w in warnings:
        print("  warning:", w)
    if unscheduled:
        print(f"  {len(unscheduled)} checklists with open rows are not scheduled (listed on the page)")
    return 0


# --------------------------------------------------------------------------------------
# Shared text helpers


def row_time(r: dict) -> str:
    if "days" in r:
        d = r["days"]
        return f"{d:g} Claude day{'s' if d != 1 else ''}"
    if "by" in r:
        return f"by {fmt_date(r['by'])}"
    return fmt_hours(r.get("hours", 0))


def row_needs(r: dict) -> list[str]:
    needs = list(r.get("needs", []))
    if "_counts" in r:
        c = r["_counts"]
        where = f" (on branch {r['checklist_branch']} until the merge)" if r.get("checklist_branch") else ""
        bits = f"{c['open']} rows to run"
        if c["open_two_seat"]:
            bits += f", {c['open_two_seat']} of them in a two-seat section"
        needs.insert(0, f"checklist {r['checklist']}{where}: {bits}")
    return needs


def row_refs(r: dict) -> list[tuple[str, str]]:
    """(label, target) pairs a reader looks status up in."""
    refs = []
    if "checklist" in r:
        refs.append(("checklist", r["checklist"]))
    if "todo" in r:
        refs.append(("To-Do entry", r["todo"]))
    return refs


# --------------------------------------------------------------------------------------
# Markdown


def md_cell(s: str) -> str:
    return s.replace("|", "\\|").replace("\n", " ")


def render_md(c: dict) -> str:
    meta, weeks, rows, s = c["meta"], c["weeks"], c["rows"], c["summary"]
    L: list[str] = []
    L.append(f"# {meta['title']}")
    L.append("")
    L.append(f"**Generated** {c['today']} from `docs/schedule_detail.toml` at repo `{c['head']}` by "
             f"`tools/schedule_detail.py`. Do not edit this file; edit the plan file and rerun.")
    L.append(f"**Target:** {meta['target']} (fixed). Every other date is a proposal.")
    if meta.get("published_url"):
        L.append(f"**Readable copy:** `docs/schedule_detail.html` (same content), also published at "
                 f"{meta['published_url']}.")
    else:
        L.append("**Readable copy:** `docs/schedule_detail.html` (same content).")
    L.append("")
    L.append("> **This page carries no status.** It says what happens, who does it, what it needs, "
             "how long it takes, what it waits on, and where the result is recorded. Whether a row "
             "passed lives in the checklist it names, or in the `CLAUDE.md` To-Do entry it names. "
             "The counts of open rows are the size of the sitting still to run, read from the "
             "checklist files at generation time, not a verdict.")
    L.append("")
    L.append("## At a glance")
    L.append("")
    L.append(f"- **Verification debt now:** {s['debt_rows']} open rows in {s['debt_files']} "
             f"checklists, {s['debt_two_seat']} of them needing a second seat. All runnable today.")
    L.append(f"- **Build lane:** {s['build_days']:g} Claude days laid out, {s['tentative_days']:g} "
             f"of them tentative (waiting on the spell batch approval).")
    L.append(f"- **The user's time scheduled:** {s['user_hours']:g} hours across {s['weeks']} weeks, "
             f"against about {meta['hours_per_week']} hours a week available.")
    L.append("")
    L.append("## Milestones")
    L.append("")
    L.append("| Date | Milestone | Means |")
    L.append("|---|---|---|")
    for m in c["plan"]["milestone"]:
        t = " *(tentative)*" if m.get("tentative") else ""
        L.append(f"| {fmt_date(m['date'])} | **{m['name']}**{t} | {md_cell(m['means'])} |")
    L.append("")
    L.append("## How to read the weeks")
    L.append("")
    L.append("Five lanes. Each row is one act that can be checked afterwards: one checklist sitting, "
             "one build step, one redeploy, one friend session, one decision.")
    L.append("")
    for lane in LANES:
        L.append(f"- **{LANE_LABEL[lane]}**: {LANE_WHO[lane]}.")
    L.append("")
    L.append("Columns: what, who, needs, time (the user's hours, or Claude's build days, or the date a "
             "decision starts to block), waits on (row ids), done when (where the result is recorded). "
             "A *tentative* row waits on an approval or a decision.")
    L.append("")
    for w in weeks.values():
        L.append(f"## {w['id'].upper()}: {w['_range']}: {w['title']}")
        L.append("")
        L.append(w["summary"])
        L.append("")
        L.append(f"The user's time this week: {w['_user_hours']:g} h. Claude build days: "
                 f"{w['_claude_days']:g}.")
        L.append("")
        L.append("| Id | Lane | What | Who | Needs | Time | Waits on | Done when |")
        L.append("|---|---|---|---|---|---|---|---|")
        for lane in LANES:
            for r in [x for x in w["_rows"] if x["lane"] == lane]:
                what = r["what"]
                if r.get("day"):
                    what = f"*{r['day']}.* " + what
                if r.get("tentative"):
                    what = "**tentative** " + what
                if r.get("blocks"):
                    what += f" Blocks: {r['blocks']}"
                needs = "; ".join(row_needs(r)) or "nothing"
                waits = ", ".join(r.get("waits_on", [])) or ""
                done = r["done_when"]
                refs = row_refs(r)
                if refs:
                    done += " Look it up in: " + "; ".join(f"{k} `{v}`" for k, v in refs)
                L.append("| " + " | ".join(md_cell(x) for x in [
                    r["id"], LANE_LABEL[lane], what, r["who"], needs, row_time(r), waits, done]) + " |")
        L.append("")
    L.append("## Waiting on a yes")
    L.append("")
    L.append("Every decision above, by the date it starts to block something.")
    L.append("")
    L.append("| By | Decision | Who | Blocks |")
    L.append("|---|---|---|---|")
    for r in sorted([r for r in rows if r["lane"] == "decide"], key=lambda r: r["by"]):
        L.append(f"| {fmt_date(r['by'])} | {md_cell(r['what'])} | {r['who']} | {md_cell(r['blocks'])} |")
    L.append("")
    L.append("## Open rows this plan does not schedule")
    L.append("")
    L.append("Read from `docs/playtest_notes/` at generation time. A recent one (touched in the last "
             f"{meta['stale_checklist_days']} days) needs a row above or a reason; an older one is a "
             "candidate for the week-5 triage, which decides whether it is retired, superseded, or "
             "worth a re-run.")
    L.append("")
    L.append("| Last touched | Open | Passed | Skipped | Checklist |")
    L.append("|---|---|---|---|---|")
    for u in c["unscheduled"]:
        flag = " *(recent)*" if u["age"] <= meta["stale_checklist_days"] else ""
        L.append(f"| {u['mtime']}{flag} | {u['open']} | {u['pass']} | {u['skip']} | `{u['name']}` |")
    L.append("")
    L.append("## After the door opens")
    L.append("")
    L.append("Undated by the planner's choice. Status for each lives in the To-Do; phase 5's four "
             "decisions come first.")
    L.append("")
    for a in c["plan"]["after"]:
        L.append(f"- {a['text']}")
    L.append("")
    L.append("## Risks")
    L.append("")
    L.append("| Risk | Impact | Mitigation |")
    L.append("|---|---|---|")
    for k in c["plan"]["risk"]:
        L.append(f"| **{md_cell(k['risk'])}** | {md_cell(k['impact'])} | {md_cell(k['mitigation'])} |")
    L.append("")
    L.append("## Assumptions")
    L.append("")
    for a in c["plan"]["assumption"]:
        L.append(f"- {a['text']} *Source: {a['source']}*")
    L.append("")
    L.append("## Words used here")
    L.append("")
    for g in c["plan"]["glossary"]:
        L.append(f"- **{g['term']}.** {g['meaning']}")
    L.append("")
    L.append("## How this stays current")
    L.append("")
    L.append("One home per fact. This page carries dates, sequence, owner and dependencies; the "
             "`CLAUDE.md` To-Do carries status; the checklists carry verdicts; `docs/schedule.md` "
             "carries the phases. The plan file `docs/schedule_detail.toml` is the only thing a person "
             "edits here.")
    L.append("")
    L.append("Claude regenerates this page in every session that changes a To-Do status or a checklist "
             "(Session workflow step 4 in `CLAUDE.md`). The procedure, three lines:")
    L.append("")
    L.append("1. `python tools/schedule_detail.py` from the repo root. It stops with an error if any row "
             "names a checklist or To-Do entry that no longer exists.")
    L.append("2. Read its report. An unscheduled checklist with open rows, or a scheduled checklist "
             "with none left, means the plan file needs a row added, moved or removed. Edit and rerun.")
    L.append("3. Commit the plan file with both generated files, and republish the page at its link.")
    L.append("")
    L.append(f"*Last reconciled {c['today']} at repo `{c['head']}`.*")
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------------------
# HTML (tokens and type match docs/schedule.html so the two pages read as one set)

CSS = r"""
  /* Layout: a single reading column, each week a section with one lane-grouped table. */
  :root {
    --ground:    #EEF0F3;
    --surface:   #FFFFFF;
    --surface-2: #F6F7F9;
    --ink:       #1A1F28;
    --ink-soft:  #58616F;
    --ink-faint: #8A93A1;
    --rule:      #D6DAE1;
    --rule-soft: #E4E7EC;
    --accent:    #9A6518;
    --accent-br: #C8862A;
    --accent-wash:#F3E7D2;
    --blue:      #3E5C7E;
    --blue-wash: #DDE5EE;
    --good:      #3F6B4C;
    --good-wash: #DFEBE2;
    --risk:      #9C3F2C;
    --risk-wash: #F5E2DD;
    --serif: "Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia, serif;
    --sans: "Segoe UI", system-ui, -apple-system, "Helvetica Neue", sans-serif;
    --mono: "Cascadia Code", Consolas, ui-monospace, "SF Mono", Menlo, monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --ground: #12151C; --surface: #191D26; --surface-2: #1F242F;
      --ink: #E4E7EC; --ink-soft: #9AA3B2; --ink-faint: #6B7484;
      --rule: #2A303C; --rule-soft: #222834;
      --accent: #D9973C; --accent-br: #E8AC57; --accent-wash: #3A2C15;
      --blue: #6B93BF; --blue-wash: #1E2A38;
      --good: #6BA37C; --good-wash: #1C2E22;
      --risk: #D06A52; --risk-wash: #3A1F19;
      color-scheme: dark;
    }
  }
  :root[data-theme="dark"] {
    --ground: #12151C; --surface: #191D26; --surface-2: #1F242F;
    --ink: #E4E7EC; --ink-soft: #9AA3B2; --ink-faint: #6B7484;
    --rule: #2A303C; --rule-soft: #222834;
    --accent: #D9973C; --accent-br: #E8AC57; --accent-wash: #3A2C15;
    --blue: #6B93BF; --blue-wash: #1E2A38;
    --good: #6BA37C; --good-wash: #1C2E22;
    --risk: #D06A52; --risk-wash: #3A1F19;
    color-scheme: dark;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--ground); color: var(--ink); font-family: var(--sans);
         font-size: 15px; line-height: 1.5; }
  .wrap { max-width: 1120px; margin: 0 auto; padding-block: 40px 56px; padding-inline: 16px; }
  @media (min-width: 720px) { .wrap { padding-inline: 32px; } }
  h1, h2, h3 { font-family: var(--serif); font-weight: 400; text-wrap: balance; margin: 0; }
  h1 { font-size: clamp(28px, 4vw, 40px); line-height: 1.15; }
  h1 em { font-style: italic; color: var(--accent); }
  h2 { font-size: 26px; margin-top: 56px; padding-top: 20px; border-top: 1px solid var(--rule); }
  h3 { font-size: 19px; }
  p { margin: 0; }
  p + p { margin-top: 10px; }
  a { color: var(--accent); }
  code { font-family: var(--mono); font-size: 0.92em; background: var(--surface-2);
         padding: 1px 4px; border-radius: 3px; }
  .eyebrow { font-family: var(--mono); font-size: 11.5px; letter-spacing: .12em; text-transform: uppercase;
             color: var(--ink-faint); margin-bottom: 14px; }
  .thesis { font-size: 17px; color: var(--ink-soft); max-width: 68ch; margin-top: 18px; }
  .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 14px;
           margin-top: 28px; }
  .stat { background: var(--surface); border: 1px solid var(--rule-soft); padding: 14px 16px; min-width: 0; }
  .stat-k { font-family: var(--mono); font-size: 11px; letter-spacing: .1em; text-transform: uppercase;
            color: var(--ink-faint); }
  .stat-v { font-family: var(--serif); font-size: 26px; margin-top: 4px; font-variant-numeric: tabular-nums; }
  .stat-v.hi { color: var(--accent); }
  .stat-sub { display: block; font-family: var(--sans); font-size: 12.5px; color: var(--ink-soft); margin-top: 2px; }
  .rule-note { background: var(--surface); border-left: 3px solid var(--accent); padding: 14px 18px;
               margin-top: 22px; color: var(--ink-soft); max-width: 78ch; }
  .rule-note b { color: var(--ink); }
  .lede { color: var(--ink-soft); max-width: 72ch; margin-top: 12px; }
  .milestones { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 12px; margin-top: 20px; }
  .ms { background: var(--surface); border-top: 3px solid var(--accent); padding: 12px 14px; min-width: 0; }
  .ms.tent { border-top-style: dashed; }
  .ms .when { font-family: var(--mono); font-size: 12px; color: var(--ink-faint); }
  .ms .name { font-family: var(--serif); font-size: 18px; margin-top: 4px; }
  .ms .means { font-size: 13.5px; color: var(--ink-soft); margin-top: 6px; }
  .lanes { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-top: 16px; }
  .lane-card { background: var(--surface); padding: 10px 12px; font-size: 13.5px; color: var(--ink-soft); min-width: 0; }
  .lane-card b { color: var(--ink); }
  .week-head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px 16px; }
  .week-head .when { font-family: var(--mono); font-size: 12.5px; color: var(--ink-faint); }
  .week-meta { display: flex; flex-wrap: wrap; gap: 8px 18px; margin-top: 10px; font-family: var(--mono);
               font-size: 12px; color: var(--ink-soft); }
  .scroll { overflow-x: auto; margin-top: 16px; border: 1px solid var(--rule-soft); background: var(--surface); }
  table { border-collapse: collapse; width: 100%; min-width: 900px; font-size: 13.5px; }
  th { text-align: left; font-family: var(--mono); font-size: 11px; letter-spacing: .08em; text-transform: uppercase;
       color: var(--ink-faint); padding: 10px 12px; border-bottom: 1px solid var(--rule); background: var(--surface-2); }
  td { padding: 10px 12px; border-bottom: 1px solid var(--rule-soft); vertical-align: top; }
  tr:last-child td { border-bottom: 0; }
  td.id { font-family: var(--mono); font-size: 12px; color: var(--ink-faint); white-space: nowrap; }
  td.time { white-space: nowrap; font-variant-numeric: tabular-nums; }
  td.what { min-width: 300px; }
  td.needs, td.done { min-width: 200px; color: var(--ink-soft); }
  td ul { margin: 0; padding-left: 16px; }
  td .day { font-family: var(--mono); font-size: 11.5px; color: var(--ink-faint); display: block; margin-bottom: 3px; }
  td .blocks { display: block; margin-top: 4px; color: var(--ink-soft); }
  td .ref { display: block; margin-top: 4px; font-size: 12.5px; }
  tr.tent td { color: var(--ink-soft); }
  tr.tent td.what { border-left: 3px dashed var(--accent-br); }
  .chip { display: inline-block; font-family: var(--mono); font-size: 10.5px; letter-spacing: .06em; text-transform: uppercase;
          padding: 2px 7px; border-radius: 3px; border: 1px solid var(--rule); white-space: nowrap; }
  .chip.build   { color: var(--blue); background: var(--blue-wash); border-color: transparent; }
  .chip.operate { color: var(--accent); background: var(--accent-wash); border-color: transparent; }
  .chip.verify  { color: var(--good); background: var(--good-wash); border-color: transparent; }
  .chip.people  { color: var(--ink); background: var(--surface-2); }
  .chip.decide  { color: var(--risk); background: var(--risk-wash); border-color: transparent; }
  .chip.tent    { color: var(--accent-br); border-style: dashed; margin-left: 6px; }
  .chip.ms      { color: var(--accent); border-color: var(--accent); margin-left: 6px; }
  .plain { margin-top: 14px; max-width: 78ch; }
  .plain li { margin-top: 8px; }
  .plain li b { color: var(--ink); }
  .two-col { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px 28px; margin-top: 14px; }
  .two-col div { font-size: 14px; color: var(--ink-soft); min-width: 0; }
  .two-col b { color: var(--ink); }
  .steps { margin-top: 12px; padding-left: 20px; max-width: 78ch; }
  .steps li { margin-top: 6px; }
  footer { margin-top: 64px; padding-top: 20px; border-top: 1px solid var(--rule); font-family: var(--mono);
           font-size: 11.5px; color: var(--ink-faint); display: flex; flex-wrap: wrap; gap: 6px 20px; }
  a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
"""


def esc(s: str) -> str:
    return html.escape(str(s), quote=True)


def render_html(c: dict) -> str:
    meta, weeks, rows, s = c["meta"], c["weeks"], c["rows"], c["summary"]
    H: list[str] = []
    H.append(f"<title>{esc(meta['title'])}</title>")
    H.append("<style>" + CSS + "</style>")
    H.append('<div class="wrap">')
    H.append('<header>')
    H.append('<div class="eyebrow">Project Dawn</div>')
    H.append('<h1>Five weeks to the first evening your friends play it, <em>one act at a time</em>.</h1>')
    H.append('<p class="thesis">The schedule you already have says which phase we are in. This page says what '
             'happens in each of the weeks between now and November 8: every checklist sitting, build step, '
             'redeploy, export, decision and friend session, with who does it, what it needs, how long it takes '
             'and what it waits on. It is generated from the project files, so the counts are read, not typed.</p>')
    H.append('<div class="stats">')
    H.append(f'<div class="stat"><div class="stat-k">Target</div><div class="stat-v hi">Nov 8'
             f'<span class="stat-sub">the only fixed date here</span></div></div>')
    H.append(f'<div class="stat"><div class="stat-k">Reconciled</div><div class="stat-v">{esc(fmt_date(c["today"]))}'
             f'<span class="stat-sub">repo {esc(c["head"])}</span></div></div>')
    H.append(f'<div class="stat"><div class="stat-k">Verification debt</div><div class="stat-v">{s["debt_rows"]} rows'
             f'<span class="stat-sub">in {s["debt_files"]} checklists, {s["debt_two_seat"]} need a second seat; all runnable now</span></div></div>')
    H.append(f'<div class="stat"><div class="stat-k">Build lane</div><div class="stat-v">{s["build_days"]:g} days'
             f'<span class="stat-sub">of Claude time, {s["tentative_days"]:g} of them waiting on the spell batch approval</span></div></div>')
    H.append(f'<div class="stat"><div class="stat-k">The user\'s time</div><div class="stat-v">{s["user_hours"]:g} h'
             f'<span class="stat-sub">scheduled over {s["weeks"]} weeks, against about {meta["hours_per_week"]} a week</span></div></div>')
    H.append('</div>')
    H.append('<div class="rule-note"><p><b>This page carries no status.</b> It says what happens, who does it, what '
             'it needs, how long it takes, what it waits on, and where the result gets written down. Whether a row '
             'passed lives in the checklist it names or in the To-Do entry it names, never here. The open-row '
             'counts are the size of the sitting still to run, read from the checklist files when this page was '
             'generated. They are not a verdict.</p></div>')
    H.append('</header>')

    # Milestones
    H.append('<section><h2>Milestones</h2>')
    H.append('<p class="lede">Placed by working back from November 8 at the measured pace, with the fifth week '
             'left as slack. A dashed top edge means the milestone waits on an approval.</p>')
    H.append('<div class="milestones">')
    for m in c["plan"]["milestone"]:
        cls = "ms tent" if m.get("tentative") else "ms"
        H.append(f'<div class="{cls}"><div class="when">{esc(fmt_date(m["date"]))}</div>'
                 f'<div class="name">{esc(m["name"])}</div><div class="means">{esc(m["means"])}</div></div>')
    H.append('</div></section>')

    # How to read
    H.append('<section><h2>How to read the weeks</h2>')
    H.append('<p class="lede">Five lanes. Each row is one act that can be checked afterwards: one checklist '
             'sitting, one build step, one redeploy, one friend session, one decision. The time column is the '
             'user\'s hours, or Claude\'s build days, or the date a decision starts to block something. '
             'A row with a dashed edge is tentative: it waits on an approval or a decision.</p>')
    H.append('<div class="lanes">')
    for lane in LANES:
        H.append(f'<div class="lane-card"><span class="chip {lane}">{LANE_LABEL[lane]}</span><br>'
                 f'<b>Who:</b> {esc(LANE_WHO[lane])}.</div>')
    H.append('</div></section>')

    # Weeks
    for w in weeks.values():
        H.append('<section>')
        H.append(f'<h2><span class="week-head"><span>{esc(w["title"])}</span>'
                 f'<span class="when">{esc(w["id"].upper())} &middot; {esc(w["_range"])}</span></span></h2>')
        H.append(f'<p class="lede">{esc(w["summary"])}</p>')
        H.append(f'<div class="week-meta"><span>the user\'s time: {w["_user_hours"]:g} h</span>'
                 f'<span>Claude build days: {w["_claude_days"]:g}</span></div>')
        H.append('<div class="scroll"><table>')
        H.append('<thead><tr><th>Id</th><th>Lane</th><th>What</th><th>Who</th><th>Needs</th><th>Time</th>'
                 '<th>Waits on</th><th>Done when (look it up in)</th></tr></thead><tbody>')
        for lane in LANES:
            for r in [x for x in w["_rows"] if x["lane"] == lane]:
                cls = ' class="tent"' if r.get("tentative") else ""
                H.append(f'<tr{cls}>')
                H.append(f'<td class="id">{esc(r["id"])}</td>')
                chips = f'<span class="chip {lane}">{LANE_LABEL[lane]}</span>'
                if r.get("tentative"):
                    chips += '<span class="chip tent">tentative</span>'
                if r.get("milestone"):
                    chips += f'<span class="chip ms">{esc(c["milestones"][r["milestone"]]["name"])}</span>'
                H.append(f'<td>{chips}</td>')
                what = ""
                if r.get("day"):
                    what += f'<span class="day">{esc(r["day"])}</span>'
                what += esc(r["what"])
                if r.get("blocks"):
                    what += f'<span class="blocks"><b>Blocks:</b> {esc(r["blocks"])}</span>'
                H.append(f'<td class="what">{what}</td>')
                H.append(f'<td>{esc(r["who"])}</td>')
                needs = row_needs(r)
                H.append('<td class="needs">' + ("<ul>" + "".join(f"<li>{esc(n)}</li>" for n in needs) + "</ul>"
                                                 if needs else "nothing") + '</td>')
                H.append(f'<td class="time">{esc(row_time(r))}</td>')
                H.append(f'<td class="id">{esc(", ".join(r.get("waits_on", [])))}</td>')
                done = esc(r["done_when"])
                for k, v in row_refs(r):
                    if k == "checklist":
                        href = f"playtest_notes/{v}"
                        done += f'<span class="ref">{k}: <a href="{esc(href)}"><code>{esc(v)}</code></a></span>'
                    else:
                        done += f'<span class="ref">{k}: <code>{esc(v)}</code></span>'
                H.append(f'<td class="done">{done}</td>')
                H.append('</tr>')
        H.append('</tbody></table></div>')
        H.append('</section>')

    # Decisions
    H.append('<section><h2>Waiting on a yes</h2>')
    H.append('<p class="lede">Every decision above, by the date it starts to block something.</p>')
    H.append('<div class="scroll"><table><thead><tr><th>By</th><th>Decision</th><th>Who</th><th>Blocks</th></tr></thead><tbody>')
    for r in sorted([r for r in rows if r["lane"] == "decide"], key=lambda r: r["by"]):
        H.append(f'<tr><td class="time">{esc(fmt_date(r["by"]))}</td><td class="what">{esc(r["what"])}</td>'
                 f'<td>{esc(r["who"])}</td><td class="needs">{esc(r["blocks"])}</td></tr>')
    H.append('</tbody></table></div></section>')

    # Unscheduled
    H.append('<section><h2>Open rows this plan does not schedule</h2>')
    H.append(f'<p class="lede">Read from the checklist folder when this page was generated. A recent one '
             f'(touched in the last {meta["stale_checklist_days"]} days) needs a row above or a reason. An older '
             f'one is a candidate for the week-5 triage, which decides whether it is retired, superseded, or worth '
             f'a re-run.</p>')
    H.append('<div class="scroll"><table><thead><tr><th>Last touched</th><th>Open</th><th>Passed</th><th>Skipped</th><th>Checklist</th></tr></thead><tbody>')
    for u in c["unscheduled"]:
        flag = ' <span class="chip tent">recent</span>' if u["age"] <= meta["stale_checklist_days"] else ""
        H.append(f'<tr><td class="time">{u["mtime"]}{flag}</td><td class="time">{u["open"]}</td>'
                 f'<td class="time">{u["pass"]}</td><td class="time">{u["skip"]}</td>'
                 f'<td><a href="playtest_notes/{esc(u["name"])}"><code>{esc(u["name"])}</code></a></td></tr>')
    H.append('</tbody></table></div></section>')

    # After
    H.append('<section><h2>After the door opens</h2>')
    H.append('<p class="lede">Undated by the planner\'s choice. Status for each lives in the To-Do; phase 5\'s '
             'four decisions come first.</p>')
    H.append('<ul class="plain">' + "".join(f"<li>{esc(a['text'])}</li>" for a in c["plan"]["after"]) + '</ul>')
    H.append('</section>')

    # Risks
    H.append('<section><h2>Risks</h2>')
    H.append('<div class="scroll"><table><thead><tr><th>Risk</th><th>Impact</th><th>Mitigation</th></tr></thead><tbody>')
    for k in c["plan"]["risk"]:
        H.append(f'<tr><td class="what"><b>{esc(k["risk"])}</b></td><td class="needs">{esc(k["impact"])}</td>'
                 f'<td class="needs">{esc(k["mitigation"])}</td></tr>')
    H.append('</tbody></table></div></section>')

    # Assumptions + glossary
    H.append('<section><h2>Assumptions</h2>')
    H.append('<ul class="plain">' + "".join(
        f"<li>{esc(a['text'])} <i>Source: {esc(a['source'])}</i></li>" for a in c["plan"]["assumption"]) + '</ul>')
    H.append('</section>')
    H.append('<section><h2>Words used here</h2><div class="two-col">')
    for g in c["plan"]["glossary"]:
        H.append(f'<div><b>{esc(g["term"])}.</b> {esc(g["meaning"])}</div>')
    H.append('</div></section>')

    # Upkeep
    H.append('<section><h2>How this stays current</h2>')
    H.append('<div class="rule-note"><p><b>One home per fact.</b> This page carries dates, sequence, owner and '
             'dependencies. The To-Do carries status. The checklists carry verdicts. The schedule carries the '
             'phases. The plan file <code>docs/schedule_detail.toml</code> is the only thing a person edits here; '
             'both this page and its markdown twin are generated from it.</p></div>')
    H.append('<p class="plain">Claude regenerates this page in every session that changes a To-Do status or a '
             'checklist, as part of the session workflow. The procedure:</p>')
    H.append('<ol class="steps">'
             '<li>Run <code>python tools/schedule_detail.py</code> from the repo root. It stops with an error if '
             'any row names a checklist or To-Do entry that no longer exists.</li>'
             '<li>Read its report. An unscheduled checklist with open rows, or a scheduled checklist with none '
             'left, means the plan file needs a row added, moved or removed. Edit it and rerun.</li>'
             '<li>Commit the plan file with both generated files, and republish this page at its link.</li>'
             '</ol>')
    H.append('</section>')

    pub = f'<span>Published copy: <a href="{esc(meta["published_url"])}">{esc(meta["published_url"])}</a></span>' \
        if meta.get("published_url") else ""
    H.append(f'<footer><span>Project Dawn</span><span>Week by week to the friends build</span>'
             f'<span>Generated {esc(str(c["today"]))} at repo {esc(c["head"])}</span>'
             f'<span>Plan: docs/schedule_detail.toml</span><span>Phases: schedule.html</span>{pub}</footer>')
    H.append('</div>')
    return "\n".join(H) + "\n"


if __name__ == "__main__":
    sys.exit(main())
