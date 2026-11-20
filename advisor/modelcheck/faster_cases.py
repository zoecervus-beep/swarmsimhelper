"""Reference cases for the faster-aware climb test as recommended in advisor/MODEL-CHECK.md ("Faster-aware climbing,
pass 2", rule FA): exported saves the real game loads, the test evaluated on each failing tier, and the simulator's own
climb decisions (variant c2 of advisor/sim/faster_study.py). See faster_cases/README.md.

Usage (from the repo root; node on PATH, `npm install` in advisor/modelcheck):
    python3 -I advisor/modelcheck/faster_cases.py        # about 2 minutes; writes advisor/modelcheck/faster_cases/
"""
import copy, json, math, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim')); sys.path.insert(0, HERE)
import sim, bignum as bn, export, faster_study as F, warp_route as W, longrun_cases as LC

OUTDIR = os.path.join(HERE, 'faster_cases'); os.makedirs(OUTDIR, exist_ok=True)
D = bn.dec; lg = F.lg; GAP = 300.0; T0 = time.time()
C2 = [v for k, _, v in F.VARIANTS if k == 'c2'][0]
MAXL = 12

def faster_test(s, p, k, larvae_for_climb, age_multiple):
    """Rule FA on tier k of state s (pure). Inputs as the advisor reads them: H, the horizon, the units held, the tier
    below held, costs, twin, the faster level and the larvae the climb may use."""
    age = sim.run_age(s, p); horizon = age_multiple * age
    H = sim.H(s, k)
    out = {'tier': k, 'name': sim.NAMES[k], 'H_s': D(H), 'horizon_s': horizon, 'passes_plain': bool(H <= horizon),
           'held': D(s.c[k]), 'twin': D(sim.TWO ** s.twin[k]), 'faster_level': s.prod[k]}
    if H <= horizon or k < 2: return out
    below = s.c[k - 1]; cost = sim.UNITC[k]
    n = math.floor(min(larvae_for_climb, below / cost, s.c[0] / sim.MEATC[k])) if min(larvae_for_climb, below / cost, s.c[0] / sim.MEATC[k]) < 2 ** 53 else min(larvae_for_climb, below / cost, s.c[0] / sim.MEATC[k])
    got = s.c[k] + n * sim.TWO ** s.twin[k]
    out.update({'below_held': D(below), 'cost_below': cost, 'meat': D(s.c[0]), 'meat_cost': sim.MEATC[k], 'larvae_for_climb': D(larvae_for_climb),
                'n_affordable': D(n), 'got': D(got)})
    levels = []; Fl = 0.0; chosen = None
    for L in range(1, MAXL + 1):
        Fl = Fl + sim.prod_cost_at(s, k, s.prod[k] + L - 1); N = got - Fl
        Heff = H * (N + Fl) / (N * sim.TWO ** L) if N >= 1 else None
        ok = bool(N >= 1 and Heff <= horizon)
        levels.append({'L': L, 'price_total': D(Fl), 'N_kept': D(N), 'H_eff_s': D(Heff) if Heff is not None else None, 'passes': ok})
        if ok and chosen is None: chosen = L
    out['levels'] = levels
    if chosen is not None:
        out['decision'] = {'type': 'start', 'hatch': D(n), 'faster_levels': chosen, 'faster_price_total': levels[chosen - 1]['price_total']}
    else:
        Lmin = max(1, math.ceil(math.log2(float(H / horizon))))
        Fm = sum(sim.prod_cost_at(s, k, s.prod[k] + i) for i in range(Lmin))
        Nstar = H * Fm / (sim.TWO ** Lmin * horizon - H)
        need_got = Nstar + Fm
        out['decision'] = {'type': 'wait', 'levels_needed': Lmin, 'their_price': D(Fm), 'units_needed_after_hatch': D(need_got),
                           'hatch_needed': D(max(0.0, (need_got - s.c[k]) / sim.TWO ** s.twin[k])), 'affordable': D(n)}
    return out

def larvae_for_climb(s, p):
    f = p['f'] if not (s.casts.get('mirror') and 'f_mirror' in p) else p['f_mirror']
    return max(0.0, (s.larva - s.purse if f > 0 else s.larva) - s.reserve - s.nexres)

def sim_decisions(cs, p):
    s = copy.deepcopy(cs); sim.TRACE = []
    LC.run_climb_and_push(s, dict(p, ci=GAP))
    ev = list(sim.TRACE); sim.TRACE = None
    d = LC.events_to_decisions(ev)
    return {'climb': d['climb'], 'faster_after_climb': d['faster_after_climb'], 'push': d['push']}

