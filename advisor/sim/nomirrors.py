"""Every achievement without House of Mirrors (advisor/NO-MIRRORS.md).

Starts from the owner's 20.1 h save, no crystals, premutagen as the mean of the game's roll, as in ASCENSION.md.
Territory empower is modelled (sim.EMPOWER_MODEL) in every section except where a row says "empower off".

Sections (default: all):
  bound     the arithmetic behind the bounding arguments                                          (instant)
  stall     the long run after the mirrors route's first ascension, with each other spell instead
            of mirrors, empower off and on: expansions stall                                       (~1 min)
  transfer  premutagen a run earns against the mutagen it starts with (no spells; each spell with
            its mutation; run lengths 4-32 days with swarmwarp)                                   (~6 min with 4 jobs)
  route     the no-mirrors route from the save: ascend, cast swarmwarp, let mutagen compound,
            then one run to 5,000 expansions. Variants, and a person's cadence                    (~7 min with 4 jobs)
  nowarp    the same route with larva rush, clone larvae, territory rush or no spell instead      (~1 min)
  hybrid    mirrors in one run only: the long run (the existing plan), run 1, or a last run       (~2 min)
All sections: about 11 minutes with 4 jobs.
Usage (from the repo root):
    python3 -I advisor/sim/nomirrors.py [sections] [--jobs N]
Writes advisor/modelcheck/out/nomirrors_<section>.json and prints markdown.
"""
import copy, json, math, os, pickle, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim, bignum as bn, cadence, longrun_rules as lr

OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
lg = lambda x: bn.lg(x) if x > 0 else float('-inf')
SPEC4 = lr.SPEC4          # the long-run climb rules as specified in ASCENSION.md A.10.2 (pass 4)
# Mutations for the no-mirrors route: lepidoptera, warp and bat first (any order costs 1, 15,625, 2.44e8), then
# frequency, meta-mutation and territory; the other four only for the "unlock 10" achievement. An unlock after the
# third is bought only when it costs at most 30% of the mutagen held.
UNLOCK = ['mutatenexus', 'mutateswarmwarp', 'mutatebat', 'mutatefreq', 'mutateeach', 'mutatearmy', 'mutaterush', 'mutateclone',
          'mutatemeat', 'mutatehatchery']
