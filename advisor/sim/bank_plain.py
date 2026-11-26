"""Banking rule 4 with and without the console script's divisor (advisor/ASCENSION.md, note after A.10.9, Nov 25 2026).

Rule 4 banks tier k when the tier above makes more than bank x larva income x (1 - territory) x twin_k / twin_{k+1}.
The division by twin_{k+1} comes from the console script and understates what larvae could hatch. The twin rule (twin_r,
the advisor's rule 7) has the same divisor. `bank_twin='plain'` drops it in both (the native advisor's new default);
'plain_bank' drops it in banking only. Sections main and extra were run with 'plain_bank'; section both re-runs the
headline rows (run2b and warp, seed off / on, ideal and human seed 1) with both rules plain, and the script for
comparison, both with `bank_pre` (banking on the counts before the climb, as the native advisor judges it).
Everything else as lr_cut.py (FA c2 on, advisor sizing, H with the meat mutation, age multiple 5, each route's settings). Seed off = lr_cut 'off'; seed on = lr_cut 'B1' (rule SEED, 1%).
Starts: run2 (45 h), run2b (3.0 d), run2c (the owner's run 2 at 7.2 d: 1.26e22 larvae idle), mirrors20, warp.
Usage (from the repo root):  python3 -I advisor/sim/bank_plain.py [main] [extra] [both] [--jobs N]   # main+extra ~60 min with 4 jobs
"""
import json, math, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, cadence, faster_study as F, lr_cut as L, warp_route as W

F.SAVES['run2c'] = 'example_save_run2_7d.json'
MK = [1, 3, 7, 20, 60]
STARTS = ('run2', 'run2b', 'run2c', 'mirrors20', 'warp')
CAD = [('ideal', None, 1), ('human1', 'human', 1)]
SEEDV = {'off': L.VAR['off'], 'on': L.VAR['B1']}
EXTRA = {'f=1e-3': dict(L.VAR['B3']), 'f=0.1': dict(L.VAR['B1'], seed={'f': 0.1}),
         'never bank': dict(L.VAR['B1'], bank=None), 'never bank, seed off': dict(L.VAR['off'], bank=None)}

def play(start, var, prof, seed, days=500):
    """F.play plus idle larvae (larvae held / larva income, seconds) and the top owned tier at the marks."""
    s, age0 = F.load(start)
    route = F.route_for(start, dict(var, age0=age0))
    sim.EMPOWER_MODEL = True
    end_h = s.time / 3600 + 24 * days
    gaps = cadence.gaps(prof, days + 2, seed=seed, start=s.time) if prof else 300
    marks = {}; t0 = time.time()
    while s.time < end_h * 3600 - 1 and not W.all_done(s):
        p = route.policy(s); a0 = s.asc; st0 = route.stage(s)
        def until(st):
            for m in MK:
                if m not in marks and st.time >= m * 86400:
                    top = max([k for k in range(1, sim.K + 1) if st.c[k] > 0] or [0])
                    marks[m] = {'lmeat': F.lg(st.c[1] * sim.P(st, 1)), 'top': sim.NAMES[top], 'idle': st.larva / sim.lam(st), 'asc': st.asc}
            return st.asc != a0 or route.stage(st) != st0 or W.all_done(st)
        s, rows, log = sim.run_cycles(p, gaps, end_h, plans=[route.plan] * 1000, s0=s, every=86400, until=until)
    when = {n: t / 86400 for t, n in s.ach_log}
    return {'start': start, 'when': when, 'done': W.all_done(s), 'end_day': s.time / 86400 if W.all_done(s) else None,
            'asc': s.asc, 'exp': s.exp, 'marks': marks, 'secs': round(time.time() - t0)}

def job(a):
    start, vname, var, cname, prof, sd = a
    r = play(start, var, prof, sd); r.update(variant=vname, cadence=cname); return r

def specs_main():
    return [(st, '%s/%s' % (sv, bt), dict(SEEDV[sv], bank_twin=bt), c, pr, sd)
            for st in STARTS for sv in ('off', 'on') for bt in ('script', 'plain_bank') for c, pr, sd in CAD]
def specs_both():
    """Headline rows with both rules plain, and with banking judged on the counts before the climb (`bank_pre`, as the
    native advisor does: the simulator otherwise re-reads the tier above after buying from it, so a tier emptied by the
    purchase above it is never banked and the larvae are not left idle)."""
    return [(st, '%s/%s+pre' % (sv, bt), dict(SEEDV[sv], bank_twin=bt, bank_pre=True), c, pr, sd)
            for st in ('run2b', 'warp') for sv in ('off', 'on') for bt in ('script', 'plain') for c, pr, sd in CAD]
def specs_extra():
    return [(st, '%s/plain_bank' % v, dict(var, bank_twin='plain_bank'), c, pr, sd)
            for st in ('run2b', 'mirrors20', 'warp') for v, var in EXTRA.items() for c, pr, sd in CAD]

fmt = lambda x: '-' if x is None else '%.0f' % x
def report(res):
    get = lambda st, v, c: next((r for r in res if r['start'] == st and r['variant'] == v and r['cadence'] == c), None)
    vs = sorted({r['variant'] for r in res}, key=lambda v: [r['variant'] for r in res].index(v))
    print('| start | variant | all done (ideal / human 1) | first endless | 1e62 | top tier day 20 / 60 | idle larvae, seconds of income, day 1 / 7 / 20 / 60 |')
    print('| --- | --- | --- | --- | --- | --- | --- |')
    for st in STARTS:
        for v in vs:
            ri, rh = get(st, v, 'ideal'), get(st, v, 'human1')
            if not ri: continue
            d = lambda r: fmt(r['end_day']) if r and r['done'] else 'not by 500'
            w = lambda n: '%s / %s' % (fmt(ri['when'].get(n)), fmt(rh['when'].get(n)) if rh else '-')
            m = ri['marks']
            print('| %s | %s | %s / %s | %s | %s | %s / %s | %s |' % (st, v, d(ri), d(rh), w('overmind6_1'), w('overmind6_3'),
                  m.get(20, {}).get('top', '-'), m.get(60, {}).get('top', '-'),
                  ' / '.join('%.1g' % m[k]['idle'] if k in m else '-' for k in (1, 7, 20, 60))))

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    T = time.time()
    for w in (args or ['main', 'extra']):
        with ProcessPoolExecutor(jobs) as ex:
            res = list(ex.map(job, globals()['specs_' + w]()))
        json.dump(res, open(os.path.join(F.OUTD, 'bank_plain_%s.json' % w), 'w'), default=str)
        print('\n## %s\n' % w); report(res)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
