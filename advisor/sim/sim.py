import json, math, copy, sys, os
HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0,HERE)
import bignum as bn
from bignum import lg
# Large quantities are bignum.F: bit-identical to float while they fit, unbounded (bignum.Big) when they do not.
TWO=bn.F(2.0); TEN=bn.F(10.0); X11=bn.F(1.1); X245=bn.F(2.45); X666=bn.F(666.0); X500=bn.F(500.0); X50=bn.F(50.0)
GAME_DATA=os.path.join(HERE,'..','..','swarmsim-coffee','app','scripts','spreadsheetpreload','v0.2.js')
_ACH=None
def _achievements():
    """{name: (points, unit or upgrade it requires, required value)} from the game's own data table."""
    global _ACH
    if _ACH is None:
        t=open(GAME_DATA).read(); key="'spreadsheetPreload-v0.2',"
        data=json.loads(t[t.index(key)+len(key):t.rindex('});')+1])
        _ACH={e['name']:(e['points'],e['requires.unittype'] or e['requires.upgradetype'],e['requires.val'])
              for e in data['achievements']['elements'] if e.get('name')}
    return _ACH
def achievement_points(d):
    """Achievement points earned in a decoded save, as game.achievementPoints() counts them: the sum of
    `points` over the achievements present in d['achievements']."""
    return sum(_achievements().get(n,(0,))[0] for n in d.get('achievements',{}))
EARN_ACH=True   # award achievements the run earns; more points raise larva production via accomplished ancestry
def earn_achievements(s):
    """The game awards unit achievements on the number of units *bought* (statistics twinnum, so mirror
    clones and production do not count) and upgrade achievements on the level. Only units and upgrades
    the simulator models are checked: meat chain, territory units, expansion, nexus5."""
    if not EARN_ACH or ACH is not None: return
    for name in list(s.unearned):
        pts,req,val=_achievements()[name]
        if req=='expansion': have=s.exp
        elif req=='nexus5': have=1 if s.nexus>=5 else 0
        else: have=s.bought.get(req,0.0)
        if have>=float(val): s.unearned.remove(name); s.achpts+=pts; log_ach(s,name)
def log_ach(s,name):
    if not hasattr(s,'ach_log'): s.ach_log=[]
    s.ach_log.append((s.time,name))
def buy_stat(s,name,twinnum): s.bought[name]=s.bought.get(name,0.0)+twinnum
K=20  # meat tiers 1..K (drone=1 ... endless=overmind6=20)
NAMES=['meat','drone','queen','nest','greaterqueen','hive','hivequeen','empress','prophet','goddess','pantheon','pantheon2','pantheon3',
       'pantheon4','pantheon5','overmind','overmind2','overmind3','overmind4','overmind5','overmind6']
# Display names (the fork renamed overmind2..6; internal names are unchanged).
LABEL={'overmind2':'ascended','overmind3':'cosmic network','overmind4':'galactic cluster','overmind5':'universal cortex','overmind6':'endless'}
BASEP=[0]+list(range(1,K+1))                 # tier k makes k of tier k-1 /s
# Checked against the game (advisor/MODEL-CHECK.md). Meat cost per hatch: drone 10, queen 810, then x90 per tier
# (the formula up to pantheon3, as checked; the game's own rounded table values above it, e.g. 1.21577e38 for endless).
_MEAT_TABLE={'pantheon4':2.54187e24,'pantheon5':2.28768e26,'overmind':2.05891e28,'overmind2':1.85302e30,'overmind3':1.66772e32,
             'overmind4':1.50095e34,'overmind5':1.35085e36,'overmind6':1.21577e38}
MEATC=[0,10]+[810*90**(k-2) if k<=12 else _MEAT_TABLE[NAMES[k]] for k in range(2,K+1)]
# Cost in tier k-1 units: 10^k up to pantheon (k=10), then 1e12, 1e14, 1e16, 1e19 (pantheon2..5), and
# 1e23, 1e28, 1e34, 1e41, 1e49, 1e58 (overmind..endless).
UNITC=[0,0]+[10.0**k for k in range(2,11)]+[1e12,1e14,1e16,1e19,1e23,1e28,1e34,1e41,1e49,1e58]
# Twin of tier k costs TWINF[k]^level units of tier k+1: x10 up to pantheon5, x12 .. x20 for overmind..universal cortex; endless has no twin.
TWINF=[0]+[bn.F(10.0)]*14+[bn.F(12.0),bn.F(14.0),bn.F(16.0),bn.F(18.0),bn.F(20.0)]
TN=['swarmling','stinger','spider','mosquito','locust','roach','giantspider','centipede','wasp','devourer','goon']
TC=[750*450.0**j for j in range(11)]
TP=[0.07*45.0**j for j in range(11)]
ACH=None   # achievement points; None = read from the save (see achievement_points). Set a number to override.
LMULT=1.0
MMULT=1.0
# ---------------------------------------------------------------------------------------------------------
# Ascension and mutagen (advisor/ASCENSION.md). Everything below is read from the game's data table and
# game.coffee / effect.coffee, and checked against the game in advisor/modelcheck/ascension_compare.py.
# With a save that holds no mutagen and no mutant units (both example saves), none of it changes any
# number the simulator produced before: multipliers are exactly 1.0 and mutagen larvae exactly 0.
MUTANTS=['mutanthatchery','mutantbat','mutantclone','mutantswarmwarp','mutantrush','mutanteach','mutantfreq',
         'mutantnexus','mutantarmy','mutantmeat']
MUTATE={'mutate'+m[len('mutant'):]:m for m in MUTANTS}      # unlock upgrade -> the mutant unit it unlocks
UNLOCK_FACTOR=15625.0      # k-th unlock (any of them) costs 15625^k mutagen: 1, 15625, 2.44e8, 3.8e12, ...
MUTAGEN_LARVA=0.1          # each unspent mutagen makes 0.1 larva/s (no hatchery, expansion or ancestry bonus)
PREMUT='expected'          # premutagen accrual: 'expected' (mean of the game's roll), 'exact' (the game's seeded roll), None (off)
SEED_TZ=('+0000','Coordinated Universal Time')   # the game seeds with Date.toString() of the start date: local time zone
CRYSTALS=False             # option: hatchery/expansion buys grant 500 crystals per 30 min (nexus>=1), converted to energy
SPELL_UP={'mirror':'clonearmy','larvarush':'larvarush','warp':'swarmwarp','meatrush':'meatrush','terrrush':'territoryrush','clone':'clonelarvae'}
_MUT=None
def _game_data():
    t=open(GAME_DATA).read(); key="'spreadsheetPreload-v0.2',"
    return json.loads(t[t.index(key)+len(key):t.rindex('});')+1])
