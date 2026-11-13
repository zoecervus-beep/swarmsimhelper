"""Long-run climb rules under a person's cadence (advisor/ASCENSION.md, "Long-run climb rules").

Starts from the first ascension from the owner's 20.1 h save (lepidoptera + frequency mutations, no crystals),
cached in advisor/modelcheck/out/lr_start.pkl, and plays the long run under cadences from cadence.py.

Sections:
  diag      why slow visits hurt: the pass-2 policy and single fixes, under every cadence          (~2 min)
  rules     the pieces of the two rules and their alternatives, four cadences, two more seeds        (~5 min)
  rounds    following the push suggestions several times per visit                               (~2 min)
  glance    single looks per session: what fixes them                                             (~1 min)
  final     the specified rules (SPEC) under four cadences                                       (~2 min)
  early     no harm early: the mode against the current rules, fresh run / after an ascension / the save, 1-7 days (~2 min)
  empower   territory empower (sim.EMPOWER_MODEL, option `empower`), long run with and without     (~2 min)
Usage (from the repo root):
    python3 -I advisor/sim/longrun_rules.py [sections] [--days N] [--jobs N]
Each long run takes 0.3-2 minutes; variants run in parallel (--jobs, default 4). All sections: about 15 minutes.
Results also go to advisor/modelcheck/out/longrun_rules_<section>.json.
"""
import copy, json, math, os, pickle, sys, time
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ['SAVE'] = os.path.join(HERE, 'example_save_20h.json')
import sim, bignum as bn, cadence

OUTD = os.path.join(HERE, '..', 'modelcheck', 'out'); os.makedirs(OUTD, exist_ok=True)
POLICY = json.load(open(os.path.join(HERE, 'policy.json')))
BASE = dict(POLICY, age0=72406)
# pass 2's achievement policy, unchanged
PASS2 = dict(BASE, theta_age=20, moth_N=30000, faster_aware='multi', push={'goal': 20, 'share': 0.5, 'base': 0.02, 'twin_mult': 1e6})
# The rules as specified for the advisor (ASCENSION.md, "Long-run climb rules"): the existing rules below hive network
# (tier 11) unchanged; from tier 11 up, multi-faster climbing and push with twin protection; twins also offered after
# hatching in the same visit. Age multiple and lepidoptera are the player's settings (long run: 30,000).
SPEC_RULES = dict(faster_aware='multi', push={'goal': 20, 'share': 0.5, 'base': 0.02, 'twin_mult': 1e6},
                  lr_age=2 * 86400, moth_late=(3 * 86400, 30000))
SPEC = dict(BASE, **SPEC_RULES)
SPEC_EARLY = SPEC
FIRST_PLAN = {'unlock': ['mutatenexus', 'mutatefreq'], 'buy': {'mutantnexus': 1e6, 'mutantfreq': 1e6}}
lg = lambda x: bn.lg(x) if x > 0 else float('-inf')

def start_state():
    path = os.path.join(OUTD, 'lr_start.pkl')
    if os.path.exists(path): return pickle.load(open(path, 'rb'))
    q = dict(BASE, ascend=[{'after': 0}])
    s, rows, log = sim.run_cycles(q, 60, 24 * 30, plans=[FIRST_PLAN], every=3600, until=lambda s: bool(s.asc_log))
    pickle.dump(s, open(path, 'wb'))
    return s

MARKS = [('overmind6_1', 'endless 1'), ('overmind6_2', 'endless 1e31'), ('overmind6_3', 'endless 1e62'), ('expansion9', 'exp 5,000')]
TIERS = ['empress', 'pantheon', 'pantheon5', 'overmind', 'overmind3', 'overmind5', 'overmind6']

def long_run(args):
    """One long run. args = (name, policy, cadence profile, days, seed). Returns a summary dict."""
    name, p, prof, days, seed = args
    s0 = start_state()
    s = copy.deepcopy(s0); s.ach_log = []; s.ewaste = 0.0
    gap = cadence.gaps(prof, days, seed=seed, start=s.time)
    t0 = time.time()
    s2, rows, _ = sim.run_cycles(dict(p, ascend=None), gap, s.time / 3600 + 24 * days, s0=s, every=24 * 3600)
    when = {n: (t - s0.time) / 86400 for t, n in s2.ach_log}
    first = {n: (s2.firstclimb[n] - s0.time) / 86400 for n in TIERS if n in s2.firstclimb}
    return {'name': name, 'cadence': prof, 'seed': seed, 'when': when, 'first': first, 'exp': s2.exp,
            'endless': lg(s2.bought.get('overmind6', 0)) if s2.bought.get('overmind6', 0) else None,
            'ewaste_days': s2.ewaste / (sim.erate(s2) * 86400) if sim.erate(s2) else 0, 'secs': time.time() - t0,
            'visits': len([v for v in gap.visits if v <= s2.time])}

