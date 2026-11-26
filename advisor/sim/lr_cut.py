"""Can the long-run climb mode be cut, or replaced by one always-on rule? (advisor/ASCENSION.md A.10, pass 5)

Everything with the advisor's sizing (rule 3), honest larvae, rule FA (variant c2, always on, not gated), age multiple 5,
H as the advisor computes it (meat mutation included), the A.11 plan and each route's own settings (faster_study.py's
drivers). Variants (all of them with FA):
  on        the long-run mode as specified (LR-0 gate, LR-2 push with the 1% reserve, LR-3 guard; on the mirrors route
            in its long run, on the swarmwarp route always)
  off       the mode off (the advisor as the owner runs it now)
  C         off + the twin planner's prefix detour (`twin_prefix`)
  A         C + the horizon raised to the run's expected remaining time (`horizon_fn`, see remaining())
  Bp        C + a seeding rule, f = horizon / H per tier (`seed` 'payback')
  B1 / B3   C + a seeding rule with f = 1e-2 / 1e-3
  ablations of the mode: on without the gate, without the reserve, without the guard, without the day-3 lepidoptera
            raise, LR-2 alone, on + prefix
Starts: run2 (the owner's run 2 at 45 h, mode on), run2b (the same run at 3.0 d, mode off), mirrors20 (the mirrors route
from the 20.1 h save: first run, long run, quick runs), warp (the swarmwarp route from the 20.1 h save).
Usage (from the repo root):  python3 -I advisor/sim/lr_cut.py [main] [ablate] [--jobs N]     # ~40 min with 4 jobs
"""
import json, math, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, faster_study as F, warp_route as W

F.SAVES['run2b'] = 'example_save_run2_72h.json'
def _mpolicy(self, s):
    """The mirrors route: the variant's settings, and the long-run mode (push, gate) only in its long run."""
    p = W.mirror_policy(s, climb='mode', f_mirror=0.0); p.update(self.over)
    if W.mirror_stage(s) != 'longRun': p.update(push=None, lr_age=None)
    return p
F.MRoute.policy = _mpolicy
OUTD = F.OUTD
FA = [v for k, _, v in F.VARIANTS if k == 'c2'][0]
OFF = dict(push=None, lr_age=None)

def remaining(s, p):
    """Candidate A: the time the run is expected to last from now, for its stage on its route (seconds).
    mirrors long run: until 5,000 expansions at 0.774 expansions per House of Mirrors cast (2,500 energy each);
    a run that will ascend (first, quick, swarmwarp build/quick): until the ascension is affordable, from the cost
    formula (spend down to the save point, then hold it); swarmwarp final run: 0 (unknown)."""
    er = sim.erate(s)
    if er <= 0: return 0.0
    if 'warp' in (p.get('spells') or ()):
        st = W.stage(s, W.CFG)
        if st not in ('build', 'quick'): return 0.0
    else:
        st = W.mirror_stage(s)
        if st == 'longRun':
            return max(0.0, 5000 - s.exp) / 0.774 * 2500 / er
    halving = 50000.0 * s.acm
    save_at = min(sim.ecap(s), halving / math.log(2))
    cost = sim.asc_cost(s)
    spend = halving * math.log2(cost / save_at) if cost > save_at else 0.0
    return (spend + max(0.0, min(cost, save_at) - s.energy)) / er

VAR = {'on': dict(FA),
       'off': dict(FA, **OFF),
       'C': dict(FA, **OFF, twin_prefix=True),
       'A': dict(FA, **OFF, twin_prefix=True, horizon_fn=remaining),
       'Bp': dict(FA, **OFF, twin_prefix=True, seed={'f': 'payback'}),
       'B1': dict(FA, **OFF, twin_prefix=True, seed={'f': 1e-2}),
       'B3': dict(FA, **OFF, twin_prefix=True, seed={'f': 1e-3}),
       'on+prefix': dict(FA, twin_prefix=True),
       'on, no gate (LR-0)': dict(FA, lr_age=None),
       'on, no reserve (LR-2 honest, no 1%)': 'noreserve',
       'on, no twin guard (LR-3)': 'noguard',
       'on, no day-3 lepidoptera raise (LR-4)': dict(FA, moth_late=None),
       'LR-2 alone (no gate, no guard, no LR-4)': 'lr2alone'}
LABEL = {'on': 'mode on (as specified)', 'off': 'mode off', 'C': 'off + twin prefix (FA + fixed planner)',
         'A': 'A: horizon = remaining run time', 'Bp': 'Bp: seeding, f = horizon / H', 'B1': 'B1: seeding, f = 1e-2', 'B3': 'B3: seeding, f = 1e-3'}

def over_for(name, route_p):
    v = VAR[name]
    if v == 'noreserve': return dict(FA, push=dict(route_p['push'], reserve=None))
    if v == 'noguard': return dict(FA, push=dict(route_p['push'], twin_mult=1))
    if v == 'lr2alone': return dict(FA, lr_age=None, push=dict(route_p['push'], twin_mult=1), moth_late=None)
    return dict(v)

def job(args):
    start, name, cname, prof, seed = args
    over = over_for(name, sim_spec_push())
    r = F.play(start, over, prof, seed, days=500)
    r.update(variant=name, cadence=cname)
    return r

def sim_spec_push():
    return W.SPEC4

