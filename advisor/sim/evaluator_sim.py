"""The evaluator against the current rule set in the simulator (advisor/EVALUATOR.md).

current   = the advisor's rules as they stand: rule-3 sizing, banking 3 (plain, on the counts before the climb), FA (c2),
            rule SEED (1%), faster at 2x the price, twins (flow test, twin plans with the prefix), age multiple 5
evaluator = evaluator.py in place of faster / twins / twin plans / climb / banking / FA / SEED; everything else (energy,
            territory, hatcheries, expansions, lepidoptera, the routes' ascension and mutagen rules) unchanged
Starts: early27 (the owner's first run at 27 min), mirrors20 (20.1 h), run2b (run 2 at 3.0 d), warp (swarmwarp route
from 20.1 h). Usage (repo root): python3 -I advisor/sim/evaluator_sim.py [ideal human1 busy] [--jobs N]
"""
import json, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, faster_study as F, lr_cut as L, bank_plain as B

F.SAVES['early27'] = 'example_save_27min.json'
CUR = dict(L.VAR['B1'], bank_twin='plain', bank_pre=True)
EVAL = dict(L.VAR['off'], evaluator=True, faster_aware=None, seed=None, twin_prefix=None)
VARS = {'current': CUR, 'evaluator': EVAL}
CADS = {'ideal': (None, 1), 'human1': ('human', 1), 'busy': ('busy', 1)}
STARTS = ('warp', 'run2b', 'mirrors20')

def job(a):
    st, vn, cn = a
    prof, sd = CADS[cn]
    r = F.play(st, VARS[vn], prof, sd, days=500)
    r.update(variant=vn, cadence=cn); return r

KEYS = [('overmind6_1', 'endless'), ('overmind6_3', '1e62'), ('expansion9', 'exp 5,000'), ('mutation4', '10 unlocks')]
def fmt(x): return '-' if x is None else '%.0f' % x
def report(res):
    print('| start | cadence | variant | all done | ' + ' | '.join(l for _, l in KEYS) + ' | first ascension (day, log10 premutagen) | nexus 5, runs 1 / 2 (h) | log10 meat/s days 1 / 3 / 7 / 20 / 60 |')
    print('|' + ' --- |' * (len(KEYS) + 7))
    for r in res:
        r0 = r['runs'][0] if r['runs'] else None; r1 = r['runs'][1] if len(r['runs']) > 1 else None
        n5 = lambda x: '%.1f' % x['nexus5_h'] if x and x['nexus5_h'] is not None else '-'
        m = r['marks']
        print('| %s | %s | %s | %s | %s | %s | %s / %s | %s |' % (r['start'], r['cadence'], r['variant'], fmt(r['end_day']) if r['done'] else 'not by 500',
              ' | '.join(fmt(r['when'].get(n)) for n, _ in KEYS), '%.1f, %.1f' % (r0['day'], r0['premut']) if r0 else '-', n5(r0), n5(r1),
              ' / '.join('%.0f' % m[k]['lmeat'] if k in m else '-' for k in (1, 3, 7, 20, 60))))

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    cads = args or ['ideal', 'human1']
    specs = [(st, v, c) for c in cads for st in STARTS for v in VARS]
    T = time.time()
    with ProcessPoolExecutor(jobs) as ex: res = list(ex.map(job, specs))
    json.dump(res, open(os.path.join(F.OUTD, 'evaluator_sim_%s.json' % '_'.join(cads)), 'w'), default=str)
    report(res)
    print('<!-- done (%.0f s) -->' % (time.time() - T))