def run_all(jobs, specs, fn=None):
    with ProcessPoolExecutor(jobs) as ex:
        return list(ex.map(fn or long_run, specs))

def table(res, title):
    print('\n### %s\n' % title)
    print('| variant | cadence | arch-mind | overmind | universal cortex | endless 1 | endless 1e31 | endless 1e62 | exp 5,000 | endless bought (log10) | energy lost to the cap (days) |')
    print('|' + ' --- |' * 11)
    for r in res:
        f = r['first']; w = r['when']
        d = lambda x: '%.0f' % x if x is not None else '-'
        print('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %.1f |' % (r['name'], r['cadence'], d(f.get('pantheon5')), d(f.get('overmind')), d(f.get('overmind5')),
              d(w.get('overmind6_1')), d(w.get('overmind6_2')), d(w.get('overmind6_3')), d(w.get('expansion9')), d(r['endless']), r['ewaste_days']))

def section_diag(days, jobs):
    var = [('pass 2 policy', PASS2),
           ('+ shares per minute (time_share)', dict(PASS2, time_share=True)),
           ('+ twins "recently" from the last visit (twin_used_gap)', dict(PASS2, twin_used_gap=True)),
           ('+ push bottom-up (several tiers per visit)', dict(PASS2, push=dict(PASS2['push'], bottom_up=True))),
           ('all three', dict(PASS2, time_share=True, twin_used_gap=True, push=dict(PASS2['push'], bottom_up=True)))]
    specs = [(n, p, c, days, 1) for c in ('every5', 'human', 'busy', 'twice') for n, p in var]
    res = run_all(jobs, specs)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_diag.json'), 'w'))
    table(res, 'Why slow visits hurt: the pass-2 policy and one fix at a time (days of the long run)')
    return res

def section_rules(days, jobs):
    """Which parts of the two rules carry the result, under once-every-5-minutes and under people's cadences."""
    P = PASS2; q = P['push']
    var = [('long-run mode (pass-2 rules)', P),
           ('+ shares per minute (time_share)', dict(P, time_share=True)),
           ('no push (multi-faster only)', dict(P, push=None)),
           ('push, no multi-faster', dict(P, faster_aware=None)),
           ('push base 0.5% (frontier tier)', dict(P, push=dict(q, base=0.005))),
           ('push base 10%', dict(P, push=dict(q, base=0.1))),
           ('push share 20%', dict(P, push=dict(q, share=0.2))),
           ('push share 90%', dict(P, push=dict(q, share=0.9))),
           ('push: twins may take pushed units', dict(P, push=dict(q, twin_mult=1))),
           ('push: twin protection 1e3', dict(P, push=dict(q, twin_mult=1e3))),
           ('age multiple 5', dict(P, theta_age=5)),
           ('age multiple 1', dict(P, theta_age=1)),
           ('no banking', dict(P, bank=0)),
           ('existing rule below hive empress (multi-faster from tier 7)', dict(P, fa_from=7)),
           ('existing rule below hive network (multi-faster from tier 11)', dict(P, fa_from=11)),
           ('current rules (no long-run mode), age multiple 20, lepidoptera 30,000', dict(BASE, theta_age=20, moth_N=30000))]
    specs = [(n, p, c, days, 1) for c in ('every5', 'human', 'glance', 'every120') for n, p in var]
    res = run_all(jobs, specs)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_rules.json'), 'w'))
    table(res, 'The rules, piece by piece (days of the long run)')
    # a second seed for the human cadence, base mode only
    res2 = run_all(jobs, [('long-run mode (pass-2 rules)', P, c, days, sd) for c in ('human', 'busy', 'glance') for sd in (2, 3)])
    table(res2, 'Other random schedules (seeds 2, 3)')
    return res

