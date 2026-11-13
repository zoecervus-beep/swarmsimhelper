"""Reference cases for the advisor's long-run mode (ASCENSION.md A.10): simulator states exported as saves the
real game loads, with the simulator's decisions at that instant. See longrun_cases/README.md.

What it does:
  1. Plays the long run from the first ascension (cached start, see advisor/sim/longrun_rules.py) under the
     specified rules (SPEC + a 60 s push cooldown) at one visit per 5 minutes, recording at every visit which
     situations the rules met (a faster-level pass with L = 1 or L > 1 or a fail, each push cap binding, the twin
     guard, frontier heights, the gate and lepidoptera boundaries, chosen days).
  2. Replays the run and, at the first visit of each situation, captures the state the climb and push rules
     see (after energy, upgrades, twins and territory), exports it as a save and records the decisions.
  3. Adds edited cases (twin guard either side of the 1e6x line, push cooldown) and two states where the mode
     must change nothing (the 20.1 h save, an early fresh run).
  4. Loads every exported save in the real game (longrun_roundtrip.js) and compares what the rules read.

Usage (from the repo root; node on PATH):
    python3 -I advisor/modelcheck/longrun_cases.py        # about 4 minutes; writes advisor/modelcheck/longrun_cases/
"""
import copy, json, math, os, pickle, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim'))
os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
import sim, bignum as bn, export, longrun_rules as LR

OUTDIR = os.path.join(HERE, 'longrun_cases'); os.makedirs(OUTDIR, exist_ok=True)
CONFIG = dict(LR.SPEC, push=dict(LR.SPEC['push'], cooldown=60))   # the spec as written: 60 s push cooldown
GAP = 300.0
D = bn.dec
T0 = time.time()

def clear_logs(s):
    for a in ('upg_log', 'premut_log', 'ach_log', 'fa_log', 'emp_log', 'asc_log'):
        if hasattr(s, a): setattr(s, a, [])
    if not hasattr(s, 'emp'): s.emp = [0] * 11

def start():
    s = copy.deepcopy(LR.start_state()); clear_logs(s); return s

def categories(ev, s, p):
    """Situations met at one visit, from its trace."""
    out = set()
    age = sim.run_age(s, p) / 86400
    for e in ev:
        if e[0] == 'fa':
            L = e[3]
            if e[2] > 0 and age > 2.05: out.add('fa_L1' if L == 1 else 'fa_Lmulti' if L and L > 1 else 'fa_fails')   # after the gate case
        if e[0] == 'push' and e[2] == 'hatch': out.add('push_binds_' + e[8])
        if e[0] == 'push' and e[2] == 'under one': out.add('push_under_one')
        if e[0] == 'twin' and e[2] == 'guard': out.add('twin_guard')
        if e[0] == 'frontier':
            f = e[1]
            if f == 7: out.add('frontier_empress')
            if f in (10, 11, 12): out.add('frontier_pantheon')
            if f in (15, 16, 17): out.add('frontier_overmind')
    if s.c[19] > 0 and not s.c[20] > 0: out.add('cortex_owned_no_endless')
    if s.c[20] > 0: out.add('endless_owned')
    for lo, name in ((1.95, 'gate_before'), (2.0, 'gate_after'), (2.95, 'moth_before'), (3.0, 'moth_after')):
        if lo <= age < lo + 0.05: out.add(name)
    for d in (5, 10, 20, 30, 40, 52):
        if d <= age < d + 0.01: out.add('day_%d' % d)
    return out

def survey(days):
    """Pass 1: the first visit (by run age) at which each situation occurs."""
    s = start(); p = dict(CONFIG, ci=GAP); first = {}
    sim.TRACE = []
    while sim.run_age(s, p) < days * 86400:
        gained = sim.advance(s, GAP)
        sim.TRACE.clear()
        policy_with(s, p, gained)
        for c in categories(sim.TRACE, s, p) - set(first):
            first[c] = s.time
    sim.TRACE = None
    return first

def policy_with(s, p, gained):
    sim.policy(s, p, gained)

