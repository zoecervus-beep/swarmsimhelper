"""Strategy for the achievement objective (advisor/ASCENSION.md, part A): what it takes to earn every achievement,
to buy endless (`overmind6`) and lots of them, and how many ascensions to make and when.

Starts from the owner's 20.1 h save. No crystals anywhere. Premutagen is the mean of the game's roll.

Sections (all by default):
  first    the first ascension from the save, at the earliest moment                    (~10 s)
  long     one long run after it, under several policies: when each achievement falls,
           endless bought over time, expansions                                          (~1 min per variant)
  quick    short runs that only collect ascensions: days per ascension, with little and with
           enormous mutagen                                                              (~2 min)
  energy   the energy bill of 20 ascensions, from the cost formula                         (instant)

Usage (from the repo root):
    python3 -I advisor/sim/achievement_strategy.py [sections] [--days N] [--quick]
--quick runs the long run for the base policy only.
Writes advisor/modelcheck/out/achievement_strategy.json (ignored by version control) and prints markdown.
Whole run with every variant: about 12 minutes.
"""
import copy, json, math, os, pickle, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim, bignum as bn

AGE0 = 72406
POLICY = json.load(open(os.path.join(HERE, 'policy.json')))
BASE = dict(POLICY, age0=AGE0)                          # no crystals: the owner's choice
# The achievement policy: horizon 20 x run age, lepidoptera to 30,000, faster-aware climbing (any number of
# faster levels), and push: feed every tier above the climb frontier up to endless, keeping pushed units
# for climbing rather than spending them on twins below (twin only from a stock of 1e6 x the twin's price).
ACHIEVE = dict(BASE, theta_age=20, moth_N=30000, faster_aware='multi',
               push={'goal': 20, 'share': 0.5, 'base': 0.02, 'twin_mult': 1e6})
FIRST_PLAN = {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6}}
OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
OUT = {}; T0 = time.time()
lg = lambda x: bn.lg(x) if x > 0 else float('-inf')
def note(m): print('<!-- %s (%.0f s) -->' % (m, time.time() - T0), flush=True)
def lab(n): return sim.LABEL.get(n, n)

def first_ascension(plan=FIRST_PLAN, p=BASE):
    q = dict(p, ascend=[{'after': 0}])
    s, rows, log = sim.run_cycles(q, 60, 24 * 30, plans=[plan], every=3600, until=lambda s: bool(s.asc_log))
    return s, log[0]

ACH_ORDER = ['pantheon5_1', 'overmind1', 'overmind2_1', 'overmind3_1', 'overmind4_1', 'overmind5_1', 'overmind6_1', 'overmind6_2',
             'overmind6_3', 'expansion6', 'expansion7', 'expansion8', 'expansion9', 'swarmling3', 'goon3']
TIERS = ['pantheon51', 'overmind1', 'overmind2_1', 'overmind3_1', 'overmind4_1', 'overmind5_1', 'overmind6_1', 'overmind6_2', 'overmind6_3']

def long_run(s0, p, days, ci=300):
    s = copy.deepcopy(s0); s.ach_log = []
    t_start = s.time
    s2, rows, _ = sim.run_cycles(dict(p, ascend=None), ci, s.time / 3600 + 24 * days, s0=s, every=24 * 3600)
    when = {n: (t - t_start) / 86400 for t, n in s2.ach_log}
    return s2, rows, when

