"""Run the tuned policy forward from a decoded save and print total meat earned.

Usage: SAVE=out.json python3 run_example.py <run age in seconds at the save>
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim import run, NAMES
policy = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'policy.json')))
age = float(sys.argv[1]) if len(sys.argv) > 1 else 0
marks = [1, 2, 4, 8, 24, 48, 96]          # hours ahead
out = run(dict(policy, age0=age), 0, 60, marks)   # 60 = seconds between check-ins
for m in marks:
    meat_rate, larva_rate, top, state, earned = out[m]
    print('+%3dh  log10 meat earned %.2f  log10 larvae/s %.2f  top unit %s' % (m, earned, larva_rate, NAMES[top]))
