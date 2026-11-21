"""The seeding rule's share f (advisor/ASCENSION.md A.10 pass 5): f = 1e-4 .. 0.1, the payback form capped at 1%, and
f = 1% without the twin prefix; three starts, ideal and human seed 1.  Usage: python3 -I advisor/sim/lr_cut_sweep.py  (~12 min)"""
import os, sys
from concurrent.futures import ProcessPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lr_cut as L

def payback_capped(cap):
    return {'f': 'payback', 'cap': cap}
L.VAR.update({'f=1e-4': dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': 1e-4}),
              'f=1e-3': dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': 1e-3}),
              'f=1e-2': dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': 1e-2}),
              'f=0.1': dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': 0.1}),
              'f=min(1e-2, horizon/H)': dict(L.FA, **L.OFF, twin_prefix=True, seed={'f': 'payback', 'cap': 1e-2}),
              'f=1e-2, no twin prefix': dict(L.FA, **L.OFF, seed={'f': 1e-2}),
              'f=1e-2 + the mode on': dict(L.FA, twin_prefix=True, seed={'f': 1e-2})})
SW = ('on', 'f=1e-4', 'f=1e-3', 'f=1e-2', 'f=0.1', 'f=min(1e-2, horizon/H)', 'f=1e-2, no twin prefix', 'f=1e-2 + the mode on')
if __name__ == '__main__':
    cads = L.CAD[:2]
    specs = [(st, v, c, pr, sd) for st in ('warp', 'mirrors20', 'run2b') for v in SW for c, pr, sd in cads]
    res = L.run(specs, 4, 'sweep')
    L.report(res, ('warp', 'mirrors20', 'run2b'), SW, cads)