def section_long(s1, days, quick):
    variants = [('achievement policy (base)', ACHIEVE, 300, None)]
    if not quick:
        variants += [
            ('push without keeping units from twins', dict(ACHIEVE, push=dict(ACHIEVE['push'], twin_mult=1)), 300, None),
            ('no push (climb rules only, faster-aware)', dict(ACHIEVE, push=None), 300, None),
            ('age multiple 5', dict(ACHIEVE, theta_age=5), 300, None),
            ('lepidoptera 4,000', dict(ACHIEVE, moth_N=4000), 300, None),
            ('check-in every 30 min', ACHIEVE, 1800, None),
            ('check-in every 2 h', ACHIEVE, 7200, None),
            ('second unlock meat (50% of mutagen) instead of frequency',
             ACHIEVE, 300, {'unlock': ['mutatenexus', 'mutatemeat'], 'buy': {'mutantnexus': 1e6, 'mutantmeat': 0.5}}),
            ('no ascension first: run 1 continued (no lepidoptera mutation)', ACHIEVE, 300, 'noasc'),
        ]
    res = []
    for name, p, ci, alt in variants:
        if alt == 'noasc':
            s = sim.load(); start = s
        elif alt is not None:
            start, _ = first_ascension(alt)
        else:
            start = s1
        s2, rows, when = long_run(start, p, days, ci)
        traj = [(round(r['age'] / 24) if alt != 'noasc' else round((r['t']) / 24), r['exp'], r['llarva'], r['lmeat'], sim.NAMES[r['top']]) for r in rows]
        endless = s2.bought.get('overmind6', 0)
        res.append({'name': name, 'when': when, 'traj': traj, 'endless': lg(endless) if endless else None,
                    'exp': s2.exp, 'first': {n: (t - start.time) / 86400 for n, t in s2.firstclimb.items()}})
        note('long ' + name)
        if name.startswith('achievement policy'):
            pickle.dump(s2, open(os.path.join(OUTD, 'achievement_long_end.pkl'), 'wb'))
            OUT['base_rows'] = [{k: (str(v) if bn.isbig(v) else v) for k, v in r.items()} for r in rows]
    OUT['long'] = res
    print('\n### One long run after the first ascension: day of the run each achievement falls\n')
    cols = ['pantheon51', 'overmind1', 'overmind2_1', 'overmind3_1', 'overmind4_1', 'overmind5_1', 'overmind6_1', 'overmind6_2', 'overmind6_3',
            'expansion7', 'expansion8', 'expansion9', 'overmind6_3']
    cols = list(dict.fromkeys(cols))
    names = {'pantheon51': 'arch-mind', 'overmind1': 'overmind', 'overmind2_1': 'ascended', 'overmind3_1': 'cosmic network',
             'overmind4_1': 'galactic cluster', 'overmind5_1': 'universal cortex', 'overmind6_1': 'endless 1', 'overmind6_2': 'endless 1e31',
             'overmind6_3': 'endless 1e62', 'expansion7': 'exp 1,000', 'expansion8': 'exp 2,000', 'expansion9': 'exp 5,000'}
    print('| variant | ' + ' | '.join(names[c] for c in cols) + ' | endless bought by day %d (log10) |' % days)
    print('|' + ' --- |' * (len(cols) + 2))
    for r in res:
        print('| %s | ' % r['name'] + ' | '.join('%.0f' % r['when'][c] if c in r['when'] else '-' for c in cols) +
              ' | %s |' % ('%.0f' % r['endless'] if r['endless'] else '-'))
    b = res[0]
    print('\n### Base policy: the run day by day (every 10 days)\n')
    print('| run day | expansions | log10 larvae/s | log10 meat/s | top tier owned |'); print('| --- | --- | --- | --- | --- |')
    for d, e, l, m, top in b['traj']:
        if d % 10 == 0: print('| %d | %d | %.0f | %.0f | %s |' % (d, e, l, m, lab(top)))
    print('\nFirst unit of each tier (base): ' + ', '.join('%s %.1f d' % (lab(n), t) for n, t in sorted(b['first'].items(), key=lambda x: x[1]) if t > 0.5))
    other = sorted((t, n) for n, t in b['when'].items() if n not in cols)
    print('\nOther achievements in the base run (day): ' + ', '.join('%s %.1f' % (n, t) for t, n in other))

