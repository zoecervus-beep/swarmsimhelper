"""One purchase evaluator for the meat tiers (advisor/EVALUATOR.md). Prototype, simulator side.

Every candidate purchase at a look is scored on one scale: how much it raises J, the meat the hive will have made by
the horizon T if nothing else were bought after this look.

    v_0 = 1 (meat);  v_j(T) = P_1 x ... x P_j x T^j / j!      the meat one unit of tier j makes by T (exact for the
                                                              game's production chain); P_j = tier j's prodEach
    J = sum_j S_j v_j                      the stocks held
      + sum of the look's hatch gains      larvae to hatches in order of value per larva (2^twin_k v_k - cost_k v_(k-1)
                                           - meat), each tier up to what its stock and the meat share allow
      + sum_j r_j w_j T / (deg_j + 1)      the steady hatch flows over T (larva income shared out by the same rule),
                                           valued at each tier's best use w_j (kept, or hatched into tier j+1)

Candidates: n hatches of a tier (with faster levels of it bought out of the result), a faster level, 1-3 twin levels
of a tier with the hatches that pay for them and up to two detours through the paying tier's own twin, and twin jumps
(6 to 96 levels at once, for a tier that only pays once it is twinned enough to take the larvae). A candidate passes
when it raises J; the look takes the best, re-plans on what is left, and repeats; the larvae left go to the hatches.

Policy option `evaluator` (sim.policy): replaces faster/twin/twinseek/climb/banking/FA. Options inside it:
  ev_levels (3)  ev_detour (2)  ev_meat (0.5: share of the meat the hatches may spend)  ev_iter (12: picks per look)
"""
import math
import sim, bignum as bn

TWO = bn.F(2.0)


class Led:
    """What the look still has: stocks (S), larvae (L), meat budget (M), twin and faster levels, and the steps taken."""
    __slots__ = ('S', 'L', 'M', 'tw', 'pr', 'steps')
    def __init__(self, S, L, M, tw, pr, steps):
        self.S, self.L, self.M, self.tw, self.pr, self.steps = S, L, M, tw, pr, steps
    def copy(self): return Led(list(self.S), self.L, self.M, list(self.tw), list(self.pr), list(self.steps))

def Pk(s, led, k): return sim.P(s, k) * TWO ** (led.pr[k] - s.prod[k])
def values(s, led, T):
    v = [bn.F(1.0)]
    for j in range(1, sim.K + 1): v.append(v[-1] * Pk(s, led, j) * T / j)
    return v
def shadow(s, led, v, mu):
    """A unit's best use: kept (v_j), or hatched into tier j+1 when that is worth more (a hatch also spends a larva at
    mu and meat). deg_j is the power of T in w_j."""
    w = list(v); deg = list(range(sim.K + 1))
    for j in range(sim.K - 1, 0, -1):
        conv = (TWO ** led.tw[j + 1] * w[j + 1] - sim.MEATC[j + 1] - mu) / sim.UNITC[j + 1]
        if conv > v[j]: w[j] = conv; deg[j] = deg[j + 1]
    return w, deg
def twin_price(k, level): return sim.TWINF[k] ** level
def faster_price(level): return 66 * sim.X666 ** level

def hatch_nv(s, led, k, n, v):
    """Hatch n of tier k, then the faster levels of k (paid from the result) that raise the value most: (NV, levels)."""
    S = led.S; got = S[k] + n * TWO ** led.tw[k]
    cost = n * sim.MEATC[k] + (n * sim.UNITC[k] * v[k - 1] if k >= 2 else 0)
    best = (got * v[k] - S[k] * v[k] - cost, 0); F = bn.F(0.0)
    for L in range(1, 60):
        F = F + faster_price(led.pr[k] + L - 1); N = got - F
        if N < 1: break
        nv = N * TWO ** L * v[k] - S[k] * v[k] - cost
        if nv > best[0]: best = (nv, L)
        elif L > 1: break
    return best

