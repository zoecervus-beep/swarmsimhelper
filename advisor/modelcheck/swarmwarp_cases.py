"""Reference cases for the swarmwarp route in the advisor (advisor/NO-MIRRORS.md, "Rules for the advisor"): simulator
states exported as saves the real game loads, with the route's rules evaluated on them (advisor/sim/warp_route.py)
and the simulator's energy decisions at that instant. See swarmwarp_cases/README.md.

What it does:
  1. Plays the swarmwarp route as specified (warp_route.CFG, one visit per 5 minutes) from the 20.1 h save and, at
     the first visit of each situation (by phase of the route), keeps the state as the visit starts; at every
     ascension it keeps the state just after the reset, before any mutagen is spent.
  2. Plays the mirrors route (the advisor today) to the long run and keeps states for the route switches.
  3. Adds edited states either side of every boundary in the rules.
  4. Writes <case>.save.json (export.py) and <case>.json, then loads every save in the real game
     (swarmwarp_roundtrip.js) and compares what the rules read (roundtrip.md).

Usage (from the repo root; node on PATH, `npm install` in advisor/modelcheck):
    python3 -I advisor/modelcheck/swarmwarp_cases.py       # about 3 minutes; writes advisor/modelcheck/swarmwarp_cases/
"""
import copy, json, math, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim')); sys.path.insert(0, HERE)   # longrun_cases (record format)
os.environ['SAVE'] = os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')
import sim, bignum as bn, export, warp_route as W

OUTDIR = os.path.join(HERE, 'swarmwarp_cases'); os.makedirs(OUTDIR, exist_ok=True)
CFG = dict(W.CFG)
GAP = 300.0
D = bn.dec
lg = W.lg
T0 = time.time()
sim.EMPOWER_MODEL = True

# ------------------------------------------------------------------------------------------- what the rules read
def state_fields(s, p, cfg=CFG):
    st = W.stage(s, cfg)
    ok, inputs = W.ascension_test(s, p, cfg)
    halving = 50000.0 * s.acm
    threshold = math.floor(halving / math.log(2))
    cap = sim.ecap(s)
    q = sim.epow(s) * s.spw['warp']
    out = {'run_age_s': sim.run_age(s, p), 'ascensions': s.asc, 'nexus': s.nexus, 'energy': D(s.energy), 'energy_rate': D(sim.erate(s)),
           'cap': D(cap), 'moths': D(s.moth), 'bats': D(s.bat), 'nightbugs': D(s.nightbug),
           'ascension_cost': s.asc and sim.asc_cost(s) or sim.asc_cost(s), 'energy_spent': D(sim.espent(s)),
           'halving': D(halving), 'threshold': threshold, 'save_at': D(min(cap, threshold)),
           'mutagen_held': D(s.mutagen), 'premutagen': D(s.premut), 'unlocks': sorted(s.unlocked), 'unlock_count': s.unlocks,
           'next_unlock_price': D(sim.UNLOCK_FACTOR ** s.unlocks),
           'mutants': {m: D(v) for m, v in s.mut.items() if v > 0},
           'swarmwarp_power': D(q), 'swarmwarp_skip_s': D(900 * q), 'expansions': s.exp,
           'mirror_casts_this_run': s.casts.get('mirror', 0), 'swarmwarp_casts_this_run': s.casts.get('warp', 0),
           'earned': {g: W.earned(s, g) for g in W.LONG_GOALS},
           'stage': st, 'test': {'kind': cfg['test'][0], 'passes': ok, **{k: (D(v) if not isinstance(v, (int, str)) else v) for k, v in inputs.items()}},
           'wants_ascension': W.wants_ascension(s, p, cfg),
           'larvae': D(s.larva), 'larva_rate': D(sim.lam(s)), 'meat': D(s.c[0]), 'achievement_points': s.achpts}
    out['ascension_cost'] = D(sim.asc_cost(s))
    # the clocks (NO-MIRRORS.md, "Game time"): game clock = wall clock + time skipped by swarmwarp
    wall_age = sim.run_age(s, dict(p, game_age=False)); skipped = getattr(s, 'gskip_run', 0.0)
    game_age = wall_age + skipped
    est = wall_age + s.casts.get('warp', 0) * 900 * q
    out['clock'] = {'run_age_wall_s': wall_age, 'skipped_this_run_s': skipped, 'skipped_total_s': getattr(s, 'gskip', 0.0),
                    'run_age_game_s': game_age, 'run_age_game_estimate_s': est,
                    'horizon_s': p['theta_age'] * game_age, 'long_run_gate_active': game_age >= p['lr_age']}
    out['run_age_s'] = game_age
    return out