def capture_at(times):
    """Pass 2: replay; at the given visit times keep (state as the climb starts, trace, gained)."""
    s = start(); p = dict(CONFIG, ci=GAP); want = sorted(set(times)); got = {}
    end = max(want)
    while s.time <= end + 1:
        gained = sim.advance(s, GAP)
        if any(abs(s.time - w) < 1e-6 for w in want):
            sim.TRACE = []; sim.CAPTURE = []
            sim.policy(s, p, gained)
            got[s.time] = (sim.CAPTURE[0] if sim.CAPTURE else None, list(sim.TRACE), gained)
            sim.TRACE = None; sim.CAPTURE = None
        else:
            sim.policy(s, p, gained)
    return got

def decide(cs, p):
    """The decisions the rules make on the captured state cs (the state as the climb starts): rerun the rest of
    the policy (climb and push) on a copy with tracing, plus the pure quantities the port needs."""
    s = copy.deepcopy(cs)
    # rerun from the climb: the captured state already had energy, upgrades, twins and territory applied, so the
    # only thing left of the visit is the climb and the push. Do it with the same code path:
    sim.TRACE = []
    q = dict(p); q['ci'] = GAP
    run_climb_and_push(s, q)
    ev = list(sim.TRACE); sim.TRACE = None
    return ev

def run_climb_and_push(s, p):
    """The part of sim.policy after territory: the climb loop and the push (with the gate applied)."""
    if p.get('lr_age') and sim.run_age(s, p) < p['lr_age']:
        p = dict(p, faster_aware=None, push=None)
    if p.get('theta_age'): p['theta'] = p['theta_age'] * sim.run_age(s, p)
    f = p['f']
    avail = (s.larva - s.purse if f > 0 else s.larva) - s.reserve - s.nexres
    top = max([k for k in range(1, sim.K + 1) if s.c[k] > 0] or [1])
    sim.tr('before_climb', avail, top)
    sim._climb_and_push(s, p, avail, top, f)      # the end of sim.policy, the same code

def pure(cs, p):
    """Quantities computed directly on the captured state, for the rules the port checks exactly."""
    s = cs; q = dict(p); q['ci'] = GAP
    age = sim.run_age(s, q)
    active = not (q.get('lr_age') and age < q['lr_age'])
    q['theta'] = q['theta_age'] * age
    out = {'run_age_s': age, 'gate_active': active, 'horizon_s': q['theta']}
    if not active:
        q = dict(q, faster_aware=None, push=None)
    fr = sim.push_frontier(s, q) if q.get('push') else None
    out['frontier'] = fr
    tiers = []
    for k in range(1, sim.K + 1):
        since = s.time - s.lastbuy[k]
        t = {'tier': k, 'name': sim.NAMES[k], 'count': D(s.c[k]), 'prod_level': s.prod[k], 'twin_level': s.twin[k] if k < sim.K else None,
             'H_s': D(sim.H(s, k)), 'passes_plain': bool(sim.allowed(s, q, k)),
             'since_last_hatch_s': since if since < 1e15 else None}
        if k < sim.K and q.get('push'):
            cost = sim.twin_cost(s, k)
            guarded = (k + 1 > fr) and (s.c[k + 1] < q['push'].get('twin_mult', 1) * cost)
            t['twin_guard'] = {'pay_tier': sim.NAMES[k + 1], 'price': D(cost), 'pay_held': D(s.c[k + 1]),
                               'pushed_pay_tier': bool(k + 1 > fr), 'suppressed': bool(guarded)}
        if q.get('faster_aware') == 'multi' and not t['passes_plain'] and k >= 2:
            # smallest number of units held after the purchase ("got") for which L faster levels pass
            h = sim.H(s, k); th = q['theta']; Fl = 0.0; mins = []
            for L in range(1, 9):
                Fl = Fl + sim.prod_cost_at(s, k, s.prod[k] + L - 1)
                den = sim.TWO ** L * th - h
                mins.append({'L': L, 'faster_price_total': D(Fl), 'got_min': D(Fl + h * Fl / den) if den > 0 else None})
            t['faster_levels_pass_if_got_at_least'] = mins
        tiers.append(t)
    out['tiers'] = tiers
    out['top_owned'] = max([k for k in range(1, sim.K + 1) if s.c[k] > 0] or [1])
    out['larvae_held_back'] = {'territory_purse': D(s.purse), 'nexus_saving': D(s.nexres), 'clone_reserve': D(s.reserve)}
    out['moth_target'] = (q['moth_late'][1] if q.get('moth_late') and age >= q['moth_late'][0] else q.get('moth_N', 0))
    return out

