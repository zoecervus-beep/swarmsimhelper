import json, math, copy, sys, os
HERE=os.path.dirname(os.path.abspath(__file__))
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
        if have>=float(val): s.unearned.remove(name); s.achpts+=pts
def buy_stat(s,name,twinnum): s.bought[name]=s.bought.get(name,0.0)+twinnum
K=12  # meat tiers 1..K (drone=1)
NAMES=['meat','drone','queen','nest','greaterqueen','hive','hivequeen','empress','prophet','goddess','pantheon','pantheon2','pantheon3']
BASEP=[0]+list(range(1,K+1))                 # tier k makes k of tier k-1 /s
# Checked against the game (advisor/MODEL-CHECK.md). Meat cost per hatch: drone 10, queen 810, then x90 per tier.
MEATC=[0,10]+[810*90**(k-2) for k in range(2,K+1)]
# Cost in tier k-1 units: 10^k up to pantheon (k=10); pantheon2 and pantheon3 cost 10^12 and 10^14.
UNITC=[0,0]+[10.0**k for k in range(2,11)]+[1e12,1e14]
TN=['swarmling','stinger','spider','mosquito','locust','roach','giantspider','centipede','wasp','devourer','goon']
TC=[750*450.0**j for j in range(11)]
TP=[0.07*45.0**j for j in range(11)]
ACH=None   # achievement points; None = read from the save (see achievement_points). Set a number to override.
LMULT=1.0
MMULT=1.0
class S: pass
def load():
    d=json.load(open(os.environ.get('SAVE','/tmp/save.json'))); u=d['unittypes']; g=d['upgrades']
    s=S(); s.c=[float(u[n]) for n in NAMES]            # c[0]=meat
    s.achpts=ACH if ACH is not None else achievement_points(d)
    s.bought={n:float(v.get('twinnum',0)) for n,v in d.get('statistics',{}).get('byUnit',{}).items()}
    modelled=set(NAMES[1:]+TN+['expansion','nexus5'])
    s.unearned=[n for n,(pts,req,val) in _achievements().items()
                if n not in d.get('achievements',{}) and req in modelled and pts>0 and val!='']
    s.larva=float(u['larva']); s.terr=float(u['territory'])
    s.prod=[0]*(K+2); s.twin=[0]*(K+2)
    for k in range(1,K+1):
        s.prod[k]=int(g.get(NAMES[k]+'prod',0)); s.twin[k]=int(g.get(NAMES[k]+'twin',0))
    s.t=[float(u[n]) for n in TN]; s.tt=[int(g.get(n+'twin',0)) for n in TN]
    s.hatch=int(g['hatchery']); s.exp=int(g['expansion']); s.ach=int(g['achievementbonus'])
    s.energy=float(u.get('energy',0)); s.nexus=int(float(u.get('nexus',0))); s.moth=float(u.get('moth',0)); s.bat=float(u.get('bat',0)); s.nightbug=float(u.get('nightbug',0)); s.hatched=[0.0]*(K+2); s.hprev=[0.0]*(K+2); s.carry=[0.0]*(K+2); s.reserve=0.0; s.nexres=0.0; s.casts={}; s.earned=0.0
    s.lastbuy=[-1e18]*(K+2); s.purse=0.0; s.time=0.0; s.spent=[0.0]*(K+1); s.spentT=0.0
    return s
