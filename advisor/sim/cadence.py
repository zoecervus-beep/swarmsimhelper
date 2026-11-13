"""When a person looks at the game: irregular visits for sim.run_cycles (pass the returned function as `ci`).

A day: asleep 8 h (23:00-07:00 game-clock time of day); awake, the player comes in sessions. During a session
the advisor panel is open and they act on it every `visit` minutes; between sessions they are away for a
random 1-4 h (the `away` range). Deterministic for a given seed.

Profiles:
  'everyN'  a visit every N minutes, day and night (every5 = the simulator's earlier cadence)
  'human'   sessions of 15-40 min with a visit every 2 min; away 1-4 h between sessions; asleep 8 h
  'busy'    sessions of 5-15 min with a visit every 2 min; away 3-8 h between sessions; asleep 8 h
  'glance'  as 'human', but a single visit per session (no panel left open)
  'twice'   one 10-minute session in the morning and one in the evening (visit every 2 min); nothing else
"""
import random

PROFILES = {
    'human': dict(session=(15, 40), visit=2, away=(60, 240)),
    'busy': dict(session=(5, 15), visit=2, away=(180, 480)),
    'glance': dict(session=(0, 0), visit=2, away=(60, 240)),     # 'human' gaps, but one look per session
}


def visits(profile, days, seed=1, start=0.0, day_offset=12 * 3600.0):
    """Sorted visit times (seconds of game time from `start`) for `days` days. `day_offset` is the time of day
    at start (default noon). A trailing '+' (e.g. 'glance+') adds two more visits 1 and 2 minutes after each."""
    if profile.endswith('+'):
        v = visits(profile[:-1], days, seed, start, day_offset)
        return sorted(set(v) | {x + 60 for x in v} | {x + 120 for x in v})
    out = []
    if profile.startswith('every'):                     # 'every5', 'every30', 'every120': fixed gap in minutes
        step = 60.0 * float(profile[5:])
        t = 0.0
        while t < days * 86400:
            t += step; out.append(t)
        return [start + x for x in out]
    rng = random.Random(seed)
    if profile == 'twice':
        for d in range(days + 1):
            for hour in (8, 20):
                base = d * 86400 + hour * 3600 - day_offset
                for m in range(0, 10, 2):
                    if base + m * 60 > 0: out.append(base + m * 60)
        return [start + x for x in sorted(out) if x <= days * 86400]
    pr = PROFILES[profile]
    t = 0.0
    while t < days * 86400:
        tod = (t + day_offset) % 86400
        if tod >= 23 * 3600 or tod < 7 * 3600:            # asleep until 07:00
            wake = (7 * 3600 - tod) % 86400
            t += wake + rng.uniform(0, 1800)
            continue
        length = rng.uniform(*pr['session']) * 60
        end = t + length
        out.append(t); t += pr['visit'] * 60          # at least one visit per session
        while t < end:
            out.append(t); t += pr['visit'] * 60
        t += rng.uniform(*pr['away']) * 60
    return [start + x for x in out if x > 0]


def gaps(profile, days, seed=1, start=0.0, day_offset=12 * 3600.0):
    """A function for sim.run_cycles(ci=...): given the current game time, the gap to the next visit."""
    v = visits(profile, days + 1, seed, start, day_offset)
    import bisect

    def gap(now):
        i = bisect.bisect_right(v, now + 1e-6)
        if i >= len(v):
            return 3600.0
        return max(1.0, v[i] - now)
    gap.visits = v
    return gap


def summary(profile, days=7, seed=1):
    v = visits(profile, days, seed)
    g = [b - a for a, b in zip(v, v[1:])]
    return {'visits_per_day': len(v) / days, 'longest_gap_h': max(g) / 3600, 'gaps_over_1h_per_day': sum(x > 3600 for x in g) / days}


if __name__ == '__main__':
    for p in ('every5', 'human', 'busy', 'twice'):
        print(p, summary(p))