def warp_sequence(cs, p, gained, n_max=5):
    """Several swarmwarps affordable: cast one, then the purchases the advisor would suggest with every timer on the game
    clock (the rest of the visit, sim.policy with energy off), then the next. Per warp: the skip, and what was bought."""
    import longrun_cases as LC
    s = copy.deepcopy(cs); out = []
    q = sim.epow(s) * s.spw['warp']
    pp = dict(p, energy=False, ci=GAP)
    while s.energy >= 2000 and len(out) < n_max:
        b = dict(exp=s.exp, hatch=s.hatch, emp=list(s.emp), t=list(s.t), prod=list(s.prod), twin=list(s.twin), tt=list(s.tt), anc=s.ach)
        now0 = sim.tnow(s, p)
        climbers = {}
        s.energy -= 2000; s.casts['warp'] = s.casts.get('warp', 0) + 1
        L = sim.advance(s, 900 * q, True)
        now = sim.tnow(s, p)
        for k in range(2, sim.K + 1):        # rule-3 inputs for the tiers held, as the climb will see them
            if s.c[k - 1] > 0:
                last = s.lastbuy[k]; since = now - last if last > -1e17 else None
                payback = sim.UNITC[k] / (sim.TWO ** s.twin[k] * sim.P(s, k))
                climbers[sim.NAMES[k]] = {'since_last_hatch_game_s': since, 'cooldown_released': since is None or since >= 60,
                                          'share_released': None if since is None else 1 - 0.5 ** min(since / 60.0, 1e6),
                                          'stock_release': None if since is None else float(min(1.0, since / payback))}
        sim.TRACE = []
        sim.policy(s, pp, L)
        ev = list(sim.TRACE); sim.TRACE = None
        dec = LC.events_to_decisions(ev)
        out.append({'skip_s': D(900 * q), 'game_clock_before_s': now0, 'game_clock_after_s': now, 'larvae_from_warp': D(L),
                    'bought': {'expansions': s.exp - b['exp'], 'hatcheries': s.hatch - b['hatch'],
                               'accomplished_ancestry': s.ach - b['anc'],
                               'empowers': {sim.TN[j]: s.emp[j] - b['emp'][j] for j in range(11) if s.emp[j] != b['emp'][j]},
                               'faster_levels': {sim.NAMES[k]: s.prod[k] - b['prod'][k] for k in range(1, sim.K + 1) if s.prod[k] != b['prod'][k]},
                               'twin_levels': {sim.NAMES[k]: s.twin[k] - b['twin'][k] for k in range(1, sim.K + 1) if s.twin[k] != b['twin'][k]},
                               'territory_twins': {sim.TN[j]: s.tt[j] - b['tt'][j] for j in range(11) if s.tt[j] != b['tt'][j]}},
                    'climb': dec['climb'], 'push': dec['push'], 'tiers_before_climb': climbers})
    return out

def energy_decision(cs, p, gained):
    """The simulator's energy part of the visit on a copy of the state: what it bought and cast."""
    s = copy.deepcopy(cs)
    b = dict(nexus=s.nexus, moth=s.moth, bat=s.bat, casts=dict(s.casts), energy=s.energy)
    sim.energy_policy(s, p, gained)
    casts = {k: v - b['casts'].get(k, 0) for k, v in s.casts.items() if v - b['casts'].get(k, 0) > 0}
    acts = []
    if s.nexus > b['nexus']: acts.append({'type': 'buyNexus', 'to': s.nexus})
    if s.moth > b['moth']: acts.append({'type': 'buyMoths', 'count': D(s.moth - b['moth'])})
    if s.bat > b['bat']: acts.append({'type': 'buyBats', 'count': D(s.bat - b['bat'])})
    for k, v in casts.items(): acts.append({'type': 'cast', 'spell': sim.SPELL_UP[k], 'casts': v})
    return {'actions': acts, 'saving_for_ascension': bool(s.saving_asc), 'ascend_now': bool(s.want_asc), 'energy_after': D(s.energy)}