def lam(s): return LMULT*(1+s.hatch)*1.1**s.exp*(1+0.001*s.achpts)**s.ach
def P(s,k): return BASEP[k]*2.0**s.prod[k]*(MMULT if k==1 else 1)
def trate(s): return sum(s.t[j]*TP[j] for j in range(11))
# Upgrade prices (checked against the game's totalCost() in MODEL-CHECK.md).
def anc_cost(s): return 5e6*1e4**s.ach, 500*1e4**s.ach          # accomplished ancestry: meat, territory
def exp_cost(s): return 10*2.45**s.exp                           # expansion: territory
def hatch_cost(s): return 300*10.0**s.hatch                      # hatchery: meat
def prod_cost(s,k): return 66*666.0**s.prod[k]                   # faster tier k: units of tier k
def twin_cost(s,k): return 10.0**s.twin[k]                       # twin tier k: units of tier k+1 (k<=11)
def tt_cost(s,j): return 100*500.0**s.tt[j], 50.0**s.tt[j]       # territory twin: meat, larvae
def epow(s): return 1+0.6*(1-1/(1+0.001*s.bat))
def erate(s): return 0.1*s.nexus*(1+(1-1/(1+0.001*s.moth)))
def ecap(s): return 10000.0*s.nexus*(1+5*(1-1/(1+0.001*getattr(s,'nightbug',0.0))))   # nightbugs: cap toward 6x (none bought by the policy)
NEX={1:(3.33333e15,625,0,4000),2:(3.33333e18,2500,3333333,6000),3:(3.33333e21,10000,33333330,8000),4:(3.33333e24,36000,3333333000,10000)}
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
    mt=p.get('moth_N5',p.get('moth_N',0)) if s.nexus>=5 else p.get('moth_N',0)
    if s.nexus>=4 and s.moth<mt:
        n=math.floor(min(mt-s.moth,max(0,s.energy-hold)/10,s.larva))
        if n>0: s.moth+=n; s.energy-=10*n; s.larva-=n
    if s.nexus>=5 and s.bat<p.get('bat_N',0) and s.moth>=mt:
        n=math.floor(min(p['bat_N']-s.bat,max(0,s.energy-hold)/100,s.larva))
        if n>0: s.bat+=n; s.energy-=100*n; s.larva-=n
    pw=epow(s)
    if 'clone' in p.get('spells',()) and s.nexus>=4:
        s.reserve=min(lam(s)*1e5*pw, s.larva, s.reserve+p.get('res_in',0)*gained)
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
            if sp=='clone' and s.larva<p.get('clone_min',0)*lam(s)*1e5*pw and s.energy<ecap(s)*0.98: break
            s.energy-=cost; s.casts[sp]=s.casts.get(sp,0)+1
            if sp=='warp': advance(s,900*pw,True)
            elif sp=='larvarush': s.larva+=lam(s)*2400*pw+1e5*pw
            elif sp=='meatrush': s.c[0]+=s.c[1]*P(s,1)*7200*pw; s.earned+=s.c[1]*P(s,1)*7200*pw
            elif sp=='terrrush': s.terr+=trate(s)*7200*pw
            elif sp=='clone':
                gain=min(s.larva,lam(s)*1e5*pw); s.larva+=gain
                s.reserve=min(lam(s)*1e5*pw,max(s.reserve,p.get('clone_keep',0.5)*s.larva))
            elif sp=='mirror': s.t=[x*2 for x in s.t]
        if (mw and s.nexus>=5) or (sp==p.get('spells')[0] and not p.get('spill')): break
def advance(s,dt,skip=False):
    L=lam(s)*dt; s.larva+=L; s.terr+=trate(s)*dt
    if not skip: s.time+=dt; s.energy=min(ecap(s),s.energy+erate(s)*dt)
    new=s.c[:]
    for j in range(0,K):
        coef=1.0
        for i in range(j+1,K+1):
            coef*=P(s,i)*dt/(i-j)
            if s.c[i]>0: new[j]+=s.c[i]*coef
    s.earned=getattr(s,'earned',0.0)+new[0]-s.c[0]
    s.c=new
    return L
