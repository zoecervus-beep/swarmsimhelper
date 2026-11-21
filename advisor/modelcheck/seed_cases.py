"""Reference cases for rule SEED, the always-on replacement for the long-run climb mode (advisor/ASCENSION.md A.10 pass 5):
exported saves the real game loads, the rule evaluated on each tier above the frontier, and the simulator's own decisions
(lr_cut.py variant f=1e-2 with FA and the twin prefix). See seed_cases/README.md.

Usage (from the repo root; node on PATH, `npm install` in advisor/modelcheck):
    python3 -I advisor/modelcheck/seed_cases.py        # about 1 minute; writes advisor/modelcheck/seed_cases/
"""
import copy, json, math, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim')); sys.path.insert(0, HERE)
import sim, bignum as bn, export, faster_study as F, lr_cut as L, warp_route as W, longrun_cases as LC, faster_cases as FC

OUTDIR = os.path.join(HERE, 'seed_cases'); os.makedirs(OUTDIR, exist_ok=True)
D = bn.dec; GAP = 300.0; T0 = time.time()
SEED_F = 1e-2
VARIANT = dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': SEED_F})
COOLDOWN = 60

def seed_test(s, p, A, age_multiple=5):
    """Rule SEED on the state as the climb starts (pure). A = the larvae the climb may use (before the climb)."""
    age = sim.run_age(s, p); horizon = age_multiple * age
    passes = [k for k in range(1, sim.K + 1) if s.c[k] > 0 and (k < 2 or sim.H(s, k) <= horizon)]
    frontier = max(passes + [1])
    now = sim.tnow(s, p); left = A; meat = s.c[0]; c = list(s.c); lines = []
    for k in range(sim.K, frontier, -1):
        rec = {'tier': k, 'name': sim.NAMES[k], 'H_s': D(sim.H(s, k)), 'below_held': D(c[k - 1])}
        if c[k - 1] <= 0: rec['outcome'] = 'nothing below'; lines.append(rec); continue
        since = now - s.lastbuy[k]
        if since < COOLDOWN: rec.update(outcome='cooldown', since_s=since); lines.append(rec); continue
        if left < 1: rec['outcome'] = 'no larvae'; lines.append(rec); continue
        caps = {'share of the tier below': SEED_F * c[k - 1] / sim.UNITC[k], 'share of the larvae': SEED_F * A,
                'half the meat': meat * 0.5 / sim.MEATC[k], 'larvae left': left}
        b = min(caps, key=lambda x: caps[x]); n = caps[b]
        n = math.floor(n) if n < 2 ** 53 else n
        rec.update({'n': D(n), 'binding': b, 'caps': {x: D(v) for x, v in caps.items()}, 'outcome': 'hatch' if n >= 1 else 'under one'})
        lines.append(rec)
        if n >= 1:
            c[k - 1] = c[k - 1] - n * sim.UNITC[k]; meat = meat - n * sim.MEATC[k]; left = left - n
    return {'run_age_s': age, 'horizon_s': horizon, 'frontier': sim.NAMES[frontier], 'larvae_for_climb': D(A), 'lines': lines,
            'larvae_left_for_climb': D(left)}

def sim_decisions(cs, p):
    s = copy.deepcopy(cs); sim.TRACE = []
    LC.run_climb_and_push(s, dict(p, ci=GAP))
    ev = list(sim.TRACE); sim.TRACE = None
    seeds = [{'tier': e[1], 'name': sim.NAMES[e[1]], 'n': D(e[2]), 'f': e[3]} for e in ev if e[0] == 'seed']
    prefix = [{'tier': e[1], 'name': sim.NAMES[e[1]], 'n': D(e[2])} for e in ev if e[0] == 'twin_prefix']
    d = LC.events_to_decisions(ev)
    return {'seed': seeds, 'climb': d['climb'], 'twin_prefix': prefix}

def write_case(name, what, cs, p):
    save = export.export_save(cs, dict(p, game_age=False))
    save['skippedMillis'] = int(round(getattr(cs, 'gskip', 0.0) * 1000))
    json.dump(save, open(os.path.join(OUTDIR, name + '.save.json'), 'w'), indent=0)
    A = FC.larvae_for_climb(cs, p)
    case = {'case': name, 'exercises': what, 'save': name + '.save.json',
            'config': {'seed_share': SEED_F, 'cooldown_s': COOLDOWN, 'age_multiple': 5, 'meat_share': 0.5, 'gate': None, 'reserve': None},
            'rule_SEED': seed_test(cs, p, A), 'simulator': sim_decisions(cs, p)}
    json.dump(case, open(os.path.join(OUTDIR, name + '.json'), 'w'), indent=1, default=str)
    return case