def _mut_effects():
    """[(mutant, type, target unit, stat, val, val2, val3)] for every effect row of a mutant unit."""
    global _MUT
    if _MUT is None:
        _MUT=[]; cur=None
        for e in _game_data()['unittypes']['elements']:
            if e['name']: cur=e['name']
            if cur in MUTANTS and e.get('effect.type'):
                f=lambda v:(float(v) if v not in ('',None) else None)
                _MUT.append((cur,e['effect.type'],e['effect.unittype'],e['effect.stat'],f(e['effect.val']),f(e.get('effect.val2')),f(e.get('effect.val3'))))
    return _MUT
def _stat_effect(typ,n,val,val2,val3):
    """effect.coffee calcStats for one effect at level n (mult-type stats only)."""
    if typ=='logStat': return 1+(val3 if val3 is not None else 1)*(_ln(n*val+val2)/math.log(val2)-1)
    if typ=='asympStat': return 1+(val-1)*(1-1/(1+n*val2))
    if typ=='expStat': return n**val*val2+1
    if typ=='initStat': return val
    raise ValueError(typ)
def _ln(x): return x.log2()*math.log(2) if bn.isbig(x) else math.log(x)
def mstat(s,unit,stat):
    m=1.0
    for (mu,typ,tu,st,v,v2,v3) in _mut_effects():
        if tu==unit and st==stat: m*=_stat_effect(typ,s.mut.get(mu,0.0),v,v2,v3)
    return m
def refresh_mut(s):
    """Cache the multipliers mutant units give, after s.mut changes."""
    s.mm=[1.0]*(K+2)
    if any(s.mut.values()):
        for k in range(1,K+1): s.mm[k]=mstat(s,NAMES[k],'prod')
    s.lm=mstat(s,'invisiblehatchery','prod') if s.mut.get('mutanthatchery') else 1.0
    s.em=mstat(s,'nexus','prod') if s.mut.get('mutantnexus') else 1.0
    s.cm=mstat(s,'energy','capMult') if s.mut.get('mutantnexus') else 1.0
    s.acm=mstat(s,'mutagen','ascendCost')
    s.tm=[mstat(s,n,'prod') if s.mut.get('mutantarmy') else 1.0 for n in TN]
    s.pwb=mstat(s,'energy','power') if s.mut.get('mutantbat') else 1.0
    s.spw={sp:mstat(s,'energy','power.'+SPELL_UP[sp]) for sp in SPELL_UP}
    s.freq=mstat(s,'invisiblehatchery','random.freq')            # includes the 0.2 base (initStat)
    s.each=mstat(s,'invisiblehatchery','random.each')
    s.minlevel={'hatchery':mstat(s,'invisiblehatchery','random.minlevel.hatchery'),
                'expansion':mstat(s,'invisiblehatchery','random.minlevel.expansion')}
PREMUT_FACTOR={'hatchery':1.2544,'expansion':1.12}
def _seedrandom(seed):
    """seedrandom 2.4.2 (ARC4), as the game's seedrand service uses it: returns the generator function."""
    W=256; mask=255; key=[]; smear=0
    for j,ch in enumerate(seed):
        i=mask&j
        while len(key)<=i: key.append(None)
        if key[i] is not None: smear^=key[i]*19
        key[i]=mask&(smear+ord(ch))
    keylen=len(key); S=list(range(W)); j=0
    if not keylen: key=[0]; keylen=1
    for i in range(W):
        t=S[i]; j=mask&(j+key[i%keylen]+t); S[i]=S[j]; S[j]=t
    st=[0,0]
    def g(count):
        r=0; i,j=st
        for _ in range(count):
            i=mask&(i+1); t=S[i]; j=mask&(j+t); S[i]=S[j]; S[j]=t
            r=r*W+S[mask&(S[i]+t)]
        st[0]=i; st[1]=j
        return r
    g(W)
    def prng():
        n=float(g(6)); d=float(W**6); x=0
        while n<2.0**52: n=(n+x)*W; d*=W; x=g(1)
        while n>=2.0**53: n/=2; d/=2; x>>=1
        return (n+x)/d
    return prng
def js_date_string(ms):
    """Date.prototype.toString() in the zone SEED_TZ names (UTC by default)."""
    import datetime
    off,name=SEED_TZ; sign=1 if off[0]=='+' else -1
    d=datetime.datetime.fromtimestamp(ms/1000.0,datetime.timezone.utc)+sign*datetime.timedelta(hours=int(off[1:3]),minutes=int(off[3:5]))
    return d.strftime('%a %b %d %Y %H:%M:%S')+' GMT'+off+' ('+name+')'
def premut_roll(s,upname,level,mode=None,raw=False):
    """Premutagen the game adds when `upname` (hatchery or expansion) reaches `level` (effect.coffee addUnitRand).
    Returns (spawned, qty). 'expected' returns the mean: probability x mean quantity (ceil ignored)."""
    mode=mode or PREMUT
    minlevel=s.minlevel[upname]
    if level<minlevel: return False,0.0
    base=s.each*bn.F(PREMUT_FACTOR[upname])**level
    sure=(level==minlevel or level%8==0)
    if mode=='expected': return True,base*(1.0 if sure else min(1.0,s.freq))
    rng=_seedrandom('%s:[%d, %s, %d]'%(s.seedbase,s.restarted_ms,upname,level))
    roll=rng(); spawned=sure or roll<s.freq
    roll2=rng(); qty=math.ceil(base*(0.9+roll2*0.2))   # the game ceils a Decimal; float is close enough here
    return spawned,(bn.big(qty) if spawned or raw else 0.0)   # raw: the quantity even when nothing spawns (as output() reports it)
NEXUS_E={2:625,3:2500,4:10000,5:36000}   # energy price of nexus 2..5 (nexus 1 costs only meat)
def espent(s):
    """game.ascendEnergySpent(): energy price of every unit owned plus every upgrade level bought this run."""
    e=10*(s.moth+s.nightbug)+100*s.bat+sum(v for k,v in NEXUS_E.items() if s.nexus>=k)
    for sp,n in list(s.casts.items())+list(s.casts0.items()): e+=n*SPELL[sp][0]
    return e-s.respecE