def H(s,k): return UNITC[k]/2.0**(s.prod[k]+s.twin[k])   # meat break-even horizon of tier k (s) = k x cost/(twin x prodEach)
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
    if p.get('theta_age'): p['theta']=p['theta_age']*(p.get('age0',4306)+s.time)
    energy_policy(s,p,gained)
    # --- larva multipliers
    while True:
        b=False
        am,at=anc_cost(s)
        if s.ach<5 and s.c[0]>=am and s.terr>=at: s.c[0]-=am; s.terr-=at; s.ach+=1; b=True
        ec=exp_cost(s)
        if s.terr>=ec*p.get('exp_mult',1): s.terr-=ec; s.exp+=1; b=True
        hc=hatch_cost(s)
        if s.c[0]>=hc*p['hatch_mult']: s.c[0]-=hc; s.hatch+=1; b=True
        if not b: break
    top=max(k for k in range(1,K+1) if s.c[k]>0)
    # --- prod upgrades
    for k in range(1,K+1):
        while True:
            cost=prod_cost(s,k)
            if s.c[k]>=p['prod_mult']*cost: s.c[k]-=cost; s.prod[k]+=1
            else: break
    # --- twin upgrades (twin of tier k costs tier k+1)
    for k in range(1,K):
        while True:
            cost=twin_cost(s,k)
            if k>=13: break
            if p.get('twin_used') and s.time-s.lastbuy[k]>p['twin_used']: break
            if p.get('twin_r') and s.c[k+1]*P(s,k+1) > p['twin_r']*lam(s)*(1-p['f'])*2.0**s.twin[k]/2.0**s.twin[k+1]: break
            if p.get('twin_flow'):
                inc=(s.c[k]*P(s,k)/UNITC[k]) if k>=2 else 1e99
                R=2.0**s.twin[k]*min(lam(s)*(1-p['f']),inc)
                if R < p['twin_flow']*cost*P(s,k+1): break
            if s.c[k+1]>=p['twin_mult']*cost and s.c[k+1]>=cost: s.c[k+1]-=cost; s.twin[k]+=1
            else: break
    # --- twin seeking: hatch just enough tier k+1 units to afford twin_k when its payback is short
    if p.get('twinseek'):
        for k in range(1,K):
            if allowed(s,p,k+1): continue
            need=twin_cost(s,k)-s.c[k+1]
            if need<=0 or s.c[k]<=0: continue
            nb=math.ceil(need/2.0**s.twin[k+1]); costk=nb*UNITC[k+1]
            inc=(s.c[k]*P(s,k)/UNITC[k]) if k>=2 else 1e99
            R=2.0**s.twin[k]*min(lam(s)*(1-p['f']),inc)
            if R<=0: continue
            if (k+1)*costk/R<p['theta']*p.get('seek_f',1) and s.c[k]>=costk*p.get('seek_mult',1) and s.larva-s.reserve-s.nexres>=nb and s.c[0]>=nb*MEATC[k+1]:
                s.c[k]-=costk; s.c[0]-=nb*MEATC[k+1]; s.larva-=nb; s.c[k+1]+=nb*2.0**s.twin[k+1]; buy_stat(s,NAMES[k+1],nb*2.0**s.twin[k+1])
                s.c[k+1]-=twin_cost(s,k); s.twin[k]+=1
    # --- territory
    f=p['f']
    if s.casts.get('mirror') and 'f_mirror' in p: f=p['f_mirror']
    tts=p['tt_secs'] if not (s.casts.get('mirror') and 'tt_mirror' in p) else p['tt_mirror']
    s.purse=max(0.0,min(s.larva-s.reserve-s.nexres, s.purse+f*gained))
    if f>0:
        terrmode=p['terr'] if not (s.casts.get('mirror') and 'terr_mirror' in p) else p['terr_mirror']
        Lb=s.purse; Mb=p['g']*s.c[0]; lr=lam(s)*f
        if terrmode=='balanced':
            js=max([j for j in range(11) if TC[j]*max(Lb,1)<=Mb] or [0])
        else:
            js=max([j for j in range(11) if TC[j]<=Mb] or [0])
        # twin for js
        saving=False
        for j in ([js,js+1] if js<10 else [js]):
            tm,tl=tt_cost(s,j)
            if tl<=tts*lr and tm<=Mb and TC[j]<=Mb:
                if Lb>=tl: s.larva-=tl; s.purse-=tl; Lb-=tl; s.c[0]-=tm; Mb-=tm; s.tt[j]+=1
                else: saving=True
                break
        if not saving and Lb>=1:
            if terrmode=='balanced' and js<10 and TC[js+1]<=Mb:
                y=max(0.0,min(Lb,(Mb-Lb*TC[js])/(TC[js+1]-TC[js]))); x=Lb-y
                buys=[(js,x),(js+1,y)]
            else:
                buys=[(js,min(Lb,Mb/TC[js]))]
            for j,n in buys:
                n=math.floor(n)
                if n<=0: continue
                s.t[j]+=n*2.0**s.tt[j]; s.c[0]-=n*TC[j]; s.larva-=n; s.purse-=n; s.spentT+=n; buy_stat(s,TN[j],n*2.0**s.tt[j])
    # --- climb, top down
    avail=(s.larva-s.purse if f>0 else s.larva)-s.reserve-s.nexres
    first=True
    s.hprev=s.hatched; s.hatched=[0.0]*(K+2)
    for k in range(min(top+1,K),0,-1):
        if not allowed(s,p,k): continue
        if k<=p.get('min_tier',1)-1: continue
        if p.get('bank') and k<K and s.c[k+1]>0 and allowed(s,p,k+1) and s.c[k+1]*P(s,k+1) > p['bank']*lam(s)*(1-p['f'])*2.0**s.twin[k]/2.0**s.twin[k+1]: continue
        n=avail
        sh=p.get('share',1.0)
        if first and p.get('share_top'): sh=p['share_top']
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
        phi=p.get('inc_share')
        if phi is not None and k>=p.get('inc_min_tier',3) and (not p.get('inc_top_only') or first):
            if p.get('inc_gamma'):
                phi=min(1.0,phi*(p['theta']/H(s,k)/p.get('theta_age',1))**p['inc_gamma'])
            inflow=s.c[k]*P(s,k)*p['ci']+s.hprev[k-1]
            rel=p.get('stock_rel',0)*p['ci']/(H(s,k)/k)
            s.carry[k]=min(s.carry[k]+(phi*inflow+min(1.0,rel)*s.c[k-1])/UNITC[k], s.c[k-1]/UNITC[k])
            n=min(n,s.carry[k])
            n=math.floor(n); s.carry[k]-=n
        n=math.floor(n)
        if n<=0: continue
        first=False
        if k>=2: s.c[k-1]-=n*UNITC[k]
        s.c[0]-=n*MEATC[k]; s.c[k]+=n*2.0**s.twin[k]; s.larva-=n; avail-=n; s.spent[k]+=n; s.lastbuy[k]=s.time; s.hatched[k]+=n*2.0**s.twin[k]; buy_stat(s,NAMES[k],n*2.0**s.twin[k])
    earn_achievements(s)
def run(p,hours,ci,marks,s0=None):
    p=dict(p,ci=ci); s=copy.deepcopy(s0) if s0 is not None else load()
    if s0 is not None: s.time=0.0; s.earned=0.0; s.lastbuy=[t-s0.time for t in s.lastbuy]
    out={}; mi=0; gained=0
    policy(s,p,0)
    while mi<len(marks):
        gained=advance(s,ci)
        if s.time>=marks[mi]*3600:
            out[marks[mi]]=(math.log10(max(1,s.c[1]*P(s,1))), math.log10(lam(s)), max(k for k in range(1,K+1) if s.c[k]>0), copy.deepcopy(s), math.log10(s.earned)); mi+=1
        policy(s,p,gained)
    return out
if __name__=='__main__':
    s=load(); print('larvae/s',lam(s),'terr/s',trate(s),'meat/s',s.c[1]*P(s,1))
    for k in range(2,7): print(NAMES[k],'H=%.0fs'%H(s,k),'tau=%.0fs'%(H(s,k)/k), 'twin',s.twin[k],'prod',s.prod[k])
