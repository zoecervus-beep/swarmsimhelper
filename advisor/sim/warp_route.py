"""The swarmwarp ("no mirrors") route as rules the advisor can follow from game state alone (advisor/NO-MIRRORS.md,
"Rules for the advisor"), the mirrors route as the advisor plays it today, and switching between them.

The rule functions here are the reference the advisor port is checked against (advisor/modelcheck/swarmwarp_cases.py):
each reads only what the game holds (no memory), and the simulator plays the same functions.

  stage(s, cfg)            build / final / quick / done, or the guard stage mirrorsLongRun
  ascension_test(s, p, cfg) whether the route's ascension test passes now, with its inputs
  mutagen_steps(s, cfg)    the purchases after an ascension (idempotent: run twice, the second buys nothing)
  policy(cfg)              the simulator policy the energy, territory and climb rules amount to

Sections (default: all; ideal = a visit every 5 minutes, as in NO-MIRRORS.md):
  validate   the route as specified, ideal and human (2 seeds), against the study's 223 / 245-253 days    (~2 min)
  energy     below nexus 5 (A.11 plan or swarmwarp), bats 0-4,000, lepidoptera, energy lost at the cap     (~2 min)
  asctest    the ascension test: run age by mutagen held, or premutagen >= k x mutagen held; three cadences  (~2 min)
  final      the final-run threshold                                                                         (~2 min)
  mirrors    the mirrors route as the advisor plays it (for the switch baselines)                            (~1 min)
  switch     switching routes at the points a player might, with and without the guard rules                 (~6 min)
Usage (from the repo root):  python3 -I advisor/sim/warp_route.py [sections] [--jobs N]     # all sections: ~15 min on 4 cores
Writes advisor/modelcheck/out/warp_route_<section>.json and prints markdown.
"""
import copy, json, math, os, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim, bignum as bn, cadence, longrun_rules as lr

OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
lg = lambda x: bn.lg(x) if x > 0 else float('-inf')
SPEC4 = lr.SPEC4
LONG_GOALS = ['expansion9', 'overmind6_3', 'mutation4']    # what only a long build-up gets: 5,000 expansions, 1e62 endless, 10 unlocks
ASC_GOAL = 20

# ---------------------------------------------------------------------------------------------- the rules
UNLOCK_ORDER = ['mutatenexus', 'mutateswarmwarp', 'mutatebat', 'mutatefreq', 'mutateeach', 'mutatearmy', 'mutaterush', 'mutateclone',
                'mutatemeat', 'mutatehatchery']
FIXED = {'mutantnexus': 1e6, 'mutantfreq': 1e6}                                      # hold at least this many
SHARES = [('mutantswarmwarp', 0.1), ('mutantbat', 0.1), ('mutantarmy', 0.3), ('mutanteach', 0.01)]   # of W, see mutagen_steps
CFG = {'test': ('ratio', 1000.0), 'final': 270.0, 'free_unlocks': 3, 'unlock_share': 0.3, 'guard': None, 'respec': True, 'max_wall_days': None,
       'guard_exp': 100, 'stall_days': None, 'moths': 10000, 'bats': 2000,
       'clock': 'game', 'age': 'game', 'visits': True}   # timers and run age on the game clock (wall + skipped), buy between warps

def earned(s, name):
    if name in s.ach_have: return True
    return name in sim._achievements() and sim._achievements()[name][1] in (set(sim.NAMES[1:] + sim.TN) | {'expansion', 'nexus5'}) and name not in s.unearned

def stage(s, cfg=CFG):
    """The route's stage, from the game state alone:
    done   every ascension achievement and every long-build achievement earned;
    quick  the long-build achievements earned, fewer than 20 ascensions: ascend whenever the energy allows;
    mirrorsLongRun (guard) this run has cast House of Mirrors and holds >= guard_exp expansions, and 5,000 expansions are
           still missing: a mirrors long run under way (see guard_decision);
    final  10^final mutagen held and 5,000 expansions missing: this run goes to 5,000 expansions, do not ascend;
    build  otherwise: grow mutagen, ascend when the ascension test passes."""
    left = [g for g in LONG_GOALS if not earned(s, g)]
    if not left: return 'quick' if s.asc < ASC_GOAL else 'done'
    if cfg.get('guard') and s.casts.get('mirror', 0) > 0 and s.exp >= cfg['guard_exp'] and not earned(s, 'expansion9'):
        return 'mirrorsLongRun'
    if lg(s.mutagen) >= cfg['final'] and not earned(s, 'expansion9'):
        return 'final'
    return 'build'

