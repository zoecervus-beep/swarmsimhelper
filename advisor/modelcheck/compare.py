"""Game vs simulator, number for number, on one decoded save.

Runs game_check.js (the real game code in Node) and advisor/sim/sim.py on the same save and prints
markdown tables with the ratio sim/game. See advisor/MODEL-CHECK.md.

Usage (from the repo root):
    python3 -I advisor/modelcheck/compare.py [--save PATH] [--sim PATH/TO/sim.py] [--game-json PATH]

--sim lets you point at another copy of sim.py, e.g. the unfixed one:
    git show e34fc82:advisor/sim/sim.py > advisor/modelcheck/out/sim_original.py
    python3 -I advisor/modelcheck/compare.py --sim advisor/modelcheck/out/sim_original.py
"""
import argparse, copy, importlib.util, json, math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
ap = argparse.ArgumentParser()
ap.add_argument('--save', default=os.path.join(REPO, 'advisor', 'sim', 'example_save_14h.json'))
ap.add_argument('--sim', default=os.path.join(REPO, 'advisor', 'sim', 'sim.py'))
ap.add_argument('--game-json', help='reuse a game_check.js output instead of running node')
args = ap.parse_args()

if args.game_json:
    game = json.load(open(args.game_json))
else:
    game = json.loads(subprocess.run(['node', os.path.join(HERE, 'game_check.js'), os.path.abspath(args.save)],
                                     check=True, capture_output=True, text=True).stdout)

os.environ['SAVE'] = os.path.abspath(args.save)
spec = importlib.util.spec_from_file_location('sim_under_test', os.path.abspath(args.sim))
sim = importlib.util.module_from_spec(spec)
sys.path.insert(0, os.path.dirname(os.path.abspath(args.sim)))
spec.loader.exec_module(sim)

# Prices: the fixed sim exposes them as functions; the original had the same formulas inline in policy().
anc_cost = getattr(sim, 'anc_cost', lambda s: (5e6 * 1e4 ** s.ach, 500 * 1e4 ** s.ach))
exp_cost = getattr(sim, 'exp_cost', lambda s: 10 * 2.45 ** s.exp)
hatch_cost = getattr(sim, 'hatch_cost', lambda s: 300 * 10.0 ** s.hatch)
prod_cost = getattr(sim, 'prod_cost', lambda s, k: 66 * 666.0 ** s.prod[k])
twin_cost = getattr(sim, 'twin_cost', lambda s, k: 10.0 ** s.twin[k])
tt_cost = getattr(sim, 'tt_cost', lambda s, j: (100 * 500.0 ** s.tt[j], 50.0 ** s.tt[j]))
lam = sim.lam
achpts = lambda s: getattr(s, 'achpts', sim.ACH)

F = lambda x: float(x) if x is not None else float('nan')
rows_out = []
def out(line=''):
    rows_out.append(line); print(line)
def fmt(x):
    if x is None or (isinstance(x, float) and math.isnan(x)): return '-'
    if x == 0: return '0'
    if abs(x) >= 1e5 or abs(x) < 1e-2: return '%.4g' % x
    return ('%.4f' % x).rstrip('0').rstrip('.')
def ratio(sv, gv):
    if gv == 0 and sv == 0: return '1'
    if gv == 0: return 'inf'
    r = sv / gv
    return '%.6f' % r if abs(r - 1) < 1e-3 else '%.4g' % r
def table(title, rows, head=('quantity', 'game', 'sim', 'sim/game')):
    out('### ' + title); out()
    out('| ' + ' | '.join(head) + ' |'); out('|' + '---|' * len(head))
    bad = []
    for name, gv, sv in rows:
        r = ratio(sv, gv)
        out('| %s | %s | %s | %s |' % (name, fmt(gv), fmt(sv), r))
        # 1e-5: the game's table stores some large costs and rates rounded (ratios like 1.000003 vs the exact formula)
        if gv and abs(sv / gv - 1) > 1e-5 or (not gv and sv): bad.append((name, r))
    out()
    return bad