def events_to_decisions(ev):
    d = {'climb': [], 'faster_after_climb': [], 'push': [], 'larvae_for_push': None, 'frontier_at_push': None, 'larvae_before_climb': None}
    fa = {}
    for e in ev:
        if e[0] == 'before_climb': d['larvae_before_climb'] = D(e[1])
        if e[0] == 'fa': fa[e[1]] = {'n': D(e[2]), 'L': e[3]}
        if e[0] == 'climb':
            rec = {'tier': e[1], 'name': sim.NAMES[e[1]], 'outcome': e[2]}
            if e[2] in ('buys', 'passes_none', 'fa_fails'): rec['n_sim'] = D(e[3])
            if e[2] in ('buys', 'passes_none'): rec['test'] = 'faster-level' if e[4] else 'plain'
            if e[1] in fa: rec['faster_level_L'] = fa[e[1]]['L']
            d['climb'].append(rec)
        if e[0] == 'fa_faster': d['faster_after_climb'].append({'tier': e[1], 'name': sim.NAMES[e[1]], 'level_now': e[2]})
        if e[0] == 'frontier': d['frontier_at_push'] = e[1]; d['larvae_for_push'] = D(e[2])
        if e[0] == 'push':
            rec = {'tier': e[1], 'name': sim.NAMES[e[1]], 'outcome': e[2]}
            if e[2] in ('hatch', 'under one'):
                rec.update({'n': D(e[3]), 'share': e[4], 'below_held': D(e[5]), 'larvae_left': D(e[6]), 'meat': D(e[7]), 'binding': e[8]})
            d['push'].append(rec)
    return d

def write_case(name, what, cs, p, extra=None):
    save = export.export_save(cs, p)
    sp = os.path.join(OUTDIR, name + '.save.json'); json.dump(save, open(sp, 'w'), indent=0)
    ev = decide(cs, p)
    case = {'case': name, 'exercises': what, 'save': os.path.basename(sp),
            'config': {k: CONFIG_OUT.get(k) for k in CONFIG_OUT}, 'state': pure(cs, p), 'decisions': events_to_decisions(ev)}
    case['state']['larvae'] = D(cs.larva); case['state']['larva_rate'] = D(sim.lam(cs)); case['state']['meat'] = D(cs.c[0])
    case['state']['achievement_points'] = cs.achpts
    if extra: case.update(extra)
    json.dump(case, open(os.path.join(OUTDIR, name + '.json'), 'w'), indent=1)
    return case

CONFIG_OUT = {'age_multiple': CONFIG['theta_age'], 'territory_share': CONFIG['f'], 'bank': CONFIG['bank'], 'share': CONFIG['share'],
              'gate_run_age_s': CONFIG['lr_age'], 'push_share': CONFIG['push']['share'], 'push_frontier_share': CONFIG['push']['base'],
              'push_twin_guard_multiple': CONFIG['push']['twin_mult'], 'push_cooldown_s': CONFIG['push']['cooldown'],
              'moth_target': CONFIG['moth_N'], 'moth_target_late': list(CONFIG['moth_late']), 'meat_share_for_push': 0.5}

