"""Sync the Project Dawn Trello board from the project's own records.

The board is a view, never a list of its own: the CLAUDE.md To-Do stays the one live list
(Session workflow, step 6), and this script rebuilds the board's cards from it. The layout
follows the Monsters and Memories roadmap board: lists in the order a player meets the game,
status as a label, a divider card in each list (the friends build above it, later work below),
and a Welcome list with the plan and one history card per month.

    python tools/trello_board.py --dry-run   # say what would change, change nothing
    python tools/trello_board.py             # sync the board

Sources: the CLAUDE.md To-Do, docs/session_notes/ (its README index and the long
session_2026_10_25.md), docs/schedule.md section 7 and docs/schedule_detail.toml.

Credentials: TRELLO_KEY and TRELLO_TOKEN from F:/Projects/trello.local.env (outside both
repos; another path in TRELLO_ENV_FILE). Neither value is ever printed, and error messages
carry no query string.

Every card the script owns ends with a `pd-id:` line, which is how a re-run finds it again: a
changed card is updated in place, a new one created, and one whose source is gone archived.
Cards without the line (made by hand) are left alone, and so are the lists and labels they
use. A comment on a generated card survives a sync; an edit to its name, text, list or
labels does not.
"""
import argparse
import json
import os
import re
import sys
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_FILE = os.environ.get('TRELLO_ENV_FILE', r'F:/Projects/trello.local.env')
API = 'https://api.trello.com/1'
BOARD = 'b8iQBiSH'  # https://trello.com/b/b8iQBiSH/project-dawn
REQUEST_GAP = 0.12  # seconds between writes; Trello allows 100 requests per 10 s per token
DESC_CAP = 6000     # a To-Do entry past this is cut; the full text is in CLAUDE.md
ID_PREFIX = 'pd-id: '
DIVIDER = '^^ FRIENDS BUILD ^^'

MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
          'September', 'October', 'November', 'December']

# Status labels, in the order cards are sorted within a list. The first three sit above the
# divider (they are in the build the friends play), the rest below it.
STATUSES = [
    ('done', 'Done (playtested)', 'green'),
    ('built', 'Built, awaiting playtest', 'blue'),
    ('ongoing', 'Ongoing (partly built)', 'sky'),
    ('decided', 'Decided, not built', 'yellow'),
    ('discuss', 'To Be Discussed', 'red'),
    ('backlog', 'Backlog', 'black'),
]
ABOVE_DIVIDER = {'done', 'built', 'ongoing'}
STATUS_LABEL = {key: (name, color) for key, name, color in STATUSES}
STATUS_ORDER = {key: i for i, (key, _, _) in enumerate(STATUSES)}