PLAN = {'unlock': UNLOCK, 'unlock_free': 3, 'unlock_max_share': 0.3,
        'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6, 'mutantswarmwarp': 0.1, 'mutantbat': 0.1, 'mutanteach': 0.01, 'mutantarmy': 0.3}}
# The route's policy: the pass-4 long-run rules, but lepidoptera stay at 4,000 (no raise to 30,000 at run age 3 d: that
# costs 300,000 energy in each of ~30 runs), swarmwarp with all energy, 2,000 bats, territory empower on.
WARP = dict(SPEC4, spells=['warp'], bat_N=2000, empower=True, moth_late=None)

def run_par(fn, specs, jobs):
    with ProcessPoolExecutor(jobs) as ex:
        return list(ex.map(fn, specs))

# ---------------------------------------------------------------------------------------------------- bound
def section_bound(jobs):
    print('\n### The arithmetic\n')
    tot = lambda L: math.log10(10 / (1 - 1 / 2.45)) + L * math.log10(2.45)      # territory for expansions 1..L, log10
    for L in (200, 500, 1000, 2000, 5000):
        print('- expansions 1..%d cost 10^%.0f territory in all; with mirrors that is %.0f casts from a fixed income (0.774 levels per cast).' % (L, tot(L), L / 0.774))
    print('- larvae from expansions: 1.1^L, i.e. 10^%.1f at L = 5,000.' % (5000 * math.log10(1.1)))
    print('- endless has no twin: N endless bought needs N larvae. 1e62 endless needs 1e62 larvae over all runs.')
    print('- unlocks: the k-th costs 15,625^(k-1); 6 unlocks %.3g in all, 10 unlocks %.3g.' % (sum(15625.0 ** k for k in range(6)), sum(15625.0 ** k for k in range(10))))
    print('- premutagen: hatchery level H gives about 1.2544^H (H = log10(meat / 300)), so premutagen ~ meat^%.4f; expansion L gives 1.12^L.' % math.log10(1.2544))
    print('- the territory mutation is 1 + 0.001 n^0.2: x2 at 1e15, x10^17 at 1e100, x10^47 at 1e250 (a power law, not negligible at large n).')

# ---------------------------------------------------------------------------------------------------- stall
def stall_run(args):
    name, spells, emp, days = args
    sim.EMPOWER_MODEL = emp
    s0 = lr.start_state(); s = copy.deepcopy(s0); s.ach_log = []
    p = dict(SPEC4, spells=spells, empower=emp, ascend=None)
    s2, rows, _ = sim.run_cycles(p, 300, s.time / 3600 + 24 * days + 1, s0=s, every=86400)
    return {'name': name, 'traj': [(round(r['age'] / 24), r['exp'], r['llarva'], r['lmeat'], sim.NAMES[r['top']], lg(r['premut'])) for r in rows],
            'casts': {k: v for k, v in s2.casts.items()}}

def section_stall(jobs, days=40):
    specs = [('House of Mirrors (the existing plan)', ['mirror'], False, days)]
    for sp, lab in (('warp', 'swarmwarp'), ('larvarush', 'larva rush'), ('terrrush', 'territory rush'), ('clone', 'clone larvae'), ('meatrush', 'meat rush')):
        specs.append((lab + ', empower off', [sp], False, days))
    specs += [('swarmwarp, empower on', ['warp'], True, days), ('no spells, empower on', [], True, days)]
    res = run_par(stall_run, specs, jobs)
    json.dump(res, open(os.path.join(OUTD, 'nomirrors_stall.json'), 'w'))
    print('\n### The long run without mirrors (start: the mirrors route\'s first ascension, mutagen 6e7)\n')
    print('| energy spent on | expansions day 10 / 20 / 40 | log10 larvae/s day 40 | log10 meat/s day 40 | top tier day 40 | log10 premutagen day 40 |')
    print('| --- | --- | --- | --- | --- | --- |')
    for r in res:
        t = {d: x for d, *x in r['traj']}
        e = lambda d: str(t[d][0]) if d in t else '-'
        last = r['traj'][-1]
        print('| %s | %s / %s / %s | %.1f | %.0f | %s | %.1f |' % (r['name'], e(10), e(20), e(40), last[2], last[3], sim.LABEL.get(last[4], last[4]), last[5]))
    return res

# ---------------------------------------------------------------------------------------------------- transfer
def transfer_run(args):
    """A run started just after an ascension holding 10^logM mutagen (mutations bought by `plan`), D days, no
    mirrors. The start is the mirrors route's first ascension with its mutagen and mutations replaced."""
    tag, logM, days, spells, emp, plan, bat_N = args
    sim.EMPOWER_MODEL = emp
    s = copy.deepcopy(lr.start_state())
    s.mut = {m: bn.F(0.0) for m in sim.MUTANTS}; s.unlocked = []; s.unlocks = 0
    s.mutagen = bn.big(10.0) ** logM if logM > 300 else bn.F(10.0 ** logM)
    sim.apply_plan(s, plan); s.ach_log = []
    p = dict(SPEC4, spells=spells, ascend=None, empower=emp, bat_N=bat_N)
    s2, rows, _ = sim.run_cycles(p, 300, s.time / 3600 + 24 * days, s0=s, every=86400)
    return {'tag': tag, 'logM': logM, 'days': days, 'spells': spells, 'emp': emp, 'exp': s2.exp, 'hatch': s2.hatch, 'lpremut': lg(s2.premut),
            'lmeat': rows[-1]['lmeat'], 'llarva': rows[-1]['llarva'], 'q': sim.epow(s2) * s2.spw.get(spells[0], 1.0) if spells else 1.0,
            'unlocks': s.unlocks, 'ach': sorted(n for _, n in s2.ach_log)}

PLAN_OLD = {'unlock': ['mutatenexus', 'mutatefreq', 'mutateeach', 'mutatearmy', 'mutatebat', 'mutaterush', 'mutateclone', 'mutateswarmwarp', 'mutatemeat', 'mutatehatchery'],
            'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6, 'mutanteach': 0.01, 'mutantbat': 0.01, 'mutantrush': 0.01, 'mutantclone': 0.01,
                    'mutantswarmwarp': 0.01, 'mutantmeat': 0.01, 'mutantarmy': 0.5}}