def ascension_test(s, p, cfg=CFG):
    """Build stage: does the route's ascension test pass now? Returns (passes, inputs)."""
    kind = cfg['test'][0]
    age = sim.run_age(s, p)
    held = s.mutagen; m = lg(held) if held > 0 else 0.0
    if kind == 'ratio':           # premutagen this run >= k x mutagen held (unspent); with nothing held, any premutagen
        k = cfg['test'][1]
        need = k * max(held, 1.0)
        return bool(s.premut >= need), {'premutagen': s.premut, 'held': held, 'k': k, 'need': need, 'run_age_s': age}
    if kind == 'age':             # run age >= the schedule's days for the mutagen held: [(log10 limit, days), ...]
        for lim, d in cfg['test'][1]:
            if m < lim: break
        return bool(age >= d * 86400), {'held': held, 'days': d, 'run_age_s': age}
    raise ValueError(kind)

def guard_decision(s, p, cfg=CFG):
    """mirrorsLongRun: what the swarmwarp route does with a mirrors long run already under way. cfg['guard_mode']:
    'keep' (do not ascend; keep casting House of Mirrors until 5,000 expansions), 'ratio' (the build test applies as
    usual: ascend once premutagen >= k x held)."""
    return cfg.get('guard_mode', 'keep')

def wants_ascension(s, p, cfg=CFG):
    st = stage(s, cfg)
    if st == 'quick': return True
    if st in ('done', 'final'):
        if st == 'final' and cfg.get('stall_days') and sim.run_age(s, p) >= cfg['stall_days'] * 86400: return True
        return False
    if st == 'mirrorsLongRun':
        return guard_decision(s, p, cfg) == 'ratio' and ascension_test(s, p, cfg)[0]
    if cfg.get('max_wall_days') and sim.run_age(s, dict(p, game_age=False)) >= cfg['max_wall_days'] * 86400: return True   # backstop
    return ascension_test(s, p, cfg)[0]

def mutagen_steps(s, cfg=CFG):
    """Purchases after an ascension, worked out from holdings alone (pure; the state is not changed). In order:
    1. unlocks, in UNLOCK_ORDER, skipping those held: the k-th unlock costs 15,625^(k-1) (game price); buy while affordable,
       and from the 4th unlock on only while its price is at most unlock_share (30%) of the mutagen held;
    2. the lepidoptera and frequency mutations up to 1e6 each (when unlocked), as far as the mutagen held goes;
    3. W = mutagen held + the warp, bat, territory and meta-mutation mutants held (unlocked kinds); for each of those kinds,
       buy up to share x W (10%, 10%, 30%, 1%), as far as the mutagen held goes.
    What is left stays unspent (0.1 larva/s each). Applied twice in a row, the second time buys nothing."""
    held = s.mutagen; unl = list(s.unlocked); n = s.unlocks; mut = dict(s.mut); steps = []
    for up in UNLOCK_ORDER:
        if up in unl: continue
        price = sim.UNLOCK_FACTOR ** n
        if held < price: break
        if n >= cfg['free_unlocks'] and price > cfg['unlock_share'] * held: break
        held = held - price; n += 1; unl.append(up); mu = sim.MUTATE[up]; mut[mu] = mut[mu] + 1
        steps.append(('unlock', up, price))
    for mu, want in FIXED.items():
        if 'mutate' + mu[6:] not in unl: continue
        k = math.floor(min(want - mut[mu], held))
        if k >= 1: held = held - k; mut[mu] = mut[mu] + k; steps.append(('mutants', mu, bn.F(float(k)) if k < 2 ** 53 else bn.big(k)))
    managed = [(mu, sh) for mu, sh in SHARES if 'mutate' + mu[6:] in unl]
    W = held + sum((mut[mu] for mu, _ in managed), bn.F(0.0))
    for mu, sh in managed:
        k = (W * sh - mut[mu])
        if k >= 1:
            k = bn_floor(min(k, held))
            if k >= 1: held = held - k; mut[mu] = mut[mu] + k; steps.append(('mutants', mu, k))
    return steps

