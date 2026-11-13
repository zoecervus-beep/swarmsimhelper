"""Generate advisor/ACHIEVEMENTS.md: every achievement in the game's data, how the game evaluates it, and which
are earned in a save.

Sources: the game's data table (swarmsim-coffee/app/scripts/spreadsheetpreload/v0.2.js), achievement.coffee
(the listener), the save's `achievements` map and statistics, and, when node is available,
advisor/modelcheck/achievement_check.js, which runs the real AchievementsListener on every achievement
just below and at its threshold.

Usage (from the repo root):
    python3 -I advisor/sim/achievements.py [--save advisor/sim/example_save_20h.json] [--out advisor/ACHIEVEMENTS.md]
About 5 s with the code check, under 1 s without (--no-check).
"""
import argparse, json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import sim

# swarm-numberformat 0.2.1 (the version the game pins), standard "full" suffixes, first 25 (enough to 1e75)
SUFFIX = ['', ' thousand', ' million', ' billion', ' trillion', ' quadrillion', ' quintillion', ' sextillion', ' septillion',
          ' octillion', ' nonillion', ' decillion', ' undecillion', ' duodecillion', ' tredecillion', ' quattuordecillion',
          ' quinquadecillion', ' sedecillion', ' septendecillion', ' octodecillion', ' novendecillion', ' vigintillion',
          ' unvigintillion', ' duovigintillion', ' tresvigintillion']