def spell_plan(sp):
    up, mu = {'warp': ('mutateswarmwarp', 'mutantswarmwarp'), 'larvarush': ('mutaterush', 'mutantrush'), 'terrrush': ('mutaterush', 'mutantrush'),
              'clone': ('mutateclone', 'mutantclone')}[sp]
    rest = [u for u in UNLOCK[1:] if u not in (up, 'mutatebat', 'mutatefreq')]
    return {'unlock': ['mutatenexus', 'mutatefreq', 'mutatebat', up] + rest,
            'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6, 'mutantbat': 0.1, mu: 0.1, 'mutanteach': 0.01, 'mutantarmy': 0.3}}

def section_transfer(jobs):
    Ms = [8, 16, 32, 64, 96, 128, 256]
    specs = [('none', m, 8, [], e, PLAN_OLD, 0) for e in (False, True) for m in Ms]
    for sp in ('warp', 'larvarush', 'clone', 'terrrush'):
        specs += [('spell', m, d, [sp], True, spell_plan(sp), 2000) for m in (16, 32, 64, 96) for d in (4, 16)]
    LM = (7, 10, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256); D = (4, 6, 8, 12, 16, 24, 32)
    specs += [('length', m, d, ['warp'], True, PLAN, 2000) for m in LM for d in D]
    res = run_par(transfer_run, specs, jobs)
    json.dump(res, open(os.path.join(OUTD, 'nomirrors_transfer.json'), 'w'))
    get = lambda **k: [r for r in res if all((r[a] == v) for a, v in k.items())][0]
    print('\n### One 8-day run without spells: what it earns against the mutagen it starts with\n')
    print('| log10 mutagen at the start | empower off: expansions | log10 premutagen | empower on: expansions | log10 premutagen | log10 meat/s | log10 larvae/s |')
    print('| --- | --- | --- | --- | --- | --- | --- |')
    for m in Ms:
        a = get(tag='none', logM=m, emp=False); b = get(tag='none', logM=m, emp=True)
        print('| %d | %d | %.1f | %d | %.1f | %.0f | %.1f |' % (m, a['exp'], a['lpremut'], b['exp'], b['lpremut'], b['lmeat'], b['llarva']))
    print('\n### The same with each spell and its mutation (bats 2,000; 10% of mutagen in the spell\'s mutation and in the bat mutation)\n')
    print('| spell | spell power at log10 M = 16 / 32 / 64 / 96 | log10 premutagen after 4 days | after 16 days |')
    print('| --- | --- | --- | --- |')
    for sp in ('warp', 'larvarush', 'clone', 'terrrush'):
        g = lambda m, d: get(tag='spell', logM=m, days=d, spells=[sp])
        print('| %s | %s | %s | %s |' % (sp, ' / '.join('%.0f' % g(m, 4)['q'] for m in (16, 32, 64, 96)),
                                         ' / '.join('%.1f' % g(m, 4)['lpremut'] for m in (16, 32, 64, 96)),
                                         ' / '.join('%.1f' % g(m, 16)['lpremut'] for m in (16, 32, 64, 96))))
    print('\n### Swarmwarp runs by length: growth of log10 mutagen per day (the route\'s mutation plan)\n')
    print('| log10 M at the start | swarmwarp power | ' + ' | '.join('%d d' % d for d in D) + ' | expansions in 8 d |'); print('|' + ' --- |' * (len(D) + 3))
    for m in LM:
        cells = []
        for d in D:
            r = get(tag='length', logM=m, days=d); nxt = max(m, r['lpremut']) + math.log10(1 + 10 ** -abs(m - r['lpremut']))
            cells.append('%.4f' % (math.log(nxt / m) / d))
        print('| %d | %.0f | %s | %d |' % (m, get(tag='length', logM=m, days=8)['q'], ' | '.join(cells), get(tag='length', logM=m, days=8)['exp']))
    return res

# ---------------------------------------------------------------------------------------------------- route
def make_rule(sched, final_logM, min_asc=20):
    """Run length by the mutagen held: sched = [(log10 M below which, days)]; at final_logM and with min_asc
    ascensions done, the run is not ended (the 5,000-expansion run)."""
    def rule(s):
        m = lg(s.mutagen) if s.mutagen > 0 else 0.0
        if m >= final_logM and s.asc >= min_asc: return None
        for lim, d in sched:
            if m < lim: return {'after': d * 86400}
        return {'after': 0}
    return rule
SCHED = [(10, 6), (32, 16), (1e9, 0)]       # days before saving for the ascension starts: 6 below 1e10, 16 below 1e32, then at once

def route_run(args):
    name, opts = args
    sim.EMPOWER_MODEL = opts.get('emp', True)
    s = sim.load(); s.ach_log = []; s.ewaste = 0.0
    days = opts.get('days', 420)
    p = dict(WARP, **opts.get('p', {}))
    p['ascend_rule'] = make_rule(opts.get('sched', SCHED), opts.get('final', 250))
    plan = dict(PLAN, **opts.get('plan', {}))
    ci = cadence.gaps(opts['cadence'], days + 2, seed=opts.get('seed', 1), start=s.time) if opts.get('cadence') else opts.get('ci', 300)
    t0 = time.time()
    s2, rows, log = sim.run_cycles(p, ci, s.time / 3600 + 24 * days, plans=[plan] * 200, s0=s, every=86400,
                                   until=lambda s: s.exp >= 5000)
    when = {n: t / 86400 for t, n in s2.ach_log}
    asc = [{'day': r['time'] / 86400, 'run_days': r['run_age'] / 86400, 'exp': r['exp'], 'hatch': r['hatch'], 'lpremut': lg(r['premut']),
            'lmut': lg(r['mutagen_after'])} for r in log]
    return {'name': name, 'when': when, 'asc': asc, 'end_day': s2.time / 86400, 'exp': s2.exp, 'unearned': list(s2.unearned),
            'ach_have': sorted(s2.ach_have), 'n_asc': s2.asc, 'secs': time.time() - t0, 'lmut_end': lg(s2.mutagen),
            'endless': lg(s2.bought.get('overmind6', 0)) if s2.bought.get('overmind6', 0) else None, 'casts': dict(s2.casts)}

KEYS = [('ascension3', '20 ascensions'), ('mutation3', '6 unlocks'), ('mutation4', '10 unlocks'), ('overmind6_1', 'endless 1'),
        ('overmind6_3', 'endless 1e62'), ('expansion6', 'exp 500'), ('expansion7', 'exp 1,000'), ('expansion8', 'exp 2,000'), ('expansion9', 'exp 5,000')]

def route_table(res, title):
    print('\n### %s\n' % title)
    print('| variant | ' + ' | '.join(l for _, l in KEYS) + ' | ascensions | last achievement (day) | still missing |')
    print('|' + ' --- |' * (len(KEYS) + 4))
    for r in res:
        w = r['when']; d = lambda n: '%.0f' % w[n] if n in w else '-'
        miss = [n for n in r['unearned']] + [n for n, _ in KEYS if n not in w and n not in r['ach_have']]
        last = max(w.values()) if w else 0
        print('| %s | %s | %d | %.0f | %s |' % (r['name'], ' | '.join(d(n) for n, _ in KEYS), r['n_asc'], last, ', '.join(sorted(set(miss))) or 'none'))

def section_route(jobs):
    V = [('**base**: swarmwarp, run length by mutagen (6 / 16 days / at once), lepidoptera 4,000, final run from 1e250', {}),
         ('lepidoptera 30,000 from run age 3 d (as the mirrors plan)', {'p': {'moth_late': SPEC4['moth_late']}}),
         ('lepidoptera 1,000', {'p': {'moth_N': 1000}}),
         ('lepidoptera 10,000', {'p': {'moth_N': 10000}}),
         ('final run from 1e200', {'final': 200}),
         ('final run from 1e280', {'final': 280}),
         ('runs 12 days below 1e32', {'sched': [(10, 6), (32, 12), (1e9, 0)]}),
         ('runs 24 days below 1e32', {'sched': [(10, 6), (32, 24), (1e9, 0)]}),
         ('runs of 16 days throughout', {'sched': [(1e9, 16)]}),
         ('runs 4 days from 1e24 (not 1e32)', {'sched': [(10, 6), (24, 16), (1e9, 0)]}),
         ('all ten unlocks as soon as affordable', {'plan': {'unlock_max_share': None}}),
         ('territory mutation 0', {'plan': {'buy': dict(PLAN['buy'], mutantarmy=0)}}),
         ('territory mutation 0, final run from 1e280', {'plan': {'buy': dict(PLAN['buy'], mutantarmy=0)}, 'final': 280}),
         ('bats 0', {'p': {'bat_N': 0}}),
         ('bats 6,000', {'p': {'bat_N': 6000}}),
         ('empower off', {'emp': False, 'days': 300}),
         ('human cadence', {'cadence': 'human'}),
         ('human cadence, seed 2', {'cadence': 'human', 'seed': 2}),
         ('busy cadence', {'cadence': 'busy'}),
         ('glance+ cadence', {'cadence': 'glance+'}),
         ('twice a day', {'cadence': 'twice'})]
    res = run_par(route_run, V, jobs)
    json.dump(res, open(os.path.join(OUTD, 'nomirrors_route.json'), 'w'))
    route_table(res, 'The no-mirrors route from the 20.1 h save: day each achievement falls (days from the save)')
    b = res[0]
    print('\n### Base route, ascension by ascension\n')
    print('| # | day | run length (d) | expansions | hatchery | log10 premutagen | log10 mutagen after |'); print('| --- | --- | --- | --- | --- | --- | --- |')
    for i, a in enumerate(b['asc']):
        print('| %d | %.1f | %.1f | %d | %d | %.1f | %.1f |' % (i + 1, a['day'], a['run_days'], a['exp'], a['hatch'], a['lpremut'], a['lmut']))
    print('\nFinal run: expansions %d on day %.1f; log10 mutagen %.0f; endless bought 10^%s.' % (b['exp'], b['end_day'], b['lmut_end'], '%.0f' % b['endless'] if b['endless'] else '-'))
    other = sorted((t, n) for n, t in b['when'].items())
    print('\nEvery achievement in the base route (day): ' + ', '.join('%s %.0f' % (n, t) for t, n in other))
    return res

def section_nowarp(jobs):
    """The same route with another energy sink than swarmwarp, or none: what stays out of reach."""
    o = lambda sp, mu: {'p': {'spells': sp}, 'days': 400,
                        'plan': {'unlock': ['mutatenexus', 'mutatebat', mu, 'mutatefreq', 'mutateeach', 'mutatearmy'] +
                                 [u for u in UNLOCK if u not in ('mutatenexus', 'mutatebat', mu, 'mutatefreq', 'mutateeach', 'mutatearmy')],
                                 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6, 'mutantbat': 0.1, 'mutant' + mu[6:]: 0.1, 'mutanteach': 0.01, 'mutantarmy': 0.3}}}
    V = [('larva rush instead of swarmwarp', o(['larvarush'], 'mutaterush')),
         ('clone larvae instead of swarmwarp', o(['clone'], 'mutateclone')),
         ('territory rush instead of swarmwarp', o(['terrrush'], 'mutaterush')),
         # no spells: energy has to be spent on something for the ascension cost to fall; lepidoptera count (10 each)
         ('no spells: all energy into lepidoptera (they count as spent energy)', dict(o([], 'mutaterush'), p={'spells': [], 'bat_N': 0, 'moth_N': 1e12}))]
    res = run_par(route_run, V, jobs)
    json.dump(res, open(os.path.join(OUTD, 'nomirrors_nowarp.json'), 'w'))
    route_table(res, 'Without swarmwarp either: the same route with another spell, or none, 400 days (days from the save)')
    for r in res:
        print('- %s: log10 mutagen held at day 400: %.1f; most expansions in a run: %d' % (r['name'], r['lmut_end'], max([a['exp'] for a in r['asc']] + [r['exp']])))
    return res