# The player's journey, left to right. Each To-Do entry is placed by the start of its title;
# an entry no prefix claims falls back to its To-Do section (FALLBACK) and is reported.
JOURNEY = [
    ('accounts', 'Accounts & Login', [
        'Camp / kick', 'Reconnect grace', 'Tell testers about', 'Login rate limit',
        'No way to reset', 'Self-serve change-password', 'Account admin tooling',
        'Kick by account', 'Unclean-kill relogin',
        'M&M roadmap: support']),
    ('creation', 'Character Creation', [
        'Character creation follow-ups', 'Change your appearance', 'The starting kit',
        'Fae gear line', 'M&M roadmap: character']),
    ('world', 'The World', [
        'Phase 4 content', 'The starting zone at 4 km', 'The compass is mirrored',
        'Wandering wildlife', 'Obstacle collision', "The ridge's south face",
        'NPC placeholder capsules', 'Multi-zone epic', 'Time of day is per-client',
        'Weather system', 'Zone transition effects', 'Enemy AOI cell-crossing',
        'Idle enemies rebroadcast', 'The server height model',
        'M&M roadmap: the world', 'M&M roadmap: mounts', 'M&M roadmap: bigger']),
    ('movement', 'Movement & Exploration', [
        'Remote players never show a jump', 'A jump should be seen', 'Other players never turn',
        'The own body never read its facing', 'Fall damage follow-ups', 'Mount system',
        '/loc command', 'M&M roadmap: getting']),
    ('chat', 'Chat & Social', [
        'Incoming /tell', 'EQ-style /r', 'LFG flag', 'Language system wiring',
        'Sticky chat channel', 'The chat box must match', '/say reaches',
        'Social macros', 'Four chat commands', 'Chat: persist the active tab', 'Player inspect']),
    ('items', 'Items & Inventory', [
        'Held-item bank', 'The vault in the cursor grammar', 'No-drop / no-trade',
        'The cursor-slot epic', 'Full bags should move', 'Trade window',
        'Server move-merge ignores', 'Bank coin deposit', 'Coin normalises', 'Stack All scope',
        'Buying and granting ignore bag space', 'Banker exchange fee bands', 'Gem sockets',
        'Itemization oddities', 'Research: the Monsters and Memories item log',
        'Bank Items-tab', 'Bags open on left-click', 'Inventory desyncs',
        'The vendor window claims', 'Client crashed moving items',
        'M&M roadmap: items']),
    ('npcs', 'NPCs, Quests & Factions', [
        'Trade slice 2', 'Faction system', 'The consider command',
        'Quest and loot content plumbing', 'Quest reward item follow-ups',
        'No server-side proximity gate', 'M&M roadmap: NPCs']),
    ('spells', 'Classes, Spells & Abilities', [
        'The spell batch', 'Cast-code findings', 'Bard song rework', 'Dwarf racial ability',
        'Heal magnitude', 'EQ parity', 'Client-only spell backlog', 'Gate and the Soul Binder',
        'CancelCast is a missing feature', 'The cast arms duplicate', 'Active skills partly',
        'Sneak skill', 'Target-of-target heal']),
    ('combat', 'Combat', [
        'Proc follow-ups', 'Ranged attacks consume', 'A weapon swap with no target',
        'Two-handed damage arc', 'Seated-combat penalties', 'Named mobs lost enrage',
        'Regen model', 'Dual wield as', 'Class-restricted equipping', 'A two-hander needs',
        'Dual-wielding two-handers', 'Facing and view angle', 'Two small verifies',
        'PvP flagging', 'M&M roadmap: combat']),
    ('pets', 'Pets & Charm', [
        'Pet persistence', "An owner's own pet", 'Pet buffs', 'Pet level does not scale',
        'Beast Master taming', 'A charm that ends', 'A mob whose only attacker was a pet',
        'A caster can hold any number', 'A charmed pet that dies', 'PET_CHARM had no range']),
    ('death', 'Death & Corpses', [
        'A dead character died again', 'Res-sickness', 'Respawn at bind',
        'Corpse auto-re-equip', 'Per-creature corpse', 'Tune corpses',
        '"You cannot do that while dead."']),
    ('group', 'Grouping & Loot', [
        'Group-mate HP/MP', 'Loot rights odds', 'Group panel bars are blank',
        "Other players' levels", 'Dead group members']),
    ('trades', 'Tradeskills, Food & Consumables', [
        'Tradeskills create phantom', 'Tradeskill content gaps', 'Server-authoritative tradeskills',
        'Consumables system', 'Bookbinding', 'Clockwork Engineering', 'EQ-style food/water']),
    ('ui', 'UI, HUD & Audio', [
        'Right-click is the world-interact', 'Clicks pass through', 'The UI theme',
        'In-game UI layout', 'Combine character', 'ESC-menu UI scale', 'Nameplate and targeting',
        'Playtest asks from the charm-return', 'Remaining EQ keybinds', 'Art asset pipeline',
        'Player portrait', 'Hotbar + socials bleed', 'Confirm what can become', 'Sound system']),
    ('security', 'Security & Anti-cheat', [
        'Housekeeping audit', 'Client-decided outcomes', 'Assorted trust gaps', 'Silent refusals',
        'NaN Move direction', 'Exploit-audit finding 10', 'Spells had no reach',
        'M&M roadmap: suspicious']),
    ('ops', 'Server, Hosting & Tools', [
        'Stand up a deploy target', 'Public-host hardening', 'GM action audit log',
        'Test Panel "Despawn All', 'GM flight', 'Audit the schedule', 'Exporter drift',
        'Docs debt', 'Procedural dungeon', 'Localization scaffold', 'Factor-later cleanups',
        'Weapon item table gaps', 'world_two_clients.rs']),
]
FALLBACK = {
    'Multiplayer / networking': 'chat', 'Security / exploits': 'security',
    'Hosting / deployment': 'ops', 'Death / corpses': 'death', 'Combat / weapons': 'combat',
    'World systems': 'world', 'UI polish': 'ui', 'Items / economy': 'items',
    'Tradeskill depth': 'trades', 'Audio & tech debt': 'ops',
}


