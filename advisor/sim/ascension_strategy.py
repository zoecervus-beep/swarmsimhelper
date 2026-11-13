"""Ascension and mutagen strategy experiments from the owner's 20.1 h save (advisor/ASCENSION.md).

Every run uses the tuned policy (policy.json) with crystals converted to energy (the owner does this),
premutagen in the simulator's `expected` mode (the mean of the game's roll) unless a section says otherwise.
Times are hours of game time from the save; "run age" is time since the last ascension (the save is 20.1 h
into its run).

Usage (from the repo root):
    python3 -I advisor/sim/ascension_strategy.py [sections]     # all sections: about 3 minutes
    sections: curve timing purchases later inrun exact nocrystals   (default: all)
Writes advisor/modelcheck/out/ascension_strategy.json (ignored by version control) and prints markdown tables.
"""
import copy, json, math, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim

AGE0 = 72406                                     # run age of the 20.1 h save, seconds
BASE = dict(json.load(open(os.path.join(HERE, 'policy.json'))), age0=AGE0, crystals=True)
CI = 60
FIRST = {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e5, 'mutantfreq': 1e5}}
HOR = [5 * 24, 7 * 24, 10 * 24, 12 * 24, 14 * 24]
OUT = {}
T0 = time.time()
lg = lambda x: math.log10(x) if x > 0 else float('-inf')
f2 = lambda x: '%.2f' % x if x not in (None, float('-inf')) else '-'

def at(rows, h, key='total'):
    """Value of `key` in the last row at or before game hour h (None when the run stopped earlier)."""
    best = None
    for r in rows:
        if r['t'] <= h + 1e-9 and not r.get('overflow'): best = r
    if best is None or (rows[-1].get('overflow') and rows[-1]['t'] < h): return None
    return best[key]
def note(msg): print('<!-- %s (%.0f s) -->' % (msg, time.time() - T0), flush=True)

def first_ascension_state(p=None, plan=None, after=0):
    """Play from the save until the first ascension (saving starts at run age `after` hours); return the
    state right after it, with `plan` applied (None: nothing bought), and the run's rows."""
    p = dict(p or BASE, ascend=[{'after': after * 3600}])
    s, rows, log = sim.run_cycles(p, CI, 24 * 30, plans=[plan], every=3600, until=lambda s: bool(s.asc_log))
    return s, rows, log[0]