WHAT = {
    'gate_before': 'run age just under 2 days: the mode must change nothing (no faster-level passes, no push lines)',
    'gate_after': 'run age just over 2 days: the mode acts',
    'moth_before': 'run age just under 3 days: lepidoptera target 4,000',
    'moth_after': 'run age just over 3 days: lepidoptera target 30,000',
    'fa_L1': 'a tier that passes only through the faster-level rule, with L = 1',
    'fa_Lmulti': 'a tier that passes only through the faster-level rule, with L > 1',
    'fa_fails': 'a tier that fails the plain test and the faster-level test (with the purchase it would make)',
    'push_binds_share': 'push lines limited by the share of the tier below (larvae and meat plentiful)',
    'push_binds_larvae': 'a push line limited by the larvae left after climbing and territory',
    'push_binds_meat': 'a push line limited by half the meat',
    'push_under_one': 'a push line that rounds down to zero (below one hatch)',
    'twin_guard': 'a twin paid in a pushed tier, suppressed by the 1e6x guard',
    'frontier_empress': 'frontier at hive empress (tier 7)',
    'frontier_pantheon': 'frontier in the neural cluster tiers (10-12)',
    'frontier_overmind': 'frontier at overmind / ascended / cosmic network (15-17)',
    'cortex_owned_no_endless': 'universal cortex owned, endless empty: push feeds endless from cortex',
    'endless_owned': 'endless already owned',
}
for d_ in (5, 10, 20, 30, 40, 52): WHAT['day_%d' % d_] = 'the long run on day %d (a typical state)' % d_

def main():
    days = 53
    first = survey(days)
    print('survey done (%.0f s): %s' % (time.time() - T0, sorted(first)), flush=True)
    got = capture_at(list(first.values()))
    print('capture done (%.0f s)' % (time.time() - T0), flush=True)
    p = dict(CONFIG)
    cases = []
    for name, t in sorted(first.items(), key=lambda x: x[1]):
        cs, ev, gained = got[t]
        if cs is None: continue
        cases.append(write_case(name, WHAT.get(name, name), cs, p))
    # edited cases from the day-20 state: twin guard either side of the line, push cooldown
    base = got[first['day_20']][0]
    fr = sim.push_frontier(base, dict(p, theta=p['theta_age'] * sim.run_age(base, p)))
    k = fr + 1                                   # twin of tier k, paid in tier k+1 (a pushed tier)
    for tag, f in (('twin_guard_just_above', 1.000001), ('twin_guard_just_below', 0.999999)):
        cs = copy.deepcopy(base); cost = sim.twin_cost(cs, k)
        cs.c[k + 1] = cost * p['push']['twin_mult'] * f
        cases.append(write_case(tag, 'pay tier %s held at %s x 1e6 x the twin price of %s: the guard %s it' % (
            sim.NAMES[k + 1], f, sim.NAMES[k], 'allows' if f > 1 else 'suppresses'), cs, p))
    # push cooldown and push limited by meat, from the state where push lines were limited by the share
    ps, pev, _ = got[first['push_binds_share']]
    lines = [e for e in pev if e[0] == 'push' and e[2] == 'hatch']
    kc = lines[0][1]
    cs = copy.deepcopy(ps); cs.lastbuy[kc] = cs.time - 30
    cases.append(write_case('push_cooldown', '%s hatched 30 s ago: inside the 60 s push cooldown, no push line for it (others unchanged)' % sim.NAMES[kc], cs, p))
    # meat: lower the state's meat until the push line for that unit hatches but is limited by half the meat
    e = lines[0]; target = min(e[4] * e[5] / sim.UNITC[kc], e[6])
    for frac in (16, 8, 4, 2, 1, 0.5):
        cs = copy.deepcopy(ps); cs.c[0] = bn.F(frac * target * sim.MEATC[kc])   # the climb below spends some of it first
        ev = decide(cs, p)
        hit = [x for x in ev if x[0] == 'push' and x[1] == kc and x[2] == 'hatch' and x[8] == 'meat']
        if hit: break
    cases.append(write_case('push_binds_meat', 'meat set to %g x (what share and larvae allow) x the meat price of %s, so the push line hatches but half the meat binds' % (frac, sim.NAMES[kc]), cs, p))
    # no-change states: the 20.1 h save as loaded, and a fresh run (after an ascension, no mutagen) at 12 h
    s = sim.load(); clear_logs(s)
    sim.TRACE = []; sim.CAPTURE = []; sim.policy(s, dict(CONFIG, ci=GAP), 0); cs = sim.CAPTURE[0]; sim.TRACE = None; sim.CAPTURE = None
    cases.append(write_case('save_20h', "the owner's 20.1 h save (run age 0.84 d): the mode must change nothing", cs, p))
    s = start(); s.mutagen = bn.F(0.0); s.mut = {m: bn.F(0.0) for m in sim.MUTANTS}; s.unlocked = []; s.unlocks = 0; sim.refresh_mut(s)
    q = dict(CONFIG, ci=GAP)
    while sim.run_age(s, q) < 12 * 3600:
        g = sim.advance(s, GAP); sim.policy(s, q, g)
    g = sim.advance(s, GAP); sim.TRACE = []; sim.CAPTURE = []; sim.policy(s, q, g); cs = sim.CAPTURE[0]; sim.TRACE = None; sim.CAPTURE = None
    cases.append(write_case('fresh_run_12h', 'a fresh run (no mutagen) at run age 12 h: the mode must change nothing', cs, p))
    print('cases written (%.0f s)' % (time.time() - T0), flush=True)
    roundtrip(cases)
    json.dump({'cases': [c['case'] for c in cases], 'generated_in_s': round(time.time() - T0)}, open(os.path.join(OUTDIR, 'index.json'), 'w'), indent=1)
    print('done (%.0f s)' % (time.time() - T0))

