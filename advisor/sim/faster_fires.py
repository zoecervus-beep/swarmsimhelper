"""How often the faster-aware test starts a tier under the advisor's sizing (advisor/MODEL-CHECK.md, pass 2): every tier
start it causes over a whole route (tier, faster levels needed, run age, ascension), for variants b, c, c2 at the ideal
cadence, from each start of faster_study.py.  Usage: python3 -I advisor/sim/faster_fires.py   (~4 min with 4 jobs)"""
import os, sys, json
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, faster_study as F

def job(args):
    start, vk = args
    fires = []
    orig = sim.faster_aware_passes
    def wrapped(s, p, k, n):
        ok = orig(s, p, k, n)
        if ok:
            L = sim.faster_levels(s, p, k, n) if p.get('faster_aware') == 'multi' else 1
            fires.append({'asc': s.asc, 'tier': sim.NAMES[k], 'L': L, 'run_age_d': round(sim.run_age(s, p) / 86400, 2), 'level_before': s.prod[k],
                          'held': float(s.c[k]) if s.c[k] < 1e300 else None})
        return ok
    sim.faster_aware_passes = wrapped
    var = [v for k, _, v in F.VARIANTS if k == vk][0]
    r = F.play(start, var, None, 1)
    sim.faster_aware_passes = orig
    return {'start': start, 'variant': vk, 'fires': fires, 'end_day': r['end_day']}

if __name__ == '__main__':
    specs = [(st, vk) for st in ('mirrors20', 'mirrors58', 'run2', 'warp') for vk in ('b', 'c', 'c2')]
    with ProcessPoolExecutor(4) as ex:
        res = list(ex.map(job, specs))
    json.dump(res, open(os.path.join(F.OUTD, 'faster_fires.json'), 'w'), default=str)
    print('| start | variant | tier starts by the faster-aware test | first ones (ascension, tier, levels, run age d) |')
    print('| --- | --- | --- | --- |')
    for r in res:
        f = r['fires']
        print('| %s | %s | %d | %s |' % (r['start'], r['variant'], len(f), '; '.join('%d %s L%d %.2f' % (x['asc'], sim.LABEL.get(x['tier'], x['tier']), x['L'], x['run_age_d']) for x in f[:6])))