def asc_cost(s):
    """game.ascendCost(): 5e6 x 1.12^ascensions / 2^(spent / (50000 x mutantnexus ascendCost stat)), ceil."""
    c=5e6*1.12**s.asc/2.0**(espent(s)/(50000.0*s.acm))
    r=round(c)
    return r if abs(c-r)<=1e-9*c else math.ceil(c)   # the game's Decimal is exact: 5e6 x 1.12 is 5,600,000, not 5,600,001
def unlock_cost(s): return UNLOCK_FACTOR**s.unlocks
def on_upgrade(s,p,name,level):
    """Side effects of buying a hatchery or expansion level: premutagen roll, crystal timer."""
    sp,q=premut_roll(s,name,level) if PREMUT else (False,0.0)
    s.upg_log.append((s.time,name,level,s.asc,q if sp else 0.0))
    if sp: s.premut+=q; s.premut_log.append((s.time,name,level,q))
    if (CRYSTALS or p.get('crystals')) and s.nexus>=1 and s.time-s.ctimer>=1800:
        s.ctimer=s.time; s.energy+=500; s.mtx+=500; s.crystals_got+=500
class S: pass
def load():
    d=json.load(open(os.environ.get('SAVE','/tmp/save.json'))); u=d['unittypes']; g=d['upgrades']
    s=S(); s.c=[bn.num(u.get(n,0)) for n in NAMES]            # c[0]=meat
    s.achpts=ACH if ACH is not None else achievement_points(d)
    s.bought={n:bn.num(v.get('twinnum',0)) for n,v in d.get('statistics',{}).get('byUnit',{}).items()}
    modelled=set(NAMES[1:]+TN+['expansion','nexus5'])
    s.unearned=[n for n,(pts,req,val) in _achievements().items()
                if n not in d.get('achievements',{}) and req in modelled and pts>0 and val!='']
    # Cocoons are larvae parked 1:1 (the game converts both ways for free; they make nothing and count
    # toward clone larvae like larvae), so the simulator holds them as larvae.
    s.larva=bn.num(u['larva'])+float(u.get('cocoon',0)); s.terr=bn.num(u['territory'])
    s.prod=[0]*(K+2); s.twin=[0]*(K+2)
    for k in range(1,K+1):
        s.prod[k]=int(g.get(NAMES[k]+'prod',0)); s.twin[k]=int(g.get(NAMES[k]+'twin',0))
    s.t=[bn.num(u[n]) for n in TN]; s.tt=[int(g.get(n+'twin',0)) for n in TN]; s.emp=[int(g.get(n+'empower',0)) for n in TN]; s.emp_log=[]
    s.hatch=int(g['hatchery']); s.exp=int(g['expansion']); s.ach=int(g['achievementbonus'])
    s.energy=float(u.get('energy',0)); s.nexus=int(float(u.get('nexus',0))); s.moth=float(u.get('moth',0)); s.bat=float(u.get('bat',0)); s.nightbug=float(u.get('nightbug',0)); s.mtx=float(u.get('mtxEnergy',0)); s.hatched=[0.0]*(K+2); s.hprev=[0.0]*(K+2); s.carry=[0.0]*(K+2); s.reserve=0.0; s.nexres=0.0; s.casts={}; s.earned=bn.F(0.0)
    s.lastbuy=[-1e18]*(K+2); s.firstclimb={}; s.fa_log=[]; s.purse=0.0; s.time=0.0; s.spent=[0.0]*(K+1); s.spentT=0.0
    load_ascension(s,d)
    return s
def _ms(iso):
    import datetime
    return int(round(datetime.datetime.fromisoformat(iso.replace('Z','+00:00')).timestamp()*1000))
def load_ascension(s,d):
    """Mutagen, premutagen, mutant units, unlocks, ascension count, energy spent, crystals, run clock."""
    u=d['unittypes']; g=d['upgrades']; dt=d.get('date',{})
    s.mutagen=bn.num(u.get('mutagen',0)); s.premut=bn.num(u.get('premutagen',0)); s.asc=int(float(u.get('ascension',0)))
    s.freerespec=int(float(u.get('freeRespec',4))); s.respecE=float(u.get('respecEnergy',0))
    s.mut={m:bn.num(u.get(m,0)) for m in MUTANTS}
    s.unlocked=[n for n in MUTATE if int(float(g.get(n,0)))>0]; s.unlocks=len(s.unlocked)
    s.casts0={sp:float(g.get(up,0)) for sp,up in SPELL_UP.items() if float(g.get(up,0))>0}   # casts before the save
    s.crystal=float(u.get('crystal',0))
    s.ach_have=set(d.get('achievements',{}))
    s.t0_ms=_ms(dt['reified']) if 'reified' in dt else 0
    s.started_ms=_ms(dt['started']) if 'started' in dt else 0
    s.restarted_ms=_ms(dt.get('restarted',dt.get('started'))) if 'started' in dt else 0
    s.seedbase=js_date_string(s.started_ms)
    s.ctimer=((_ms(dt['addUnitTimed-crystal'])-s.t0_ms)/1000.0) if 'addUnitTimed-crystal' in dt else -1e18
    s.premut_log=[]; s.upg_log=[]; s.crystals_got=0.0; s.run_off=0.0; s.asc_log=[]; s.want_asc=False; s.saving_asc=False
    refresh_mut(s)
def lam(s): return LMULT*(1+s.hatch)*X11**s.exp*(1+0.001*s.achpts)**s.ach*s.lm+MUTAGEN_LARVA*s.mutagen
def P(s,k): return BASEP[k]*TWO**s.prod[k]*(MMULT if k==1 else 1)*s.mm[k]
def trate(s):
    if EMPOWER_MODEL: return sum(s.t[j]*TP[j]*s.tm[j]*EMP_PROD**s.emp[j] for j in range(11))
    return sum(s.t[j]*TP[j]*s.tm[j] for j in range(11))
# Territory empower (`<unit>empower` upgrades). EMPOWER_MODEL (default False, so earlier results are unchanged):
# level e multiplies the unit's production by 1.53228e18^e (45^11) and its meat cost by 1.53228e29^e (450^11);
# the next level costs EMP_BASE[j] x 1.53228e29^e meat; buying it wipes the units of that kind (compoundUnit 0).
EMPOWER_MODEL=False
EMP_PROD=bn.F(1.53228e18); EMP_COST=bn.F(1.53228e29)
EMP_BASE=[1.14921e32,5.17144e34,2.32715e37,1.04722e40,4.71247e42,2.12061e45,9.54276e47,4.29424e50,1.93241e53,8.69584e55,3.91313e58]
def tcosts(s):
    if not EMPOWER_MODEL: return TC
    return [TC[j]*EMP_COST**s.emp[j] for j in range(11)]