def territory_decision(s, share=0.1, meat_share=0.9):
    """advisorterritory.coffee's empower test with a fresh memory (cap = the territory share of the larvae on hand,
    meat budget = 0.9 x meat), on the simulator's units; and whether this route keeps hatching territory units."""
    L = math.floor(s.larva) if s.larva < 2 ** 53 else s.larva
    cap = (L - math.floor(s.larva * (1 - share))) if s.larva < 2 ** 53 else s.larva * share
    Mb = meat_share * s.c[0]
    tc = sim.tcosts(s); order = sorted(range(11), key=lambda j: tc[j]); low = order[0]; top = order[-1]
    price = sim.empower_price(s, low)
    fits = not (price + tc[top] * max(cap, 1) > Mb)
    inc = sim.trate(s); wiped = s.t[low] * sim.TP[low] * s.tm[low] * sim.EMP_PROD ** s.emp[low]
    share_w = float(wiped / inc) if inc > 0 else 0.0
    return {'cheapest_rung': sim.TN[low], 'top_rung': sim.TN[top], 'empower_price': D(price), 'top_meat_each': D(tc[top]),
            'territory_larvae_cap': D(cap), 'meat_budget': D(Mb), 'wiped_share': share_w,
            'empower_advised': bool(fits and share_w < 0.01), 'keeps_hatching_territory': True}

def mutagen_decision(s):
    enc = lambda st: {'type': st[0], 'name': st[1], ('price' if st[0] == 'unlock' else 'count'): D(st[2])}
    respec = W.respec_advised(s, CFG)
    s1 = copy.deepcopy(s)
    if respec: W.do_respec(s1)
    steps = W.mutagen_steps(s1, CFG)
    s2 = copy.deepcopy(s); W.apply_mutagen(s2, CFG); again = W.mutagen_steps(s2, CFG)
    return {'respec_first': respec, 'respec_refund': D(W.respec_refund(s)), 'free_respecs': s.freerespec,
            'steps': [enc(x) for x in steps], 'held_after': D(s2.mutagen), 'again': [enc(x) for x in again],
            'respec_again': W.respec_advised(s2, CFG)}

# ------------------------------------------------------------------------------------------- the route, surveyed
def phase(s):
    if s.asc == 0: return 'first'
    st = W.stage(s, CFG)
    if st != 'build': return st
    m = lg(s.mutagen)
    return 'trough' if m < 32 else 'late'

def situation(s, p):
    if s.nexus < 4: return None
    if s.nexus == 4: return 'nexus4'
    mt = p.get('moth_N5', p.get('moth_N'))
    if s.moth < mt: return 'moths'
    if s.bat < p['bat_N']: return 'bats'
    if W.stage(s, CFG) in ('final', 'quick', 'done'): return 'warp'
    ok, _ = W.ascension_test(s, p, CFG)
    if not ok: return 'warp_test_fails'
    c = sim.asc_cost(s); save_at = min(sim.ecap(s), math.floor(50000.0 * s.acm / math.log(2)))
    if s.energy >= c: return 'ascend_now'
    if c > save_at: return 'warp_test_passes_spend'
    return 'save_for_ascension'

