"""Game vs simulator for the mechanics the no-mirrors route relies on (advisor/NO-MIRRORS.md), using nomirrors_check.js.

The 20.1 h save is edited with bignum_state.json (up to 1e600 of resources, mutagen 1e350, territory mutation 1e330,
1,500 expansions) plus nomirrors_state.json (nexus 5, 2,000 bats, 30,000 lepidoptera, the bat / warp / rush / clone
mutations at 1e200 each, goon empower 60, spider empower 40, 1e300 spiders). Compares spell power, the output of
swarmwarp, larva rush, territory rush, meat rush and clone larvae, every unit after one swarmwarp cast (a skip of
1e8 s), and territory production / meat cost / empower price at those empower levels.

Usage (from the repo root): python3 -I advisor/modelcheck/nomirrors_check.py     # about 3 s
"""
import copy, json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'advisor', 'sim'))
import sim, bignum as bn
OUT = os.path.join(HERE, 'out'); os.makedirs(OUT, exist_ok=True)
game = json.loads(subprocess.run(['node', os.path.join(HERE, 'nomirrors_check.js')], check=True, capture_output=True, text=True,
                                 env=dict(os.environ, TZ='UTC')).stdout)
d = json.load(open(os.path.join(REPO, 'advisor', 'sim', 'example_save_20h.json')))
for f in ('bignum_state.json', 'nomirrors_state.json'):
    E = json.load(open(os.path.join(HERE, f)))
    d['unittypes'].update(E['units']); d['upgrades'].update(E['upgrades'])
tmp = os.path.join(OUT, '_nomirrors_save.json'); json.dump(d, open(tmp, 'w'))
os.environ['SAVE'] = tmp
sim.EMPOWER_MODEL = True
s = sim.load()
rows = []; worst = [0.0, '']
def _short(x):
    v = bn.num(x) if isinstance(x, str) else x
    if v == 0: return '0'
    l = bn.lg(abs(v)); e = math.floor(l)
    return '%.6fe%d' % (10 ** (l - e), e)
def row(name, gv, sv):
    g = bn.num(gv); v = bn.big(sv) if not isinstance(sv, int) else bn.F(sv)
    r = 1.0 if (g == 0 and v == 0) else float(v / g)
    if abs(r - 1) > worst[0]: worst[0] = abs(r - 1); worst[1] = name
    rows.append('| %s | %s | %s | %s |' % (name, _short(gv), _short(sv), '%.9f' % r))
row('larvae/s (mutagen 1e350)', game['rates']['larva'], sim.lam(s))
row('territory/s (territory mutation 1e330, empowered)', game['rates']['territory'], sim.trate(s))
row('energy/s', game['rates']['energy'], sim.erate(s))
q = {sp: sim.epow(s) * s.spw[sp] for sp in sim.SPELL}
for sp, up in (('warp', 'swarmwarp'), ('larvarush', 'larvarush'), ('terrrush', 'territoryrush'), ('clone', 'clonelarvae'), ('meatrush', 'meatrush')):
    row(up + ' power', game['power'][up], q[sp])
o = game['output']
row('swarmwarp: seconds skipped', o['swarmwarp'][0], 900 * q['warp'])
row('swarmwarp: energy debit', o['swarmwarp'][1], -900 * q['warp'] * sim.erate(s))
row('larva rush: larvae (velocity part)', o['larvarush'][0], sim.lam(s) * 2400 * q['larvarush'])
row('larva rush: larvae (flat part)', o['larvarush'][1], 1e5 * q['larvarush'])
row('territory rush: territory (velocity part)', o['territoryrush'][0], sim.trate(s) * 7200 * q['terrrush'])
row('meat rush: meat (velocity part)', o['meatrush'][0], s.c[1] * sim.P(s, 1) * 7200 * q['meatrush'])
row('clone larvae: larvae (cap)', o['clonelarvae'][0], min(s.larva, sim.lam(s) * 1e5 * q['clone']))
s1 = copy.deepcopy(s); sim.advance(s1, 900 * q['warp'], True)
B, A = game['warpBefore'], game['warpAfter']
for n in ['meat', 'larva', 'territory'] + sim.NAMES[1:]:
    sv = s1.larva if n == 'larva' else s1.terr if n == 'territory' else s1.c[sim.NAMES.index(n)]
    row('after one swarmwarp: ' + n, A[n], sv)
row('after one swarmwarp: energy', A['energy'], s.energy - 2000)
for j, n in enumerate(sim.TN):
    e = game['empower'][n]
    if e['level'] in ('0',): continue
    row(n + ' empower level %s: territory each' % e['level'], e['prodEach'], sim.TP[j] * s.tm[j] * sim.EMP_PROD ** s.emp[j])
    row(n + ' empower level %s: meat cost' % e['level'], e['meatCost'], sim.tcosts(s)[j])
    row(n + ' empower level %s: next empower price' % e['level'], e['price'], sim.empower_price(s, j))
sim.EMPOWER_MODEL = False
txt = ['# No-mirrors mechanics at large counts: game vs simulator', '', '| quantity | game | sim | sim/game |', '|---|---|---|---|'] + rows
txt += ['', '**%d numbers compared; worst |sim/game - 1| = %.3g (%s).**' % (len(rows), worst[0], worst[1])]
open(os.path.join(OUT, 'nomirrors_check.md'), 'w').write('\n'.join(txt) + '\n')
print('\n'.join(txt))
os.remove(tmp)