# --- reading the records -------------------------------------------------------------------

def clean(text):
    """The user's punctuation rules: no em dashes, no arrows."""
    text = re.sub(r'[ \t]*\u2014[ \t]*$', '', text, flags=re.M)  # a dash ending a line
    text = text.replace(' \u2014 ', ', ').replace('\u2014', ', ').replace(' \u2013 ', ' to ')
    return text.replace('\u2192', 'to').replace('\u2190', 'from').replace('\u2194', 'and')


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')[:60]


def cap(text, limit, tail):
    if len(text) <= limit:
        return text
    cut = text[:limit]
    return cut[:cut.rfind(' ')] + ' ...\n\n' + tail


def read_todo():
    """Every `- [ ]` / `- [x]` entry of the To-Do, with its section and full text."""
    text = open(os.path.join(ROOT, 'CLAUDE.md'), encoding='utf-8').read()
    todo = text[text.index('## To-Do (open items only)'):]
    entries, section, current = [], None, None
    for line in todo.splitlines():
        if line.startswith('### '):
            section, current = line[4:].strip(), None
            continue
        m = re.match(r'^- \[( |x)\] (.*)', line)
        if m:
            current = {'done': m.group(1) == 'x', 'section': section, 'lines': [m.group(2)]}
            entries.append(current)
        elif current is not None and (line.startswith('  ') or not line.strip()):
            current['lines'].append(line.strip())
        else:
            current = None
    for e in entries:
        body = '\n'.join(e['lines']).strip()
        e['text'] = body
        flat = ' '.join(body.split())
        bold = re.findall(r'\*\*(.+?)\*\*', flat)
        e['title'] = clean((bold[0] if bold else flat[:90]).replace('`', '')).strip(' .:')
    return entries


# Entries whose words read as fully built while only part is. Keyed by title prefix; each
# says why, and goes when its entry is rewritten or ticked.
STATUS_OVERRIDES = {
    'Remaining EQ keybinds': 'ongoing',      # only the "/" key is built; F7, F8, F10 are not
    'In-game UI layout': 'ongoing',          # only the cast bar is built; the layout pass is not
    'Faction system': 'ongoing',             # slice 1 of 3 built
    'Camp / kick': 'ongoing',                # the notice and countdown built; return to lobby not
}


def status_of(entry):
    """One status per entry, read from the words the To-Do itself uses."""
    if entry['done']:
        return 'done'
    for prefix, status in STATUS_OVERRIDES.items():
        if entry['title'].startswith(prefix):
            return status
    t = entry['text']
    if re.search(r'\b(BUILT|DEPLOYED|MERGED)\b', t) or re.search(r'pending (the )?playtest', t):
        partly = re.search(r'still open|remains? open|stays? open|open for|is still open|'
                           r'\*\*Left:\*\*|Not built:|Still open', t, re.I)
        return 'ongoing' if partly else 'built'
    if re.search(r'\bDECIDED\b', t):
        return 'decided'
    if re.search(r'\bDESIGNED\b', t) or re.search(
            r'design call|decisions? wait|waits? on the user|user.s call|Decisions \(user\)',
            t, re.I):
        return 'discuss'
    return 'backlog'