mismatches = {}
CH = sim.NAMES  # meat, drone..pantheon3

# 1. Rates, units, prices --------------------------------------------------------------------
s = sim.load()
g = game['rates']
rows = [('larvae / s', F(g['larva']), lam(s)), ('meat / s', F(g['meat']), s.c[1] * sim.P(s, 1)),
        ('territory / s', F(g['territory']), sim.trate(s)), ('energy / s', F(g['energy']), sim.erate(s)),
        ('energy cap', F(g['energyCap']), sim.ecap(s)), ('achievement points', g['achievementPoints'], achpts(s))]
mismatches['rates'] = table('Rates at the save', rows)

rows = []
for k in range(1, sim.K + 1):
    n = CH[k]; u = game['units'][n]; below = CH[k - 1]
    rows.append((n + ' count', F(u['count']), s.c[k]))
    rows.append((n + ' production each (' + below + '/s)', F(u['prodEach']), sim.P(s, k)))
    if k >= 2: rows.append((n + ' cost in ' + below, F(u['cost'][below]), sim.UNITC[k]))
    rows.append((n + ' cost in meat', F(u['cost']['meat']), sim.MEATC[k]))
    rows.append((n + ' units per hatch (twin)', F(u['twin']), 2.0 ** s.twin[k]))
mismatches['meat units'] = table('Meat chain', rows)

rows = []
for j, n in enumerate(sim.TN):
    u = game['units'][n]
    rows += [(n + ' count', F(u['count']), s.t[j]), (n + ' territory/s each', F(u['prodEach']), sim.TP[j]),
             (n + ' cost in meat', F(u['cost']['meat']), sim.TC[j]), (n + ' units per hatch', F(u['twin']), 2.0 ** s.tt[j])]
mismatches['territory units'] = table('Territory units', rows)

up = game['upgrades']
rows = [('hatchery (meat)', F(up['hatchery']['cost']['meat']), hatch_cost(s)),
        ('expansion (territory)', F(up['expansion']['cost']['territory']), exp_cost(s)),
        ('accomplished ancestry (meat)', F(up['achievementbonus']['cost']['meat']), anc_cost(s)[0]),
        ('accomplished ancestry (territory)', F(up['achievementbonus']['cost']['territory']), anc_cost(s)[1])]
for lvl in (2, 3, 4, 5):
    m, e, l, _ = sim.NEX[lvl - 1]
    c = up['nexus%d' % lvl]['cost']
    rows += [('nexus%d meat' % lvl, F(c['meat']), m), ('nexus%d energy' % lvl, F(c['energy']), e),
             ('nexus%d larvae' % lvl, F(c.get('larva', 0)), l)]
for k in range(1, sim.K + 1):
    n = CH[k]
    rows.append((n + 'prod (' + n + ')', F(up[n + 'prod']['cost'][n]), prod_cost(s, k)))
for k in range(1, sim.K):
    n = CH[k]; pay = CH[k + 1]
    rows.append((n + 'twin (' + pay + ')', F(up[n + 'twin']['cost'][pay]), twin_cost(s, k)))
for j, n in enumerate(sim.TN):
    c = up[n + 'twin']['cost']; tm, tl = tt_cost(s, j)
    rows += [(n + 'twin (meat)', F(c['meat']), tm), (n + 'twin (larvae)', F(c['larva']), tl)]
mismatches['prices'] = table('Upgrade prices at the save', rows)

# 2. Idle dynamics ------------------------------------------------------------------------------
WATCH = ['meat'] + CH[1:6] + ['larva', 'territory', 'energy']
def simval(s, n):
    if n in CH: return s.c[CH.index(n)]
    return {'larva': s.larva, 'territory': s.terr, 'energy': s.energy}[n]
for secs, snap in sorted(game['idle'].items(), key=lambda kv: int(kv[0])):
    s = sim.load(); sim.advance(s, int(secs))
    mismatches['idle %ss' % secs] = table('No purchases, +%s s' % secs, [(n, F(snap[n]), simval(s, n)) for n in WATCH])

