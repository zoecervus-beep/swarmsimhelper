"""The evaluator's first look on the owner's saves (advisor/EVALUATOR.md, the seven catches), and its reference cases.
Usage: python3 -I advisor/sim/evaluator_saves.py [--write]   (--write: advisor/modelcheck/evaluator_cases/*.json)"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, bignum as bn, evaluator as E
sim.H_MUT = True

SAVES = [('1: 58 h first run', 'example_save_58h.json', 0.1),
         ('2: run 2, 45 h', 'example_save_run2_45h.json', 0.0),
         ('3: run 2, 3.0 d', 'example_save_twin_3d.json', 0.0),
         ('4+5: run 2, 7.2 d', 'example_save_run2_7d.json', 0.0),
         ('6: run 2, 7.2 d (b)', 'example_save_run2_7d_b.json', 0.0),
         ('7: run 2, now', 'example_save_run2_now.json', 0.0)]
NM = lambda k: sim.LABEL.get(sim.NAMES[k], sim.NAMES[k])
def h(x): return 'never' if x == float('inf') else ('%.3g h' % (x / 3600) if x < 3600 * 2000 else '%.2g d' % (x / 86400))
def num(x): return repr(x) if bn.isbig(x) else '%.6e' % float(x)

def show(label, f, terr, multiple=5):
    os.environ['SAVE'] = os.path.join(HERE, f); s = sim.load()
    age = (s.t0_ms - s.restarted_ms) / 1000.0 + getattr(s, 'gskip_run', 0.0)
    T = multiple * age
    p = {'f': terr}
    avail = s.larva * (1 - terr)
    lam_eff = sim.lam(s) * (1 - terr)
    out, led, mu = E.look(s, p, avail, T)
    print('\n### %s (%s): run age %.1f h, horizon %s, larvae %.3g, larva income %.3g/s' % (label, f, age / 3600, h(T), s.larva, sim.lam(s)))
    print('| # | purchase | steps | raises J by | payback |'); print('| --- | --- | --- | --- | --- |')
    rows = []
    for i, o in enumerate(out):
        if o['kind'] == 'hatch':
            what = 'hatch %.3g %s%s' % (o['n'], NM(o['tier']), (' + %d faster' % o['faster']) if o['faster'] else '')
            pb = E.payback(s, o['ledger'], 'hatch', o['tier'], o['n'], p, lam_eff, T)
            ratio = '-'
        else:
            what = '%s %s x%d' % (o['kind'], NM(o['tier']), o['levels'])
            pb = E.payback(s, o['ledger'], o['kind'], o['tier'], o['levels'], p, lam_eff, T)
            ratio = '+%.3g%%' % (100 * o['nv'] / o['J'])
        st = '; '.join('%s %s %s' % (a, NM(k), ('%.3g' % x) if a == 'hatch' else '') for a, k, x in o['steps'] if not (o['kind'] == 'hatch'))
        print('| %d | %s | %s | %s | %s |' % (i + 1, what, st or '-', ratio, h(pb)))
        rows.append({'kind': o['kind'], 'name': sim.NAMES[o['tier']], 'n': num(o['n']) if 'n' in o else None, 'levels': o.get('levels'),
                     'faster_after': o.get('faster'), 'steps': [[a, sim.NAMES[k], num(x)] for a, k, x in o['steps']],
                     'raises_J_pct': None if o['kind'] == 'hatch' else float(100 * o['nv'] / o['J']),
                     'payback_s': None if pb == float('inf') else pb})
    led0 = E.Led(list(s.c), avail, s.c[0] * 0.5, list(s.twin), list(s.prod), [])
    J0 = E.J(s, led0, lam_eff, T)
    alts = sorted(E.candidates(s, led0, lam_eff, T, p, J0), key=lambda c: c[0], reverse=True)[:6]
    v = J0[1]
    case = {'case': f.replace('example_save_', '').replace('.json', ''), 'catch': label, 'save': 'advisor/sim/' + f,
            'run_age_s': age, 'age_multiple': multiple, 'horizon_s': T, 'territory_share': terr, 'larvae_for_look': num(avail),
            'larva_income_per_s': num(sim.lam(s)), 'meat_share': 0.5,
            'log10_meat_by_horizon_per_unit': {sim.NAMES[j]: round(bn.lg(v[j]), 4) for j in range(1, sim.K + 1) if s.c[j] > 0 or s.c[j - 1] > 0},
            'purchases': rows,
            'first_pick_alternatives': [{'kind': c[1], 'name': sim.NAMES[c[2]], 'levels': c[3], 'raises_J_pct': float(100 * c[0] / J0[0])} for c in alts]}
    return s, out, case

if __name__ == '__main__':
    cases = [show(label, f, terr)[2] for label, f, terr in SAVES]
    if '--write' in sys.argv:
        d = os.path.join(HERE, '..', 'modelcheck', 'evaluator_cases'); os.makedirs(d, exist_ok=True)
        for c in cases: json.dump(c, open(os.path.join(d, c['case'] + '.json'), 'w'), indent=1)
        print('\nwrote %d cases to %s' % (len(cases), os.path.normpath(d)))
