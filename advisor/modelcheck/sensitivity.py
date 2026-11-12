"""Do the tuned settings survive the simulator fixes? A sensitivity check, not a re-tuning.

Runs advisor/sim/sim.py with policy.json and one setting changed at a time, from the example save (and,
with --states, from two later states of the tuned run itself), and prints the handoff's score: log10 of
total meat earned at fixed marks ahead. Differences are shown against the tuned policy, in log10 units
(+1.0 = 10x more meat earned).

Usage (from the repo root; one 14-day run takes about a second):
    python3 -I advisor/modelcheck/sensitivity.py [--sim PATH/TO/sim.py] [--states] [--json OUT]
"""
import argparse, copy, importlib.util, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
ap = argparse.ArgumentParser()
ap.add_argument('--save', default=os.path.join(REPO, 'advisor', 'sim', 'example_save_14h.json'))
ap.add_argument('--age', type=float, default=52124, help='run age at the save, seconds (example save: 14 h 28 min)')
ap.add_argument('--sim', default=os.path.join(REPO, 'advisor', 'sim', 'sim.py'))
ap.add_argument('--states', action='store_true', help='also start from the tuned run at +12 h and +48 h')
ap.add_argument('--json')
args = ap.parse_args()

os.environ['SAVE'] = os.path.abspath(args.save)
spec = importlib.util.spec_from_file_location('sim_under_test', os.path.abspath(args.sim))
sim = importlib.util.module_from_spec(spec); spec.loader.exec_module(sim)
BASE = json.load(open(os.path.join(REPO, 'advisor', 'sim', 'policy.json')))

MARKS = [1, 2, 4, 8, 24, 48, 96, 168, 336]   # hours ahead
SHORT = [1, 2, 4, 8, 24, 48]                  # the handoff's "1 to 48 hours" average

VARIANTS = [
    ('tuned policy.json (age 5, share 0.5, bank 3, moths 4000, mirrors)', {}),
    ('age multiple 1', {'theta_age': 1}),
    ('age multiple 3 (native advisor default)', {'theta_age': 3}),
    ('age multiple 10', {'theta_age': 10}),
    ('age multiple 20', {'theta_age': 20}),
    ('share 0.25', {'share': 0.25}),
    ('share 0.75', {'share': 0.75}),
    ('bank 1', {'bank': 1}),
    ('bank 10', {'bank': 10}),
    ('never bank', {'bank': 0}),
    ('lepidoptera target 0 or 2000 (the save already has 2416: buy no more)', {'moth_N': 0}),
    ('swarmwarp instead of House of Mirrors', {'spells': ['warp']}),
    ('no hatching a higher tier just for twins', {'twinseek': False}),
    ('check in every 15 min', {'_ci': 900}),
]
MOTHS = [0, 1000, 2000, 4000, 8000]

def policy_for(over):
    p = dict(BASE); p.update({k: v for k, v in over.items() if not k.startswith('_')})
    return p

def score(over, s0=None, age=args.age):
    p = policy_for(over); p['age0'] = age
    out = sim.run(p, 0, over.get('_ci', 60), MARKS, s0)
    return {m: out[m][4] for m in MARKS}, out

starts = [('save (14.5 h)', None, args.age)]
if args.states:
    o = sim.run(dict(policy_for({}), age0=args.age), 0, 60, [12, 48])
    for h in (12, 48):
        st = o[h][3]
        starts.append(('tuned run +%d h' % h, st, args.age + h * 3600))

results = {}
for sname, s0, age in starts:
    base, _ = score({}, s0, age)
    rows = []
    for name, over in VARIANTS:
        sc, _ = score(over, s0, age)
        d = {m: sc[m] - base[m] for m in MARKS}
        rows.append((name, sc, d))
    results[sname] = rows
    print('## start: %s   (sim: %s)' % (sname, os.path.relpath(args.sim, REPO)))
    print()
    print('| variant | ' + ' | '.join('+%dh' % m for m in MARKS) + ' | mean 1-48 h |')
    print('|---|' + '---|' * (len(MARKS) + 1))
    for name, sc, d in rows:
        if name.startswith('tuned'):
            cells = ['%.2f' % sc[m] for m in MARKS] + ['%.2f' % (sum(sc[m] for m in SHORT) / len(SHORT))]
            print('| %s (log10 meat earned) | %s |' % (name, ' | '.join(cells)))
        else:
            cells = ['%+.2f' % d[m] for m in MARKS] + ['%+.2f' % (sum(d[m] for m in SHORT) / len(SHORT))]
            print('| %s | %s |' % (name, ' | '.join(cells)))
    print()

# Lepidoptera targets need a start with fewer lepidoptera than the targets: the save with its 2,416
# lepidoptera set to 0 (a counterfactual state, nothing refunded).
s0 = sim.load(); s0.moth = 0
base, _ = score({'moth_N': 4000}, s0)
print('## start: save with lepidoptera set to 0 (counterfactual)   (sim: %s)' % os.path.relpath(args.sim, REPO))
print()
print('| lepidoptera target | ' + ' | '.join('+%dh' % m for m in MARKS) + ' |')
print('|---|' + '---|' * len(MARKS))
for n in MOTHS:
    sc, _ = score({'moth_N': n}, s0)
    if n == 4000:
        print('| 4000 (log10 meat earned) | %s |' % ' | '.join('%.2f' % sc[m] for m in MARKS))
    else:
        print('| %d | %s |' % (n, ' | '.join('%+.2f' % (sc[m] - base[m]) for m in MARKS)))
print()
if args.json:
    json.dump({k: [(n, sc, d) for n, sc, d in v] for k, v in results.items()}, open(args.json, 'w'), indent=1)