def cap(led, k, left, M):
    n = min(left, M / sim.MEATC[k])
    if k >= 2: n = min(n, led.S[k - 1] / sim.UNITC[k])
    return math.floor(n) if n >= 1 else 0

def allocate(s, led, v):
    """The look's larvae to the hatches by value per larva: [(k, n, faster levels, NV)] and mu, the per-larva value of
    the last tier served when the larvae run out (0 when some are left)."""
    rows = []
    for k in range(sim.K, 0, -1):
        n = cap(led, k, led.L, led.M)
        if n < 1: continue
        nv, L = hatch_nv(s, led, k, n, v)
        if nv > 0: rows.append((nv / n, k))
    rows.sort(key=lambda x: x[0], reverse=True)
    left = led.L; M = led.M; plan = []; mu = bn.F(0.0)
    for per, k in rows:
        if left < 1: break
        n = cap(led, k, left, M)
        if n < 1: continue
        nv, L = hatch_nv(s, led, k, n, v)
        if nv <= 0: continue
        plan.append((k, n, L, nv)); left = left - n; M = M - n * sim.MEATC[k]
        if left < 1: mu = nv / n
    return plan, mu

def flows(s, led, lam_eff, v, planned):
    """Steady hatch flows (units/s), the same rule as the look's larvae: by value per larva, each tier up to what its
    income allows (the tier below as tier k makes it, after this look's hatches) and the meat income's share."""
    r = [bn.F(0.0)] * (sim.K + 1); left = lam_eff
    meat = (led.S[1] + planned.get(1, 0) * TWO ** led.tw[1]) * Pk(s, led, 1) * 0.5
    rows = []
    for k in range(1, sim.K + 1):
        per = TWO ** led.tw[k] * v[k] - sim.MEATC[k] - (sim.UNITC[k] * v[k - 1] if k >= 2 else 0)
        if per > 0: rows.append((per, k))
    rows.sort(key=lambda x: x[0], reverse=True)
    for per, k in rows:
        if not left > 0 or not meat > 0: break
        if k >= 2:
            held = led.S[k] + planned.get(k, 0) * TWO ** led.tw[k]
            if not held > 0: continue
            rate = min(left, held * Pk(s, led, k) / sim.UNITC[k], meat / sim.MEATC[k])
        else:
            rate = min(left, meat / sim.MEATC[k])
        if not rate > 0: continue
        r[k] = rate * TWO ** led.tw[k]; left = left - rate; meat = meat - rate * sim.MEATC[k]
    return r

def J(s, led, lam_eff, T):
    v = values(s, led, T)
    plan, mu = allocate(s, led, v); planned = {k: n for k, n, L, nv in plan}
    r = flows(s, led, lam_eff, v, planned)
    w, deg = shadow(s, led, v, mu)
    tot = led.M
    for j in range(1, sim.K + 1):
        if led.S[j] > 0: tot = tot + led.S[j] * v[j]
        if r[j] > 0: tot = tot + r[j] * w[j] * T / (deg[j] + 1)
    for k, n, L, nv in plan: tot = tot + nv
    return tot, v, w, mu, plan, r