def early_run(args):
    name, p, prof, start_kind, days = args
    if start_kind == 'save':
        s = sim.load()
    else:
        s = copy.deepcopy(start_state())
        if start_kind == 'fresh':                       # a run after an ascension with no mutagen and no mutations
            s.mutagen = bn.F(0.0); s.mut = {m: bn.F(0.0) for m in sim.MUTANTS}; s.unlocked = []; s.unlocks = 0; sim.refresh_mut(s)
    gap = cadence.gaps(prof, days, seed=1, start=s.time)
    s2, rows, _ = sim.run_cycles(dict(p, ascend=None), gap, s.time / 3600 + 24 * days, s0=s, every=3600)
    out = {}
    for d in (1, 2, 4, 7):
        r = [x for x in rows if x['t'] <= s.time / 3600 + 24 * d + 1e-9]
        if r: out[d] = {'earned': r[-1]['lmeat'], 'top': sim.NAMES[r[-1]['top']], 'premut': lg(r[-1]['premut']) if r[-1]['premut'] > 0 else None}
    return {'name': name, 'cadence': prof, 'start': start_kind, 'out': out}

def section_early(days, jobs):
    """No harm early: the long-run mode against the current rules over the first 7 days."""
    CUR = BASE
    LRonly = dict(BASE, faster_aware='multi', push=PASS2['push'])
    var = [('current rules', CUR), ('long-run rules on, settings as now (age multiple 5, lepidoptera 4,000)', LRonly),
           ('rules + lepidoptera 30,000', dict(LRonly, moth_N=30000)), ('rules + age multiple 20', dict(LRonly, theta_age=20)),
           ('pass-2 mode (rules + age multiple 20 + lepidoptera 30,000)', PASS2),
           ('the spec: rules from run age 2 d, lepidoptera 30,000 from 3 d (age multiple 5)', SPEC),
           ('the spec, rules from run age 3 d', dict(SPEC, lr_age=3 * 86400))]
    specs = [(n, p, c, st, 7) for st in ('fresh', 'asc1', 'save') for c in ('every5', 'human') for n, p in var]
    res = run_all(jobs, specs, early_run)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_early.json'), 'w'))
    print('\n### No harm early: log10 meat per second (top tier) after 1, 2, 4, 7 days\n')
    print('| start | cadence | rules | day 1 | day 2 | day 4 | day 7 |'); print('|' + ' --- |' * 7)
    lab = {'fresh': 'fresh run (no mutagen)', 'asc1': 'after the first ascension', 'save': 'the 20.1 h save'}
    for r in res:
        cells = []
        for d in (1, 2, 4, 7):
            o = r['out'].get(d)
            cells.append('%.1f (%s)' % (o['earned'], sim.LABEL.get(o['top'], o['top'])) if o else '-')
        print('| %s | %s | %s | %s |' % (lab[r['start']], r['cadence'], r['name'], ' | '.join(cells)))
    return res

def empower_run(args):
    name, p, prof, days, model = args
    sim.EMPOWER_MODEL = model
    s0 = start_state(); s = copy.deepcopy(s0); s.ach_log = []
    if not hasattr(s, 'emp'): s.emp = [0] * 11; s.emp_log = []
    gap = cadence.gaps(prof, days, seed=1, start=s.time)
    s2, rows, _ = sim.run_cycles(dict(p, ascend=None), gap, s.time / 3600 + 24 * days, s0=s, every=24 * 3600)
    when = {n: (t - s0.time) / 86400 for t, n in s2.ach_log}
    return {'name': name, 'cadence': prof, 'when': when, 'exp': [(round(r['age'] / 24), r['exp']) for r in rows],
            'emp': [((t - s0.time) / 86400, u, l) for t, u, l in s2.emp_log][:40], 'nemp': len(s2.emp_log), 'emplevels': list(s2.emp)}