CAD = [('ideal', None, 1), ('human1', 'human', 1), ('human2', 'human', 2), ('human3', 'human', 3), ('busy', 'busy', 1), ('twice', 'twice', 1)]
STARTS = ('run2', 'run2b', 'mirrors20', 'warp')
MAIN = ('on', 'off', 'C', 'A', 'Bp', 'B1')
ABL = ('on+prefix', 'on, no gate (LR-0)', 'on, no reserve (LR-2 honest, no 1%)', 'on, no twin guard (LR-3)', 'on, no day-3 lepidoptera raise (LR-4)',
       'LR-2 alone (no gate, no guard, no LR-4)', 'B3')

def run(specs, jobs, tag):
    with ProcessPoolExecutor(jobs) as ex:
        res = list(ex.map(job, specs))
    for r in res: r['when'] = {k: v for k, v in r['when'].items()}
    json.dump(res, open(os.path.join(OUTD, 'lr_cut_%s.json' % tag), 'w'), default=str)
    return res

KEYS = [('overmind6_1', 'endless 1'), ('overmind6_2', '1e31'), ('overmind6_3', '1e62'), ('expansion7', 'exp 1,000'), ('expansion8', 'exp 2,000'), ('expansion9', 'exp 5,000')]

def fmt(x): return '-' if x is None or x != x else '%.0f' % x

def report(res, starts, variants, cads):
    get = lambda st, v, c: next((r for r in res if r['start'] == st and r['variant'] == v and r['cadence'] == c), None)
    def day(r): return r['end_day'] if r and r['done'] else None
    for st in starts:
        print('\n### %s: days to every achievement (from the save)\n' % st)
        print('| variant | ' + ' | '.join(c for c, _, _ in cads) + ' | human mean vs mode on | spread of "on", human |')
        print('|' + ' --- |' * (len(cads) + 3))
        base_h = [day(get(st, 'on', 'human%d' % i)) for i in (1, 2, 3)]
        spread = (max(base_h) - min(base_h)) if all(x is not None for x in base_h) else None
        for v in variants:
            ds = [day(get(st, v, c)) for c, _, _ in cads]
            hs = [day(get(st, v, 'human%d' % i)) for i in (1, 2, 3)]
            md = (sum(hs) / 3 - sum(base_h) / 3) if all(x is not None for x in hs + base_h) else None
            print('| %s | %s | %s | %s |' % (LABEL.get(v, v), ' | '.join(fmt(x) for x in ds), '%+.1f' % md if md is not None else '-', fmt(spread)))
        print('\nMilestones (days from the save), ideal / human seed 1:\n')
        print('| variant | ' + ' | '.join(l for _, l in KEYS) + ' | first ascension (day, log10 premutagen) | nexus 5 run 1 / 2 (h) | quick runs: mean length (d) |')
        print('|' + ' --- |' * (len(KEYS) + 4))
        for v in variants:
            ri = get(st, v, 'ideal'); rh = get(st, v, 'human1')
            if not ri: continue
            cell = lambda n: '%s / %s' % (fmt(ri['when'].get(n)), fmt(rh['when'].get(n)) if rh else '-')
            r0 = ri['runs'][0] if ri['runs'] else None; r1 = ri['runs'][1] if len(ri['runs']) > 1 else None
            q = [x for x in ri['runs'] if x['stage'] in ('quickRun', 'quick')]
            ql = sum(x['day'] - x['start_day'] for x in q) / len(q) if q else None
            n5 = lambda r: '%.1f' % r['nexus5_h'] if r and r['nexus5_h'] is not None else '-'
            print('| %s | %s | %s | %s / %s | %s |' % (LABEL.get(v, v), ' | '.join(cell(n) for n, _ in KEYS),
                  '%.1f, %.1f' % (r0['day'], r0['premut']) if r0 else '-', n5(r0), n5(r1), '%.2f' % ql if ql else '-'))
        print('\nlog10 meat/s at days 1 / 3 / 7 / 20 / 60 from the save (ideal):\n')
        print('| variant | day 1 | day 3 | day 7 | day 20 | day 60 |'); print('| --- | --- | --- | --- | --- | --- |')
        for v in variants:
            r = get(st, v, 'ideal')
            if not r: continue
            m = r['marks']
            print('| %s | %s |' % (LABEL.get(v, v), ' | '.join('%.1f (%s)' % (m[k]['lmeat'], sim.LABEL.get(sim.NAMES[m[k]['top']], sim.NAMES[m[k]['top']])) if k in m else '-' for k in (1, 3, 7, 20, 60))))

def section_main(jobs):
    specs = [(st, v, c, pr, sd) for st in STARTS for v in MAIN for c, pr, sd in CAD]
    res = run(specs, jobs, 'main'); report(res, STARTS, MAIN, CAD); return res

def section_ablate(jobs):
    cads = CAD[:2]
    specs = [(st, v, c, pr, sd) for st in ('run2', 'mirrors20', 'warp') for v in ('on', 'off') + ABL for c, pr, sd in cads]
    res = run(specs, jobs, 'ablate'); report(res, ('run2', 'mirrors20', 'warp'), ('on', 'off') + ABL, cads); return res

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    want = args or ['main', 'ablate']
    T = time.time()
    for w in want:
        globals()['section_' + w](jobs)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