def tick_date(entry):
    """The date a ticked entry was closed, from the words its entry uses for it."""
    for pattern, flags in ((r'(?:DONE|CLOSED|TICKED|PLAYTESTED|RE-TESTED)', 0),
                           (r'(?:playtested|ticked)', re.I), (r'BUILT', 0)):
        m = re.search(pattern + r'[^0-9]{0,60}?(2026-\d\d-\d\d)', entry['text'], flags)
        if m:
            return m.group(1)
    return None


def reflow(text):
    """The To-Do wraps its prose at about 100 columns; Trello would keep each break, so join
    the lines of a paragraph back up. Table rows stay on their own lines."""
    out, para, in_table = [], [], False
    for line in text.split('\n'):
        row = line.lstrip().startswith('|')
        stage = line.lstrip().startswith('**')  # the To-Do opens each stage of an entry so
        if para and (row or not line.strip() or stage):
            out.append(' '.join(para))
            para = []
            if stage:
                out.append('')
        if row and not in_table:
            out.append('')  # markdown draws a table only after a blank line
        elif in_table and not row:
            out.append('')
        in_table = row
        if row or not line.strip():
            out.append(line.strip())
        else:
            para.append(line.strip())
    if para:
        out.append(' '.join(para))
    return re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip()


def journey_of(entry):
    title = entry['title'].replace('`', '')
    for key, _, prefixes in JOURNEY:
        if any(title.startswith(p) for p in prefixes):
            return key, False
    return FALLBACK.get(entry['section'], 'ops'), True


def read_history():
    """(date, headline) for every work session, from the session notes index and the long
    session_2026_10_25.md, which the index carries as one row."""
    notes = os.path.join(ROOT, 'docs', 'session_notes')
    rows = []
    row = re.compile(r'^\| (2026-\d\d-\d\d) \| \[([^\]]+)\]\([^)]+\) \| (.*) \|\s*$')
    for line in open(os.path.join(notes, 'README.md'), encoding='utf-8'):
        m = row.match(line)
        if not m or m.group(2) == 'session_2026_10_25.md':
            continue
        date, _, topics = m.groups()
        bold = re.findall(r'\*\*(.+?)\*\*', topics)
        head = bold[0] if bold else re.sub(r'\s+', ' ', topics)[:100]
        rows.append((date, clean(head).replace('`', '').strip(' .:')))
    long_note = open(os.path.join(notes, 'session_2026_10_25.md'), encoding='utf-8').read()
    date = '2026-10-25'
    for head in re.findall(r'^## (.+)$', long_note, re.M):
        m = re.search(r'\([^)]*?(2026-\d\d-\d\d|\d\d-\d\d)', head)
        if m:
            date = m.group(1) if m.group(1).startswith('2026') else '2026-' + m.group(1)
        title = re.sub(r'^\d+\.\s*', '', head)
        title = re.sub(r'\s*\([^)]*\)\s*$', '', title)
        rows.append((date, clean(title).replace('`', '')))
    return sorted(rows)


# --- the board as it should be ---------------------------------------------------------------

def desired_board():
    """Lists in order, each a list of card dicts: name, desc, status, due, pd_id."""
    lists = [('welcome', 'Welcome')] + [(k, name) for k, name, _ in JOURNEY]
    cards = {k: [] for k, _ in lists}
    unplaced = []

    entries = read_todo()
    for e in entries:
        key, fell_back = journey_of(e)
        if fell_back:
            unplaced.append(e['title'])
        st = status_of(e)
        desc = cap(clean(reflow(e['text'])), DESC_CAP, '(The full entry is in the CLAUDE.md To-Do.)')
        desc += f"\n\nSource: CLAUDE.md To-Do, {e['section']}"
        cards[key].append({'name': e['title'], 'desc': desc, 'status': st,
                           'due': tick_date(e) if st == 'done' else None,
                           'pd_id': 'todo-' + slug(e['title'])})

    for key, _ in lists[1:]:
        cards[key].sort(key=lambda c: STATUS_ORDER[c['status']])  # stable: To-Do order kept
        above = [c for c in cards[key] if c['status'] in ABOVE_DIVIDER]
        below = [c for c in cards[key] if c['status'] not in ABOVE_DIVIDER]
        divider = {'name': DIVIDER, 'status': None, 'due': None, 'pd_id': f'divider-{key}',
                   'desc': 'Above this line: done, or built (wholly or in part) and waiting on '
                           'its playtest. Most built work is in the build the friends hold; a '
                           'card still on a branch or waiting on a zip says so in its text. '
                           'Below it: decided, under discussion or not started.'}
        cards[key] = above + [divider] + below

    cards['welcome'] = welcome_cards(entries)
    return lists, cards, unplaced