def write_case(name, what, cs, p, age_multiple=5):
    save = export.export_save(cs, p)
    json.dump(save, open(os.path.join(OUTDIR, name + '.save.json'), 'w'), indent=0)
    q = dict(p, theta_age=age_multiple)
    A = larvae_for_climb(cs, q)
    top = max([k for k in range(1, sim.K + 1) if cs.c[k] > 0] or [1])
    tiers = [faster_test(cs, q, k, A, age_multiple) for k in range(2, min(top + 1, sim.K) + 1)]
    case = {'case': name, 'exercises': what, 'save': name + '.save.json',
            'config': {'age_multiple': age_multiple, 'max_faster_levels': MAXL, 'faster_price': '66 x 666^level of the tier itself',
                       'long_run_mode': 'on' if q.get('lr_age') else 'off', 'territory_share': q['f'] if not cs.casts.get('mirror') else q.get('f_mirror', q['f'])},
            'state': {'run_age_s': sim.run_age(cs, q), 'horizon_s': age_multiple * sim.run_age(cs, q), 'top_owned': sim.NAMES[top],
                      'larvae': D(cs.larva), 'larvae_for_climb': D(A), 'meat': D(cs.c[0])},
            'rule_FA': [t for t in tiers if not t['passes_plain']], 'plain_passes': [t['name'] for t in tiers if t['passes_plain']],
            'simulator': sim_decisions(cs, dict(q, **C2))}
    json.dump(case, open(os.path.join(OUTDIR, name + '.json'), 'w'), indent=1, default=str)
    return case

def survey(start, days, warp=False):
    """Play variant c2 from a start and keep, for the first start of each tier by the faster-aware test, the state as
    the climb starts at that visit."""
    s, age0 = F.load(start)
    route = F.route_for(start, dict(C2, age0=age0)); sim.EMPOWER_MODEL = True
    p = dict(route.policy(s), ci=GAP); a0 = s.asc
    got = {}
    while s.time < days * 86400:
        g = sim.advance(s, GAP)
        sim.TRACE = []; sim.CAPTURE = []
        sim.policy(s, p, g)
        fires = [e for e in sim.TRACE if e[0] == 'fa' and e[3]]
        bought = [e[1] for e in sim.TRACE if e[0] == 'climb' and e[2] == 'buys' and e[4]]
        cap = sim.CAPTURE[0] if sim.CAPTURE else None
        sim.TRACE = None; sim.CAPTURE = None
        for k in bought:
            key = (s.asc, sim.NAMES[k])
            if key not in got and cap is not None: got[key] = (cap, p)
        if s.want_asc:
            sim.ascend(s, p, route.plan); p = dict(route.policy(s), ci=GAP)
    return got