# ---------------------------------------------------------------------------------------------------- hybrid
def hybrid_run(args):
    """Mirrors in one run only. kind 'mirror1': run 1 (from the save) casts mirrors, as in the existing plan, then
    the no-mirrors route. 'finalmirror': the no-mirrors route until the mutagen held reaches 10^switch with 20
    ascensions done, then one last run that casts mirrors instead of swarmwarp until 5,000 expansions."""
    name, kind, opts = args
    sim.EMPOWER_MODEL = True
    s = sim.load(); s.ach_log = []
    days = opts.get('days', 420)
    p = dict(WARP, ascend_rule=make_rule(opts.get('sched', SCHED), opts.get('final', 250)))
    t0 = time.time()
    if kind == 'mirror1':
        q = dict(p, spells=['mirror', 'larvarush'], ascend_rule=lambda s: {'after': 0})   # as the existing plan: ascend at once
        s, _, _ = sim.run_cycles(q, 300, 24 * 30, plans=[PLAN], s0=s, every=86400, until=lambda s: bool(s.asc_log))
    s2, rows, log = sim.run_cycles(p, 300, s.time / 3600 + 24 * days, plans=[PLAN] * 200, s0=s, every=86400,
                                   until=lambda st: st.exp >= 5000 or (kind == 'finalmirror' and lg(st.mutagen) >= opts.get('switch', 64) and st.asc >= 20))
    if kind == 'finalmirror' and s2.exp < 5000:
        # the last run: keep going, mirrors instead of swarmwarp, never ascend
        q = dict(SPEC4, spells=['mirror'], empower=True, bat_N=0, ascend=None)
        s2, rows, _ = sim.run_cycles(q, 300, s2.time / 3600 + 24 * days, s0=s2, every=86400, until=lambda st: st.exp >= 5000)
    when = {n: t / 86400 for t, n in s2.ach_log}
    return {'name': name, 'when': when, 'end_day': s2.time / 86400, 'exp': s2.exp, 'unearned': list(s2.unearned), 'ach_have': sorted(s2.ach_have),
            'n_asc': s2.asc, 'secs': time.time() - t0, 'asc': [], 'lmut_end': lg(s2.mutagen), 'endless': None, 'casts': dict(s2.casts)}

