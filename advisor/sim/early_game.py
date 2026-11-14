"""Early game: the fastest path from the start of a run to the first House of Mirrors cast and to an affordable
ascension (advisor/ASCENSION.md, "Early game: the fastest path to the first mirror cast").

Three kinds of run from the owner's route (ASCENSION.md A.1/A.5):
  first   the very first run: no mutagen. Starts from the fresh run on this fork at 27 minutes
          (example_save_27min.json); times are run age.
  second  the run right after the first ascension: lepidoptera and frequency mutations (1e6 each), the rest of
          the first run's mutagen unspent (~7e7). Made by playing `first` with today's defaults to its ascension.
  late    a late quick run: all ten mutations unlocked (one mutant each, 1e6 lepidoptera mutation), 1e335 mutagen
          unspent, the 11th ascension's cost. Made from `second` by editing the state.
No crystals anywhere. Premutagen is the mean of the game's roll. Times in hours of run age.

Targets: n5 = nexus 5 bought; mirror = first House of Mirrors cast; afford = the energy covers the ascension cost
under the save rule of A.5 (spend until the cost is at most min(cap, 50,000 x N / ln 2), then save); asc = the
visit at which the player could ascend (afford rounded up to a visit).

Policies (sim.py options; all with the advisor's own purchase sizing, `advisor_sizing`):
  TODAY   today's advisor defaults: age multiple 3, share 0.5, cooldown 60, bank 3, territory 0.1, lepidoptera 4,000,
          spare energy to larva rush below nexus 5, larvae for the next nexus held once its meat is in hand and its
          larva price is under 20,000 s of income (the simulator's rule; see `literal` for the advisor taken literally)
  PLAN    the plan the new defaults give: spare energy saved for the next nexus (larva rush only at the cap), the
          next nexus's larvae kept from the climb, at nexus 4 1,000 lepidoptera first, then only the energy nexus 5
          needs "just in time" kept (the rest into lepidoptera), and after nexus 5 lepidoptera to the run's target:
          10,000 in a first run, 30,000 in a quick run, 4,000 then 30,000 from day 3 in the long run.

Sections (all by default):
  energy     the pure energy model from nexus 4: lepidoptera before / after nexus 5 against the two targets  (instant)
  bind       what binds: each nexus price made free in turn (meat, larvae, energy), ideal cadence             (~20 s)
  plan       today's defaults against the plan, three runs, ideal / human / busy cadence (5 seeds each)       (~1 min)
  parts      what each change contributes: added one at a time to today's defaults, and left out of the plan  (~2 min)
  first5     first run: lepidoptera target after nexus 5 against the mutagen it leaves                       (~1 min)
  meat       first run: the meat-side settings (age multiple, share, bank, territory, nexus larva timing)    (~1 min)
  longstart  the long run's start with less mutagen left from the first run                                 (~30 s)
  cadence    today against the plan under more cadences: a 45-minute stay at the start, twice a day, glance+ (~1 min)
Usage (from the repo root):
    python3 -I advisor/sim/early_game.py [sections] [--jobs N]
Results also go to advisor/modelcheck/out/early_game.json; start states are cached in advisor/modelcheck/out/eg_*.pkl.
"""
import copy, json, math, os, pickle, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_27min.json')
import sim, bignum as bn, cadence

OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
POLICY = json.load(open(os.path.join(HERE, 'policy.json')))
AGE27 = 1631   # run age of example_save_27min.json (saved - restarted), s; ascensions keep this offset (sim.run_off)
TODAY = dict(POLICY, theta_age=3, advisor_sizing=True, cooldown_s=60, age0=AGE27, ascend=[{'after': 0}])
SAVE_PLAN = dict(spare_pre5='save')                                   # spare energy held for the next nexus
EARLY = dict(moth_N=1000, moth_first=True)                            # at nexus 4: 1,000 lepidoptera first
JIT = dict(pre5_excess='moths', jit5=True)                            # then keep only what nexus 5 needs just in time
STAGE = {'first': dict(moth_N5=10000), 'second': dict(moth_N5=4000, moth_late=(3 * 86400, 30000)), 'late': dict(moth_N5=30000)}
def plan(run): return dict(TODAY, **SAVE_PLAN, **EARLY, **JIT, **STAGE[run])
FIRST_PLAN = {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6}}
CAD = [('ideal', None, [1]), ('human', 'human', [1, 2, 3, 4, 5]), ('busy', 'busy', [1, 2, 3, 4, 5]),
       ('human, 45 min stay at the start', 'human@stay', [1, 2, 3, 4, 5]), ('twice', 'twice', [1]), ('glance+', 'glance+', [1, 2, 3])]