def play_route():
    p = dict(W.policy(CFG), ci=GAP); s = W.start_save(); caps = {}; ascs = []
    def plan(st):
        ascs.append(copy.deepcopy(st)); return W.apply_mutagen(st, CFG)
    final_seen = None
    while not W.all_done(s) and s.time < 400 * 86400:
        gained = sim.advance(s, GAP)
        ph = phase(s); si = situation(s, p)
        if si:
            key = ph + '_' + si
            if key not in caps: caps[key] = (copy.deepcopy(s), gained)
        if ph == 'final':
            if final_seen is None: final_seen = s.time
            if s.time - final_seen >= 2 * 86400 and 'final_day2' not in caps: caps['final_day2'] = (copy.deepcopy(s), gained)
        sim.policy(s, p, gained)
        if s.want_asc:
            sim.ascend(s, p, plan); sim.policy(s, p, 0)
    print('route played (%.0f s): %d situations, %d ascensions, all done %s day %.1f' % (time.time() - T0, len(caps), len(ascs), W.all_done(s), s.time / 86400), flush=True)
    return p, caps, ascs, s

def mirrors_states():
    """The mirrors route (the advisor today) from the save: the state just after its first ascension's reset (before its
    mutagen purchases), right after them, and its long run on days 10 and 30."""
    out = {}
    p1 = dict(W.mirror_policy(W.start_save()), ci=GAP)
    s = W.start_save()
    pre = []
    def plan(st):
        pre.append(copy.deepcopy(st)); return W.mirror_mutagen(st)
    while s.asc == 0:
        g = sim.advance(s, GAP); sim.policy(s, p1, g)
        if s.want_asc: sim.ascend(s, p1, plan)
    out['after_first_ascension_before_purchases'] = (pre[0], 0.0)
    out['after_first_ascension_mirrors_purchases'] = (copy.deepcopy(s), 0.0)
    p2 = dict(W.mirror_policy(s), ci=GAP)
    for day in (10, 30):
        while sim.run_age(s, p2) < day * 86400:
            g = sim.advance(s, GAP); sim.policy(s, p2, g)
        out['long_day%d' % day] = (copy.deepcopy(s), g)
    print('mirrors route states (%.0f s)' % (time.time() - T0), flush=True)
    return out

# ------------------------------------------------------------------------------------------- writing
CONFIG_OUT = {'route': 'swarmwarp (advisor/NO-MIRRORS.md, Rules for the advisor)', 'ascension_test': list(CFG['test']),
              'final_log10_mutagen_held': CFG['final'], 'free_unlocks': CFG['free_unlocks'], 'unlock_share': CFG['unlock_share'],
              'unlock_order': W.UNLOCK_ORDER, 'fixed_mutants': W.FIXED, 'mutant_shares': dict(W.SHARES),
              'guard': CFG['guard'], 'free_respec_when_warp_unaffordable': CFG['respec'],
              'clock': {'timers': CFG['clock'], 'run_age': CFG['age'], 'one_warp_at_a_time': CFG['visits']},
              'age_multiple': 5, 'long_run_gate_s': 172800, 'cooldown_s': 60, 'share_per_minute': 0.5,
              'moths_after_nexus5': CFG.get('moths', 4000), 'early_moths_at_nexus4': 1000, 'bats': CFG.get('bats', 2000),
              'territory_share': 0.1, 'long_run_climb_mode': 'on', 'spell': 'swarmwarp', 'ascensions_goal': W.ASC_GOAL}

def write_case(name, what, cs, p, gained=0.0, at_ascension=False, extra=None):
    save = export.export_save(cs, dict(p, game_age=False))          # the save's run clock is the wall clock
    save['skippedMillis'] = int(round(getattr(cs, 'gskip', 0.0) * 1000))   # cumulative over the save, as the game keeps it
    sp = os.path.join(OUTDIR, name + '.save.json'); json.dump(save, open(sp, 'w'), indent=0)
    pe = dict(p, warp_visits=False)      # the energy decision alone: what is affordable and cast (casts between purchases: warp_sequence)
    case = {'case': name, 'exercises': what, 'save': os.path.basename(sp), 'config': CONFIG_OUT, 'state': state_fields(cs, p),
            'decisions': {'energy': energy_decision(cs, pe, gained), 'territory': territory_decision(cs)}}
    if cs.nexus >= 5 and cs.energy >= 2000 and W.stage(cs, CFG) in ('build', 'final') and not (
            W.ascension_test(cs, p, CFG)[0] and sim.asc_cost(cs) <= min(sim.ecap(cs), math.floor(50000.0 * cs.acm / math.log(2)))):
        case['decisions']['warp_sequence'] = warp_sequence(cs, p, gained)
    if at_ascension or cs.mutagen > 0 and cs.asc > 0:
        case['decisions']['mutagen'] = mutagen_decision(cs)
    if extra: case.update(extra)
    json.dump(case, open(os.path.join(OUTDIR, name + '.json'), 'w'), indent=1, default=str)
    return case