def capture(start, days_list):
    """Play the variant from a start; keep the state as the climb starts at the first visit at or after each day."""
    s, age0 = F.load(start)
    route = F.route_for(start, dict(VARIANT, age0=age0)); sim.EMPOWER_MODEL = True
    p = dict(route.policy(s), ci=GAP); out = {}
    want = sorted(days_list)
    while want and s.time < want[-1] * 86400 + GAP:
        g = sim.advance(s, GAP)
        grab = want and s.time >= want[0] * 86400
        if grab: sim.TRACE = []; sim.CAPTURE = []
        sim.policy(s, p, g)
        if grab:
            if sim.CAPTURE: out[want[0]] = (sim.CAPTURE[0], dict(p))
            sim.TRACE = None; sim.CAPTURE = None; want.pop(0)
        if s.want_asc:
            sim.ascend(s, p, route.plan); p = dict(route.policy(s), ci=GAP)
    return out

def main():
    cases = []
    for start, what in (('run2', "the owner's run 2 at 45 h (mode was on; under rule SEED there is no mode)"),
                        ('run2b', "the owner's run 2 at 3.0 d (4.4e18 empresses, 1 neuroprophet)")):
        s, age0 = F.load(start); route = F.route_for(start, dict(VARIANT, age0=age0)); p = dict(route.policy(s), ci=GAP)
        sim.TRACE = []; sim.CAPTURE = []; sim.policy(s, p, 0.0); cs = sim.CAPTURE[0]; sim.TRACE = None; sim.CAPTURE = None
        cases.append(write_case(start + '_save', what, cs, p))
    for start, days, label in (('mirrors20', (0.5, 2.0, 3.5, 6.0, 20.0, 45.0), 'mirrors route from the 20.1 h save'),
                               ('warp', (2.0, 10.0, 30.0), 'swarmwarp route from the 20.1 h save')):
        got = capture(start, list(days))
        for d, (cs, p) in sorted(got.items()):
            st = W.mirror_stage(cs) if start != 'warp' else W.stage(cs, W.CFG)
            cases.append(write_case('%s_day%g' % (start, d), '%s, day %g (stage %s, ascensions %d)' % (label, d, st, cs.asc), cs, p))
    # edited: a seed line in its cooldown, and the share of the larvae binding instead of the share of the tier below
    base = [c for c in cases if any(l['outcome'] == 'hatch' for l in c['rule_SEED']['lines'])][0]
    os.environ['SAVE'] = os.path.join(OUTDIR, base['save']); cs = sim.load(); os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
    p = dict(F.route_for('mirrors20', dict(VARIANT, age0=base['rule_SEED']['run_age_s'])).policy(cs), ci=GAP)
    k = [l for l in base['rule_SEED']['lines'] if l['outcome'] == 'hatch'][0]['tier']
    c1 = copy.deepcopy(cs); c1.lastbuy[k] = sim.tnow(c1, p) - 30
    cases.append(write_case('cooldown', '%s with %s hatched 30 s ago (game clock): no seed line for it' % (base['case'], sim.NAMES[k]), c1, p))
    c2 = copy.deepcopy(cs); c2.larva = bn.F(10.0)
    cases.append(write_case('few_larvae', '%s with 10 larvae: the share of the larvae gives under one hatch' % base['case'], c2, p))
    print('cases written (%.0f s)' % (time.time() - T0), flush=True)
    FC.OUTDIR = OUTDIR
    FC.roundtrip(cases_for_roundtrip(cases))
    json.dump({'cases': [c['case'] for c in cases], 'generated_in_s': round(time.time() - T0)}, open(os.path.join(OUTDIR, 'index.json'), 'w'), indent=1)
    print('done (%.0f s), %d cases' % (time.time() - T0, len(cases)))

def cases_for_roundtrip(cases):
    return [dict(c, state={'run_age_s': c['rule_SEED']['run_age_s']}) for c in cases]

if __name__ == '__main__':
    main()