def section_curve(crystals=True):
    """1. One run, never ascending: premutagen, its rate, and the ascension price over time."""
    p = dict(BASE, crystals=crystals)
    s, rows, _ = sim.run_cycles(p, CI, 24 * 14, every=3600)
    # when could it ascend? the same run with the ascension rule on, stopping at the ascension
    _, _, rec = first_ascension_state(p)
    tag = 'curve' if crystals else 'curve_nocrystals'
    OUT[tag] = {'rows': rows[::6], 'first_ascension': {k: v for k, v in rec.items() if k != 'bought'}}
    print('\n### Run 1 continued from the 20.1 h save, never ascending (crystals %s)\n' % ('on' if crystals else 'off'))
    print('| hours from save | run age (d) | log10 premutagen | gain per day (log10) | expansions | mirrors cast | energy spent | ascension cost | energy cap |')
    print('| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
    for h in [0, 12, 24, 36, 48, 60, 72, 84, 96, 120, 144, 168, 216, 264, 336]:
        r = [x for x in rows if abs(x['t'] - h) < 1e-6]
        if not r: continue
        r = r[0]; prev = [x for x in rows if abs(x['t'] - (h - 24)) < 1e-6]
        d = (lg(r['premut']) - lg(prev[0]['premut'])) if prev and prev[0]['premut'] > 0 else None
        print('| %d | %.1f | %s | %s | %d | %d | %s | %s | %s |' % (h, r['age'] / 24, f2(lg(r['premut'])), f2(d) if d else '-', r['exp'], r['mirrors'],
              '{:,.0f}'.format(r['espent']), '{:,.0f}'.format(r['cost']), '{:,.0f}'.format(r['cap'])))
    print('\nEarliest ascension with the saving rule: %.1f h from the save (run age %.1f d), %.3g premutagen, cost %s energy.' % (
        rec['time'] / 3600, rec['run_age'] / 86400, rec['premut'], '{:,}'.format(rec['cost'])))
    note('curve done')
    return rows, rec

def section_timing(never_rows):
    """2. When to ascend: ascend at the earliest moment, or start saving at a later run age; then run 2 with
    the first purchases (nexus + frequency). Total mutagen (held + premutagen) and meat/s at fixed hours."""
    res = {'never': {h: (at(never_rows, h), at(never_rows, h, 'lmeat')) for h in HOR}}
    rows_by = {}
    for after in [0, 120, 144, 168, 216]:
        s, rows, log = sim.run_cycles(dict(BASE, ascend=[{'after': after * 3600}]), CI, max(HOR), plans=[FIRST], every=3600)
        rec = log[0]
        res[after] = {'asc_h': rec['time'] / 3600, 'asc_age': rec['run_age'] / 3600, 'M1': rec['premut'],
                      'h': {h: (at(rows, h), at(rows, h, 'lmeat')) for h in HOR}}
        rows_by[after] = rows
        note('timing after=%d' % after)
    OUT['timing'] = res
    print('\n### When to ascend: total mutagen (log10, held + not yet activated) at hours from the save\n')
    print('| ascend | at hour | M1 (log10) | ' + ' | '.join('+%d d' % (h // 24) for h in HOR) + ' |')
    print('|' + ' --- |' * (3 + len(HOR)))
    print('| never | - | - | ' + ' | '.join(f2(lg(res['never'][h][0])) for h in HOR) + ' |')
    for after in [0, 120, 144, 168, 216]:
        r = res[after]
        print('| %s | %.0f | %.2f | ' % ('earliest' if after == 0 else 'save from run age %d d' % (after // 24), r['asc_h'], lg(r['M1'])) +
              ' | '.join(f2(lg(r['h'][h][0])) if r['h'][h][0] else 'overflow' for h in HOR) + ' |')
    print('\n### Same runs: log10 meat per second\n')
    print('| ascend | ' + ' | '.join('+%d d' % (h // 24) for h in HOR) + ' |'); print('|' + ' --- |' * (1 + len(HOR)))
    print('| never | ' + ' | '.join(f2(res['never'][h][1]) for h in HOR) + ' |')
    for after in [0, 120, 144, 168, 216]:
        r = res[after]
        print('| %s | ' % ('earliest' if after == 0 else 'from %d d' % (after // 24)) + ' | '.join(f2(r['h'][h][1]) if r['h'][h][1] else '-' for h in HOR) + ' |')
    # break-even: first hour where ascending-at-earliest leads never-ascending, for mutagen and meat
    for key, name in (('total', 'mutagen'), ('lmeat', 'meat/s')):
        be = None
        for r in rows_by[0]:
            if r.get('overflow') or r['asc'] == 0: continue
            n = at(never_rows, r['t'], key)
            if n is None: break
            v = r[key]; vv = lg(v) if key == 'total' else v; nn = lg(n) if key == 'total' else n
            if vv > nn: be = r['t']; break
        print('\nAscending at the earliest moment overtakes never ascending in %s at hour %s (%.1f d after the ascension).' % (
            name, '%.0f' % be if be else 'never (within 14 d)', (be - res[0]['asc_h']) / 24 if be else float('nan')))
        res['breakeven_' + name] = be
    return rows_by[0]

def run2(state, plan, days=6, p=None, every=3600):
    s = copy.deepcopy(state)
    sim.apply_plan(s, plan)
    t_end = s.time / 3600 + days * 24
    s2, rows, _ = sim.run_cycles(dict(p or BASE, ascend=None), CI, t_end, s0=s, every=every)
    return s2, rows

def run2_metrics(rows, t_asc):
    m = {}
    for d in (1, 2, 3, 4, 5, 6, 8):
        h = t_asc + d * 24
        v = at(rows, h, 'premut'); m['p%d' % d] = lg(v) if v else None
        m['m%d' % d] = at(rows, h, 'lmeat')
    m['slope'] = (m['p6'] - m['p4']) / 2 if m.get('p6') and m.get('p4') else None
    return m

def section_purchases(state, t_asc):
    """3. What to buy with the first mutagen. Run 2 from the same ascension, one plan each."""
    M = state.mutagen
    plans = [('nothing (all held: %.3g larvae/s)' % (0.1 * M), {})]
    single = [('nexus 1e5', 'mutatenexus', {'mutantnexus': 1e5}), ('frequency 1e5', 'mutatefreq', {'mutantfreq': 1e5}),
              ('quantity (each) 50%', 'mutateeach', {'mutanteach': 0.5}), ('hatchery 50%', 'mutatehatchery', {'mutanthatchery': 0.5}),
              ('meat 50%', 'mutatemeat', {'mutantmeat': 0.5}), ('rush 50%', 'mutaterush', {'mutantrush': 0.5}),
              ('territory (army) 50%', 'mutatearmy', {'mutantarmy': 0.5}), ('bat 50%', 'mutatebat', {'mutantbat': 0.5}),
              ('clone 50%', 'mutateclone', {'mutantclone': 0.5}), ('warp 50%', 'mutateswarmwarp', {'mutantswarmwarp': 0.5})]
    for name, up, buy in single: plans.append(('only ' + name, {'unlock': [up], 'buy': buy}))
    for name, up, buy in single[1:]:
        plans.append(('nexus 1e5, then ' + name, {'unlock': ['mutatenexus', up], 'buy': dict({'mutantnexus': 1e5}, **buy)}))
    plans.append(('frequency 1e5, then nexus 1e5', {'unlock': ['mutatefreq', 'mutatenexus'], 'buy': {'mutantnexus': 1e5, 'mutantfreq': 1e5}}))
    plans.append(('nexus 1e3 + frequency 1e3 (cheap)', {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e3, 'mutantfreq': 1e3}}))
    plans.append(('nexus 1e6 + frequency 1e6', {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6}}))
    plans.append(('nexus + frequency 1e5, hatchery... (3rd unlock unaffordable)', {'unlock': ['mutatenexus', 'mutatefreq', 'mutatehatchery'], 'buy': {'mutantnexus': 1e5, 'mutantfreq': 1e5}, '_p': {'hatch_dyn': True}}))
    plans.append(('nexus 1e5, then hatchery, held at the larva-maximising count (hatch_dyn)', {'unlock': ['mutatenexus', 'mutatehatchery'], 'buy': {'mutantnexus': 1e5}, '_p': {'hatch_dyn': True}}))
    plans.append(('nexus 1e5, then rush 50%, with territory rush as 1 cast in 4', {'unlock': ['mutatenexus', 'mutaterush'], 'buy': {'mutantnexus': 1e5, 'mutantrush': 0.5},
                  '_p': {'spells': ['mirror', 'terrrush'], 'mixw': {'mirror': 3, 'terrrush': 1}}}))
    res = []
    for name, plan in plans:
        p = dict(BASE, **plan.pop('_p', {}))
        s2, rows = run2(state, plan, p=p)
        m = run2_metrics(rows, t_asc); m['name'] = name
        res.append(m)
        note('plan ' + name)
    OUT['purchases'] = {'M1': M, 't_asc': t_asc, 'rows': res}
    print('\n### First purchases: run 2 from the same ascension (%.3g mutagen), log10 premutagen at run age\n' % M)
    print('| plan | 1 d | 2 d | 3 d | 4 d | 5 d | 6 d | gain/day (4-6 d) | log10 meat/s at 3 d / 6 d |')
    print('| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
    for m in sorted(res, key=lambda m: -(m['p6'] or -1)):
        print('| %s | %s | %s | %s | %s | %s | %s | %s | %s / %s |' % (m['name'], f2(m['p1']), f2(m['p2']), f2(m['p3']), f2(m['p4']), f2(m['p5']), f2(m['p6']),
              f2(m['slope']), f2(m['m3']), f2(m['m6'])))

def section_later(state, t_asc):
    """4. Later runs: with nexus + frequency bought, ascend again after run 2 lasts N days, or never."""
    s = copy.deepcopy(state); sim.apply_plan(s, FIRST)
    SECOND = {'unlock': ['mutateeach', 'mutatehatchery', 'mutatemeat'], 'buy': {'mutanteach': 0.3, 'mutantmeat': 0.1}}
    res = {}
    hs = [t_asc + d * 24 for d in (4, 6, 8, 10)]
    s2, rows, _ = sim.run_cycles(dict(BASE, ascend=None), CI, max(hs), s0=s, every=3600)
    res['never'] = {'h': {h: at(rows, h) for h in hs}}
    for after_d in (2, 3, 4, 5):
        # the state already holds one ascension record, so the second ascension is entry 1 of each list
        s2, rows, log = sim.run_cycles(dict(BASE, ascend=[None, {'after': after_d * 86400}], hatch_dyn=True), CI, max(hs), s0=s, plans=[None, SECOND], every=3600)
        rec = log[1] if len(log) > 1 else None
        res[after_d] = {'asc_h': rec['time'] / 3600 if rec else None, 'M2': rec['premut'] if rec else None,
                        'bought': rec['bought'] if rec else None, 'h': {h: at(rows, h) for h in hs}}
        note('later after=%d' % after_d)
    OUT['later'] = res
    print('\n### Later runs: run 2 (nexus + frequency bought) ascends again, or not. Total mutagen (log10) at hours from the save\n')
    print('| second ascension | at hour | premutagen it activates (log10) | ' + ' | '.join('%d h' % h for h in hs) + ' |')
    print('|' + ' --- |' * (3 + len(hs)))
    print('| never | - | - | ' + ' | '.join(f2(lg(res['never']['h'][h])) if res['never']['h'][h] else 'overflow' for h in hs) + ' |')
    for d in (2, 3, 4, 5):
        r = res[d]
        print('| saving from run age %d d | %s | %s | ' % (d, '%.0f' % r['asc_h'] if r['asc_h'] else '-', f2(lg(r['M2'])) if r['M2'] else '-') +
              ' | '.join(f2(lg(r['h'][h])) if r['h'][h] else 'overflow' for h in hs) + ' |')

def section_inrun(state, t_asc):
    """5. In-run settings during run 2 (after nexus + frequency): age multiple, lepidoptera, spells."""
    variants = [('tuned policy (age multiple 5, 4,000 lepidoptera, mirrors)', {}),
                ('age multiple 3', {'theta_age': 3}), ('age multiple 10', {'theta_age': 10}), ('age multiple 20', {'theta_age': 20}),
                ('lepidoptera 0', {'moth_N': 0}), ('lepidoptera 10,000', {'moth_N': 10000}), ('lepidoptera 30,000', {'moth_N': 30000}),
                ('swarmwarp instead of mirrors', {'spells': ['warp']}), ('no crystals', {'crystals': False}),
                ('no territory larvae (f=0)', {'f': 0.0}), ('territory share 0.3', {'f': 0.3}),
                ('stop territory units once mirrors start (f_mirror=0)', {'f_mirror': 0.0})]
    res = []
    for name, ch in variants:
        s2, rows = run2(state, FIRST, p=dict(BASE, **ch), days=8)
        m = run2_metrics(rows, t_asc); m['name'] = name; res.append(m)
        note('inrun ' + name)
    OUT['inrun'] = res
    print('\n### Run 2 settings (nexus + frequency bought): log10 premutagen and meat/s at run age\n')
    print('| variant | premutagen 2 d | 4 d | 6 d | 8 d | gain/day (4-6 d) | meat/s 2 d | 4 d | 6 d |'); print('|' + ' --- |' * 9)
    for m in res:
        print('| %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (m['name'], f2(m['p2']), f2(m['p4']), f2(m['p6']), f2(m['p8']), f2(m['slope']), f2(m['m2']), f2(m['m4']), f2(m['m6'])))
    # and run 1: do the age multiple or lepidoptera target change when the first ascension can happen?
    print('\n### Run 1 settings: first ascension (earliest), from the save\n')
    print('| variant | ascends at hour | premutagen activated (log10) |'); print('| --- | --- | --- |')
    r1 = []
    for name, ch in [('tuned policy', {}), ('age multiple 3', {'theta_age': 3}), ('age multiple 10', {'theta_age': 10}),
                     ('lepidoptera 8,000', {'moth_N': 8000}), ('lepidoptera 20,000', {'moth_N': 20000}), ('no crystals', {'crystals': False}),
                     ('swarmwarp instead of mirrors', {'spells': ['warp']})]:
        _, _, rec = first_ascension_state(dict(BASE, **ch))
        r1.append((name, rec['time'] / 3600, rec['premut']))
        print('| %s | %.0f | %.2f |' % (name, rec['time'] / 3600, lg(rec['premut'])))
        note('run1 ' + name)
    OUT['inrun_run1'] = r1

def section_exact(never_rows):
    """6. The same comparison with the game's own rolls (UTC seed) instead of their mean."""
    sim.PREMUT = 'exact'
    s, rows, _ = sim.run_cycles(BASE, CI, 24 * 14, every=3600)
    s2, rows2, log = sim.run_cycles(dict(BASE, ascend=[{'after': 0}]), CI, 24 * 14, plans=[FIRST], every=3600)
    sim.PREMUT = 'expected'
    print('\n### The game\'s own rolls (UTC seed) instead of their mean: total mutagen (log10)\n')
    print('| path | ' + ' | '.join('+%d d' % (h // 24) for h in HOR) + ' |'); print('|' + ' --- |' * (1 + len(HOR)))
    print('| never, mean | ' + ' | '.join(f2(lg(at(never_rows, h))) for h in HOR) + ' |')
    print('| never, rolled | ' + ' | '.join(f2(lg(at(rows, h))) for h in HOR) + ' |')
    print('| earliest, rolled (ascends at %.0f h with %.3g) | ' % (log[0]['time'] / 3600, log[0]['premut']) + ' | '.join(f2(lg(at(rows2, h))) if at(rows2, h) else '-' for h in HOR) + ' |')
    OUT['exact'] = {'never': {h: at(rows, h) for h in HOR}, 'earliest': {h: at(rows2, h) for h in HOR}, 'asc': log[0]['time'] / 3600}

if __name__ == '__main__':
    want = set(sys.argv[1:]) or {'curve', 'timing', 'purchases', 'later', 'inrun', 'exact', 'nocrystals'}
    never_rows, rec = section_curve()
    if 'nocrystals' in want: section_curve(crystals=False)
    if 'timing' in want: section_timing(never_rows)
    if want & {'purchases', 'later', 'inrun'}:
        state, _, rec = first_ascension_state()
        t_asc = rec['time'] / 3600
        if 'purchases' in want: section_purchases(state, t_asc)
        if 'later' in want: section_later(state, t_asc)
        if 'inrun' in want: section_inrun(state, t_asc)
    if 'exact' in want: section_exact(never_rows)
    od = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(od, exist_ok=True)
    json.dump(OUT, open(os.path.join(od, 'ascension_strategy.json'), 'w'), default=str)
    note('all done')