def acquire(s, led, j, amt, depth, down, ctx):
    """Make tier j hold amt: from stock, else by hatching it (paid from tier j-1 stock, or from tier j-1 hatched first
    when down > 0), optionally after buying up to ev_detour twin levels of tier j first (depth > 0). The option that
    leaves J highest. Returns the new ledger or None."""
    if led.S[j] >= amt: return led
    best = None; bestj = None
    for d in range(0, (ctx['detour'] if depth > 0 and j < sim.K else 0) + 1):
        l2 = led.copy(); ok = True
        for _ in range(d):
            c = twin_price(j, l2.tw[j])
            l3 = acquire(s, l2, j + 1, c, depth - 1, down, ctx)
            if l3 is None: ok = False; break
            l2 = l3; l2.S[j + 1] = l2.S[j + 1] - c; l2.tw[j] += 1; l2.steps.append(('twin', j, 1))
        if not ok: continue
        need = amt - l2.S[j]
        if need > 0:
            h = math.ceil(need / TWO ** l2.tw[j])
            if l2.L < h or l2.M < h * sim.MEATC[j]: continue
            if j >= 2:
                cost = h * sim.UNITC[j]
                if l2.S[j - 1] < cost:
                    if down <= 0: continue
                    l3 = acquire(s, l2, j - 1, cost, 0, down - 1, ctx)
                    if l3 is None: continue
                    l2 = l3
                l2.S[j - 1] = l2.S[j - 1] - cost
            l2.L = l2.L - h; l2.M = l2.M - h * sim.MEATC[j]; l2.S[j] = l2.S[j] + h * TWO ** l2.tw[j]; l2.steps.append(('hatch', j, h))
        if d == 0 and depth <= 0: return l2          # nothing to choose between
        jv = J(s, l2, ctx['lam'], ctx['T'])[0]
        if bestj is None or jv > bestj: best, bestj = l2, jv
    return best

JUMPS = (6, 12, 24, 48, 96)
def candidates(s, led, lam_eff, T, ev, J0):
    base, v, w, mu, plan, r = J0
    ctx = {'lam': lam_eff, 'T': T, 'detour': ev.get('ev_detour', 2)}
    top = max([k for k in range(1, sim.K + 1) if led.S[k] > 0] or [1])
    sink = max([k for k, n, L, nv in plan] or [1])
    out = []
    hatched = {k for k, n, L, nv in plan}
    for k in range(1, min(top + 2, sim.K)):
        # without jumps, a twin of a tier that neither hatches this look nor has a steady flow adds nothing to J
        if not ev.get('ev_jumps', True) and k not in hatched and not r[k] > 0: continue
        l2 = led.copy()
        for lv in range(1, ev.get('ev_levels', 3) + 1):
            c = twin_price(k, l2.tw[k])
            l3 = acquire(s, l2, k + 1, c, 1, 1, ctx)
            if l3 is None: break
            l2 = l3.copy(); l2.S[k + 1] = l2.S[k + 1] - c; l2.tw[k] += 1; l2.steps.append(('twin', k, 1))
            out.append(('twin', k, lv, l2))
        if k >= sink and ev.get('ev_jumps', True):
            for lv in JUMPS:
                c = twin_price(k, led.tw[k]) * (twin_price(k, lv) - 1) / (sim.TWINF[k] - 1)
                l3 = acquire(s, led, k + 1, c, 0, 1, ctx)
                if l3 is None: break
                l3 = l3.copy(); l3.S[k + 1] = l3.S[k + 1] - c; l3.tw[k] += lv; l3.steps.append(('twin', k, lv))
                out.append(('twin', k, lv, l3))
    for k in range(1, sim.K + 1):
        F = faster_price(led.pr[k])
        if led.S[k] >= F + 1:
            l2 = led.copy(); l2.S[k] = l2.S[k] - F; l2.pr[k] += 1; l2.steps.append(('faster', k, 1))
            out.append(('faster', k, 1, l2))
    scored = []
    for kind, k, lv, l2 in out:
        j2 = J(s, l2, lam_eff, T)[0]
        if j2 > base: scored.append((j2 - base, kind, k, lv, l2))
    return scored

