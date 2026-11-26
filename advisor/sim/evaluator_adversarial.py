"""States where the evaluator could do what a careful player would call wrong (advisor/EVALUATOR.md, adversarial pass).
Usage: python3 -I advisor/sim/evaluator_adversarial.py      (about a minute)"""
import os, sys, copy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, bignum as bn, evaluator as E
sim.H_MUT = True
NM = lambda k: sim.LABEL.get(sim.NAMES[k], sim.NAMES[k])

def load(f):
    os.environ['SAVE'] = os.path.join(HERE, f); s = sim.load()
    return s, (s.t0_ms - s.restarted_ms) / 1000.0

def show(title, s, T, terr=0.0, larvae=None):
    out, led, mu = E.look(s, {'f': terr}, s.larva * (1 - terr) if larvae is None else larvae, T)
    print('\n#### %s (horizon %.1f h)' % (title, T / 3600))
    for o in out:
        if o['kind'] == 'hatch':
            print('- hatch %.3g %s%s' % (o['n'], NM(o['tier']), (' + %d faster' % o['faster']) if o['faster'] else ''))
        else:
            hs = [(NM(k), '%.3g' % x) for a, k, x in o['steps'] if a == 'hatch']
            print('- %s %s x%d (+%.3g%% J)%s' % (o['kind'], NM(o['tier']), o['levels'], 100 * o['nv'] / o['J'], ', paid by hatching %s' % hs if hs else ''))
    return out

# A1. The run is about to end. 3.0 d save: the twin plan pays back in 16.7 h; with 2 h left it never pays.
s, age = load('example_save_twin_3d.json')
show('A1: 3.0 d save, horizon 5 x age (as the advisor has it)', s, 5 * age)
show('A1: same state, horizon 2 h (the ascension is 2 h away)', s, 2 * 3600)

# A2. The larva sink is about to change. 58 h save at a horizon just under hive queens' H (they still fail), then at
# the save's own horizon (they pass): what is bought for the tier that will lose the larvae within hours.
s, age = load('example_save_58h.json')
o1 = show('A2: 58 h save, horizon 250 h (hive queens fail: H 278 h)', s, 250 * 3600, 0.1)
o2 = show('A2: 58 h save, horizon 290 h (5 x age: hive queens pass)', s, 290 * 3600, 0.1)

# A3. A faster level that eats almost the whole stock: the run-2 save "now" (prophets 5.56e35, the level costs 5.03e35).
s, age = load('example_save_run2_now.json')
show('A3: run 2 now, faster neuroprophet with 1.1x its price held', s, 5 * age)
s2 = copy.deepcopy(s); s2.c[9] = s2.c[9] * 1e-6     # hive neurons scarce: the prophets' own production matters more
show('A3b: same, with a millionth of the hive neurons', s2, 5 * age)

# A4. Larvae scarce: the same save with larva income and stock / 1e6 (unit-rich, larva-poor).
s3 = copy.deepcopy(s); sim.LMULT = 1e-6
show('A4: run 2 now, larvae and larva income / 1e6', s3, 5 * age, larvae=s.larva * 1e-6)
sim.LMULT = 1.0