OUT = {}; T0 = time.time()
def note(m): print('<!-- %s (%.0f s) -->' % (m, time.time() - T0), flush=True)

# ------------------------------------------------------------------------------------------------- starts
def start(name):
    path = os.path.join(OUTD, 'eg_%s.pkl' % name)
    if os.path.exists(path): return pickle.load(open(path, 'rb'))
    if name == 'first':
        s = sim.load()
    elif name == 'second':
        s0 = start('first')
        s, rows, log = sim.run_cycles(TODAY, 60, 400, s0=copy.deepcopy(s0), every=86400, plans=[FIRST_PLAN], until=lambda s: bool(s.asc_log))
        s.asc_log = []
    elif name == 'late':
        s = copy.deepcopy(start('second'))
        s.unlocked = list(sim.MUTATE); s.unlocks = 10
        for m in sim.MUTANTS: s.mut[m] = max(s.mut[m], bn.F(1.0))
        s.mutagen = bn.big(10) ** 335; s.asc = 10
        sim.refresh_mut(s)
    elif name.startswith('second_m'):   # the long run's start with this much mutagen left (second_m9e6, second_m1e5)
        s = copy.deepcopy(start('second')); m = float(name[len('second_m'):])
        s.mutagen = bn.F(m)
        if m < 1e6: s.mut['mutantnexus'] = bn.F(1.6e5)   # a first run that brought ~1.8e5: all of it into the mutation
        sim.refresh_mut(s)
    pickle.dump(s, open(path, 'wb'))
    return s

