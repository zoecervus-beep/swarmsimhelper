"""Turn a simulator state into a decoded save the real game can load (advisor/modelcheck/lib/game.js loadSave).

export_save(s, p) starts from the owner's 20.1 h save as a template (options, watched, version, the crystal
timer) and writes over it everything the simulator models:
  unittypes   every meat tier, larvae (cocoons 0: the simulator holds them as larvae), meat, territory, the 11
              territory units, energy, nexus, lepidoptera, bats, nightbugs, crystal energy (mtxEnergy), crystals,
              mutagen, premutagen, ascension count, free respecs, respecEnergy, the 10 mutant units
  upgrades    hatchery, expansion, accomplished ancestry, faster/twin for all 20 tiers, territory twins and
              empower levels, nexus1-5, spell casts this run (they count as spent energy), mutation unlocks and
              mutatehidden (= number of unlocks)
  date        reified/saved = the template's (a save from the future is refused), restarted = reified - run age,
              so the game's run age equals the simulator's run_age(s, p); started = restarted before any ascension
              (the premutagen seed then differs from the owner's: see longrun_cases/README.md)
  statistics  byUnit[name].twinnum (= num) from the units bought, as achievements and the advisor's purchase
              detection read them
  achievements every achievement the state has earned (the save's, those the simulator earned since, ascension
              and mutation ones); points equal the state's achpts
Counts beyond a double are decimal strings with 17 significant digits (bignum.dec).
Not exported (the simulator does not model them): cocoons, empowered swarmling counts beyond what it holds,
click statistics, the advisor's own purchase memory.
"""
import datetime, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim, bignum as bn

TEMPLATE = os.path.join(HERE, 'example_save_20h.json')
SPELL_UPGRADE = sim.SPELL_UP          # sim spell name -> upgrade name


def _iso(ms):
    return datetime.datetime.fromtimestamp(ms / 1000.0, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.') + '%03dZ' % (ms % 1000)


def earned_achievements(s):
    """Names of every achievement the state has earned."""
    modelled = set(sim.NAMES[1:] + sim.TN + ['expansion', 'nexus5'])
    out = set(s.ach_have)
    for n, (pts, req, val) in sim._achievements().items():
        if req in modelled and pts > 0 and val != '' and n not in s.unearned:
            out.add(n)
    return out


def export_save(s, p, template=TEMPLATE):
    d = json.load(open(template))
    u = d['unittypes']; g = d['upgrades']; D = bn.dec
    for k in range(sim.K + 1):
        u[sim.NAMES[k]] = D(s.c[k])
    u['larva'] = D(s.larva); u['cocoon'] = '0'; u['territory'] = D(s.terr)
    for j, n in enumerate(sim.TN):
        u[n] = D(s.t[j])
    u['energy'] = D(s.energy); u['nexus'] = str(s.nexus); u['moth'] = D(s.moth); u['bat'] = D(s.bat)
    u['nightbug'] = D(s.nightbug); u['mtxEnergy'] = D(s.mtx); u['crystal'] = D(s.crystal)
    u['mutagen'] = D(s.mutagen); u['premutagen'] = D(s.premut); u['ascension'] = str(s.asc)
    u['freeRespec'] = str(s.freerespec); u['respecEnergy'] = D(s.respecE)
    for m in sim.MUTANTS:
        u[m] = D(s.mut.get(m, 0.0))
    # upgrades: start from nothing, then what the state holds
    for key in list(g):
        g[key] = '0'
    g['hatchery'] = str(s.hatch); g['expansion'] = str(s.exp); g['achievementbonus'] = str(s.ach)
    for k in range(1, sim.K + 1):
        g[sim.NAMES[k] + 'prod'] = str(s.prod[k])
        if k < sim.K: g[sim.NAMES[k] + 'twin'] = str(s.twin[k])
    for j, n in enumerate(sim.TN):
        g[n + 'twin'] = str(s.tt[j])
        g[n + 'empower'] = str(getattr(s, 'emp', [0] * 11)[j])
    for lvl in range(1, 6):
        g['nexus%d' % lvl] = '1' if s.nexus >= lvl else '0'
    casts = {}
    for sp, n in list(s.casts.items()) + list(s.casts0.items()):
        casts[SPELL_UPGRADE[sp]] = casts.get(SPELL_UPGRADE[sp], 0) + n
    for up, n in casts.items():
        g[up] = str(int(n))
    for up in sim.MUTATE:
        g[up] = '1' if up in s.unlocked else '0'
    g['mutatehidden'] = str(s.unlocks)
    g['cocooning'] = '1'
    # dates: the game's run age is now - restarted
    # the game refuses a save from the future, so keep the template's moment and put the run start before it
    reified = sim._ms(d['date']['reified'])
    restarted = reified - int(round(sim.run_age(s, p) * 1000))
    started = restarted if s.asc == 0 else min(sim._ms(d['date']['started']), restarted)
    d['date'].update({'started': _iso(started), 'restarted': _iso(restarted), 'reified': _iso(reified), 'saved': _iso(reified),
                      'closed': _iso(started)})
    d['date'].pop('loaded', None)
    st = d.setdefault('statistics', {}).setdefault('byUnit', {})
    for name, v in s.bought.items():
        e = st.setdefault(name, {'clicks': 0, 'elapsedFirst': 0})
        e['num'] = D(v); e['twinnum'] = D(v)
    d['achievements'] = {n: 1 for n in sorted(earned_achievements(s))}
    return d