WHAT = {'nexus4': 'nexus 4: the A.11 plan, unchanged (early lepidoptera, just-in-time keep for nexus 5)',
        'moths': 'nexus 5, lepidoptera under the target: buy lepidoptera (no bats, no swarmwarp yet)',
        'bats': 'lepidoptera at the target, bats under 2,000: buy bats before any swarmwarp',
        'warp_test_fails': 'bats done; the ascension test fails: every spare 2,000 energy into swarmwarp',
        'warp_test_passes_spend': 'the ascension test passes but the cost is above the save point: keep casting swarmwarp (it is spent energy)',
        'save_for_ascension': 'test passes, cost at or under the save point: stop casting, save',
        'ascend_now': 'test passes and energy covers the cost: ascend now',
        'warp': 'final run: no ascension; every spare energy into swarmwarp'}

def main():
    p, caps, ascs, end = play_route()
    cases = []
    for key in sorted(caps, key=lambda k: caps[k][0].time):
        cs, g = caps[key]
        ph, _, si = key.partition('_')
        what = ('final run, day 2: do not ascend, swarmwarp; expansions toward 5,000' if key == 'final_day2' else
                '%s phase: %s' % (ph, WHAT.get(si, si)))
        cases.append(write_case(key, what, cs, p, g))
    # just after an ascension, before any mutagen is spent: the purchase rule's branches
    picks = {}
    for st in ascs:
        m = lg(st.mutagen) if st.mutagen > 0 else 0
        tag = ('asc_%02d_lgM%d' % (st.asc, int(m)))
        if st.asc in (1, 2, 3) or (st.asc in (8, 15, 22) ) or st is ascs[-1]: picks[tag] = st
    for tag, st in picks.items():
        cases.append(write_case(tag, 'just after ascension %d, nothing bought yet: the mutagen rule (%d unlocks held, 10^%.1f mutagen)' % (
            st.asc, st.unlocks, lg(st.mutagen)), st, p, at_ascension=True))
    # edited boundaries ------------------------------------------------------------------------------------------
    base = caps.get('late_warp_test_fails', caps.get('trough_warp_test_fails'))[0]
    k = CFG['test'][1]
    for tag, f in (('ratio_just_above', 1.000001), ('ratio_just_below', 0.999999)):
        cs = copy.deepcopy(base); cs.premut = cs.mutagen * k * f
        cases.append(write_case(tag, 'premutagen = %s x %g x mutagen held: the ascension test %s' % (f, k, 'passes' if f > 1 else 'fails'), cs, p))
    fin = caps['final_warp'][0]
    for tag, f in (('final_just_above', 1.000001), ('final_just_below', 0.999999)):
        cs = copy.deepcopy(fin); cs.mutagen = bn.big(10.0) ** CFG['final'] * f
        cases.append(write_case(tag, 'mutagen held = %s x 1e%d, 5,000 expansions missing: stage %s' % (f, CFG['final'], 'final' if f > 1 else 'build'), cs, p))
    cs = copy.deepcopy(fin); cs.unearned = [n for n in cs.unearned if n not in ('expansion9', 'overmind6_3')]; cs.ach_have.add('mutation4'); cs.asc = 15
    cs.energy = sim.ecap(cs)       # a full bar (the game clamps energy at the cap)
    cases.append(write_case('quick_stage', 'every long-build achievement earned, 15 ascensions: stage quick, ascend whenever the energy covers the cost', cs, p))
    cs2 = copy.deepcopy(cs); cs2.asc = 20
    cases.append(write_case('done_stage', 'every long-build achievement and 20 ascensions: stage done, never ascend', cs2, p))
    # unlock share boundary: 3 unlocks held, the 4th costs 15,625^3 = 3.81e12, bought only while <= 30% of mutagen held
    a = [x for x in ascs if x.unlocks == 3]
    if a:
        for tag, f in (('unlock_share_just_above', 1.000001), ('unlock_share_just_below', 0.999999)):
            cs = copy.deepcopy(a[0]); cs.mutagen = bn.F(sim.UNLOCK_FACTOR ** 3 / CFG['unlock_share'] * f)
            cases.append(write_case(tag, '3 unlocks held, mutagen held = %s x the 4th unlock price / 0.3: it is %s' % (f, 'bought' if f > 1 else 'not bought'), cs, p, at_ascension=True))
    # switches: states from the mirrors route ---------------------------------------------------------------------
    ms = mirrors_states()
    pm = dict(p)
    cs, g = ms['after_first_ascension_before_purchases']
    cases.append(write_case('switch_mirrors_after_first_ascension_before_purchases', 'mirrors route, just after its first ascension, nothing bought: the swarmwarp rule decides the purchases', cs, pm, at_ascension=True))
    cs, g = ms['after_first_ascension_mirrors_purchases']
    cases.append(write_case('switch_mirrors_purchases_made', "mirrors route's purchases made (lepidoptera and frequency unlocked, 1e6 each): the swarmwarp rule adds warp and bat as affordable", cs, pm, at_ascension=True))
    for day in (10, 30):
        cs, g = ms['long_day%d' % day]
        cases.append(write_case('switch_mirrors_long_day%d' % day, 'mirrors long run day %d (%d expansions, mirrors cast) under the swarmwarp route: no guard; '
                                'premutagen is far above 1,000 x held, so the test passes (ascending here finishes sooner than keeping the long run)' % (day, cs.exp), cs, pm, g))
    cs, g = ms['after_first_ascension_mirrors_purchases']
    c2 = copy.deepcopy(cs); c2.freerespec = 0
    cases.append(write_case('switch_mirrors_purchases_no_free_respec', "as switch_mirrors_purchases_made with no free respec left: no respec advised; warp waits until 2.44e8 is held", c2, pm, at_ascension=True))
    # the game clock: a tier in cooldown by the clock now, released by one warp; several warps affordable at once
    import longrun_cases as LC
    lt = caps['late_warp_test_fails'][0]
    s5 = copy.deepcopy(lt); sim.TRACE = []; sim.policy(s5, dict(p, energy=False, ci=GAP), 0.0)
    buys = [r['tier'] for r in LC.events_to_decisions(list(sim.TRACE))['climb'] if r['outcome'] == 'buys']; sim.TRACE = None
    top = buys[0]                         # the highest tier the climb buys at this visit
    c4 = copy.deepcopy(lt); c4.energy = 3 * 2000.0 + 500; c4.lastbuy[top] = sim.tnow(c4, p) - 30
    s5 = copy.deepcopy(c4); sim.TRACE = []; sim.policy(s5, dict(p, energy=False, ci=GAP), 0.0)
    before = LC.events_to_decisions(list(sim.TRACE)); sim.TRACE = None
    cases.append(write_case('cooldown_released_by_warp', '%s hatched 30 s ago (game clock): in cooldown without a warp (climb_without_warp); one warp '
                            'skips far more than 60 s, so it is released in the first step of warp_sequence' % sim.NAMES[top], c4, p, 0.0,
                            extra={'climb_without_warp': before['climb']}))
    c6 = copy.deepcopy(lt); c6.energy = 5 * 2000.0 + 700
    cases.append(write_case('five_warps_affordable', 'energy for 5 swarmwarps at one visit: one at a time, the purchases re-taken between them (warp_sequence)', c6, p, 0.0))
    c3 = copy.deepcopy(caps['late_warp_test_fails'][0]); c3.casts = dict(c3.casts); c3.casts.pop('mirror', None)
    cases.append(write_case('no_mirrors_many_expansions', 'a swarmwarp run with many expansions and no mirror cast: no guard', c3, p))
    print('cases written (%.0f s)' % (time.time() - T0), flush=True)
    roundtrip(cases)
    json.dump({'cases': [c['case'] for c in cases], 'generated_in_s': round(time.time() - T0)}, open(os.path.join(OUTDIR, 'index.json'), 'w'), indent=1)
    print('done (%.0f s), %d cases' % (time.time() - T0, len(cases)))