def empower_price(s,j): return EMP_BASE[j]*EMP_COST**s.emp[j]
def empower_policy(s,p,Mb,Lb):
    """Policy option `empower` (needs EMPOWER_MODEL): the native advisor's empowerAdvice. Empower the cheapest
    rung when the territory larvae (Lb, at least 1) all fit in the most expensive rung with the empower's price
    still to spare, and the units it wipes make under 1% of territory income (`emp_share`)."""
    tc=tcosts(s); order=sorted(range(11),key=lambda j:tc[j]); low=order[0]; top=order[-1]
    price=empower_price(s,low)
    if price+tc[top]*max(Lb,1)>Mb: return
    inc=trate(s); wiped=s.t[low]*TP[low]*s.tm[low]*EMP_PROD**s.emp[low]
    if inc>0 and wiped/inc>=p.get('emp_share',0.01): return
    s.c[0]-=price; s.emp[low]+=1; s.t[low]=bn.F(0.0); s.emp_log.append((s.time,TN[low],s.emp[low]))
# Upgrade prices (checked against the game's totalCost() in MODEL-CHECK.md).
def anc_cost(s): return 5e6*1e4**s.ach, 500*1e4**s.ach          # accomplished ancestry: meat, territory
def exp_cost(s): return 10*X245**s.exp                           # expansion: territory
def hatch_cost(s): return 300*TEN**s.hatch                      # hatchery: meat
def prod_cost(s,k): return 66*X666**s.prod[k]                   # faster tier k: units of tier k
def twin_cost(s,k): return TWINF[k]**s.twin[k]                    # twin tier k: units of tier k+1 (k<=19)
def tt_cost(s,j): return 100*X500**s.tt[j], X50**s.tt[j]       # territory twin: meat, larvae
def epow(s): return (1+0.6*(1-1/(1+0.001*s.bat)))*s.pwb
def erate(s): return 0.1*s.nexus*(1+(1-1/(1+0.001*s.moth)))*s.em
# nightbugs: cap toward 6x (none bought by the policy); mtxEnergy (energy bought with crystals) adds 1 each (capFlat)
def ecap(s): return 10000.0*s.nexus*(1+5*(1-1/(1+0.001*getattr(s,'nightbug',0.0))))*s.cm+getattr(s,'mtx',0.0)
NEX={0:(3333333333333.0,0,0,2000),1:(3.33333e15,625,0,4000),2:(3.33333e18,2500,3333333,6000),3:(3.33333e21,10000,33333330,8000),4:(3.33333e24,36000,3333333000,10000)}
SPELL={'warp':(2000,1),'larvarush':(1600,1),'meatrush':(1600,2),'terrrush':(1600,3),'clone':(12000,4),'mirror':(2500,5)}
def energy_policy(s,p,gained):
    if not p.get('energy'): return
    s.nexres=0.0
    hold=0.0
    while s.nexus in NEX:
        m,e,l,g=NEX[s.nexus]
        if s.c[0]>=m and s.energy>=e and s.larva>=l:
            s.c[0]-=m; s.energy-=e; s.larva-=l; s.nexus+=1; s.energy=min(ecap(s),s.energy+g); s.reserve=min(s.reserve,s.larva)
        else:
            if s.c[0]>=m/p.get('nexus_soon',30) and l<=p.get('nexus_secs',3600)*lam(s): hold=e; s.nexres=min(l,s.larva)
            break
    if ascend_saving(s,p): return
    mt=p.get('moth_N5',p.get('moth_N',0)) if s.nexus>=5 else p.get('moth_N',0)
    if p.get('moth_late') and run_age(s,p)>=p['moth_late'][0]: mt=p['moth_late'][1]   # (run age, target): raise the target later in a run
    if s.nexus>=4 and s.moth<mt:
        n=math.floor(min(mt-s.moth,max(0,s.energy-hold)/10,s.larva))
        if n>0: s.moth+=n; s.energy-=10*n; s.larva-=n
    if s.nexus>=5 and s.bat<p.get('bat_N',0) and s.moth>=mt:
        n=math.floor(min(p['bat_N']-s.bat,max(0,s.energy-hold)/100,s.larva))
        if n>0: s.bat+=n; s.energy-=100*n; s.larva-=n
    pw=epow(s)
    if 'clone' in p.get('spells',()) and s.nexus>=4:
        s.reserve=min(lam(s)*1e5*pw*s.spw['clone'], s.larva, s.reserve+p.get('res_in',0)*gained)
    order=list(p.get('spells',()))
    mw=p.get('mixw')
    if mw and s.nexus>=5:
        sp0=min(mw,key=lambda x:s.casts.get(x,0)*SPELL[x][0]/mw[x])
        order=[sp0]
    for sp in order:
        cost,req=SPELL[sp]
        if s.nexus<req: continue
        guard=0
        while s.energy-hold>=cost and guard<50:
            guard+=1
            if mw and s.nexus>=5 and guard>1: break
            if sp=='clone' and s.larva<p.get('clone_min',0)*lam(s)*1e5*pw*s.spw['clone'] and s.energy<ecap(s)*0.98: break
            s.energy-=cost; s.casts[sp]=s.casts.get(sp,0)+1
            q=pw*s.spw[sp]   # spell power x the mutant power for this spell (exactly pw without mutants)
            if sp=='warp': advance(s,900*q,True)
            elif sp=='larvarush': s.larva+=lam(s)*2400*q+1e5*q
            elif sp=='meatrush': s.c[0]+=s.c[1]*P(s,1)*7200*q; s.earned+=s.c[1]*P(s,1)*7200*q
            elif sp=='terrrush': s.terr+=trate(s)*7200*q
            elif sp=='clone':
                gain=min(s.larva,lam(s)*1e5*q); s.larva+=gain
                s.reserve=min(lam(s)*1e5*q,max(s.reserve,p.get('clone_keep',0.5)*s.larva))
            elif sp=='mirror': s.t=[x*2 for x in s.t]
        if (mw and s.nexus>=5) or (sp==p.get('spells')[0] and not p.get('spill')): break
def advance(s,dt,skip=False):
    L=lam(s)*dt; s.larva+=L; s.terr+=trate(s)*dt
    if not skip:
        s.time+=dt; e=s.energy+erate(s)*dt; c=ecap(s)
        if e>c: s.ewaste=getattr(s,'ewaste',0.0)+(e-c)   # energy lost to the cap (diagnostic only)
        s.energy=min(c,e)
    new=s.c[:]
    top=K
    while top>0 and not s.c[top]>0: top-=1      # tiers above the highest one owned add nothing (same result, faster)
    for j in range(0,top):
        coef=1.0
        for i in range(j+1,top+1):
            coef*=P(s,i)*dt/(i-j)
            if s.c[i]>0: new[j]+=s.c[i]*coef
    s.earned=getattr(s,'earned',0.0)+new[0]-s.c[0]
    s.c=new
    return L