def mirrorlong_run(args):
    """The existing plan with mirrors in the long run only: run 1 from the save casts swarmwarp instead of mirrors
    (ascend at the earliest moment, then lepidoptera and frequency mutations as in ASCENSION.md), then the long run
    with the pass-4 rules and mirrors. The quick runs are not simulated: any spell spends energy as well as mirrors."""
    name, days, prof = args
    sim.EMPOWER_MODEL = False
    s = sim.load(); s.ach_log = []
    FIRST = {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6}}
    q = dict(lr.BASE, spells=['warp'], ascend=[{'after': 0}])
    s1, _, log = sim.run_cycles(q, 60, 24 * 30, plans=[FIRST], every=3600, until=lambda s: bool(s.asc_log))
    rec = log[0]
    s = copy.deepcopy(s1); s.ach_log = []
    gap = cadence.gaps(prof, days, seed=1, start=s.time) if prof != 'every5' else 300
    s2, rows, _ = sim.run_cycles(dict(SPEC4, ascend=None), gap, s.time / 3600 + 24 * days, s0=s, every=86400, until=lambda st: st.exp >= 5000)
    when = {n: (t - s1.time) / 86400 for t, n in s2.ach_log}
    return {'name': name, 'asc1_day': rec['time'] / 86400, 'asc1_mutagen': lg(rec['premut']), 'when': when, 'cadence': prof}