def roundtrip(cases):
    """Load every exported save in the real game and compare what the route's rules read."""
    files = [os.path.join(OUTDIR, c['save']) for c in cases]
    game = json.loads(subprocess.run(['node', os.path.join(HERE, 'swarmwarp_roundtrip.js')] + files, check=True, capture_output=True, text=True,
                                     env=dict(os.environ, TZ='UTC')).stdout)
    lines = ['| case | numbers | worst sim/game - 1 | where | unlocks / earned flags equal |', '|---|---|---|---|---|']
    allworst = 0.0
    for c in cases:
        g = game[c['save']]; st = c['state']; worst = [0.0, '']; n = [0]
        def cmp(name, gv, sv):
            n[0] += 1
            gv = bn.num(gv); sv = bn.num(sv) if isinstance(sv, str) else bn.big(sv)
            if gv == 0 and sv == 0: return
            r = abs(float(sv / gv) - 1) if gv != 0 else float('inf')
            if r > worst[0]: worst[0] = r; worst[1] = name
        for f, gk in (('energy', 'energy'), ('energy_rate', 'energyRate'), ('cap', 'cap'), ('moths', 'moth'), ('bats', 'bat'), ('nightbugs', 'nightbug'),
                      ('ascension_cost', 'ascendCost'), ('energy_spent', 'spent'), ('halving', 'halving'), ('mutagen_held', 'mutagen'),
                      ('premutagen', 'premutagen'), ('next_unlock_price', 'nextUnlockPrice'), ('swarmwarp_power', 'warpPower'),
                      ('swarmwarp_skip_s', 'warpSkip'), ('larvae', 'larva'), ('larva_rate', 'larvaRate'), ('meat', 'meat')):
            if g.get(gk) is not None: cmp(f, g[gk], st[f])
        ck = st['clock']
        cmp('run age (wall)', g['runAge'], ck['run_age_wall_s']); cmp('expansions', g['expansion'], st['expansions'])
        cmp('skipped total (s)', g['skippedMillis'] / 1000.0, ck['skipped_total_s'])
        cmp('swarmwarp casts this run', g['swarmwarp'], st['swarmwarp_casts_this_run'])
        cmp('game run age estimate (wall + casts x skip)', g['runAge'] + float(g['swarmwarp']) * float(g['warpSkip']), ck['run_age_game_estimate_s'])
        cmp('ascensions', g['ascension'], st['ascensions']); cmp('mirror casts', g['clonearmy'], st['mirror_casts_this_run'])
        for m in sim.MUTANTS: cmp(m, g['mutants'][m], st['mutants'].get(m, '0'))
        same = (sorted(g['unlocked']) == sorted(st['unlocks']) and g['unlockCount'] == st['unlock_count'] and
                all(g['earned'][k] == v for k, v in st['earned'].items()))
        t = c['decisions']['territory']
        cmp('empower price (cheapest rung)', g['empowerPrice'][t['cheapest_rung']], t['empower_price'])
        allworst = max(allworst, worst[0])
        lines.append('| %s | %d | %.2g | %s | %s |' % (c['case'], n[0], worst[0], worst[1], 'yes' if same else '**no**'))
    txt = '\n'.join(lines) + '\n\nWorst over all cases: %.2g\n' % allworst
    open(os.path.join(OUTDIR, 'roundtrip.md'), 'w').write('# Round trip: exported simulator states loaded in the real game\n\nGenerated by swarmwarp_cases.py.\n\n' + txt)
    print(txt)

if __name__ == '__main__':
    main()