def section_quick(s1):
    """Short runs that only collect ascensions: days per ascension, starting with the first-ascension mutagen,
    and starting from the end of the long run (enormous mutagen, all 10 mutations)."""
    res = {}
    starts = [('after the first ascension (mutagen ~6e7)', s1)]
    endp = os.path.join(OUTD, 'achievement_long_end.pkl')
    if os.path.exists(endp):
        se = pickle.load(open(endp, 'rb'))
        se.energy = max(se.energy, sim.asc_cost(se)); se.want_asc = False
        sim.ascend(se, ACHIEVE, {'unlock': list(sim.MUTATE), 'buy': {'mutantnexus': 1e6}})
        starts.append(('after the long run (mutagen 10^%.0f, all 10 mutations unlocked)' % lg(se.mutagen), se))
    print('\n### Quick runs that only collect ascensions\n')
    print('| start | ascension | run length (days) | ascension cost paid | energy spent in the run |'); print('| --- | --- | --- | --- | --- |')
    for name, st in starts:
        s = copy.deepcopy(st); s.asc_log = []
        p = dict(ACHIEVE, push=None, ascend=[{'after': 0}] * 4)
        s2, rows, log = sim.run_cycles(p, 300, s.time / 3600 + 24 * 40, s0=s, every=24 * 3600)
        lens = []
        prev = st.time
        for r in log:
            lens.append((r['time'] - prev) / 86400); prev = r['time']
            print('| %s | #%d | %.1f | %s | %s |' % (name, st.asc + len(lens), lens[-1], '{:,}'.format(r['cost']), '{:,.0f}'.format(r['espent'])))
        res[name] = lens
        note('quick ' + name)
    OUT['quick'] = res

def section_energy():
    """Energy needed for ascension n: spend S, then hold C, with C = min(cap, b/ln 2), b = 50,000 x N."""
    print('\n### The energy bill of the ascension count\n')
    print('Energy needed for the ascension after n earlier ones (spend until the cost reaches C, then hold C):\n')
    print('| n | cost with nothing spent | b = 50,000 x N | C held | energy spent + held | days at 2.0 energy/s (5 nexus, lepidoptera and nexus mutation maxed) |')
    print('| --- | --- | --- | --- | --- | --- |')
    tot = 0.0; rows = []
    for n in range(0, 20):
        A = 5e6 * 1.12 ** n; b = 50000 * 1.6; cap = 10000 * 5 * 2
        C = min(cap, b / math.log(2)); E = b * math.log2(A / C) + C
        tot += E if n >= 1 else 0
        rows.append((n, A, b, C, E))
        if n in (0, 1, 2, 4, 9, 14, 19):
            print('| %d | %s | %s | %s | %s | %.1f |' % (n, '{:,.0f}'.format(A), '{:,.0f}'.format(b), '{:,.0f}'.format(C), '{:,.0f}'.format(E), E / (2.0 * 86400)))
    print('\nAscensions 2 to 20 (n = 1..19): %.2fM energy, %.0f days at 2.0 energy/s, before the nexus ramp-up of each run.' % (tot / 1e6, tot / 2.0 / 86400))
    OUT['energy'] = {'total_19': tot}

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    days = 130
    if '--days' in sys.argv: days = int(sys.argv[sys.argv.index('--days') + 1]); args = [a for a in args if a != str(days)]
    want = set(args) or {'first', 'long', 'quick', 'energy'}
    s1, rec = first_ascension()
    print('\nFirst ascension from the save (earliest, no crystals): %.1f h after the save (run age %.1f d), %.3g mutagen, cost %s energy.' % (
        rec['time'] / 3600, rec['run_age'] / 86400, rec['premut'], '{:,}'.format(rec['cost'])))
    note('first')
    if 'long' in want: section_long(s1, days, '--quick' in sys.argv)
    if 'quick' in want: section_quick(s1)
    if 'energy' in want: section_energy()
    json.dump(OUT, open(os.path.join(OUTD, 'achievement_strategy.json'), 'w'), default=str)
    note('done')