def roundtrip(cases):
    """Load every exported save in the real game and compare what the rules read with the simulator."""
    files = [os.path.join(OUTDIR, c['save']) for c in cases]
    game = json.loads(subprocess.run(['node', os.path.join(HERE, 'longrun_roundtrip.js')] + files, check=True,
                                     capture_output=True, text=True, env=dict(os.environ, TZ='UTC')).stdout)
    lines = ['| case | numbers | worst sim/game - 1 | where | run age game / sim (s) | achievement points game / sim |', '|---|---|---|---|---|---|']
    allworst = 0.0
    for c in cases:
        os.environ['SAVE'] = os.path.join(OUTDIR, c['save'])
        s = sim.load()
        g = game[c['save']]; worst = [0.0, '']; n = 0
        def cmp(name, gv, sv):
            nonlocal n
            n += 1
            gv = bn.num(gv); sv = bn.big(sv)
            if gv == 0 and sv == 0: return
            r = abs(float(sv / gv) - 1) if gv != 0 else float('inf')
            if r > worst[0]: worst[0] = r; worst[1] = name
        for k in range(1, sim.K + 1):
            t = g['tiers'][sim.NAMES[k]]; nm = sim.NAMES[k]
            cmp(nm + ' count', t['count'], s.c[k]); cmp(nm + ' meat cost', t['costMeat'], sim.MEATC[k])
            if k >= 2: cmp(nm + ' cost below', t['costBelow'], sim.UNITC[k])
            cmp(nm + ' twin', t['twin'], sim.TWO ** s.twin[k]); cmp(nm + ' prodEach', t['prodEach'], sim.P(s, k))
            cmp(nm + ' faster price', t['prodPrice'], sim.prod_cost(s, k))
            if t['twinPrice'] is not None: cmp(nm + ' twin price', t['twinPrice'], sim.twin_cost(s, k))
            cmp(nm + ' bought', t['bought'], s.bought.get(nm, 0.0))
        cmp('larvae', g['larva'], s.larva); cmp('larvae/s', g['larvaRate'], sim.lam(s)); cmp('meat', g['meat'], s.c[0])
        cmp('energy', g['energy'], s.energy); cmp('energy/s', g['energyRate'], sim.erate(s)); cmp('lepidoptera', g['moth'], s.moth)
        cmp('territory', g['territory'], s.terr)
        sim_age = c['state']['run_age_s']
        allworst = max(allworst, worst[0])
        lines.append('| %s | %d | %.2g | %s | %.0f / %.0f | %d / %d |' % (c['case'], n, worst[0], worst[1], g['runAge'], sim_age, g['points'], c['state']['achievement_points']))
    os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
    txt = '\n'.join(lines) + '\n\nWorst over all cases: %.2g\n' % allworst
    open(os.path.join(OUTDIR, 'roundtrip.md'), 'w').write('# Round trip: exported simulator states loaded in the real game\n\nGenerated by longrun_cases.py.\n\n' + txt)
    print(txt)

if __name__ == '__main__':
    main()
