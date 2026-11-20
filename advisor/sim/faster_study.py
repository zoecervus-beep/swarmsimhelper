"""Should the climb test count a new tier's cheap "faster" levels? (advisor/MODEL-CHECK.md, "Faster-aware climbing, pass 2")

Measured with the advisor's own purchase sizing (rule 3, `advisor_sizing`), honest larva arithmetic, age multiple 5, the
A.11 early-game plan and each route's own settings, on whole routes (days to every achievement) and per run.

Variants of the climb test for a tier that fails the plain test (H > age multiple x run age):
  a  plain (the advisor today)
  b  faster-aware, one level: passes when H x (N + F) / (2 N) <= horizon, N = held + n x twin - F, n = rule 3's count
  c  faster-aware, multi: any number L of the tier's own faster levels paid out of the purchase, H x (N + F_L) / (N x 2^L)
  c2 as c, but tested on what the tier could afford (n = all of the tier below / cost), the owner's "I can buy millions"
  d  plain at age multiple 10 (the "bigger multiple" control)
When b / c / c2 start a tier, the level(s) are bought at once at 1x price. The faster-aware test also acts before the
long-run mode's 2-day gate (option fa_ungated).

Routes and starts:
  mirrors20  the mirrors route from the 20.1 h save (first run, long run, quick runs)
  mirrors58  the mirrors route from the owner's 58 h first-run save (advisor/sim/example_save_58h.json)
  run2       the mirrors route from the owner's run-2 save at 45.2 h (advisor/sim/example_save_run2_45h.json)
  warp       the swarmwarp route from the 20.1 h save (NO-MIRRORS.md section 12, game clock)
The long-run mode is on in the mirrors long run and on the swarmwarp route, off in first and quick runs (the setting's
default); territory share 0 once mirrors are cast (the advisor's advice).

Sections: routes (whole routes, 5 variants x 4 starts x 5 cadences, ~25 min with 4 jobs), save2 (save (2) as it stands:
the hours before the gate and days 3, 7, 20, ~3 min).
Usage (from the repo root):  python3 -I advisor/sim/faster_study.py [routes] [save2] [--jobs N]
"""
import copy, json, math, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim, bignum as bn, cadence, warp_route as W
sim.H_MUT = True    # H as the advisor computes it: with the meat mutation's factor (save (2) holds 1e6 meat mutants)

OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
lg = lambda x: bn.lg(x) if x > 0 else float('-inf')
SAVES = {'mirrors20': 'example_save_20h.json', 'mirrors58': 'example_save_58h.json', 'run2': 'example_save_run2_45h.json', 'warp': 'example_save_20h.json'}
VARIANTS = [('a', 'plain (today)', {}),
            ('b', 'faster-aware, one level', {'faster_aware': True, 'fa_ungated': True}),
            ('c', 'faster-aware, multi', {'faster_aware': 'multi', 'fa_ungated': True}),
            ('c2', 'faster-aware, multi, on the affordable count', {'faster_aware': 'multi', 'fa_n': 'afford', 'fa_ungated': True}),
            ('d', 'plain, age multiple 10', {'theta_age': 10})]
CADENCES = [('ideal', None, 1), ('human1', 'human', 1), ('human2', 'human', 2), ('human3', 'human', 3), ('busy', 'busy', 1)]

def load(start):
    os.environ['SAVE'] = os.path.join(HERE, SAVES[start])
    s = sim.load(); s.ach_log = []; s.ewaste = 0.0
    age0 = (s.t0_ms - s.restarted_ms) / 1000.0          # the save's run age
    return s, age0

class MRoute(W.Route):
    """The mirrors route with the long-run mode on in its long run only, territory share 0 once mirrors are cast."""
    def policy(self, s):
        p = W.mirror_policy(s, f_mirror=0.0)
        if W.mirror_stage(s) != 'longRun': p.update(push=None, lr_age=None)
        p.update(self.over)
        return p

def route_for(start, over):
    if start == 'warp':
        r = W.Route('warp'); r.over = dict(over); return r
    return MRoute('mirror', over=dict(over))