def H(s,k): return UNITC[k]/TWO**(s.prod[k]+s.twin[k])   # meat break-even horizon of tier k (s) = k x cost/(twin x prodEach)
def allowed(s,p,k):
    if k<2: return True
    ts=p.get('tier_start')
    if ts and k in ts: return p.get('age0',4306)+s.time>=ts[k]
    if H(s,k)<=p['theta']: return True
    if p.get('sat') and k>=3 and s.c[k-1]>0:
        cap=s.c[k-1]*P(s,k-1)/UNITC[k-1]
        if cap>p['sat']*lam(s): return True
    return False
def policy(s,p,gained):
    if p.get('lr_age') and run_age(s,p)<p['lr_age']:   # long-run rules switch on by themselves only from this run age
        p=dict(p,faster_aware=None,push=None)
    if p.get('theta_age'): p['theta']=p['theta_age']*(p.get('age0',4306)+s.time-s.run_off)   # run age (run_off moves at an ascension)
    energy_policy(s,p,gained)
    # --- larva multipliers
    while True:
        b=False
        am,at=anc_cost(s)
        if s.ach<5 and s.c[0]>=am and s.terr>=at: s.c[0]-=am; s.terr-=at; s.ach+=1; b=True
        ec=exp_cost(s)
        if s.terr>=ec*p.get('exp_mult',1): s.terr-=ec; s.exp+=1; b=True; on_upgrade(s,p,'expansion',s.exp)
        hc=hatch_cost(s)
        if s.c[0]>=hc*p['hatch_mult']: s.c[0]-=hc; s.hatch+=1; b=True; on_upgrade(s,p,'hatchery',s.hatch)
        if not b: break
    if p.get('hatch_dyn') and 'mutatehatchery' in s.unlocked: mutant_hatchery_dyn(s,p)
    top=max([k for k in range(1,K+1) if s.c[k]>0] or [1])   # [1]: a fresh run owns no drones yet
    # --- prod upgrades
    for k in range(1,K+1):
        while True:
            cost=prod_cost(s,k)
            if s.c[k]>=p['prod_mult']*cost: s.c[k]-=cost; s.prod[k]+=1
            else: break
    # --- twin upgrades (twin of tier k costs tier k+1)
    twin_pass(s,p)
    # --- twin seeking: hatch just enough tier k+1 units to afford twin_k when its payback is short
    if p.get('twinseek'):
        for k in range(1,K):
            if allowed(s,p,k+1): continue
            need=twin_cost(s,k)-s.c[k+1]
            if need<=0 or s.c[k]<=0: continue
            nb=math.ceil(need/TWO**s.twin[k+1]); costk=nb*UNITC[k+1]
            inc=(s.c[k]*P(s,k)/UNITC[k]) if k>=2 else 1e99
            R=TWO**s.twin[k]*min(lam(s)*(1-p['f']),inc)
            if R<=0: continue
            if (k+1)*costk/R<p['theta']*p.get('seek_f',1) and s.c[k]>=costk*p.get('seek_mult',1) and s.larva-s.reserve-s.nexres>=nb and s.c[0]>=nb*MEATC[k+1]:
                s.c[k]-=costk; s.c[0]-=nb*MEATC[k+1]; s.larva-=nb; s.c[k+1]+=nb*TWO**s.twin[k+1]; buy_stat(s,NAMES[k+1],nb*TWO**s.twin[k+1])
                s.c[k+1]-=twin_cost(s,k); s.twin[k]+=1
    # --- territory
    f=p['f']
    if s.casts.get('mirror') and 'f_mirror' in p: f=p['f_mirror']
    tts=p['tt_secs'] if not (s.casts.get('mirror') and 'tt_mirror' in p) else p['tt_mirror']
    s.purse=max(0.0,min(s.larva-s.reserve-s.nexres, s.purse+f*gained))
    if f>0:
        terrmode=p['terr'] if not (s.casts.get('mirror') and 'terr_mirror' in p) else p['terr_mirror']
        Lb=s.purse; Mb=p['g']*s.c[0]; lr=lam(s)*f
        if EMPOWER_MODEL and p.get('empower'): empower_policy(s,p,Mb,Lb); Mb=p['g']*s.c[0]
        # rungs: territory units in order of meat cost (j order; with empowered units, by live cost)
        TCs=tcosts(s); RG=list(range(11)) if not EMPOWER_MODEL else sorted(range(11),key=lambda j:TCs[j])
        if terrmode=='balanced':
            ri=max([i for i in range(11) if TCs[RG[i]]*max(Lb,1)<=Mb] or [0])
        else:
            ri=max([i for i in range(11) if TCs[RG[i]]<=Mb] or [0])
        js=RG[ri]; jn=RG[ri+1] if ri<10 else None
        # twin for js
        saving=False
        for j in ([js,jn] if jn is not None else [js]):
            tm,tl=tt_cost(s,j)
            if tl<=tts*lr and tm<=Mb and TCs[j]<=Mb:
                if Lb>=tl: s.larva-=tl; s.purse-=tl; Lb-=tl; s.c[0]-=tm; Mb-=tm; s.tt[j]+=1
                else: saving=True
                break
        if not saving and Lb>=1:
            if terrmode=='balanced' and jn is not None and TCs[jn]<=Mb and Lb*TCs[js]<=Mb:   # last test: larvae can outrun meat (mutagen larvae)
                y=max(0.0,min(Lb,(Mb-Lb*TCs[js])/(TCs[jn]-TCs[js]))); x=Lb-y
                buys=[(js,x),(jn,y)]
            else:
                buys=[(js,min(Lb,Mb/TCs[js]))]
            for j,n in buys:
                n=math.floor(n)
                if n<=0: continue
                s.t[j]+=n*TWO**s.tt[j]; s.c[0]-=n*TCs[j]; s.larva-=n; s.purse-=n; s.spentT+=n; buy_stat(s,TN[j],n*TWO**s.tt[j])
    # --- climb, top down
    avail=(s.larva-s.purse if f>0 else s.larva)-s.reserve-s.nexres
    first=True
    s.hprev=s.hatched; s.hatched=[0.0]*(K+2)
    for k in range(min(top+1,K),0,-1):
        fa=False   # tier passes only on the faster-aware test (see faster_aware below)
        if not allowed(s,p,k):
            if not (p.get('faster_aware') and k>=p.get('fa_from',2)): continue
            fa=True
        if k<=p.get('min_tier',1)-1: continue
        if p.get('bank') and k<K and s.c[k+1]>0 and allowed(s,p,k+1) and s.c[k+1]*P(s,k+1) > p['bank']*lam(s)*(1-p['f'])*TWO**s.twin[k]/TWO**s.twin[k+1]: continue
        n=avail
        sh=p.get('share',1.0)
        if first and p.get('share_top'): sh=p['share_top']
        if p.get('time_share'): sh=tshare(sh,p)
        if k>=2 and p.get('alpha'): sh=1-math.exp(-p['alpha']*p['ci']/(H(s,k)/k))
        if k>=2 and p.get('prod_reserve'):
            pc=2*prod_cost(s,k-1)
            if p['prod_reserve']*pc<=s.c[k-1]<pc: continue
        if k>=2: n=min(n,(s.c[k-1]*sh)/UNITC[k])
        n=min(n,s.c[0]*p.get('meatshare',0.5)/MEATC[k])
        if (p.get('res_min') is not None or p.get('res_beta') is not None) and k>=p.get('inc_min_tier',3):
            inflow=(s.c[k]*P(s,k)*p['ci']+s.hprev[k-1])/p['ci']
            if p.get('res_larva_only'): inflow=s.hprev[k-1]/p['ci']
            keep=inflow*(p['res_min']*60 if p.get('res_min') is not None else p['res_beta']*H(s,k)/k)
            n=min(n,max(0.0,(s.c[k-1]-keep))*p.get('res_share',1.0)/UNITC[k])
        phi=p.get('inc_share'); carried=0; carry0=s.carry[k]
        if phi is not None and k>=p.get('inc_min_tier',3) and (not p.get('inc_top_only') or first):
            if p.get('inc_gamma'):
                phi=min(1.0,phi*(p['theta']/H(s,k)/p.get('theta_age',1))**p['inc_gamma'])
            inflow=s.c[k]*P(s,k)*p['ci']+s.hprev[k-1]
            rel=p.get('stock_rel',0)*p['ci']/(H(s,k)/k)
            s.carry[k]=min(s.carry[k]+(phi*inflow+min(1.0,rel)*s.c[k-1])/UNITC[k], s.c[k-1]/UNITC[k])
            n=min(n,s.carry[k])
            n=math.floor(n); s.carry[k]-=n; carried=n
        n=math.floor(n)
        if fa and not faster_aware_passes(s,p,k,n):
            # nothing hatched. Default: the tier's earmark keeps growing while it waits (as the advisor's spare
            # does), so it starts with a slice of the stock. fa_accumulate=False: income only, as a normal start.
            if p.get('fa_accumulate',True): s.carry[k]+=carried
            else: s.carry[k]=carry0
            continue
        if n<=0: continue
        first=False
        if k>=2: s.c[k-1]-=n*UNITC[k]
        s.c[0]-=n*MEATC[k]; s.c[k]+=n*TWO**s.twin[k]; s.larva-=n; avail-=n; s.spent[k]+=n; s.lastbuy[k]=s.time; s.hatched[k]+=n*TWO**s.twin[k]; buy_stat(s,NAMES[k],n*TWO**s.twin[k])
        s.firstclimb.setdefault(NAMES[k],s.time)
        if fa:
            s.fa_log.append((s.time,NAMES[k],s.prod[k],n))
            if p.get('fa_buy',True):
                for _ in range(1 if p.get('faster_aware')!='multi' else 400):
                    if s.c[k]>=prod_cost(s,k): s.c[k]-=prod_cost(s,k); s.prod[k]+=1   # the level(s) the start relied on
                    else: break
                    if p.get('faster_aware')!='multi' or H(s,k)<=p['theta']: break
    if p.get('twin_after'): twin_pass(s,p)   # twin_after: twins for the tiers just hatched, in the same visit (as the native advisor's tips)
    if p.get('push'):
        for _ in range(p['push'].get('rounds',1)): push_up(s,p)   # rounds: the player follows the push suggestions several times in one visit
    earn_achievements(s)