def bn_floor(x):
    return bn.F(float(math.floor(x))) if x < 2 ** 52 else x      # past 2^52 a float/Big is already an integer to its precision

def respec_advised(s, cfg=CFG):
    """A free respec before the purchases: the warp mutation is not unlocked, the next unlock costs more than the mutagen
    held, a free respec is available, and what a respec gives back (every unlock's price and every mutant bought) pays for
    the lepidoptera and warp unlocks (1 + 15,625). This is the case after the mirrors route's first ascension (lepidoptera
    and frequency unlocked: warp would be the 3rd unlock, 2.44e8). A free respec keeps the energy credit (ASCENSION.md B2.6)."""
    if not cfg.get('respec') or 'mutateswarmwarp' in s.unlocked or s.freerespec < 1: return False
    if s.mutagen >= sim.UNLOCK_FACTOR ** s.unlocks: return False
    refund = respec_refund(s)
    return s.mutagen + refund >= 1 + sim.UNLOCK_FACTOR

def respec_refund(s):
    """Mutagen a respec gives back: the unlock prices paid (15,625^0 .. 15,625^(n-1)) and every mutant bought (each unlock's
    free mutant is not refunded)."""
    return sum(sim.UNLOCK_FACTOR ** i for i in range(s.unlocks)) + sum(s.mut.values()) - s.unlocks

def do_respec(s):
    s.mutagen = s.mutagen + respec_refund(s); s.mut = {m: bn.F(0.0) for m in sim.MUTANTS}; s.unlocked = []; s.unlocks = 0
    s.freerespec -= 1; sim.refresh_mut(s)

def apply_mutagen(s, cfg=CFG):
    """Callable plan for sim.ascend: apply mutagen_steps (after a free respec when respec_advised)."""
    out = []
    if respec_advised(s, cfg):
        do_respec(s); out.append(('respec',))
    for st in mutagen_steps(s, cfg):
        if st[0] == 'unlock':
            sim.apply_plan(s, {'unlock': [st[1]]}); out.append(st)
        else:
            _, mu, k = st
            s.mutagen = s.mutagen - k; s.mut[mu] = s.mut[mu] + k; out.append(st)
    sim.refresh_mut(s)
    return out

A11 = dict(spare_pre5='save', moth_N=1000, moth_first=True, pre5_excess='moths', jit5=True)
def policy(cfg=CFG, **over):
    """The route's energy, territory and climb rules as a simulator policy: the long-run climb (pass 4, advisor sizing,
    1% push reserve), territory share 0.1 with empower, lepidoptera 4,000 (never raised), 2,000 bats, every spare
    energy into swarmwarp, the A.11 plan below nexus 5 when cfg['a11'], and the ascension from wants_ascension."""
    p = dict(SPEC4, spells=['warp'], bat_N=cfg.get('bats', 2000), empower=True, moth_late=None, moth_N=4000)
    if cfg.get('a11', True): p.update(A11, moth_N5=cfg.get('moths', 4000))
    else: p['moth_N'] = cfg.get('moths', 4000)
    p['game_clock'] = cfg.get('clock') == 'game'
    p['game_age'] = cfg.get('age') == 'game'
    p['warp_visits'] = bool(cfg.get('visits'))
    p['ascend_rule'] = lambda s, p=p: ({'after': 0} if wants_ascension(s, p, cfg) else None)
    p.update(over)
    return p

# ------------------------------------------------------------------------------------ the mirrors route (today)
def mirror_stage(s):
    """advisorascension.coffee's stages."""
    if s.asc == 0: return 'firstRun'
    left = [g for g in ('expansion9', 'overmind6_3') if not earned(s, g)]   # the advisor's long-run goals: expansions and endless
    if left and 'mutatenexus' not in s.unlocked and s.mutagen < sim.unlock_cost(s): return 'needMutation'
    if left: return 'longRun'
    return 'quickRun' if s.asc < ASC_GOAL else 'done'

