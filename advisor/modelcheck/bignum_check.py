"""Game vs simulator beyond a double's range (numbers up to 1e1100), using bignum_check.js.

The 20.1 h save is edited (bignum_state.json) to hold up to 1e600 of resources, twin levels up to 1,100,
faster levels up to 200, 1,500 expansions, units on every tier up to endless and mutants up to 1e330.
Compares rates, production per unit, units per hatch, upgrade prices, one hour of idle production, a
1e200-hive purchase and the premutagen of expansion 1,501.

Usage (from the repo root): python3 -I advisor/modelcheck/bignum_check.py     # about 3 s
"""
import copy, json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim'))
import sim, bignum as bn
OUT = os.path.join(HERE, 'out'); os.makedirs(OUT, exist_ok=True)
game = json.loads(subprocess.run(['node', os.path.join(HERE, 'bignum_check.js')], check=True, capture_output=True, text=True,
                                 env=dict(os.environ, TZ='UTC')).stdout)
EDIT = json.load(open(os.path.join(HERE, 'bignum_state.json')))
d = json.load(open(os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')))
d['unittypes'].update(EDIT['units']); d['upgrades'].update(EDIT['upgrades'])
tmp = os.path.join(OUT, '_bignum_save.json'); json.dump(d, open(tmp, 'w'))
os.environ['SAVE'] = tmp
sim.PREMUT = 'exact'
s = sim.load()
rows = []; worst = [0.0, '']
def row(name, gv, sv):
    g = bn.num(gv); v = bn.big(sv) if not isinstance(sv, (int,)) else bn.F(sv)
    if g == 0 and v == 0: r = 1.0
    else: r = float(v / g)
    worst_rel = abs(r - 1)
    if worst_rel > worst[0]: worst[0] = worst_rel; worst[1] = name
    rows.append('| %s | %s | %s | %s |' % (name, gv if len(str(gv)) < 24 else '%.6e' % 0 if False else _short(gv), _short(sv), '%.9f' % r))
def _short(x):
    v = bn.num(x) if isinstance(x, str) else x
    if v == 0: return '0'
    l = bn.lg(abs(v)); e = math.floor(l)
    return '%.6fe%d' % (10 ** (l - e), e)
row('larvae/s', game['rates']['larva'], sim.lam(s))
row('meat/s', game['rates']['meat'], s.c[1] * sim.P(s, 1))
row('territory/s', game['rates']['territory'], sim.trate(s))
row('energy/s', game['rates']['energy'], sim.erate(s))
for k in range(1, sim.K + 1):
    n = sim.NAMES[k]; u = game['units'][n]
    row(n + ' production each', u['prodEach'], sim.P(s, k))
    row(n + ' units per hatch', u['twin'], sim.TWO ** s.twin[k])
    row(n + 'prod price', game['prices'][n + 'prod'], sim.prod_cost(s, k))
    if n + 'twin' in game['prices']: row(n + 'twin price', game['prices'][n + 'twin'], sim.twin_cost(s, k))
for j, n in enumerate(sim.TN):
    if n == 'swarmling': continue          # empowered swarmling: not modelled (MODEL-CHECK.md)
    u = game['units'][n]
    row(n + ' territory each', u['prodEach'], sim.TP[j] * s.tm[j]); row(n + ' units per hatch', u['twin'], sim.TWO ** s.tt[j])
row('hatchery price', game['prices']['hatchery'], sim.hatch_cost(s))
row('expansion price', game['prices']['expansion'], sim.exp_cost(s))
row('goontwin price (meat)', game['prices']['goontwin'], sim.tt_cost(s, 10)[0])
s1 = copy.deepcopy(s); sim.advance(s1, 3600)
for n in ['meat', 'larva', 'territory'] + sim.NAMES[1:]:
    sv = s1.larva if n == 'larva' else s1.terr if n == 'territory' else s1.c[sim.NAMES.index(n)]
    row('after 1 h idle: ' + n, game['idle'][n], sv)
# 1e200 hives and expansion 1,501
k = sim.NAMES.index('hive'); n = bn.num('1e200')
row('buy 1e200 hives: hives gained', game['buy']['hiveGained'], n * sim.TWO ** s.twin[k])
sp, q = sim.premut_roll(s, 'expansion', s.exp + 1)
row('expansion %d: premutagen' % (s.exp + 1), game['buy']['premutagenGained'], q if sp else 0)
txt = ['# Beyond float range: game vs simulator', '', '| quantity | game | sim | sim/game |', '|---|---|---|---|'] + rows
txt += ['', '**%d numbers compared; worst |sim/game - 1| = %.3g (%s).**' % (len(rows), worst[0], worst[1])]
open(os.path.join(OUT, 'bignum_check.md'), 'w').write('\n'.join(txt) + '\n')
print('\n'.join(txt))
os.remove(tmp)