# 3. Identical purchases --------------------------------------------------------------------------
P = game['purchases']
s = sim.load(); sim.advance(s, 7200)
k_gq, k_nest = CH.index('greaterqueen'), CH.index('nest')
def buy(kind, name, num):
    """The same purchase as the game, using the simulator's formulas (as in sim.policy)."""
    if kind == 'unit' and name in CH:
        k = CH.index(name); price = {'meat': num * sim.MEATC[k], CH[k - 1]: num * sim.UNITC[k], 'larva': num}
        s.c[k - 1] -= num * sim.UNITC[k]; s.c[0] -= num * sim.MEATC[k]; s.larva -= num; s.c[k] += num * 2.0 ** s.twin[k]
    elif kind == 'unit':
        j = sim.TN.index(name); price = {'meat': num * sim.TC[j], 'larva': num}
        s.c[0] -= num * sim.TC[j]; s.larva -= num; s.t[j] += num * 2.0 ** s.tt[j]
    elif name.endswith('twin'):
        k = CH.index(name[:-4]); price = {CH[k + 1]: twin_cost(s, k)}
        s.c[k + 1] -= twin_cost(s, k); s.twin[k] += 1
    elif name.endswith('prod'):
        k = CH.index(name[:-4]); price = {name[:-4]: prod_cost(s, k)}
        s.c[k] -= prod_cost(s, k); s.prod[k] += 1
    elif name == 'expansion':
        price = {'territory': exp_cost(s)}; s.terr -= exp_cost(s); s.exp += 1
    elif name == 'hatchery':
        price = {'meat': hatch_cost(s)}; s.c[0] -= hatch_cost(s); s.hatch += 1
    return price
rows = []
for st in P['steps']:
    price = buy(st['kind'], st['name'], st['num'])
    for unit, gv in st['price'].items():
        rows.append(('price of %s %s x%d, in %s' % (st['kind'], st['name'], st['num'], unit), F(gv), price.get(unit, 0.0)))
mismatches['purchase prices'] = table('Prices paid for the same purchases at +2 h', rows)
last = P['steps'][-1]['after']
WATCH2 = WATCH + ['goon']
def simval2(s, n): return s.t[sim.TN.index(n)] if n in sim.TN else simval(s, n)
mismatches['after purchases'] = table('State right after the purchases', [(n, F(last[n]), simval2(s, n)) for n in WATCH2])
ar = P['afterRates']
mismatches['rates after purchases'] = table('Rates after the purchases', [
    ('larvae / s', F(ar['larva']), lam(s)), ('meat / s', F(ar['meat']), s.c[1] * sim.P(s, 1)),
    ('territory / s', F(ar['territory']), sim.trate(s))])
sim.advance(s, 3600)
mismatches['1h after purchases'] = table('One hour after the purchases', [(n, F(P['later'][n]), simval2(s, n)) for n in WATCH2])

# 4. Spells --------------------------------------------------------------------------------------
def spell_state(bats, larvae=None):
    s = sim.load(); s.nexus = 5; s.energy = 1e6; s.bat = bats
    if larvae is not None: s.larva = larvae
    return s
def cast(s, sp):
    pol = {'energy': True, 'spells': [sp], 'moth_N': 0, 'clone_min': 0}
    e0 = s.energy; s.energy = sim.SPELL[sp][0]   # exactly one cast
    sim.energy_policy(s, pol, 0); s.energy = e0 - sim.SPELL[sp][0]
SIMSPELL = {'clonearmy': 'mirror', 'larvarush': 'larvarush', 'meatrush': 'meatrush', 'territoryrush': 'terrrush',
            'swarmwarp': 'warp', 'clonelarvae': 'clone', 'clonelarvae_capped': 'clone'}