def mirror_policy(s, **over):
    st = mirror_stage(s)
    p = dict(SPEC4, spells=['mirror', 'larvarush'], empower=True, moth_late=None, **A11)
    p['moth_N5'] = {'firstRun': 10000, 'needMutation': 10000, 'quickRun': 30000}.get(st, 4000)
    if st == 'longRun': p['moth_late'] = (3 * 86400, 30000)
    p['ascend_rule'] = lambda s: ({'after': 0} if mirror_stage(s) in ('firstRun', 'needMutation', 'quickRun') else None)
    p.update(over)
    return p

def mirror_mutagen(s):
    """advisorascension.coffee mutagenPlan: unlock lepidoptera, lepidoptera mutation to 1e6, then 1 more unlock after the
    first ascension or all of them from the second; the rest unspent."""
    out = []
    if 'mutatenexus' not in s.unlocked and s.mutagen >= sim.unlock_cost(s):
        sim.apply_plan(s, {'unlock': ['mutatenexus']}); out.append(('unlock', 'mutatenexus'))
    if 'mutatenexus' in s.unlocked:
        k = math.floor(min(1e6 - s.mut['mutantnexus'], s.mutagen))
        if k >= 1: s.mutagen -= k; s.mut['mutantnexus'] += k; out.append(('mutants', 'mutantnexus', k))
    want = 10 if s.asc >= 2 else 2
    order = ['mutatefreq'] + [u for u in sim.MUTATE if u not in ('mutatenexus', 'mutatefreq')]
    for up in order:
        if s.unlocks >= want: break
        if up in s.unlocked: continue
        if s.mutagen < sim.unlock_cost(s): break
        sim.apply_plan(s, {'unlock': [up]}); out.append(('unlock', up))
    sim.refresh_mut(s)
    return out

# ---------------------------------------------------------------------------------------------- the driver
class Route:
    def __init__(self, name, cfg=None, over=None):
        self.name = name; self.cfg = dict(CFG, **(cfg or {})); self.over = over or {}
    def policy(self, s):
        if self.name == 'warp':
            p = policy(self.cfg, **self.over)
            if stage(s, self.cfg) == 'mirrorsLongRun' and self.cfg.get('guard_mode', 'keep') == 'keep':
                p['spells'] = ['mirror']; p['moth_late'] = (3 * 86400, 30000)   # finish the mirrors long run as the mirrors route would
            return p
        return mirror_policy(s, **self.over)
    def plan(self, s):
        return apply_mutagen(s, self.cfg) if self.name == 'warp' else mirror_mutagen(s)
    def stage(self, s):
        return stage(s, self.cfg) if self.name == 'warp' else mirror_stage(s)

def all_done(s):
    return s.asc >= ASC_GOAL and earned(s, 'mutation4') and not s.unearned

def play(s0, route, days=450, ci=300, prof=None, seed=1, switch=None, label=None):
    """Play from s0 under `route` until every achievement is earned (or `days` from s0). switch = (condition(s),
    new Route, what to do at the switch: None or 'ascend'): the route changes at the first visit the condition holds.
    Returns a summary with the day (from the 20.1 h save) of each milestone."""
    s = copy.deepcopy(s0); s.ewaste = getattr(s, 'ewaste', 0.0)
    if not hasattr(s, 'ach_log'): s.ach_log = []
    sim.EMPOWER_MODEL = True
    end_h = s.time / 3600 + 24 * days
    gaps = cadence.gaps(prof, days + 2, seed=seed, start=s.time) if prof else ci
    t0 = time.time(); switched = None; runs = []
    while s.time < end_h * 3600 - 1 and not all_done(s):
        p = route.policy(s); a0 = s.asc; st0 = route.stage(s)
        sw = (lambda st: switch[0](st)) if (switch and switched is None) else (lambda st: False)
        def until(st):
            return st.asc != a0 or route.stage(st) != st0 or all_done(st) or sw(st)
        n0 = len(s.asc_log)
        s, rows, log = sim.run_cycles(p, gaps, end_h, plans=[route.plan] * 1000, s0=s, every=86400, until=until)
        if len(log) > n0: runs.append({'day': log[-1]['time'] / 86400, 'run_days': log[-1]['run_age'] / 86400, 'exp': log[-1]['exp'],
                             'hatch': log[-1]['hatch'], 'lpremut': lg(log[-1]['premut']), 'lmut_after': lg(log[-1]['mutagen_after']),
                             'route': route.name})
        if switch and switched is None and switch[0](s):
            switched = {'day': s.time / 86400, 'asc': s.asc, 'exp': s.exp, 'lmut': lg(s.mutagen), 'lpremut': lg(s.premut),
                        'mirrors': s.casts.get('mirror', 0), 'run_age_d': sim.run_age(s, p) / 86400}
            route = switch[1]
            if s.asc >= 1 and s.mutagen > 0:     # the new route's mutagen line shows at once (it reads holdings, not the ascension)
                switched['purchases'] = [str(x[:2]) for x in route.plan(s)]
            if len(switch) > 2 and switch[2] == 'ascend':
                s.energy = max(s.energy, sim.asc_cost(s)); sim.ascend(s, p, route.plan); switched['forced_ascension'] = True
    when = {n: t / 86400 for t, n in s.ach_log}
    for n in sim._achievements():
        if n in s.ach_have and n not in when and n.startswith(('ascension', 'mutation')): when.setdefault(n, None)
    done = all_done(s)
    return {'label': label or route.name, 'when': when, 'end_day': s.time / 86400 if done else None, 'done': done, 'asc': s.asc,
            'missing': sorted(set(s.unearned) | {g for g in ('mutation4',) if not earned(s, g)} | ({'ascension3'} if s.asc < 20 else set())),
            'runs': runs, 'switched': switched, 'ewaste_days': s.ewaste / (2.0 * 86400), 'secs': round(time.time() - t0)}