# ------------------------------------------------------------------------------------------------- one run
def run(p, s0, prof=None, seed=1, hours=400):
    """Play from s0 until the first ascension. Returns the events (run age in hours)."""
    p = dict(p); s = copy.deepcopy(s0); s.asc_log = []; s.ewaste = 0.0
    ci = 60.0
    stay = 0
    if prof and prof.endswith('@stay'): prof = prof[:-5]; stay = 45 * 60   # the player stays 45 min after the run starts
    if prof: ci = cadence.gaps(prof, int(hours / 24) + 2, seed=seed, start=s.time)
    if stay:
        import bisect
        v = sorted(set(ci.visits) | {s.time + 120.0 * i for i in range(1, stay // 120 + 1)})
        def ci(now, v=v):
            i = bisect.bisect_right(v, now + 1e-6)
            return 3600.0 if i >= len(v) else max(1.0, v[i] - now)
    ev = {}
    def until(s):
        a = sim.run_age(s, p) / 3600
        for k in range(1, 6):
            if s.nexus >= k and 'n%d' % k not in ev: ev['n%d' % k] = a; ev['m%d' % k] = s.moth; ev['w%d' % k] = s.ewaste
        if s.casts.get('mirror') and 'mirror' not in ev: ev['mirror'] = a
        if s.saving_asc and 'save' not in ev: ev['save'] = a
        if s.saving_asc and not s.want_asc:
            r = sim.erate(s)
            if r > 0: ev['afford'] = a + max(0.0, sim.asc_cost(s) - s.energy) / r / 3600   # no spending while saving
        if s.asc_log:
            r = s.asc_log[0]; ev['asc'] = r['run_age'] / 3600; ev['afford'] = min(ev.get('afford', ev['asc']), ev['asc'])
            ev['premut'] = r['premut']; ev['cost'] = r['cost']; ev['espent'] = r['espent']
            return True
        ev['moth'] = s.moth; ev['mirrors'] = s.casts.get('mirror', 0); ev['rush'] = s.casts.get('larvarush', 0); ev['waste'] = s.ewaste
        return False
    sim.run_cycles(p, ci, s.time / 3600 + hours, s0=s, every=86400, until=until)
    return ev

def job(a):
    name, p, st, prof, seed, relax = a
    keep = dict(sim.NEX)
    try:
        for k, (m, e, l, g) in list(sim.NEX.items()):
            sim.NEX[k] = (0 if 'meat' in relax else m, 0 if 'energy' in relax else e, 0 if 'larvae' in relax else l, g)
        ev = run(p, start(st), prof, seed)
    finally:
        sim.NEX.clear(); sim.NEX.update(keep)
    ev.update(name=name, start=st, prof=prof or 'ideal', seed=seed)
    return ev

JOBS = 4
def runall(specs):
    """specs: (name, policy, start, cadence label) -> one row per (name, start, cadence), averaged over its seeds."""
    jobs = []
    for sp in specs:
        name, p, st, cad = sp[:4]; relax = sp[4] if len(sp) > 4 else ()
        prof, seeds = {c[0]: (c[1], c[2]) for c in CAD}[cad]
        for seed in seeds: jobs.append((name, p, st, prof, seed, relax))
    for st in sorted({j[2] for j in jobs}): start(st)       # build the cached starts once, before the workers
    with ProcessPoolExecutor(JOBS) as ex:
        res = list(ex.map(job, jobs))
    rows = []
    for sp in specs:
        name, p, st, cad = sp[:4]
        rs = [r for r in res if r['name'] == name and r['start'] == st and r['prof'] == ({c[0]: c[1] for c in CAD}[cad] or 'ideal')]
        row = {'name': name, 'start': st, 'cadence': cad, 'seeds': len(rs)}
        for k in ('n1', 'n2', 'n3', 'n4', 'n5', 'mirror', 'save', 'afford', 'asc', 'm5', 'w5'):
            v = [r[k] for r in rs if r.get(k) is not None]
            row[k] = sum(v) / len(v) if len(v) == len(rs) and v else None
        row['premut_min'] = min((r.get('premut') or 0.0) for r in rs)
        row['premut_max'] = max((r.get('premut') or 0.0) for r in rs)
        rows.append(row)
    return rows

f1 = lambda x: '-' if x is None else '%.1f' % x
def g2(x): return '%.1e' % x if x else '0'

# ------------------------------------------------------------------------------------------------- sections
def section_energy():
    """The energy model on its own (no meat, no larvae): from the moment nexus 4 is bought, with E4 energy left,
    rate 0.1 x nexus x (1 + M/(1000+M)) x em, cap 10,000 x nexus x em. Buy M1 lepidoptera at once, save 36,000,
    buy nexus 5 (+10,000), then lepidoptera to the post target and House of Mirrors, spending until the ascension
    cost reaches min(cap, b/ln 2) and saving it. Exact to the 10 s step. Hours after nexus 4."""
    def model(M1, em, N, C0, post, E4=8000.0, dt=10.0):
        t = 0.0; E = E4; M = 0.0; nex = 4; S = 0.0; b = 50000.0 * N; t5 = None
        cap = lambda: 10000.0 * nex * em
        while True:
            if nex == 4:
                if M < M1:
                    n = min(M1 - M, math.floor(E / 10)); M += n; E -= 10 * n; S += 10 * n
                if M >= M1 and E >= 36000: E += 10000 - 36000; S += 36000; nex = 5; t5 = t
            if nex == 5:
                c = C0 / 2 ** (S / b); C = min(cap(), b / math.log(2))
                if c <= C:
                    if E >= c: return t5 / 3600, t / 3600
                elif M < post:
                    n = min(post - M, math.floor(E / 10)); M += n; E -= 10 * n; S += 10 * n
                else:
                    n = math.floor(E / 2500); E -= 2500 * n; S += 2500 * n
            E = min(E + 0.1 * nex * (1 + M / (1000.0 + M)) * em * dt, cap()); t += dt
    runs = [('first run (no mutation)', 1.0, 1.0, 5e6), ('after the 1st ascension (lepidoptera mutation 1e6)', 1.998004, 1.598802, 5.6e6),
            ('11th ascension (mutation 1e6)', 1.998004, 1.598802, 5e6 * 1.12 ** 10)]
    M1s = [0, 300, 600, 1000, 1500, 2000, 4000]
    res = {}
    print('\n### The energy model alone: hours after nexus 4 to nexus 5 / to an affordable ascension\n')
    print('| run | lepidoptera after nexus 5 | ' + ' | '.join('%d before' % m for m in M1s) + ' |')
    print('|' + ' --- |' * (len(M1s) + 2))
    for lab, em, N, C0 in runs:
        for post in (4000, 10000, 30000, 10 ** 9):
            cells = []
            for M1 in M1s:
                a, b = model(M1, em, N, C0, post); cells.append((a, b))
            res[(lab, post)] = cells
            print('| %s | %s | ' % (lab, 'all' if post == 10 ** 9 else '{:,}'.format(post)) + ' | '.join('%.1f / %.1f' % c for c in cells) + ' |')
    # the closed-form optimum for nexus 5 alone
    print('\nNexus 5 alone: time = (D + 10 M) (1000 + M) / ((1000 + 2 M) x 0.4 em) with D the energy still missing, '
          'minimal at M = sqrt(50 D - 250,000) - 500: %s.' % ', '.join('D %s: %.0f' % ('{:,}'.format(D), max(0, math.sqrt(max(0, 50 * D - 250000)) - 500)) for D in (8000, 18000, 28000, 36000)))
    OUT['energy'] = {'%s|%s' % k: v for k, v in res.items()}

def section_bind():
    specs = []
    for st in ('first', 'second', 'late'):
        for rl in ((), ('meat',), ('larvae',), ('energy',), ('meat', 'larvae')):
            specs.append(('free ' + ('+'.join(rl) or 'none'), plan(st), st, 'ideal', rl))
    rows = runall(specs)
    print('\n### What binds: the plan with each nexus price made free (ideal cadence, run age in hours)\n')
    print('| run | free | nexus 1 | 2 | 3 | 4 | 5 | affordable |'); print('| --- | --- | --- | --- | --- | --- | --- | --- |')
    for r in rows:
        print('| %s | %s | %s | %s | %s | %s | %s | %s |' % (r['start'], r['name'][5:], f1(r['n1']), f1(r['n2']), f1(r['n3']), f1(r['n4']), f1(r['n5']), f1(r['afford'])))
    OUT['bind'] = rows

def table(rows, title, cols=('n4', 'n5', 'mirror', 'afford', 'asc')):
    print('\n### %s\n' % title)
    names = {'n4': 'nexus 4', 'n5': 'nexus 5', 'mirror': 'first mirror', 'afford': 'ascension affordable', 'asc': 'ascend (at a visit)', 'w5': 'energy lost to the cap by nexus 5'}
    print('| run | cadence | policy | ' + ' | '.join(names[c] for c in cols) + ' | premutagen at ascension |')
    print('|' + ' --- |' * (len(cols) + 4))
    for r in rows:
        print('| %s | %s | %s | ' % (r['start'], r['cadence'], r['name']) + ' | '.join(f1(r[c]) if c != 'w5' else ('%.0f' % r[c] if r[c] is not None else '-') for c in cols) +
              ' | %s |' % (g2(r['premut_min']) if r['premut_min'] == r['premut_max'] else '%s to %s' % (g2(r['premut_min']), g2(r['premut_max']))))

def section_plan():
    specs = []
    for st in ('first', 'second', 'late'):
        for cad, _, _ in CAD:
            specs.append(('today', TODAY, st, cad))
            if st == 'first': specs.append(('today, literal (climb takes the nexus larvae)', dict(TODAY, no_nexres=True), st, cad))
            specs.append(('plan', plan(st), st, cad))
    rows = runall(specs)
    table(rows, "Today's defaults against the plan (run age in hours; human and busy: mean of 5 seeds)", cols=('n4', 'n5', 'mirror', 'afford', 'asc', 'w5'))
    OUT['plan'] = rows

def section_parts():
    """Each change on its own: added to today's defaults one at a time (cumulative), and left out of the plan."""
    specs = []
    for st in ('first', 'late'):
        steps = [('today', TODAY),
                 ('+ save below nexus 5', dict(TODAY, **SAVE_PLAN)),
                 ('+ 1,000 lepidoptera first at nexus 4', dict(TODAY, **SAVE_PLAN, **EARLY, moth_N5=4000)),
                 ('+ just-in-time hold for nexus 5', dict(TODAY, **SAVE_PLAN, **EARLY, **JIT, moth_N5=4000)),
                 ('+ run target after nexus 5 (= plan)', plan(st))]
        out = [('plan without saving below nexus 5', dict(plan(st), spare_pre5=None, pre5_excess=None)),
               ('plan without the early lepidoptera', dict(plan(st), moth_N=0)),
               ('plan without the just-in-time hold', dict(plan(st), pre5_excess=None, jit5=None)),
               ('plan with 4,000 after nexus 5', dict(plan(st), moth_N5=4000)),
               ('plan, all energy into lepidoptera after nexus 5', dict(plan(st), moth_N5=1e9))]
        for cad in ('ideal', 'human', 'busy'):
            for name, p in steps + out:
                specs.append((name, p, st, cad))
    rows = runall(specs)
    table(rows, 'What each change contributes', cols=('n4', 'n5', 'afford'))
    OUT['parts'] = rows

def section_first5():
    specs = []
    for m5 in (4000, 8000, 10000, 15000, 30000):
        for cad in ('ideal', 'human', 'busy'):
            specs.append(('plan, %s after nexus 5' % '{:,}'.format(m5), dict(plan('first'), moth_N5=m5), 'first', cad))
    for cad in ('ideal', 'human'):
        specs.append(('plan, 10,000 then 30,000 from day 3 (long-run mode left on)', dict(plan('first'), moth_late=(3 * 86400, 30000)), 'first', cad))
    rows = runall(specs)
    table(rows, 'First run: lepidoptera after nexus 5 against the mutagen it brings', cols=('n5', 'mirror', 'afford'))
    OUT['first5'] = rows

def section_meat():
    P = plan('first')
    V = [('plan (age multiple 3)', P), ('age multiple 5', dict(P, theta_age=5)), ('age multiple 10', dict(P, theta_age=10)),
         ('share 0.3', dict(P, share=0.3)), ('share 0.8', dict(P, share=0.8)), ('bank 10', dict(P, bank=10)), ('bank off', dict(P, bank=0)),
         ('territory 0.05', dict(P, f=0.05)), ('territory 0.2', dict(P, f=0.2)),
         ('nexus larvae held from 10,000 s', dict(P, nexus_secs=10000)), ('nexus larvae held from 40,000 s', dict(P, nexus_secs=40000))]
    specs = [(n, p, 'first', cad) for cad in ('ideal', 'human') for n, p in V]
    rows = runall(specs)
    table(rows, 'First run: the meat-side settings under the plan', cols=('n4', 'n5', 'afford'))
    OUT['meat'] = rows

def section_longstart():
    specs = []
    for st in ('second', 'second_m9e6', 'second_m1e5'):
        for cad in ('ideal', 'human'):
            specs.append(('today + long-run lepidoptera', dict(TODAY, moth_late=(3 * 86400, 30000)), st, cad))
            specs.append(('plan', plan('second'), st, cad))
    rows = runall(specs)
    table(rows, 'The long run\'s start with less mutagen left (second: ~7e7; second_m9e6; second_m1e5 with 1.6e5 lepidoptera mutation)', cols=('n4', 'n5', 'mirror'))
    OUT['longstart'] = rows

def section_cadence():
    specs = []
    for st in ('first', 'late'):
        for cad in ('human', 'human, 45 min stay at the start', 'twice', 'glance+'):
            specs.append(('today', TODAY, st, cad)); specs.append(('plan', plan(st), st, cad))
    rows = runall(specs)
    table(rows, 'Other cadences: a 45-minute stay after the run starts, twice a day, single looks plus two more', cols=('n4', 'n5', 'afford', 'asc'))
    OUT['cadence'] = rows

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--jobs' in sys.argv: JOBS = int(sys.argv[sys.argv.index('--jobs') + 1]); args = [a for a in args if a != str(JOBS)]
    want = args or ['energy', 'bind', 'plan', 'parts', 'first5', 'meat', 'longstart', 'cadence']
    for sec in want:
        globals()['section_' + sec](); note(sec)
    json.dump(OUT, open(os.path.join(OUTD, 'early_game.json'), 'w'), default=str)