def play(start, var, prof, seed, days=420):
    """Whole route, with per-run nexus 5 and ascension times, premutagen, milestones and meat marks."""
    s, age0 = load(start)
    over = dict(var, age0=age0)
    route = route_for(start, over)
    sim.EMPOWER_MODEL = True
    end_h = s.time / 3600 + 24 * days
    gaps = cadence.gaps(prof, days + 2, seed=seed, start=s.time) if prof else 300
    runs = []; marks = {}; MK = [1, 3, 7, 20, 60]
    track = {'n5': None}
    t0 = time.time()
    while s.time < end_h * 3600 - 1 and not W.all_done(s):
        p = route.policy(s); a0 = s.asc; st0 = route.stage(s); n0 = len(s.asc_log)
        track['n5'] = (s.time if s.nexus >= 5 else None)
        def until(st):
            if track['n5'] is None and st.nexus >= 5: track['n5'] = st.time
            for m in MK:
                if m not in marks and st.time >= m * 86400:
                    marks[m] = {'lmeat': lg(st.c[1] * sim.P(st, 1)), 'top': max([k for k in range(1, sim.K + 1) if st.c[k] > 0] or [0]), 'exp': st.exp}
            return st.asc != a0 or route.stage(st) != st0 or W.all_done(st)
        start_t = s.time
        s, rows, log = sim.run_cycles(p, gaps, end_h, plans=[route.plan] * 1000, s0=s, every=86400, until=until)
        if len(log) > n0:
            r = log[-1]
            runs.append({'stage': st0, 'start_day': start_t / 86400, 'day': r['time'] / 86400, 'premut': lg(r['premut']), 'exp': r['exp'],
                         'nexus5_h': None if track['n5'] is None else (track['n5'] - start_t) / 3600.0})
    when = {n: t / 86400 for t, n in s.ach_log}
    return {'start': start, 'when': when, 'done': W.all_done(s), 'end_day': s.time / 86400 if W.all_done(s) else None, 'asc': s.asc,
            'runs': runs, 'marks': marks, 'secs': round(time.time() - t0)}

def job(args):
    start, vkey, cname, prof, seed = args
    var = dict(VARIANTS)[vkey] if False else [v for k, _, v in VARIANTS if k == vkey][0]
    r = play(start, var, prof, seed)
    r.update(variant=vkey, cadence=cname)
    return r

KEYS = [('overmind6_1', 'endless 1'), ('overmind6_3', 'endless 1e62'), ('expansion7', 'exp 1,000'), ('expansion8', 'exp 2,000'),
        ('expansion9', 'exp 5,000'), ('ascension3', '20 asc.'), ('mutation4', '10 unlocks')]

def section_routes(jobs):
    specs = [(st, vk, cn, pr, sd) for st in ('mirrors20', 'mirrors58', 'run2', 'warp') for vk, _, _ in VARIANTS for cn, pr, sd in CADENCES]
    with ProcessPoolExecutor(jobs) as ex:
        res = list(ex.map(job, specs))
    json.dump(res, open(os.path.join(OUTD, 'faster_study_routes.json'), 'w'), default=str)
    report(res)
    return res

def report(res):
    get = lambda st, vk, cn: [r for r in res if r['start'] == st and r['variant'] == vk and r['cadence'] == cn][0]
    def allday(r): return r['end_day'] if r['done'] else float('nan')
    for st in ('mirrors20', 'mirrors58', 'run2', 'warp'):
        print('\n### %s: days to every achievement (from the save), difference from (a)\n' % st)
        print('| variant | ideal | human 1 / 2 / 3 | busy | human: mean difference from (a) | seed spread of (a), human |')
        print('| --- | --- | --- | --- | --- | --- |')
        base = {cn: allday(get(st, 'a', cn)) for cn, _, _ in CADENCES}
        hs = [base['human1'], base['human2'], base['human3']]
        for vk, vn, _ in VARIANTS:
            d = {cn: allday(get(st, vk, cn)) for cn, _, _ in CADENCES}
            hd = [d['human%d' % i] - base['human%d' % i] for i in (1, 2, 3)]
            print('| %s %s | %.0f | %.0f / %.0f / %.0f | %.0f | %+.1f | %.0f |' % (vk, vn, d['ideal'], d['human1'], d['human2'], d['human3'], d['busy'],
                                                                         sum(hd) / 3, max(hs) - min(hs)))
        print('\nMilestones (days from the save), ideal / human mean:\n')
        print('| variant | ' + ' | '.join(l for _, l in KEYS) + ' | first ascension | its premutagen (log10) | nexus 5 in run 1 / run 2 (h) |')
        print('|' + ' --- |' * (len(KEYS) + 4))
        for vk, vn, _ in VARIANTS:
            ri = get(st, vk, 'ideal'); rh = [get(st, vk, 'human%d' % i) for i in (1, 2, 3)]
            cell = lambda n: '%s / %s' % ('%.0f' % ri['when'][n] if n in ri['when'] else '-',
                                         '%.0f' % (sum(x['when'][n] for x in rh) / 3) if all(n in x['when'] for x in rh) else '-')
            r0 = ri['runs'][0] if ri['runs'] else None; r1 = ri['runs'][1] if len(ri['runs']) > 1 else None
            print('| %s | %s | %s | %s | %s |' % (vk, ' | '.join(cell(n) for n, _ in KEYS), '%.1f' % r0['day'] if r0 else '-', '%.1f' % r0['premut'] if r0 else '-',
                                                 '%s / %s' % ('%.1f' % r0['nexus5_h'] if r0 and r0['nexus5_h'] is not None else '-',
                                                              '%.1f' % r1['nexus5_h'] if r1 and r1['nexus5_h'] is not None else '-')))
        print('\nlog10 meat/s at days 1 / 3 / 7 / 20 / 60 from the save (ideal):\n')
        print('| variant | day 1 | day 3 | day 7 | day 20 | day 60 |'); print('| --- | --- | --- | --- | --- | --- |')
        for vk, vn, _ in VARIANTS:
            m = get(st, vk, 'ideal')['marks']
            print('| %s | %s |' % (vk, ' | '.join('%.1f (%s)' % (m[k]['lmeat'], sim.NAMES[m[k]['top']]) if k in m else '-' for k in (1, 3, 7, 20, 60))))