def welcome_cards(entries):
    plan = tomllib.load(open(os.path.join(ROOT, 'docs', 'schedule_detail.toml'), 'rb'))
    counts = {}
    for e in entries:
        counts[status_of(e)] = counts.get(status_of(e), 0) + 1
    about = (
        'A view of Project Dawn built from its own records. **The CLAUDE.md To-Do is the one '
        'live list**; this board is regenerated from it (`python tools/trello_board.py`), so '
        'edits made here are overwritten. Comments survive.\n\n'
        '**Reading it.** Lists run in the order a player meets the game, from logging in to '
        'the server behind it. Each card is one To-Do entry, its label the status:\n'
        + '\n'.join(f'- **{name}**: {counts.get(key, 0)}' for key, name, _ in STATUSES) +
        f'\n\nIn every list the **{DIVIDER}** card divides what is done or built from what '
        'comes later. An item is Done only when a filled playtest checklist shows it passing; '
        'built is not done.\n\n'
        'Cards someone adds by hand are left alone (the sync manages only its own), but an '
        'edit to a generated card is overwritten at the next sync.\n\n'
        'The layout follows the Monsters and Memories roadmap board '
        '(https://trello.com/b/wjN4owwf/monsters-and-memories-roadmap).')
    phases = []
    sch = open(os.path.join(ROOT, 'docs', 'schedule.md'), encoding='utf-8').read()
    for line in sch[sch.index('## 7. Status'):].splitlines():
        m = re.match(r'^\| (\d)\. ([^|]+)\| ([^|]+)\| (.+) \|$', line)
        if m:
            n, name, window, status = (clean(x.strip()) for x in m.groups())
            phases.append(f"**Phase {n}: {name}** ({window.replace('**', '')})\n"
                          f"{status.replace('**', '')}")
    milestones = '\n'.join(
        f"- {'no date (paused)' if m.get('paused') else m['date']}: {clean(m['name'])}"
        for m in plan['milestone'])
    week = max(plan['week'], key=lambda w: w['starts'])
    rows = [r for r in plan['row'] if r['week'] == week['id']]
    goals = (f"**{clean(week['title'])}** (the week of {week['starts']})\n\n"
             f"{clean(week['summary'])}\n\n"
             + '\n'.join(f"- {clean(r.get('day', ''))}: {clean(r['what'])}" for r in rows)
             + '\n\n**After the door**\n'
             + '\n'.join(f"- {clean(a['text'])}" for a in plan['after'])
             + f"\n\nThe week-by-week planner: {plan['meta']['published_url']}")
    out = [
        {'name': 'About this board', 'desc': about, 'pd_id': 'welcome-about'},
        {'name': 'Current goals', 'desc': cap(goals, 15000, '(See the planner page.)'),
         'pd_id': 'welcome-goals'},
        {'name': 'Phases & milestones',
         'desc': cap('\n\n'.join(phases) + '\n\n**Milestones**\n' + milestones, 15000,
                     '(See docs/schedule.md.)'), 'pd_id': 'welcome-phases'},
        {'name': 'PREVIOUS UPDATES', 'desc': 'One card per month of work, newest first, from '
         'the session notes (docs/session_notes/).', 'pd_id': 'welcome-updates'},
    ]
    by_month = {}
    for date, head in read_history():
        by_month.setdefault(date[:7], []).append(f'- {date[5:]}: {head}')
    for ym in sorted(by_month, reverse=True):
        name = f"{MONTHS[int(ym[5:]) - 1]} {ym[:4]}"
        items = by_month[ym]
        out.append({'name': f'{name}: {len(items)} sessions',
                    'desc': cap('\n'.join(items), 15000, '(More in docs/session_notes/.)'),
                    'pd_id': f'month-{ym}'})
    for c in out:
        c.setdefault('status', None)
        c.setdefault('due', None)
    return out