def hatch(s,k,n):
    """Buy n of meat tier k (n hatch events, n x 2^twin units), with the same bookkeeping as the climb."""
    if k>=2: s.c[k-1]-=n*UNITC[k]
    s.c[0]-=n*MEATC[k]; s.c[k]+=n*TWO**s.twin[k]; s.larva-=n; s.spent[k]+=n; s.lastbuy[k]=s.time
    s.hatched[k]+=n*TWO**s.twin[k]; buy_stat(s,NAMES[k],n*TWO**s.twin[k]); s.firstclimb.setdefault(NAMES[k],s.time)
def push_frontier(s,p): return max([k for k in range(1,K+1) if s.c[k]>0 and allowed(s,p,k)] + [p['push'].get('from',2)-1])   # push only tiers >= push['from']
def push_up(s,p):
    """Policy option `push` (default off), for the achievement objective: {'goal': tier, 'share': f, 'base': f0}.
    Tiers above the climb frontier (the highest tier whose break-even H passes the horizon) never pay back
    their price, so the climb rules never buy them; but the goal is to own and to have bought them. Every
    check-in, from the goal tier down to just above the frontier, hatch with a share of the tier below:
    `share` for tiers above frontier+1, `base` (small) for the first tier above the frontier, whose price
    comes out of the top growing tier. Limited by larvae (after the territory purse and reserves) and by
    half the meat."""
    q=p['push']; G=min(q.get('goal',K),K)
    frontier=push_frontier(s,p)
    larva=s.larva-s.reserve-s.nexres-(s.purse if p['f']>0 else 0)
    order=range(frontier+1,G+1) if q.get('bottom_up') else range(G,frontier,-1)   # bottom_up: a visit can carry units several tiers up
    for k in order:
        if s.c[k-1]<=0 or larva<1: continue
        sh=q.get('share',0.5) if k>frontier+1 else q.get('base',0.02)
        if p.get('time_share'): sh=tshare(sh,p)
        n=math.floor(min(sh*s.c[k-1]/UNITC[k], larva, s.c[0]*0.5/MEATC[k]))
        if n<1: continue
        hatch(s,k,n); larva-=n
