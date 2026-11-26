"""The evaluator against the current rule set in the simulator (advisor/EVALUATOR.md sections 6 and 11).

current   = the advisor's rules as they stand: rule-3 sizing, banking 3 (plain, on the counts before the climb), FA (c2),
            rule SEED (1%), faster at 2x the price, twins (flow test, twin plans with the prefix), age multiple 5
hybrid    = current, with faster and twin levels decided by evaluator.upgrades (evaluator='upgrades'): no 2x faster
            rule, no twin rules, no twin plans or prefix; hatches unchanged
evaluator = evaluator.py in place of faster / twins / twin plans / climb / banking / FA / SEED (section 6)
Everything else (energy, territory, hatcheries, expansions, lepidoptera, the routes' rules) is the same. Runs stop at
day 250 (a route not finished by then is a loss: the current rules finish every start by day 183).
Usage (repo root): python3 -I advisor/sim/evaluator_sim.py [ideal human1 busy] [--vars current,hybrid] [--jobs N]
"""
import json, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, faster_study as F, lr_cut as L, bank_plain as B

F.SAVES['early27'] = 'example_save_27min.json'
CUR = dict(L.VAR['B1'], bank_twin='plain', bank_pre=True)
HYB = dict(CUR, evaluator='upgrades', twin_prefix=None)
EVAL = dict(L.VAR['off'], evaluator=True, faster_aware=None, seed=None, twin_prefix=None)
VARS = {'current': CUR, 'hybrid': HYB, 'evaluator': EVAL}
CADS = {'ideal': (None, 1), 'human1': ('human', 1), 'busy': ('busy', 1)}
STARTS = ('warp', 'run2b', 'mirrors20')
DAYS = 250

def job(a):
    st, vn, cn = a
    prof, sd = CADS[cn]
    sim.DRAIN = []
    t = time.time()
    r = F.play(st, VARS[vn], prof, sd, days=DAYS)
    d = sim.DRAIN; sim.DRAIN = None
    # the drain check: twin levels that spent at least half the paying tier, and among them those paid by one of the
    # two highest owned tiers for a tier at least three below the top
    big = [x for x in d if x[1] >= 0.5]
    r.update(variant=vn, cadence=cn, wall=round(time.time() - t), twins=len(d), twins_half=len(big),
             drain=len([x for x in big if x[0] + 1 >= x[2] - 1 and x[0] <= x[2] - 3]))
    return r

KEYS = [('overmind6_1', 'endless'), ('overmind6_3', '1e62'), ('expansion9', 'exp 5,000'), ('mutation4', '10 unlocks')]
def fmt(x): return '-' if x is None else '%.0f' % x
def report(res):
    print('| start | cadence | variant | all done | ' + ' | '.join(l for _, l in KEYS) + ' | first ascension (day, log10 premutagen) | nexus 5, runs 1 / 2 (h) | log10 meat/s days 1 / 3 / 7 / 20 / 60 | twin levels: all / spent >= half the paying tier / of those, an upper tier paying for a tier 3+ below | wall s |')
    print('|' + ' --- |' * (len(KEYS) + 9))
    for r in res:
        r0 = r['runs'][0] if r['runs'] else None; r1 = r['runs'][1] if len(r['runs']) > 1 else None
        n5 = lambda x: '%.1f' % x['nexus5_h'] if x and x['nexus5_h'] is not None else '-'
        m = r['marks']
        print('| %s | %s | %s | %s | %s | %s | %s / %s | %s | %d / %d / %d | %d |' % (r['start'], r['cadence'], r['variant'], fmt(r['end_day']) if r['done'] else 'not by %d' % DAYS,
              ' | '.join(fmt(r['when'].get(n)) for n, _ in KEYS), '%.1f, %.1f' % (r0['day'], r0['premut']) if r0 else '-', n5(r0), n5(r1),
              ' / '.join('%.0f' % m[k]['lmeat'] if k in m else '-' for k in (1, 3, 7, 20, 60)), r['twins'], r['twins_half'], r['drain'], r['wall']))

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4; vs = ['current', 'hybrid']
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    if '--vars' in sys.argv: vs = sys.argv[sys.argv.index('--vars') + 1].split(','); args.remove(sys.argv[sys.argv.index('--vars') + 1])
    cads = args or ['ideal', 'human1']
    specs = [(st, v, c) for c in cads for st in STARTS for v in vs]
    T = time.time()
    with ProcessPoolExecutor(jobs) as ex: res = list(ex.map(job, specs))
    json.dump(res, open(os.path.join(F.OUTD, 'evaluator_sim_%s_%s.json' % ('_'.join(vs), '_'.join(cads))), 'w'), default=str)
    report(res)
    print('<!-- done (%.0f s) -->' % (time.time() - T))
