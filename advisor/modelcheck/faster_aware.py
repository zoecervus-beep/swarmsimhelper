"""Faster-aware climbing: should the climb test count the next "faster" upgrade? (MODEL-CHECK.md)

1. The 20.1 h save at its first instant: the native advisor (real game code, via advisor_at_save.js) next
   to the simulator's view (H, wait, banking, what the first policy step hatches), age multiple 3.
2. A sweep: policy.json with the rule off / on / on but upgrade bought at 2x its price / naive (H halved,
   price ignored), at age multiples 3, 5, 10, from two real saves and three later states of the
   simulator's own tuned run (not independent). Score: log10 total meat earned at +8 h ... +14 d,
   shown as differences from "off" at the same age multiple; plus when hive queens and empresses are
   first hatched with larvae, and how many are held.

Usage (from the repo root; the sweep takes about 2 minutes):
    python3 -I advisor/modelcheck/faster_aware.py [--quick]
"""
import argparse, copy, importlib.util, json, math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
SIMDIR = os.path.join(REPO, 'advisor', 'sim')
ap = argparse.ArgumentParser()
ap.add_argument('--quick', action='store_true', help='age multiples 3 and 5 only, real saves only')
args = ap.parse_args()

spec = importlib.util.spec_from_file_location('sim', os.path.join(SIMDIR, 'sim.py'))
sim = importlib.util.module_from_spec(spec); spec.loader.exec_module(sim)
BASE = json.load(open(os.path.join(SIMDIR, 'policy.json')))
SAVES = {'20.1 h save': ('example_save_20h.json', 72406.0), '14.5 h save': ('example_save_14h.json', 52124.0)}
MARKS = [8, 24, 48, 96, 168, 336]
HQ, EMP = sim.NAMES.index('hivequeen'), sim.NAMES.index('empress')

def load(fname):
    os.environ['SAVE'] = os.path.join(SIMDIR, fname)
    return sim.load()

# ---- 1. first instant of the 20.1 h save -------------------------------------------------------------
print('## 1. The 20.1 h save at its first instant, age multiple 3\n')
adv = json.loads(subprocess.run(['node', os.path.join(HERE, 'advisor_at_save.js'),
                                 os.path.join(SIMDIR, 'example_save_20h.json'), '3'],
                                check=True, capture_output=True, text=True).stdout)
s = load('example_save_20h.json'); age = SAVES['20.1 h save'][1]
p = dict(BASE, theta_age=3, age0=age, ci=60); p['theta'] = 3 * age
print('native advisor: ' + adv['header'])
print()
print('| tier | advisor H | sim H | advisor action | sim: passes run-age test | sim: banks | sim: first step hatches | same, no larvae held for nexus 5 |')
print('|---|---|---|---|---|---|---|---|')
s1 = copy.deepcopy(s); sim.policy(s1, p, 0)
s2 = copy.deepcopy(s); sim.policy(s2, dict(p, nexus_secs=0), 0)   # the advisor's meat rules do not hold larvae for a nexus
for t in adv['tiers']:
    k = sim.NAMES.index(t['name'])
    banks = bool(p.get('bank') and k < sim.K and s.c[k + 1] > 0 and sim.allowed(s, p, k + 1) and
                 s.c[k + 1] * sim.P(s, k + 1) > p['bank'] * sim.lam(s) * (1 - p['f']) * 2.0 ** s.twin[k] / 2.0 ** s.twin[k + 1])
    print('| %s | %.6g s | %.6g s | %s | %s | %s | %.3g units | %.3g units |' % (t['name'], t['H'], sim.H(s, k), t['action'],
          sim.allowed(s, p, k), banks, s1.spent[k] * 2.0 ** s.twin[k], s2.spent[k] * 2.0 ** s.twin[k]))
print('\nsim: larvae held for nexus 5 at the first step: %.3g of %.3g' % (s1.nexres, s.larva))
print('sim: hive queen waits %.2f d (H/3 - age); faster hive queens costs %g hive queens\n'
      % ((sim.H(s, HQ) / 3 - age) / 86400, sim.prod_cost(s, HQ)))