def section_hybrid(jobs):
    ml = run_par(mirrorlong_run, [('run 1 without mirrors, long run with mirrors', 110, 'every5'),
                                  ('run 1 without mirrors, long run with mirrors (human cadence)', 110, 'human')], jobs)
    json.dump(ml, open(os.path.join(OUTD, 'nomirrors_mirrorlong.json'), 'w'))
    print('\n### Mirrors in the long run only (run 1 casts swarmwarp instead)\n')
    print('| variant | first ascension (days from the save) | log10 mutagen it brings | endless 1 | endless 1e62 | exp 2,000 | exp 5,000 (days of the long run) |')
    print('| --- | --- | --- | --- | --- | --- | --- |')
    for r in ml:
        w = r['when']; d = lambda n: '%.0f' % w[n] if n in w else '-'
        print('| %s | %.1f | %.1f | %s | %s | %s | %s |' % (r['name'], r['asc1_day'], r['asc1_mutagen'], d('overmind6_1'), d('overmind6_3'), d('expansion8'), d('expansion9')))
    V = [('mirrors in run 1 only (to the first ascension), then the no-mirrors route', 'mirror1', {}),
         ('no mirrors until mutagen 1e64 and 20 ascensions, then one run with mirrors to 5,000 expansions', 'finalmirror', {'switch': 64}),
         ('the same, switching at mutagen 1e32', 'finalmirror', {'switch': 32}),
         ('the same, switching at mutagen 1e128', 'finalmirror', {'switch': 128})]
    res = run_par(hybrid_run, V, jobs)
    json.dump(res, open(os.path.join(OUTD, 'nomirrors_hybrid.json'), 'w'))
    route_table(res, 'Mirrors in one run only (days from the save)')
    for r in res: print('- %s: ends day %.0f, %d ascensions, casts %s' % (r['name'], r['end_day'], r['n_asc'], r['casts']))
    return res

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = 4
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    want = args or ['bound', 'stall', 'transfer', 'route', 'nowarp', 'hybrid']
    lr.start_state()
    T = time.time()
    for w in want:
        globals()['section_' + w](jobs)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