def start_save():
    s = sim.load(); s.ach_log = []; s.ewaste = 0.0; return s

# ---------------------------------------------------------------------------------------------- reporting
KEYS = [('mutation3', '6 unlocks'), ('mutation4', '10 unlocks'), ('ascension3', '20 asc.'), ('overmind6_1', 'endless 1'),
        ('overmind6_3', 'endless 1e62'), ('expansion7', 'exp 1,000'), ('expansion8', 'exp 2,000'), ('expansion9', 'exp 5,000')]
def table(res, title):
    print('\n### %s\n' % title)
    print('| variant | ' + ' | '.join(l for _, l in KEYS) + ' | all done | ascensions | energy lost at the cap (days at 2/s) |')
    print('|' + ' --- |' * (len(KEYS) + 4))
    for r in res:
        w = r['when']; d = lambda n: ('%.0f' % w[n]) if w.get(n) is not None else '-'
        print('| %s | %s | %s | %d | %.1f |' % (r['label'], ' | '.join(d(n) for n, _ in KEYS), '%.0f' % r['end_day'] if r['done'] else
                                               'not by day %.0f (missing %d)' % (max([0] + [x['day'] for x in r['runs']]), len(r['missing'])), r['asc'], r['ewaste_days']))

def run_spec(spec):
    label, route, kw = spec
    return play(kw.pop('s0', None) or start_save(), route, label=label, **kw)

def run_par(specs, jobs):
    with ProcessPoolExecutor(jobs) as ex:
        return list(ex.map(run_spec, specs))

AGE_SCHED = ('age', [(10, 6), (32, 16), (1e9, 0)])        # NO-MIRRORS.md's schedule: days by log10 mutagen held

def section_validate(jobs):
    W = lambda **c: Route('warp', c)
    WALL = dict(clock='wall', age='wall', visits=False)
    STUDY = dict(WALL, test=AGE_SCHED, a11=False, final=250, guard=None, moths=4000)
    specs = [('the study route (wall clock, warps back to back, age schedule, lepidoptera 4,000)', W(**STUDY), {}),
             ('the study route, human', W(**STUDY), {'prof': 'human'}),
             ('the spec on the wall clock (warps back to back)', W(**WALL), {}),
             ('the spec on the wall clock, human', W(**WALL), {'prof': 'human'}),
             ('the spec on the wall clock, busy', W(**WALL), {'prof': 'busy'}),
             ('the spec on the wall clock, twice a day', W(**WALL), {'prof': 'twice', 'days': 500}),
             ('the spec, game clock for timers only (run age on the wall clock)', W(age='wall'), {}),
             ('the spec, game clock for timers only, human', W(age='wall'), {'prof': 'human'}),
             ('**the spec** (game clock, one warp at a time)', W(), {})]
    specs += [('the spec, human seed %d' % sd, W(), {'prof': 'human', 'seed': sd}) for sd in (1, 2, 3)]
    specs += [('the spec, %s' % c, W(), {'prof': c, 'days': 500}) for c in ('busy', 'glance+', 'every120', 'twice')]
    res = run_par(specs, jobs); dump('validate', res); table(res, 'Re-validation: advisor sizing, honest larvae (days from the 20.1 h save)')
    return res