def tshare(sh,p):
    """`time_share` (default off): a share stated per minute, applied over the time since the last visit, as the
    native advisor sizes purchases: 1 - (1 - share)^(minutes since). At one-minute visits it is the share itself."""
    return 1-(1-sh)**(p['ci']/60.0)
def twin_pass(s,p):
    """Twin upgrades (twin of tier k costs tier k+1), as the tuned policy buys them."""
    for k in range(1,K):
        while True:
            cost=twin_cost(s,k)
            if p.get('twin_used') and s.time-s.lastbuy[k]>p['twin_used']+(p['ci'] if p.get('twin_used_gap') else 0): break   # twin_used_gap: 'recently' counts from the previous visit
            if p.get('twin_r') and s.c[k+1]*P(s,k+1) > p['twin_r']*lam(s)*(1-p['f'])*TWO**s.twin[k]/TWO**s.twin[k+1]: break
            if p.get('twin_flow'):
                inc=(s.c[k]*P(s,k)/UNITC[k]) if k>=2 else 1e99
                R=TWO**s.twin[k]*min(lam(s)*(1-p['f']),inc)
                if R < p['twin_flow']*cost*P(s,k+1): break
            if p.get('push') and k+1>push_frontier(s,p) and s.c[k+1]<p['push'].get('twin_mult',1)*cost: break   # keep pushed units for climbing
            if s.c[k+1]>=p['twin_mult']*cost and s.c[k+1]>=cost: s.c[k+1]-=cost; s.twin[k]+=1
            else: break
def faster_aware_passes(s,p,k,n):
    """Policy option `faster_aware` (default off). A tier that fails the run-age test may still be climbed
    when its break-even clock, counted as if the next faster level were bought out of this purchase, is
    under the horizon. N = units held after the purchase and after paying the upgrade's price F (66 x 666^level
    units of the tier itself); the sunk F counts as cost, production counts N at double rate:
        H_eff = k x (N + F) x cost_each / (N x 2 x prodEach) = H x (N + F) / (2 N)
    n is what the policy could hatch at this check-in under its usual share/carry/meat/larva limits. With
    `fa_naive`, H_eff = H / 2 (the upgrade counted, its price not). Never passes unless N >= 1 after paying F."""
    if p.get('faster_aware')=='multi': return faster_levels(s,p,k,n)>0
    F=prod_cost(s,k); got=s.c[k]+n*TWO**s.twin[k]; N=got-F
    if n<=0 or N<1: return False
    Heff=H(s,k)/2 if p.get('fa_naive') else H(s,k)*(N+F)/(2*N)
    return Heff<=p['theta']
def faster_levels(s,p,k,n):
    """`faster_aware='multi'` (default off): the same honest test as above, but allowing any number L >= 1 of
    faster levels bought out of the purchase: N = held + n x twin - (price of L levels), H_eff = H x (N + F_L) /
    (N x 2^L). Returns the smallest L that passes (0 if none does). On the way up a long chain, a tier whose
    plain H is far over the horizon becomes worth climbing once one check-in can buy it by the 1e40."""
    if n<=0: return 0
    got=s.c[k]+n*TWO**s.twin[k]; Fl=0.0; h=H(s,k)
    for L in range(1,400):
        Fl=Fl+prod_cost_at(s,k,s.prod[k]+L-1); N=got-Fl
        if N<1: return 0
        if h*(N+Fl)/(N*TWO**L)<=p['theta']: return L
    return 0
def prod_cost_at(s,k,level): return 66*X666**level
def run_age(s,p): return p.get('age0',4306)+s.time-s.run_off
def asc_cfg(s,p):
    """The ascension rule for the current run: p['ascend'] is a list, one entry per future ascension made in
    this simulation (None or a missing entry: never ascend). Entry: {'after': run age in seconds before
    which the policy does not start saving energy for the ascension}."""
    A=p.get('ascend')
    if not A: return None
    k=len(s.asc_log)
    return A[k] if k<len(A) else None
def ascend_saving(s,p):
    """Policy option `ascend` (default off). Once the run is old enough and the ascension cost fits under the
    energy cap, stop spending energy (spending lowers the cost until then, so mirrors keep going) and ascend
    as soon as the energy is there. Returns True while saving, so the rest of the energy policy is skipped."""
    A=asc_cfg(s,p); s.saving_asc=False
    if A is None or run_age(s,p)<A.get('after',0): return False
    c=asc_cost(s)
    # Spending E more energy lowers the cost by about c x E ln2 / (50000 x acm), so spending beats saving
    # until c falls to 50000 x acm / ln 2 (72,135 without the nexus mutation); the cost must also fit the cap.
    if c>min(ecap(s)*A.get('cap_frac',1.0), A.get('save_below',50000.0*s.acm/math.log(2))): return False
    s.saving_asc=True
    if s.energy>=c: s.want_asc=True
    return True
ASC_ACH=None
def ascend(s,p,plan=None):
    """game.ascend(): premutagen becomes mutagen, the ascension count goes up, a free respec every third
    ascension, the run clock restarts, and every unit and upgrade outside the mutagen tab goes back to its
    starting value (meat 35, larvae 10, everything else 0). Kept: mutagen, premutagen (now 0), mutant units,
    unlocks, crystals and crystal-bought energy cap (mtxEnergy), achievements, statistics (units bought).
    Then `plan` (see apply_plan) spends mutagen."""
    global ASC_ACH
    cost=asc_cost(s); assert s.energy>=cost, 'cannot afford the ascension'
    rec={'time':s.time,'run_age':run_age(s,p),'premut':s.premut,'cost':cost,'espent':espent(s),'exp':s.exp,'hatch':s.hatch,
         'mutagen_before':s.mutagen,'earned':s.earned}
    s.mutagen+=s.premut; s.premut=0.0; s.asc+=1
    if s.asc%3==0: s.freerespec+=1
    s.restarted_ms=s.t0_ms+int(round(s.time*1000)); rec['restarted_ms']=s.restarted_ms
    if ASC_ACH is None: ASC_ACH=[(n,v[0],float(v[2])) for n,v in _achievements().items() if v[1]=='ascension']
    for n,pts,val in ASC_ACH:
        if n not in s.ach_have and s.asc>=val: s.ach_have.add(n); s.achpts+=pts; log_ach(s,n)
    s.c=[bn.F(0.0)]*(K+1); s.c[0]=bn.F(35.0); s.larva=bn.F(10.0); s.terr=bn.F(0.0)
    s.prod=[0]*(K+2); s.twin=[0]*(K+2); s.t=[bn.F(0.0)]*11; s.tt=[0]*11; s.emp=[0]*11
    s.hatch=0; s.exp=0; s.ach=0; s.energy=0.0; s.nexus=0; s.moth=0.0; s.bat=0.0; s.nightbug=0.0
    s.hatched=[0.0]*(K+2); s.hprev=[0.0]*(K+2); s.carry=[0.0]*(K+2); s.reserve=0.0; s.nexres=0.0; s.purse=0.0
    s.casts={}; s.casts0={}; s.respecE=0.0; s.lastbuy=[-1e18]*(K+2); s.firstclimb={}; s.fa_log=[]
    s.spent=[0.0]*(K+1); s.spentT=0.0
    s.run_off=s.time+p.get('age0',4306); s.want_asc=False; s.saving_asc=False
    rec['bought']=apply_plan(s,plan or {})
    rec['mutagen_after']=s.mutagen
    s.asc_log.append(rec)
    return rec