def main():
    cases = []
    # the owner's saves as they stand
    for start, what in (('run2', "the owner's run-2 save (45.2 h, mirrors long run, mode on, gate in 2.8 h): empresses fail even with faster levels"),
                        ('mirrors58', "the owner's 58 h first-run save")):
        s, age0 = F.load(start); route = F.route_for(start, dict(C2, age0=age0)); p = dict(route.policy(s), ci=GAP)
        sim.TRACE = []; sim.CAPTURE = []; sim.policy(s, p, 0.0); cs = sim.CAPTURE[0]; sim.TRACE = None; sim.CAPTURE = None
        cases.append(write_case(start + '_save', what + ' (age multiple 5)', cs, p, 5))
        if start == 'mirrors58':
            cases.append(write_case(start + '_save_x3', what + ' at age multiple 3: hive queens fail the plain test, rule FA decides', cs, p, 3))
    # first starts by the test along the routes
    for start, days, label in (('mirrors20', 4.0, 'first run from the 20.1 h save'), ('run2', 12.0, 'run 2 from save (2)'), ('warp', 8.0, 'swarmwarp route')):
        got = survey(start, days)
        print('%s: %s (%.0f s)' % (start, sorted(got), time.time() - T0), flush=True)
        for (asc, tier), (cs, p) in sorted(got.items(), key=lambda x: x[1][0].time)[:4]:
            cases.append(write_case('%s_asc%d_%s' % (start, asc, tier), '%s: the visit where rule FA first starts %s' % (label, sim.LABEL.get(tier, tier)), cs, p, 5))
    # both sides of the line: from the first case that started a tier with L >= 2, set the tier below so that what the
    # tier would hold after hatching all it can afford is 1 +- 1e-6 times the units the test needs
    starts = [c for c in cases if c['rule_FA'] and any(t.get('decision', {}).get('type') == 'start' for t in c['rule_FA'])]
    big = lambda c: max(float(t['n_affordable']) for t in c['rule_FA'] if t.get('decision', {}).get('type') == 'start')
    base = max(starts, key=big)          # the largest hatch: a 1e-6 step is then far above the integer resolution
    s0, age0 = None, None
    name = base['case']; save = os.path.join(OUTDIR, base['save'])
    os.environ['SAVE'] = save; cs = sim.load(); os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
    t = [t for t in base['rule_FA'] if t['decision']['type'] == 'start'][0]
    k = t['tier']; L = t['decision']['faster_levels']
    p = dict(F.route_for('mirrors20', dict(C2, age0=base['state']['run_age_s'])).policy(cs), ci=GAP)
    am = base['config']['age_multiple']
    H = sim.H(cs, k); hz = am * base['state']['run_age_s']
    Fl = sum(sim.prod_cost_at(cs, k, cs.prod[k] + i) for i in range(L))
    Nstar = H * Fl / (sim.TWO ** L * hz - H); need = Nstar + Fl
    for tag, f in (('line_just_above', 1.000001), ('line_just_below', 0.999999)):
        c2 = copy.deepcopy(cs)
        n = (need * f - c2.c[k]) / sim.TWO ** c2.twin[k]
        c2.c[k - 1] = bn.F(n * sim.UNITC[k]); c2.larva = bn.F(max(float(c2.larva), 10 * n)); c2.c[0] = bn.F(max(float(c2.c[0]), 10 * n * sim.MEATC[k]))
        cases.append(write_case(tag, '%s with the tier below set so that %s held after hatching all it can afford = %s x what %d faster level(s) need' % (
            name, sim.LABEL.get(sim.NAMES[k], sim.NAMES[k]), f, L), c2, p, am))
    print('cases written (%.0f s)' % (time.time() - T0), flush=True)
    roundtrip(cases)
    json.dump({'cases': [c['case'] for c in cases], 'generated_in_s': round(time.time() - T0)}, open(os.path.join(OUTDIR, 'index.json'), 'w'), indent=1)
    print('done (%.0f s), %d cases' % (time.time() - T0, len(cases)))

def roundtrip(cases):
    files = [os.path.join(OUTDIR, c['save']) for c in cases]
    game = json.loads(subprocess.run(['node', os.path.join(HERE, 'longrun_roundtrip.js')] + files, check=True, capture_output=True, text=True,
                                     env=dict(os.environ, TZ='UTC')).stdout)
    lines = ['| case | numbers | worst sim/game - 1 | where | run age game / case (s) |', '|---|---|---|---|---|']
    allw = 0.0
    for c in cases:
        os.environ['SAVE'] = os.path.join(OUTDIR, c['save']); s = sim.load()
        g = game[c['save']]; worst = [0.0, '']; n = [0]
        def cmp(nm, gv, sv):
            n[0] += 1; gv = bn.num(gv); sv = bn.big(sv)
            if gv == 0 and sv == 0: return
            r = abs(float(sv / gv) - 1) if gv != 0 else float('inf')
            if r > worst[0]: worst[0] = r; worst[1] = nm
        for k in range(1, sim.K + 1):
            t = g['tiers'][sim.NAMES[k]]; nm = sim.NAMES[k]
            cmp(nm + ' count', t['count'], s.c[k]); cmp(nm + ' meat cost', t['costMeat'], sim.MEATC[k])
            if k >= 2: cmp(nm + ' cost below', t['costBelow'], sim.UNITC[k])
            cmp(nm + ' twin', t['twin'], sim.TWO ** s.twin[k]); cmp(nm + ' prodEach', t['prodEach'], sim.P(s, k)); cmp(nm + ' faster price', t['prodPrice'], sim.prod_cost(s, k))
        cmp('larvae', g['larva'], s.larva); cmp('meat', g['meat'], s.c[0])
        allw = max(allw, worst[0])
        lines.append('| %s | %d | %.2g | %s | %.0f / %.0f |' % (c['case'], n[0], worst[0], worst[1], g['runAge'], c['state']['run_age_s']))
    os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
    txt = '\n'.join(lines) + '\n\nWorst over all cases: %.2g\n' % allw
    open(os.path.join(OUTDIR, 'roundtrip.md'), 'w').write('# Round trip: exported states loaded in the real game\n\nGenerated by faster_cases.py.\n\n' + txt)
    print(txt)

if __name__ == '__main__':
    main()