def section_energy(jobs):
    W = lambda **c: Route('warp', c)
    specs = [('A.11 plan below nexus 5 (spec)', W(), {}), ('swarmwarp from nexus 1 instead', W(a11=False), {}),
             ('bats 0', W(bats=0), {}), ('bats 1,000', W(bats=1000), {}), ('bats 4,000', W(bats=4000), {}),
             ('lepidoptera 10,000', W(moths=10000), {}), ('lepidoptera 30,000', W(moths=30000), {}),
             ('A.11 plan, human', W(), {'prof': 'human'}), ('swarmwarp from nexus 1, human', W(a11=False), {'prof': 'human'}),
             ('A.11 plan, busy', W(), {'prof': 'busy'}), ('A.11 plan, twice a day', W(), {'prof': 'twice', 'days': 500})]
    res = run_par(specs, jobs); dump('energy', res); table(res, 'Energy rules (days from the save)')
    return res

def section_asctest(jobs):
    W = lambda **c: Route('warp', c)
    tests = [('run age by mutagen held (6 / 16 / 0 days)', AGE_SCHED), ('premutagen >= 10 x held', ('ratio', 10.0)),
             ('premutagen >= 100 x held', ('ratio', 100.0)), ('premutagen >= 1,000 x held', ('ratio', 1000.0)),
             ('premutagen >= 10^4 x held', ('ratio', 1e4))]
    specs = []
    for prof in (None, 'human', 'busy'):
        for name, t in tests:
            specs.append(('%s, %s' % (name, prof or 'ideal'), W(test=t), {'prof': prof} if prof else {}))
    res = run_par(specs, jobs); dump('asctest', res); table(res, 'The ascension test (days from the save)')
    return res

def section_final(jobs):
    W = lambda **c: Route('warp', c)
    specs = [('final from 1e%d' % f, W(final=float(f)), {}) for f in (250, 260, 270, 280, 300)]
    specs += [('final from 1e250, stall guard 15 d', W(final=250.0, stall_days=15), {})]
    res = run_par(specs, jobs); dump('final', res); table(res, 'The final-run threshold (days from the save)')
    for r in res: print('- %s: last runs %s' % (r['label'], ', '.join('%.0f d %d exp' % (x['run_days'], x['exp']) for x in r['runs'][-3:])))
    return res

def section_mirrors(jobs):
    specs = [('mirrors route (advisor today), ideal', Route('mirror'), {}), ('mirrors route, human seed 1', Route('mirror'), {'prof': 'human'}),
             ('mirrors route, human seed 2', Route('mirror'), {'prof': 'human', 'seed': 2}), ('mirrors route, busy', Route('mirror'), {'prof': 'busy'})]
    res = run_par(specs, jobs); dump('mirrors', res); table(res, 'The mirrors route as the advisor plays it (days from the save)')
    return res

def cond(kind, v=None):
    """Switch conditions (picklable by name)."""
    age = lambda s: sim.run_age(s, SPEC4) / 86400
    return {'age_first': lambda s: s.asc == 0 and age(s) >= v,
            'mirrors_first': lambda s: s.asc == 0 and s.casts.get('mirror', 0) >= v,
            'asc': lambda s: s.asc >= v,
            'asc_age': lambda s: s.asc >= v[0] and age(s) >= v[1],
            'long_day': lambda s: s.asc == 1 and s.casts.get('mirror', 0) > 0 and age(s) >= v,
            'final_age': lambda s: lg(s.mutagen) >= 270 and age(s) >= v}[kind]

def switch_run(spec):
    label, frm, to, (kind, v), kw = spec
    return play(start_save(), frm, label=label, switch=(cond(kind, v), to), **kw)