def look(s, p, avail, T):
    """One look: the ordered purchases and the final ledger."""
    lam_eff = sim.lam(s) * (1 - p.get('f', 0.0))
    led = Led(list(s.c), bn.F(max(0.0, math.floor(avail))) if not bn.isbig(avail) else avail, s.c[0] * p.get('ev_meat', 0.5),
              list(s.twin), list(s.prod), [])
    out = []
    for _ in range(p.get('ev_iter', 12)):
        J0 = J(s, led, lam_eff, T)
        cands = candidates(s, led, lam_eff, T, p, J0)
        if not cands: break
        nv, kind, k, lv, l2 = max(cands, key=lambda c: c[0])
        out.append({'kind': kind, 'tier': k, 'levels': lv, 'nv': nv, 'steps': l2.steps[len(led.steps):], 'ledger': led.copy(), 'J': J0[0]})
        led = l2
    tot, v, w, mu, plan, r = J(s, led, lam_eff, T)
    for k, n, L, nv in plan:
        out.append({'kind': 'hatch', 'tier': k, 'n': n, 'faster': L, 'nv': nv, 'steps': [('hatch', k, n)] + [('faster', k, 1)] * L,
                    'ledger': led.copy(), 'J': tot})
    return out, led, mu

def upgrades(s, p, avail, T):
    """The hybrid (evaluator='upgrades', EVALUATOR.md section 11): faster and twin levels only, no jumps; the look's
    hatches stay with today's climb. The candidates are scored on J with the evaluator's own allocation of the larvae
    left (the larvae's best use, so an upgrade that spends larvae is charged their highest value)."""
    ev = dict(p, ev_jumps=False)
    lam_eff = sim.lam(s) * (1 - p.get('f', 0.0))
    led = Led(list(s.c), bn.F(max(0.0, math.floor(avail))) if not bn.isbig(avail) else avail, s.c[0] * p.get('ev_meat', 0.5),
              list(s.twin), list(s.prod), [])
    out = []
    for _ in range(p.get('ev_iter', 6)):
        J0 = J(s, led, lam_eff, T)
        cands = candidates(s, led, lam_eff, T, ev, J0)
        if not cands: break
        nv, kind, k, lv, l2 = max(cands, key=lambda c: c[0])
        out.append({'kind': kind, 'tier': k, 'levels': lv, 'nv': nv, 'steps': l2.steps[len(led.steps):], 'ledger': led.copy(), 'J': J0[0]})
        led = l2
    return out

def nv_at(s, led, kind, k, levels, ev, lam_eff, T):
    if kind == 'hatch': return hatch_nv(s, led, k, levels, values(s, led, T))[0]
    for c in candidates(s, led, lam_eff, T, ev, J(s, led, lam_eff, T)):
        if c[1] == kind and c[2] == k and c[3] == levels: return c[0]
    return bn.F(-1.0)

def payback(s, led0, kind, k, levels, ev, lam_eff, T0):
    """The smallest horizon at which the purchase raises J (bisection on log10 T, 1 s to 3e4 years); for the report."""
    lo, hi = 0.0, 12.0
    if not nv_at(s, led0, kind, k, levels, ev, lam_eff, 10 ** hi) > 0: return float('inf')
    for _ in range(30):
        mid = (lo + hi) / 2
        if nv_at(s, led0, kind, k, levels, ev, lam_eff, 10 ** mid) > 0: hi = mid
        else: lo = mid
    return 10 ** hi

def apply(s, p, out, now):
    """Carry the look out on the state, step by step (the steps were planned on the ledger)."""
    for o in out:
        for kind, k, x in o['steps']:
            if kind == 'hatch':
                if k >= 2 and s.c[k - 1] < x * sim.UNITC[k]: x = math.floor(s.c[k - 1] / sim.UNITC[k])
                x = math.floor(min(x, s.larva, s.c[0] / sim.MEATC[k]))
                if x < 1: continue
                sim.hatch(s, k, x, now)
            elif kind == 'twin':
                for _ in range(x):
                    c = twin_price(k, s.twin[k])
                    if s.c[k + 1] >= c:
                        # the drain check (EVALUATOR.md 11): sim.drain logs the share of the paying tier spent
                        sim.drain(s, k, c)
                        s.c[k + 1] = s.c[k + 1] - c; s.twin[k] += 1
                    else: break
            elif kind == 'faster':
                c = faster_price(s.prod[k])
                if s.c[k] >= c: s.c[k] = s.c[k] - c; s.prod[k] += 1