# --- Trello ----------------------------------------------------------------------------------

def credentials():
    vals = {}
    for line in open(ENV_FILE, encoding='utf-8-sig'):
        if '=' in line:
            k, v = line.split('=', 1)
            vals[k.strip()] = v.strip().strip('"').strip("'")
    return vals.get('TRELLO_KEY', ''), vals.get('TRELLO_TOKEN', '')


class Trello:
    def __init__(self, dry_run):
        self.key, self.token = credentials()
        self.dry_run = dry_run
        self.writes = 0

    def call(self, method, path, **params):
        if method != 'GET' and self.dry_run:
            self.writes += 1
            return {'id': f'dry-{self.writes}'}
        params = {k: v for k, v in params.items() if v is not None}
        query = urllib.parse.urlencode({**params, 'key': self.key, 'token': self.token})
        url, data = f'{API}{path}', None
        if method == 'GET':
            url += '?' + query
        else:
            data = query.encode()
        for attempt in range(6):
            req = urllib.request.Request(url, data=data, method=method)
            if data is not None:
                req.add_header('Content-Type', 'application/x-www-form-urlencoded')
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    body = r.read().decode()
                if method != 'GET':
                    self.writes += 1
                    time.sleep(REQUEST_GAP)
                return json.loads(body) if body else None
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    time.sleep(2 + 2 * attempt)
                    continue
                msg = e.read().decode(errors='replace')[:200]
                raise SystemExit(f'{method} {path} failed: HTTP {e.code} {msg}') from None
        raise SystemExit(f'{method} {path} failed: still rate limited')


def pd_id(desc):
    m = re.search(r'^' + re.escape(ID_PREFIX) + r'(\S+)\s*$', desc or '', re.M)
    return m.group(1) if m else None