SWITCHES = [
    # mirrors route -> swarmwarp route
    ('mirrors -> swarmwarp: first run, day 1 (no mirror cast yet)', 'mirror', 'warp', ('age_first', 1.0)),
    ('mirrors -> swarmwarp: first run, after 20 mirror casts', 'mirror', 'warp', ('mirrors_first', 20)),
    ('mirrors -> swarmwarp: first run, after 20 mirror casts, with a guard keeping mirror runs of 100+ expansions', 'mirror', 'warpkeep', ('mirrors_first', 20)),
    ('mirrors -> swarmwarp: right after the first ascension (mirrors purchases made), free respec', 'mirror', 'warp', ('asc_age', (1, 0.0))),
    ('mirrors -> swarmwarp: right after the first ascension, no respec', 'mirror', 'warpnorespec', ('asc_age', (1, 0.0))),
    ('mirrors -> swarmwarp: right after the first ascension, no respec, 16-day wall backstop', 'mirror', 'warpcap', ('asc_age', (1, 0.0))),
    ('mirrors -> swarmwarp: long run day 10 (the ratio test ascends at once)', 'mirror', 'warp', ('long_day', 10.0)),
    ('mirrors -> swarmwarp: long run day 10, guard keeps the long run', 'mirror', 'warpkeep', ('long_day', 10.0)),
    ('mirrors -> swarmwarp: long run day 30', 'mirror', 'warp', ('long_day', 30.0)),
    ('mirrors -> swarmwarp: long run day 30, guard keeps it', 'mirror', 'warpkeep', ('long_day', 30.0)),
    ('mirrors -> swarmwarp: long run day 60', 'mirror', 'warp', ('long_day', 60.0)),
    ('mirrors -> swarmwarp: long run day 60, guard keeps it', 'mirror', 'warpkeep', ('long_day', 60.0)),
    ('mirrors -> swarmwarp: long run day 90', 'mirror', 'warp', ('long_day', 90.0)),
    ('mirrors -> swarmwarp: long run day 90, guard keeps it', 'mirror', 'warpkeep', ('long_day', 90.0)),
    ('mirrors -> swarmwarp: quick runs (5 ascensions done)', 'mirror', 'warp', ('asc', 5)),
    # swarmwarp route -> mirrors route
    ('swarmwarp -> mirrors: first run, day 2', 'warp', 'mirror', ('age_first', 2.0)),
    ('swarmwarp -> mirrors: 5 ascensions (trough)', 'warp', 'mirror', ('asc', 5)),
    ('swarmwarp -> mirrors: 20 ascensions', 'warp', 'mirror', ('asc', 20)),
    ('swarmwarp -> mirrors: final run, day 2', 'warp', 'mirror', ('final_age', 2.0)),
]
def mkroute(name):
    if name == 'warpkeep': return Route('warp', {'guard': 'mirrors', 'guard_mode': 'keep'})
    if name == 'warpnorespec': return Route('warp', {'respec': False})
    if name == 'warpcap': return Route('warp', {'respec': False, 'max_wall_days': 16})
    return Route(name)

def section_switch(jobs):
    specs = [(l, mkroute(f), mkroute(t), c, {}) for l, f, t, c in SWITCHES]
    with ProcessPoolExecutor(jobs) as ex:
        res = list(ex.map(switch_run, specs))
    dump('switch', res); table(res, 'Switching routes (days from the save; the routes alone: mirrors 174, swarmwarp 141)')
    print('\n| switch | at day | ascensions | expansions this run | log10 mutagen held | log10 premutagen this run | then |')
    print('| --- | --- | --- | --- | --- | --- | --- |')
    for r in res:
        w = r['switched'] or {}
        after = [x for x in r['runs'] if w and x['day'] >= w.get('day', 0) - 1e-9][:2]
        print('| %s | %s | %s | %s | %s | %s | %s |' % (r['label'], '%.1f' % w['day'] if w else '-', w.get('asc', '-'), w.get('exp', '-'),
              '%.1f' % w['lmut'] if w else '-', '%.1f' % w['lpremut'] if w else '-',
              '; '.join('next ascension day %.1f (run %.1f d, %d exp)' % (x['day'], x['run_days'], x['exp']) for x in after)))
    return res

def dump(name, res):
    json.dump(res, open(os.path.join(OUTD, 'warp_route_%s.json' % name), 'w'), default=str)

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    want = args or ['validate', 'energy', 'asctest', 'final', 'mirrors', 'switch']
    T = time.time()
    for w in want:
        globals()['section_' + w](jobs)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