for bats in ('0', '1000'):
    G = game['spells'][bats]; rows = []
    for gname, sname in SIMSPELL.items():
        r = G[gname]
        s = spell_state(float(bats), 1e12 if gname.endswith('capped') else None)
        before = {'larva': s.larva, 'meat': s.c[0], 'territory': s.terr}
        before.update({n: s.t[j] for j, n in enumerate(sim.TN)})
        cast(s, sname)
        after = {'larva': s.larva, 'meat': s.c[0], 'territory': s.terr}
        after.update({n: s.t[j] for j, n in enumerate(sim.TN)})
        if gname == 'clonearmy':
            for n in ('swarmling', 'centipede', 'goon'):
                rows.append(('House of Mirrors: %s after/before' % n, F(r['after'][n]) / F(r['before'][n]), after[n] / before[n]))
        elif gname == 'swarmwarp':
            for n in ('meat', 'larva', 'territory'):
                rows.append(('swarmwarp: %s gained' % n, F(r['after'][n]) - F(r['before'][n]), after[n] - before[n]))
        else:
            n = {'larvarush': 'larva', 'meatrush': 'meat', 'territoryrush': 'territory'}.get(gname, 'larva')
            rows.append(('%s: %s gained' % (gname, n), F(r['after'][n]) - F(r['before'][n]), after[n] - before[n]))
    rows.append(('spell power', F(G['larvarush']['rates']['spellPower']), sim.epow(spell_state(float(bats)))))
    mismatches['spells, %s bats' % bats] = table('Spells cast once, %s bats (nexus 5)' % bats, rows)

# 5. Energy units -------------------------------------------------------------------------------
rows = []
for n, gv in game['energy']['moth'].items():
    s = sim.load(); s.moth = float(n); rows.append(('energy/s with %s lepidoptera (4 nexus)' % n, F(gv), sim.erate(s)))
for n, gv in game['energy']['bat'].items():
    s = sim.load(); s.bat = float(n); rows.append(('spell power with %s bats' % n, F(gv), sim.epow(s)))
for n, gv in game['energy']['nightbug'].items():
    s = sim.load(); s.nightbug = float(n); rows.append(('energy cap with %s nightbugs (4 nexus)' % n, F(gv), sim.ecap(s)))
mismatches['energy'] = table('Lepidoptera, bats, nightbugs', rows)

# 6. Accomplished ancestry ------------------------------------------------------------------------
rows = []
for lvl, r in game['ancestry']['byLevel'].items():
    s = sim.load(); s.ach = int(lvl)
    rows.append(('larvae/s at ancestry %s, %d points' % (lvl, r['points']), F(r['rate']), lam(s)))
    rows.append(('larvae gained in 60 s at ancestry %s' % lvl, F(r['gained60s']), lam(s) * 60))
mismatches['ancestry'] = table('Accomplished ancestry', rows)

C = game['cocoons']
mismatches['cocoons'] = table('Cocoons (from 1e6 larvae: cocoon 400k, then uncocoon 100k)', [
    ('larvae + cocoons after cocooning', F(C['afterCocooning400k']['larva']) + F(C['afterCocooning400k']['cocoon']), 1e6),
    ('larvae + cocoons after uncocooning', F(C['afterUncocooning100k']['larva']) + F(C['afterUncocooning100k']['cocoon']), 1e6),
    ('cocoon production / s', F(C['cocoonVelocity']), 0.0)])

# 7. Achievements earned during a run -----------------------------------------------------------
A = game['achievements']
s = sim.load(); s.exp = 100; s.t[sim.TN.index('swarmling')] = 1e16
if hasattr(sim, 'earn_achievements'):
    s.bought['hive'] = 1e6; sim.earn_achievements(s)
mismatches['achievements'] = table('Achievements earned in the run (expansion 100, 1e6 hives bought, 1e16 swarmlings owned not bought)', [
    ('achievement points', A['after']['points'], achpts(s)), ('larvae / s', F(A['after']['larva']), lam(s))])

out('### Summary: rows where sim and game differ by more than 1 part in 100,000'); out()
for sec, bad in mismatches.items():
    out('- %s: %s' % (sec, ', '.join('%s (%s)' % b for b in bad) if bad else 'none'))
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
open(os.path.join(HERE, 'out', 'compare.md'), 'w').write('\n'.join(rows_out) + '\n')