def sync(dry_run):
    lists, cards, unplaced = desired_board()
    if unplaced:
        print('Placed by their To-Do section (no journey prefix matched):')
        for t in unplaced:
            print('  -', t)
    t = Trello(dry_run)
    board = t.call('GET', f'/boards/{BOARD}', fields='id,name')['id']

    # Labels: one per status; anything else on the board is from an older layout.
    have_labels = {l['name']: l for l in t.call('GET', f'/boards/{board}/labels',
                                                fields='name,color', limit=1000)}
    label_id = {}
    for key, (name, color) in STATUS_LABEL.items():
        if name in have_labels:
            label_id[key] = have_labels[name]['id']
        else:
            label_id[key] = t.call('POST', '/labels', idBoard=board, name=name, color=color)['id']

    # Lists in journey order; reuse by name.
    have_lists = {l['name']: l for l in t.call('GET', f'/boards/{board}/lists', fields='name,pos')}
    list_id = {}
    for key, name in lists:
        if name in have_lists:
            list_id[key] = have_lists[name]['id']
        else:
            list_id[key] = t.call('POST', '/lists', idBoard=board, name=name, pos='bottom')['id']
    # Lists keep the journey's order; compared as an order, as cards are below.
    existing_ids = {l['id'] for l in have_lists.values()}
    have_order = [l['id'] for l in sorted(have_lists.values(), key=lambda l: l['pos'])
                  if l['id'] in list_id.values()]
    want_order = [list_id[k] for k, _ in lists if list_id[k] in existing_ids]
    if have_order != want_order:
        top = max((l['pos'] for l in have_lists.values()), default=0)
        for i, (key, _) in enumerate(lists):
            t.call('PUT', f'/lists/{list_id[key]}', pos=top + 1000 * (i + 1))

    existing = t.call('GET', f'/boards/{board}/cards', filter='open',
                      fields='name,desc,idList,idLabels,pos,due,dueComplete')
    by_id = {}
    duplicates, unmanaged = [], []
    for c in existing:
        pid = pd_id(c['desc'])
        if pid is None:
            unmanaged.append(c)  # made by hand: never touched
        elif pid in by_id:
            duplicates.append(c)
        else:
            by_id[pid] = c

    created = updated = 0
    wanted = set()
    for key, _ in lists:
        for i, c in enumerate(cards[key]):
            wanted.add(c['pd_id'])
            want = {
                'name': c['name'][:16000],
                'desc': f"{c['desc']}\n\n{ID_PREFIX}{c['pd_id']}"[:16300],
                'idList': list_id[key],
                'idLabels': label_id[c['status']] if c['status'] else '',
                'due': (c['due'] + 'T12:00:00.000Z') if c['due'] else None,
            }
            have = by_id.get(c['pd_id'])
            if have is None:
                params = {k: v for k, v in want.items() if v not in (None, '')}
                params['pos'] = 'bottom'
                if c['due']:
                    params['dueComplete'] = 'true'
                t.call('POST', '/cards', **params)
                created += 1
                continue
            change = {}
            for f in ('name', 'desc', 'idList'):
                if have[f] != want[f]:
                    change[f] = want[f]
            if 'idList' in change:
                change['pos'] = 'bottom'  # the order pass below puts it in its place
            if ','.join(sorted(have['idLabels'])) != want['idLabels']:
                change['idLabels'] = want['idLabels']
            if (have.get('due') or '')[:10] != (c['due'] or ''):
                change['due'] = want['due'] or ''
                change['dueComplete'] = 'true' if c['due'] else 'false'
            if change:
                t.call('PUT', f"/cards/{have['id']}", **change)
                updated += 1

    archived = 0
    for c in duplicates + [c for pid, c in by_id.items() if pid not in wanted]:
        t.call('PUT', f"/cards/{c['id']}", closed='true')
        archived += 1

    # Order. Compared as an order, never as numbers: Trello renumbers a position that
    # collides with another card's, so exact values never settle. A list out of order is
    # renumbered from above its highest position, where nothing can collide.
    reordered = 0
    for key, _ in lists:
        in_list = t.call('GET', f'/lists/{list_id[key]}/cards', fields='desc,pos')
        managed = {pd_id(c['desc']): c for c in in_list if pd_id(c['desc'])}
        want_order = [c['pd_id'] for c in cards[key]]
        have_order = [pid for pid, _ in sorted(managed.items(), key=lambda kv: kv[1]['pos'])
                      if pid in want_order]
        if have_order == want_order:
            continue
        top = max((c['pos'] for c in in_list), default=0)
        for i, pid in enumerate(want_order):
            if pid in managed:
                t.call('PUT', f"/cards/{managed[pid]['id']}", pos=top + 1000 * (i + 1))
        reordered += 1

    # Lists and labels from an older layout go once nothing made by hand needs them.
    keep_lists = set(list_id.values()) | {c['idList'] for c in unmanaged}
    old_lists = [l for l in have_lists.values() if l['id'] not in keep_lists]
    for l in old_lists:
        t.call('PUT', f"/lists/{l['id']}/closed", value='true')
    keep_labels = set(label_id.values()) | {i for c in unmanaged for i in c['idLabels']}
    old_labels = [l for l in have_labels.values() if l['id'] not in keep_labels]
    for l in old_labels:
        t.call('DELETE', f"/labels/{l['id']}")

    total = sum(len(v) for v in cards.values())
    verb = 'would make' if dry_run else 'made'
    print(f'{total} cards in {len(lists)} lists: {verb} {created} new, {updated} updated, '
          f'{archived} archived, {reordered} lists reordered; {len(old_lists)} old lists '
          f'closed, {len(old_labels)} old '
          f'labels deleted; {t.writes} writes.')
    if unmanaged:
        print(f'{len(unmanaged)} card(s) made by hand, left alone:')
        for c in unmanaged:
            print('  -', c['name'][:90])


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--dry-run', action='store_true', help='report the changes, make none')
    sync(ap.parse_args().dry_run)