# ---- 2. sweep -----------------------------------------------------------------------------------------
VARIANTS = [('off', {}), ('faster-aware', {'faster_aware': True}),
            ('faster-aware, upgrade at 2x price', {'faster_aware': True, 'fa_buy': False}),
            ('faster-aware, income only (no stock earmarked while waiting)', {'faster_aware': True, 'fa_accumulate': False}),
            ('naive H/2', {'faster_aware': True, 'fa_naive': True}),
            ('off, age multiple doubled', {'_double': True})]
AGES = [3, 5] if args.quick else [3, 5, 10]

starts = [(name, load(f), a) for name, (f, a) in SAVES.items()]
if not args.quick:
    tuned = dict(BASE, age0=SAVES['14.5 h save'][1])
    os.environ['SAVE'] = os.path.join(SIMDIR, 'example_save_14h.json')
    o = sim.run(tuned, 0, 60, [12, 48])
    for h in (12, 48):
        starts.append(('14.5 h save, tuned run +%d h' % h, o[h][3], SAVES['14.5 h save'][1] + h * 3600))
    os.environ['SAVE'] = os.path.join(SIMDIR, 'example_save_20h.json')
    o = sim.run(dict(BASE, age0=SAVES['20.1 h save'][1]), 0, 60, [24])
    starts.append(('20.1 h save, tuned run +24 h', o[24][3], SAVES['20.1 h save'][1] + 24 * 3600))

def fmt_t(x): return '-' if x is None else '%.1f' % (x / 3600)
results = []
for sname, s0, age in starts:
    s0 = copy.deepcopy(s0); s0.firstclimb = {}; s0.fa_log = []
    print('## start: %s (run age %.1f h; holds %g hive queens, %g empresses)\n' % (sname, age / 3600, s0.c[HQ], s0.c[EMP]))
    print('| age x | variant | ' + ' | '.join('+%s' % (('%dh' % m) if m < 96 else ('%dd' % (m // 24))) for m in MARKS)
          + ' | hive queens first hatched (h) | empresses first hatched (h) | hive queens held +24h / +4d / +14d | faster hive queens level +14d |')
    print('|---|---|' + '---|' * len(MARKS) + '---|---|---|---|')
    for a in AGES:
        base = None
        for vname, over in VARIANTS:
            pol = dict(BASE, theta_age=2 * a if over.get('_double') else a, age0=age)
            pol.update({kk: v for kk, v in over.items() if not kk.startswith('_')})
            o = sim.run(pol, 0, 60, MARKS, s0)
            sc = {m: o[m][4] for m in MARKS}
            last = o[MARKS[-1]][3]
            fc = last.firstclimb
            row = {'start': sname, 'age': a, 'variant': vname, 'score': sc,
                   'hq_first': fc.get('hivequeen'), 'emp_first': fc.get('empress'),
                   'hq_held': [o[m][3].c[HQ] for m in (24, 96, 336)], 'hq_prod': last.prod[HQ],
                   'fa_fired': [(round(t / 3600, 2), name, lvl, n) for t, name, lvl, n in last.fa_log][:6]}
            results.append(row)
            if base is None:
                base = sc; cells = ['%.2f' % sc[m] for m in MARKS]
            else:
                cells = ['%+.2f' % (sc[m] - base[m]) for m in MARKS]
            print('| %d | %s | %s | %s | %s | %s | %d |' % (a, vname, ' | '.join(cells), fmt_t(row['hq_first']),
                  fmt_t(row['emp_first']), ' / '.join('%.3g' % x for x in row['hq_held']), row['hq_prod']))
    print()
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
json.dump(results, open(os.path.join(HERE, 'out', 'faster_aware.json'), 'w'), indent=1)
print('first firings of the faster-aware rule (hours, tier, faster level before, hive queens hatched) are in out/faster_aware.json')