def apply_plan(s,plan):
    """Spend mutagen after an ascension. plan = {'unlock': [mutate upgrade names, in order],
    'buy': {mutant: n}} where n >= 1 is a count and 0 < n < 1 a share of the mutagen held at that point.
    An unlock costs 15625^(unlocks so far) and comes with one free unit (mutation1 achievement on the first)."""
    out=[]
    for up in plan.get('unlock',[]):
        if up in s.unlocked: continue
        c=unlock_cost(s)
        if s.mutagen<c: break
        s.mutagen-=c; s.unlocks+=1; s.unlocked.append(up); s.mut[MUTATE[up]]+=1; out.append((up,c))
        for an,(pts,req,val) in _achievements().items():   # mutation1..4: 1, 3, 6, 10 unlocks
            if req=='mutatehidden' and an not in s.ach_have and s.unlocks>=float(val): s.ach_have.add(an); s.achpts+=pts; log_ach(s,an)
    for mu,n in plan.get('buy',{}).items():
        if 'mutate'+mu[len('mutant'):] not in s.unlocked: continue
        n=math.floor(n if n>=1 else n*s.mutagen); n=min(n,math.floor(s.mutagen))
        if n>0: s.mutagen-=n; s.mut[mu]+=n; out.append((mu,n))
    refresh_mut(s)
    return out
def mutant_hatchery_dyn(s,p):
    """Policy option `hatch_dyn`: hold hatchery mutants at the count that maximises larvae now.
    Larvae = B x log10(10 + x) + 0.1 x (M - x), with B the hatchery larvae before the mutation, so the best x is
    B / (0.1 ln 10) - 10. Mutants are never sold, so this only ever buys."""
    B=(lam(s)-MUTAGEN_LARVA*s.mutagen)/s.lm
    x=B/(MUTAGEN_LARVA*math.log(10))-10
    n=math.floor(min(x-s.mut['mutanthatchery'],s.mutagen*p.get('hatch_dyn_max',1.0)))
    if n>=1: s.mutagen-=n; s.mut['mutanthatchery']+=n; refresh_mut(s)
def snap(s,p):
    """One row of a cycle record (all numbers, log10 where they get large)."""
    lg=lambda x:bn.lg(x) if x>0 else float('-inf')
    return {'t':s.time/3600,'age':run_age(s,p)/3600,'asc':s.asc,'premut':s.premut,'mutagen':s.mutagen,'total':s.mutagen+s.premut,
            'exp':s.exp,'hatch':s.hatch,'nexus':s.nexus,'energy':s.energy,'espent':espent(s),'cost':asc_cost(s),'cap':ecap(s),
            'erate':erate(s),'lmeat':lg(s.c[1]*P(s,1)),'llarva':lg(lam(s)),'earned':lg(s.earned),
            'top':max([k for k in range(1,K+1) if s.c[k]>0] or [0]),'mirrors':s.casts.get('mirror',0),'saving':s.saving_asc}
def run_cycles(p,ci,hours,plans=None,s0=None,every=3600,stop_on_overflow=True,until=None):
    """Play `hours` of game time from the save (or s0), ascending as p['ascend'] says and spending mutagen
    by plans[i] after the i-th ascension. Returns (final state, rows every `every` seconds, ascension records).
    `hours` is the total game time of the state (s.time), so a run continued from s0 stops at the same clock.
    until(s): stop as soon as it returns True (checked after every check-in).
    Floats overflow when territory passes about 1e308 (~1,000 mirror casts in one run): the run stops there
    and the last row has 'overflow': True."""
    gapf=ci if callable(ci) else None
    p=dict(p,ci=(60.0 if gapf else ci)); s=copy.deepcopy(s0) if s0 is not None else load()
    rows=[snap(s,p)]; nxt=(math.floor(s.time/every)+1)*every; gained=0
    try:
        policy(s,p,0)
        while s.time<hours*3600:
            if gapf: p['ci']=float(gapf(s.time))     # a person's irregular visits: the gap before this visit
            gained=advance(s,p['ci'])
            if s.time>=nxt: rows.append(snap(s,p)); nxt+=every
            policy(s,p,gained)
            if s.want_asc:
                ascend(s,p,(plans or [])[len(s.asc_log)] if plans and len(s.asc_log)<len(plans) else None)
                rows.append(snap(s,p))
                policy(s,p,0)
            if until and until(s): break
    except (OverflowError,ValueError) as e:
        if not stop_on_overflow: raise
        r=snap(s,p) if s.terr<float('inf') else dict(rows[-1]); r['overflow']=str(e); rows.append(r)
    return s,rows,s.asc_log
def run(p,hours,ci,marks,s0=None):
    p=dict(p,ci=ci); s=copy.deepcopy(s0) if s0 is not None else load()
    if s0 is not None: s.time=0.0; s.earned=0.0; s.lastbuy=[t-s0.time for t in s.lastbuy]; s.run_off=0.0; s.ctimer-=s0.time
    out={}; mi=0; gained=0
    policy(s,p,0)
    while mi<len(marks):
        gained=advance(s,ci)
        if s.time>=marks[mi]*3600:
            out[marks[mi]]=(lg(max(1,s.c[1]*P(s,1))), lg(lam(s)), max([k for k in range(1,K+1) if s.c[k]>0] or [0]), copy.deepcopy(s), lg(s.earned)); mi+=1
        policy(s,p,gained)
    return out
if __name__=='__main__':
    s=load(); print('larvae/s',lam(s),'terr/s',trate(s),'meat/s',s.c[1]*P(s,1))
    for k in range(2,7): print(NAMES[k],'H=%.0fs'%H(s,k),'tau=%.0fs'%(H(s,k)/k), 'twin',s.twin[k],'prod',s.prod[k])
