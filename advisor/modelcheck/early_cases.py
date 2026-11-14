"""Reference cases for the 'save' plan at nexus 4 (advisor/ASCENSION.md A.11): the simulator's energy decisions on
states from its own runs, for advisor/modelcheck/early_check.js to compare with the advisor's energyAdvice.

Plays advisor/sim/early_game.py's PLAN for the first run (ideal cadence and the 'human' cadence, seeds 1-3) and the
late quick run (ideal and human seed 1). At every visit at nexus 4 it records what energyAdvice reads (energy,
energy rate, cap, lepidoptera, larvae, larvae per second, nexus 5's price and what is held of it) and what the
simulator then did with energy: nexus 5 bought, lepidoptera bought, a larva rush cast, or nothing; and the energy it
kept for nexus 5 (sim.jit_hold). The lepidoptera target after nexus 5 is the run's (10,000 / 30,000).
Writes advisor/modelcheck/early_cases.json (about 150 states, chosen evenly from each run).
Usage (from the repo root): python3 -I advisor/modelcheck/early_cases.py
"""
import copy, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'sim'))
import early_game as E, sim, cadence, bignum as bn
N = lambda x: str(x) if bn.isbig(x) else float(x)   # past float range: the Big's own text (7 digits)

def cases(run, prof, seed, keep=25):
    p = E.plan(run); s = copy.deepcopy(E.start(run)); s.asc_log = []
    out = []
    orig = sim.energy_policy
    def wrapped(st, pp, gained):
        if st.nexus == 4:
            m, e, l, g = sim.NEX[4]
            hold = 1.0 if (st.c[0] >= m and l <= pp.get('nexus_secs', 3600) * sim.lam(st)) else 0.0
            rec = {'run': run, 'cadence': prof or 'ideal', 'seed': seed, 'age_h': sim.run_age(st, pp) / 3600,
                   'energy': st.energy, 'rate': sim.erate(st), 'cap': sim.ecap(st), 'moths': st.moth,
                   'larvae': N(st.larva), 'larva_rate': N(sim.lam(st)), 'meat': N(st.c[0]),
                   'price': {'meat': m, 'energy': e, 'larva': l}, 'early': pp['moth_N'], 'target': pp['moth_N5'],
                   'sim_keep': sim.jit_hold(st, pp, hold) if st.c[0] >= m else e}
            before = (st.nexus, st.moth, st.casts.get('larvarush', 0))
            orig(st, pp, gained)
            rec['sim'] = {'nexus5': st.nexus == 5, 'moths': st.moth - before[1] if st.nexus == 4 else None,
                          'rush': st.casts.get('larvarush', 0) - before[2]}
            out.append(rec)
        else:
            orig(st, pp, gained)
    sim.energy_policy = wrapped
    try:
        ci = 60.0 if not prof else cadence.gaps(prof, 20, seed=seed, start=s.time)
        sim.run_cycles(p, ci, s.time / 3600 + 400, s0=s, every=86400, until=lambda st: st.nexus >= 5)
    finally:
        sim.energy_policy = orig
    # every state where something happened, plus an even spread of the rest
    act = [c for c in out if c['sim']['nexus5'] or c['sim']['moths'] or c['sim']['rush']]
    idle = [c for c in out if c not in act]
    step = max(1, len(idle) // keep)
    return act[:keep] + idle[::step][:keep]

if __name__ == '__main__':
    allc = []
    for run, prof, seed in [('first', None, 1), ('first', 'human', 1), ('first', 'human', 2), ('first', 'human', 3), ('late', None, 1), ('late', 'human', 1)]:
        c = cases(run, prof, seed); allc += c
        print(run, prof or 'ideal', seed, len(c), 'states')
    json.dump(allc, open(os.path.join(HERE, 'early_cases.json'), 'w'), indent=0)
    print('wrote', len(allc))