def section_empower(days, jobs):
    """Territory empower in the long run: off, the advisor's rule, and the rule only until mirrors start."""
    P = PASS2
    specs = [('no empower (model on)', P, 'every5', days, True),
             ("empower by the advisor's rule", dict(P, empower=True), 'every5', days, True),
             ("empower by the advisor's rule, human cadence", dict(P, empower=True), 'human', days, True),
             ('no empower, human cadence', P, 'human', days, True)]
    res = run_all(jobs, specs, empower_run)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_empower.json'), 'w'))
    print('\n### Territory empower in the long run (days of the run)\n')
    print('| variant | expansions day 10 / 40 / 90 | exp 1,000 | exp 2,000 | exp 5,000 | endless 1 | endless 1e62 | empowers bought | levels by unit |')
    print('|' + ' --- |' * 9)
    for r in res:
        ex = dict(r['exp']); w = r['when']; d = lambda x: '%.0f' % x if x is not None else '-'
        print('| %s | %s / %s / %s | %s | %s | %s | %s | %s | %d | %s |' % (r['name'], ex.get(10, '-'), ex.get(40, '-'), ex.get(90, '-'), d(w.get('expansion7')),
              d(w.get('expansion8')), d(w.get('expansion9')), d(w.get('overmind6_1')), d(w.get('overmind6_3')), r['nemp'], r['emplevels']))
    if res[1]['emp']: print('\nFirst empowers (day, unit, level): ' + ', '.join('%.2f %s %d' % e for e in res[1]['emp'][:12]))
    return res

def section_rounds(days, jobs):
    """One visit, several rounds of push suggestions (the panel refreshes after each purchase)."""
    P = PASS2; q = P['push']
    var = [('long-run mode, 1 round per visit', P),
           ('3 rounds per visit', dict(P, push=dict(q, rounds=3))),
           ('10 rounds per visit', dict(P, push=dict(q, rounds=10))),
           ('push bottom-up (all tiers in one round)', dict(P, push=dict(q, bottom_up=True)))]
    specs = [(n, p, c, days, 1) for c in ('glance', 'every120', 'human', 'every5') for n, p in var]
    res = run_all(jobs, specs)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_rounds.json'), 'w'))
    table(res, 'Following the push suggestions several times per visit (days of the long run)')
    return res

def section_glance(days, jobs):
    """Single looks: what is lost when the player does not stay for a second visit."""
    P = PASS2; q = P['push']
    var = [('long-run mode', P),
           ('+ twins "recently" counted from the previous visit (twin_used_gap)', dict(P, twin_used_gap=True)),
           ('+ twin_used_gap + 3 push rounds', dict(P, twin_used_gap=True, push=dict(q, rounds=3))),
           ('twin test off (twin_used 0)', dict(P, twin_used=0)),
           ('+ stay 2 more minutes each visit (cadence)', P)]
    specs = []
    for c in ('glance', 'every120'):
        for n, p in var:
            specs.append((n, p, c + ('+' if 'stay' in n else ''), days, 1))
    res = run_all(jobs, specs)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_glance.json'), 'w'))
    table(res, 'Single looks per session: what fixes them (days of the long run)')
    return res

def section_final(days, jobs):
    """The specified rules against pass 2, under every cadence."""
    var = [('pass-2 mode', PASS2),
           ('spec: rules from run age 2 d, lepidoptera 30,000 from 3 d, age multiple 5', SPEC),
           ('spec, rules from run age 3 d', dict(SPEC, lr_age=3 * 86400)),
           ('spec, rules from the start', dict(SPEC, lr_age=None)),
           ('spec, age multiple 20', dict(SPEC, theta_age=20)),
           ('spec without push (multi-faster only)', dict(SPEC, push=None))]
    specs = [(n, p, c, days, 1) for c in ('every5', 'human', 'busy', 'glance+') for n, p in var]
    res = run_all(jobs, specs)
    json.dump(res, open(os.path.join(OUTD, 'longrun_rules_final.json'), 'w'))
    table(res, 'The specified rules under each cadence (days of the long run)')
    return res

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    days = 130; jobs = 4
    if '--days' in sys.argv: days = int(sys.argv[sys.argv.index('--days') + 1]); args.remove(str(days))
    if '--jobs' in sys.argv: jobs = int(sys.argv[sys.argv.index('--jobs') + 1]); args.remove(str(jobs))
    want = args or ['diag', 'rules', 'rounds', 'glance', 'final', 'early', 'empower']
    start_state()
    T = time.time()
    for w in want:
        globals()['section_' + w](days, jobs)
        print('<!-- %s done (%.0f s) -->' % (w, time.time() - T), flush=True)