def longnum(v):
    """The game's `longnum` filter as achievement descriptions call it ({sigfigs: undefined}): below 1e5 the
    number with thousands separators (the game passes `minsuffix: 1e6`, but the library reads `minSuffix`, so its
    default 1e5 applies); from 1e5 a prefix and a word suffix per factor of 1000."""
    v = float(v)
    if v < 1e5: return '{:,}'.format(int(math.floor(v)))
    i = int(math.floor(math.log10(v) / 3 + 1e-12))
    pre = v / 1000 ** i
    s = ('%.15g' % pre)
    return s + SUFFIX[i]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--save', default=os.path.join(HERE, 'example_save_20h.json'))
    ap.add_argument('--out', default=os.path.join(REPO, 'advisor', 'ACHIEVEMENTS.md'))
    ap.add_argument('--no-check', action='store_true')
    a = ap.parse_args()
    data = sim._game_data()
    save = json.load(open(a.save))
    have = save.get('achievements', {})
    labels = {}
    for sheet in ('unittypes', 'upgrades'):
        for e in data[sheet]['elements']:
            if e.get('name') and e.get('label'): labels.setdefault(e['name'], e['label'])
    unbuyable = {e['name'] for e in data['unittypes']['elements'] if e.get('name') and e.get('unbuyable')}
    check = None
    if not a.no_check:
        try:
            check = json.loads(subprocess.run(['node', os.path.join(REPO, 'advisor', 'modelcheck', 'achievement_check.js')],
                                              check=True, capture_output=True, text=True, env=dict(os.environ, TZ='UTC')).stdout)
        except Exception as e:
            print('code check skipped:', e, file=sys.stderr)
    bought = {n: float(v.get('twinnum', 0)) for n, v in save.get('statistics', {}).get('byUnit', {}).items()}
    ups = save.get('upgrades', {}); units = save.get('unittypes', {})
    EVENTS = {
        'changelog': 'open the Patch Notes page (ChangelogCtrl emits `changelog`; hotkey n)',
        'import': 'import a save successfully (options page broadcasts `import` with {success: true})',
        'achieveclick': "click this achievement's own slot on the achievements page ({name: 'clickme'})",
        'konami': 'type the Konami code anywhere (header.coffee)',
        'debugPage': 'open the #/debug page (DebugCtrl emits `debugPage` before any check)',
        'achieve-publictest1': 'nothing in this code emits it: it was given to v1.0 public-test players. **Cannot be earned.**',
        'therightquestion': 'press the keys s, e, q, u, e, l in sequence (a hotkey registered reversed in app.coffee, emitting `therightquestion`)',
    }
    rows = []
    for e in data['achievements']['elements']:
        n = e.get('name')
        if not n: continue
        req_u, req_g, req_e, val = e.get('requires.unittype'), e.get('requires.upgradetype'), e.get('requires.event'), e.get('requires.val')
        vis = [(e.get('visible.unittype') or e.get('visible.upgradetype'), e.get('visible.val'))] if (e.get('visible.unittype') or e.get('visible.upgradetype')) else []
        desc = e.get('description', '')
        if (req_u or req_g) and val not in ('', None): desc = desc.replace('$REQUIRED', longnum(val))
        if req_u == 'ascension':
            group, req = 'ascensions', 'ascension count >= %s (checked by the ascend command on the raw count)' % longnum(val)
            progress = float(units.get('ascension', 0))
        elif req_u:
            lab = sim.LABEL.get(req_u, labels.get(req_u, req_u))
            terr = req_u in sim.TN
            group = 'territory units bought' if terr else 'meat units bought'
            req = '`%s` (%s) bought >= %s: statistics twinnum, all runs together; twins count, production and House of Mirrors clones do not' % (req_u, lab, longnum(val))
            progress = bought.get(req_u, 0.0)
        elif req_g == 'mutatehidden':
            group, req = 'mutations', 'mutations unlocked >= %s (`mutatehidden` level; kept across ascensions)' % longnum(val)
            progress = float(ups.get('mutatehidden', 0))
        elif req_g:
            group = 'upgrade levels'
            req = '`%s` level >= %s in the current run (upgrades reset at an ascension)' % (req_g, longnum(val))
            progress = float(ups.get(req_g, 0))
        else:
            group = 'events and secrets'
            req = EVENTS.get(req_e, req_e)
            if val: req += ' (parameter must include %s)' % val
            progress = None
        if req_e == 'achieve-publictest1': group = 'cannot be earned'
        if not vis:
            shown = 'secret: shown as ??? until earned (no visibility rule)'
        else:
            w, v = vis[0]
            shown = 'visible' if (w == 'meat' and float(v) == 0) else 'masked until %s >= %s' % (sim.LABEL.get(w, labels.get(w, w)), longnum(v))
        ck = ''
        if check:
            c = check['achievements'][n]
            ok = c.get('atEarns') and not c.get('belowEarns') and not c.get('ownedNotBoughtEarns') and not c.get('wrongParamEarns')
            ck = 'yes' if ok else 'NO'
        rows.append(dict(name=n, label=e.get('label', ''), desc=desc, req=req, points=e['points'], shown=shown, group=group,
                         earned=n in have, val=val, progress=progress, check=ck, unit=req_u, upg=req_g))
    total = sum(r['points'] for r in rows); got = sum(r['points'] for r in rows if r['earned'])
    L = ['# Achievements', '',
         'Generated by `advisor/sim/achievements.py` from the game data, `achievement.coffee` and the save `%s`.' % os.path.relpath(a.save, REPO),
         'Do not edit by hand.', '',
         '**%d achievements, %d points possible. Earned in this save: %d achievements, %d points. Remaining: %d achievements, %d points (%d of them earnable).**' % (
             len(rows), total, sum(r['earned'] for r in rows), got, sum(not r['earned'] for r in rows), total - got,
             total - got - sum(r['points'] for r in rows if r['group'] == 'cannot be earned' and not r['earned'])), '']
    if check:
        L.append('"Checked" = run through the real AchievementsListener (`advisor/modelcheck/achievement_check.js`): not earned just below the threshold, '
                 'earned at it; for unit achievements, owning 10x the threshold without having bought it does not earn it; for events, '
                 'a wrong parameter does not earn it. All %d: %s. The game also reports %d points possible.' % (
                     len(rows), 'pass' if all(r['check'] == 'yes' for r in rows) else 'SEE NO ROWS', check['pointsPossible']))
        L.append('')
    L += ['How the game decides (achievement.coffee):', '',
          '- **Units**: after every buy command the listener compares each unit achievement with `statistics.byUnit[unit].twinnum`, the units *bought* including twins, summed over every run (statistics survive ascension). Units made by production, House of Mirrors clones and swarmwarp never count.',
          '- **Ascensions**: on the ascend command it compares the raw `ascension` count.',
          '- **Upgrades**: after every upgrade purchase, the current level. Expansion and nexus levels reset at an ascension; `mutatehidden` (unlocks) does not, and an earned achievement is never taken back (a respec does not remove it).',
          '- **Events**: one-off UI events, listed below.',
          '- **$REQUIRED** in a description is the threshold printed with the game\'s `longnum` filter (swarm-numberformat, full suffixes, automatic precision): e.g. 201, 10,000, 1 million, 10 quadrillion, 100 novendecillion (1e62).', '']
    order = ['meat units bought', 'territory units bought', 'upgrade levels', 'ascensions', 'mutations', 'events and secrets', 'cannot be earned']
    for grp in order:
        rs = [r for r in rows if r['group'] == grp]
        if not rs: continue
        rem = [r for r in rs if not r['earned']]
        L.append('## %s: %d of %d remaining (%d points)' % (grp[0].upper() + grp[1:], len(rem), len(rs), sum(r['points'] for r in rem)))
        L.append('')
        L.append('| | name | title | description (as shown) | requirement as evaluated | points | shown | in save now |%s' % (' checked |' if check else ''))
        L.append('|---|---|---|---|---|---|---|---|%s' % ('---|' if check else ''))
        for r in rs:
            prog = '' if r['progress'] is None else ('%s / %s' % (('%.3g' % r['progress']) if r['progress'] else '0', longnum(r['val']) if r['val'] not in ('', None) else ''))
            L.append('| %s | `%s` | %s | %s | %s | %d | %s | %s |%s' % ('done' if r['earned'] else '**todo**', r['name'], r['label'], r['desc'], r['req'], r['points'], r['shown'], prog,
                                                                    (' %s |' % r['check']) if check else ''))
        L.append('')
    open(a.out, 'w').write('\n'.join(L) + '\n')
    print('wrote %s: %d achievements, %d/%d points earned' % (os.path.relpath(a.out, REPO), len(rows), got, total))

if __name__ == '__main__':
    main()