# ---------------------------------------------------------------------------------------------------------- save (2)
def save2_job(args):
    vkey, cname, prof, seed = args
    var = [v for k, _, v in VARIANTS if k == vkey][0]
    s, age0 = load('run2')
    route = route_for('run2', dict(var, age0=age0))
    p = dict(route.policy(s)); sim.EMPOWER_MODEL = True
    gaps = cadence.gaps(prof, 22, seed=seed, start=s.time) if prof else None
    out = {'variant': vkey, 'cadence': cname, 'first_hours': [], 'days': {}}
    gate = p['lr_age'] - age0
    p['ci'] = 300.0
    k_emp = sim.NAMES.index('empress')
    emp_bought0 = s.bought.get('empress', 0.0); fasters0 = s.prod[k_emp]
    nxt = [3 * 3600.0 * i / 6 for i in range(1, 7)]   # every 30 min to 3 h
    while s.time < 20 * 86400 + 1:
        dt = float(gaps(s.time)) if gaps else 300.0; p['ci'] = dt
        g = sim.advance(s, dt); sim.policy(s, p, g)
        if s.want_asc: break
        while nxt and s.time >= nxt[0]:
            out['first_hours'].append({'h': nxt[0] / 3600, 'empress_held': float(s.c[k_emp]), 'empress_bought': float(s.bought.get('empress', 0.0) - emp_bought0),
                                       'empress_faster': s.prod[k_emp] - fasters0, 'top': sim.NAMES[max(k for k in range(1, sim.K + 1) if s.c[k] > 0)]})
            nxt.pop(0)
        for d in (3, 7, 20):
            if d not in out['days'] and s.time >= d * 86400:
                out['days'][d] = {'lmeat': lg(s.c[1] * sim.P(s, 1)), 'top': sim.NAMES[max(k for k in range(1, sim.K + 1) if s.c[k] > 0)], 'exp': s.exp,
                                  'empress_faster': s.prod[k_emp], 'prophet_held': lg(s.c[k_emp + 1]) if s.c[k_emp + 1] > 0 else None}
    out['gate_h'] = gate / 3600
    return out

def section_save2(jobs):
    specs = [(vk, cn, pr, sd) for vk, _, _ in VARIANTS for cn, pr, sd in (('ideal', None, 1), ('human1', 'human', 1))]
    with ProcessPoolExecutor(jobs) as ex:
        res = list(ex.map(save2_job, specs))
    json.dump(res, open(os.path.join(OUTD, 'faster_study_save2.json'), 'w'), default=str)
    print('\n### Save (2) as it stands: empresses in the hours before the long-run gate (opens after %.1f h)\n' % res[0]['gate_h'])
    print('| variant | cadence | ' + ' | '.join('%.1f h: bought / faster' % x['h'] for x in res[0]['first_hours']) + ' |')
    print('|' + ' --- |' * (2 + len(res[0]['first_hours'])))
    for r in res:
        print('| %s | %s | %s |' % (r['variant'], r['cadence'], ' | '.join('%.3g / %d' % (x['empress_bought'], x['empress_faster']) for x in r['first_hours'])))
    print('\n| variant | cadence | day 3: log10 meat/s (top) | day 7 | day 20 | expansions day 20 |')
    print('| --- | --- | --- | --- | --- | --- |')
    for r in res:
        d = r['days']
        print('| %s | %s | %s | %s | %s | %s |' % (r['variant'], r['cadence'], *['%.1f (%s)' % (d[k]['lmeat'], sim.LABEL.get(d[k]['top'], d[k]['top'])) if k in d else '-' for k in (3, 7, 20)],
                                                d.get(20, {}).get('exp', '-')))
    return res

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    want = args or ['save2', 'routes']
    T = time.time()
    for w in want:
        globals()['section_' + w](jobs)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
