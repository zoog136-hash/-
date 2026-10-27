#!/usr/bin/env python3
"""Original raster VFX painting. No external pixels, extracted silhouettes or fonts.

The light fields, heated materials, turbulence, blade sheets and filigree are
independently constructed. Reference observation never implies fidelity approval.
Coordinates use the game's 128px logical cell; paint at 256 then downsample.
"""
from __future__ import annotations
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE=256
SCALE=SIZE/128
Y,X=np.mgrid[0:SIZE,0:SIZE].astype(np.float32)/SCALE
TAU=math.tau


def clip(x): return np.clip(x,0,1)
def smooth(a,b,x):
    t=clip((x-a)/(b-a));return t*t*(3-2*t)
def pts(points):return [(round(x*SCALE),round(y*SCALE)) for x,y in points]
def curve(a,b,c,d,n=50):
    return [tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]+3*(1-t)*t*t*c[k]+t**3*d[k] for k in (0,1)) for t in np.linspace(0,1,n)]


def noise(seed,phase=0):
    """Coherent, advected multi-scale value noise; no per-frame random flicker."""
    rng=np.random.default_rng(seed%2**32);out=np.zeros((SIZE,SIZE),np.float32)
    for side,weight in [(4,.47),(8,.27),(16,.15),(32,.075),(64,.035)]:
        values=(rng.random((side,side))*255).astype('uint8')
        layer=np.asarray(Image.fromarray(values).resize((SIZE,SIZE),Image.Resampling.BICUBIC),dtype=np.float32)/255
        out+=np.roll(layer,(round(phase*(side+3)*2),round(phase*(side+1))),axis=(0,1))*weight
    return out

class Paint:
    def __init__(self,seed,palette):
        self.seed=seed;self.rng=random.Random(seed)
        self.light=np.zeros((SIZE,SIZE,3),np.float32)
        self.surface=Image.new('RGBA',(SIZE,SIZE))
        self.n=noise(seed);self.c=np.array(palette[0],dtype=np.float32)/255
        self.hot=np.array(palette[1],dtype=np.float32)/255
        self.dark=np.array(palette[2],dtype=np.float32)/255
    def mask(self,points,width=0):
        m=Image.new('L',(SIZE,SIZE));d=ImageDraw.Draw(m)
        if width:d.line(pts(points),fill=255,width=max(1,round(width*SCALE)),joint='curve')
        else:d.polygon(pts(points),fill=255)
        return m
    def emit(self,field,color=None,power=1):
        c=self.c if color is None else np.array(color,dtype=np.float32)
        self.light+=np.maximum(0,field)[:,:,None]*c[None,None,:]*power
    def glow(self,x,y,rx,ry,color=None,power=1):
        self.emit(np.exp(-(((X-x)/max(.1,rx))**2+((Y-y)/max(.1,ry))**2)*2),color,power)
    def stroke(self,points,width=1,color=None,power=1,halo=2,broken=False):
        m=self.mask(points,width);a=np.asarray(m,dtype=np.float32)/255
        if broken:a*=smooth(.18,.7,self.n)
        self.emit(a,color,power)
        if halo:
            b=np.asarray(m.filter(ImageFilter.GaussianBlur(halo*SCALE)),dtype=np.float32)/255
            self.emit(b,color,power*.75)
    def blade(self,points,width=5,power=1,color=None,taper=True):
        left=[];right=[]
        for i,(x,y) in enumerate(points):
            a=points[max(0,i-1)];b=points[min(len(points)-1,i+1)];dx=b[0]-a[0];dy=b[1]-a[1];l=max(.001,math.hypot(dx,dy))
            w=width*(math.sin(math.pi*i/(len(points)-1))**.75+.015 if taper else 1)
            left.append((x-dy/l*w,y+dx/l*w));right.append((x+dy/l*w,y-dx/l*w))
        m=self.mask(left+right[::-1]);f=np.asarray(m,dtype=np.float32)/255
        # Uneven luminous sheets retain a sharp leading edge and a fibrous interior.
        f*=.22+smooth(.2,.8,self.n)*.78
        self.emit(f,color,power)
        self.emit(np.asarray(m.filter(ImageFilter.GaussianBlur(3*SCALE)),dtype=np.float32)/255,color,power*.3)
        self.stroke(left,.45,self.hot,power*.8,1)
        self.stroke(points,.65,self.hot,power*.42,1)
    def star(self,x,y,r=5,power=1,color=None):
        c=self.hot if color is None else color
        self.glow(x,y,r*1.5,r*1.5,self.c,.45*power)
        self.stroke([(x-r,y),(x+r,y)],.45,c,power,1)
        self.stroke([(x,y-r*.8),(x,y+r*.8)],.4,c,power,1)
        self.glow(x,y,1.2,1.2,(1,1,.96),power*1.8)
        if r>=9:
            rays=random.Random(self.seed+round(x*7+y*13))
            for i in range(17):
                a=i*TAU/17+rays.uniform(-.08,.08);length=r*rays.uniform(.45,1.15)
                self.stroke([(x+math.cos(a)*2,y+math.sin(a)*2),(x+math.cos(a)*length,y+math.sin(a)*length)],.22,c,power*.5,.7)
    def dust(self,t,count=40,origin=(64,76),radius=45,lift=0,power=1,streak=False):
        rng=random.Random(self.seed+123)
        for i in range(count):
            lag=rng.uniform(-.15,.22);q=max(0,(t-lag)/(1-lag));a=rng.uniform(0,TAU);v=rng.uniform(.22,1)
            x=origin[0]+math.cos(a)*radius*v*q
            y=origin[1]+math.sin(a)*radius*v*q*.55-lift*q+12*q*q
            energy=(1-clip(q))**1.4*power
            r=rng.uniform(.25,1.05)
            if streak:
                self.stroke([(x-math.cos(a)*r*3,y-math.sin(a)*r*2+lift*.025),(x,y)],r*.35,self.hot,energy,1)
            else:self.glow(x,y,r,r,self.hot,energy*2)
            if i%13==0:self.star(x,y,2.2,energy*.5)
    def material(self,mask,color,shade=None,alpha=1):
        a=clip(mask*alpha);c=np.asarray(color)
        if c.ndim==1:c=np.broadcast_to(c,(SIZE,SIZE,3)).copy()
        if shade is not None:c=c*shade[:,:,None]
        arr=np.dstack((clip(c)*255,a*255)).astype('uint8')
        self.surface.alpha_composite(Image.fromarray(arr))
    def finish(self):
        # Expose brilliant cores without bleaching the coloured envelope.
        emission=1-np.exp(-self.light*1.4)
        peak=np.max(emission,axis=2);alpha=np.sqrt(clip(peak));alpha[peak>.985]=1
        rgb=emission/np.maximum(alpha[:,:,None],.00001)
        arr=np.dstack((clip(rgb)*255,alpha*255)).astype('uint8')
        self.surface.alpha_composite(Image.fromarray(arr))
        return self.surface.resize((128,128),Image.Resampling.LANCZOS)


def flame_volume(p,t,kind='burst',origin=(64,91),travel=False):
    """Turbulent hot material with separate tongues, incandescent base and ash."""
    n=noise(p.seed,t*.65);warp=(n-.5)*12
    density=np.zeros_like(X)
    if travel:
        for i in range(18):
            u=i/17;cx=108-u*88;cy=64+math.sin(u*8-t*5)*u*7
            density+=np.exp(-((X-cx+warp*.4)/(6+u*10))**2-((Y-cy+warp*.3)/(6-u*3))**2)*(1-u)**.6*.35
        density*=.5+n*1.1
    else:
        expand=(1-math.exp(-t*8));decay=(1-t)**.7
        for i in range(13 if kind=='storm' else 9):
            angle=i*TAU/(13 if kind=='storm' else 9)+.25+t*.8
            r=(17+16*expand) if kind=='storm' else 18*expand
            cx=origin[0]+math.cos(angle)*r;cy=origin[1]+math.sin(angle)*r*.33
            height=(48+p.rng.random()*30)*expand*(1-t*.3)
            u=(cy-Y)/max(1,height);v=clip(u);w=(6+4*math.sin(angle)**2)*(1-v*.78)
            centre=cx+np.sin(v*8-angle-t*8)*(3+v*5)+warp*.55
            plume=np.exp(-((X-centre)/np.maximum(1,w))**2)*smooth(-.04,.12,u)*(1-smooth(.65,1,u))
            density+=plume*.65*decay
        density*=smooth(.12,.7,n)*1.5
    heat=clip(density*1.7)
    colors=p.dark[None,None,:]*(1-heat[:,:,None])+p.c[None,None,:]*heat[:,:,None]
    hot=smooth(.45,1.2,density)
    colors=colors*(1-hot[:,:,None])+np.array([1,.94,.57])[None,None,:]*hot[:,:,None]
    p.material(smooth(.04,.5,density),colors,alpha=.85)
    p.emit(density,np.array([1,.27,.025]),1.4)
    p.emit(density**3,np.array([1,.91,.53]),2.7)
    if not travel:
        p.glow(*origin,25,5,(1,.35,.035),1.7*(1-t)**2)
        p.dust(t,44,origin,54,18,1,True)


def lightning(p,t,horizontal=False,armor=False):
    # Branch topology holds across adjacent frames, then re-strikes: no noisy straight zigzag.
    rng=random.Random(p.seed+int(t*4)*107)
    start=(8,64) if horizontal else (65,4);end=(120,64) if horizontal else (64,106)
    points=[start];n=20
    for i in range(1,n):
        u=i/n;j=rng.uniform(-9,9)*math.sin(math.pi*u)
        points.append((start[0]+(end[0]-start[0])*u+(0 if horizontal else j),start[1]+(end[1]-start[1])*u+(j if horizontal else 0)))
    points.append(end)
    envelope=(1-t)**1.1*(.8+.2*math.cos(t*45))
    p.stroke(points,5.2,(.12,.22,1),envelope*.65,5)
    p.stroke(points,2.6,(.35,.66,1),envelope*1.5,2.5)
    p.stroke(points,.85,(.96,.99,1),envelope*4,1)
    for branch_index,i in enumerate([3,7,11,15]):
        x,y=points[i];side=(-1)**branch_index
        branch=[(x,y)]
        for k in range(1,6):
            branch.append((x+side*k*4+(rng.random()-.5)*6,y+k*3+(rng.random()-.5)*7))
        p.stroke(branch,.48,(.55,.71,1),envelope*1.1,1.3)
        if i in (7,11):
            b=branch[2];p.stroke([b,(b[0]+side*9,b[1]-5),(b[0]+side*12,b[1]-2)],.35,p.c,envelope*.6,1)
    corona=np.asarray(p.mask(points,4),dtype=np.float32)/255
    p.emit(corona*smooth(.25,.73,noise(p.seed+12,t*.3)),np.array([.23,.38,1]),envelope*.5)
    for strand in range(3):
        streamer=[]
        for j,(x,y) in enumerate(points):
            u=j/(len(points)-1);offset=math.sin(u*8+strand*2+t*TAU)*(2+strand*2)*math.sin(math.pi*u)
            streamer.append((x+(0 if horizontal else offset),y+(offset if horizontal else 0)))
        p.stroke(streamer,.3,np.array([.52,.56,1]),envelope*.6,1.5)
    if not horizontal:
        for i in range(10):
            a=i*TAU/10+.2;points=curve((64,104),(64+math.cos(a)*13,104+math.sin(a)*4),(64+math.cos(a+.3)*28,104+math.sin(a+.3)*9),(64+math.cos(a)*40,104+math.sin(a)*14))
            p.stroke(points,.65,p.c,envelope*.8,1.5)
        p.glow(64,103,19,5,(.55,.72,1),envelope*2.3)
        p.star(64,101,12,envelope)
        p.dust(t,25,(64,102),36,12,envelope,True)
    else:
        p.glow(117,64,6,8,(.6,.8,1),envelope)


def blade_hit(p,t,kind):
    angle=-2.7+min(1,t*2.9)*4.2
    span=2.9 if kind=='scythe' else 2.3
    fade=(1-t)**1.8
    count=3 if kind in ('foe','claw') else 1
    for s in range(count):
        a=angle-s*.22;r=43-s*5;cy=67+s*6
        path=[(64+math.cos(a-span+u*span)*r,cy+math.sin(a-span+u*span)*r*.66) for u in np.linspace(0,1,60)]
        p.blade(path,(9 if kind=='scythe' else 6.5)-s*1.1,fade*(1-s*.15))
        for f in range(6):
            points=[(x+(f-3)*.65,y+f*.6) for x,y in path[8+f*2:]]
            p.stroke(points,.23,p.hot,fade*.35,.5,True)
    if kind in ('stun','dark_stun','holy_stun','thunder_stun','rune_stun'):
        p.stroke([(57,30),(67,56),(62,82)],2,p.hot,fade,2)
        p.star(64,70,19,fade*1.6)
    elif kind=='axe':
        p.blade(curve((30,20),(60,42),(72,73),(91,89)),11,fade*1.4)
        p.glow(82,88,15,6,p.c,fade*2)
    else:p.star(65,74,13,fade)
    p.dust(t,38,(64,76),47,4,fade,True)


def foe_slayer(p,t):
    # Independent S-shaped chainblade study informed by the reviewed PC SPX family.
    # This is not evidence that PC Foe Slayer Force and Lineage M are identical.
    fade=(1-t)**1.55;sweep=min(1,t*4)
    path=curve((19,94),(48,96),(62,47),(91,29))
    p.blade(path,5.3,fade,np.array([.35,.48,1]))
    p.stroke([(x+1.6,y-1) for x,y in path],.75,(.8,.95,1),fade*1.6,1.2)
    hook=curve((104,98),(74,103),(77,74),(88,66))
    p.blade(hook,2.4,fade,np.array([.5,.28,1]))
    for i in range(4):
        q=i*.25+t*.5;x=30+q*55;y=87-q*48
        bolt=[(x-5,y+9),(x+2,y+2),(x-1,y-2),(x+7,y-11)]
        p.stroke(bolt,.5,(.65,.37,1),fade*.65,1.6)
    p.star(86,35,16,fade*1.2,np.array([1,.56,.96]))
    p.star(81,73,10,fade*.8,np.array([.66,.85,1]))
    p.dust(t,34,(75,65),44,6,fade*.7,True)


def holy_ward(p,t,kind,persistent=False):
    # Thin curved shell, embossed cross and streaming filigree; not a shield icon.
    pulse=.82+.18*math.sin(t*TAU);fade=pulse if persistent else (1-t)**.65
    xx=(X-64)/34;yy=(Y-64)/49;r=np.sqrt(xx**2+yy**2)
    shell=np.exp(-((r-1)/.018)**2)*(.22+.78*smooth(.25,.8,p.n))
    angle=np.arctan2(yy,xx);sweep=np.maximum(0,np.cos(angle+t*TAU))**10
    p.emit(shell,np.array([1,.68,.2]),fade*.7)
    p.emit(np.exp(-((r-1)/.032)**2)*sweep,np.array([1,.92,.57]),fade*1.8)
    for side in (-1,1):
        for i in range(6):
            points=curve((64+side*(8+i*1.6),85-i*3),(64+side*(27+i*2),82-i*5),(64+side*(41+i*1.4),48-i*3),(64+side*(27+i*2.5),26+i*.8))
            p.blade(points,1.35-i*.12,fade*(.55-i*.06),np.array([1,.76,.32]))
        spiral=curve((64+side*8,99),(64+side*39,89),(64+side*30,71),(64+side*13,77))
        p.stroke(spiral,.65,p.hot,fade*.55,1.2)
    cross=[(62,35),(66,35),(66,49),(77,49),(77,53),(66,53),(66,81),(64,85),(62,81),(62,53),(51,53),(51,49),(62,49)]
    m=np.asarray(p.mask(cross),dtype=np.float32)/255
    p.emit(m*(.35+.65*p.n),np.array([1,.9,.56]),fade*.9)
    p.stroke([(64,35),(64,81)],.5,(1,1,.92),fade,1)
    p.glow(64,51,9,9,(1,.84,.4),fade*.6)
    p.dust((t*.7)%1,22,(64,100),27,69,fade*.55)


def counter(p,t,persistent=False,cast=False):
    fade=(.6+.2*math.sin(t*TAU)) if persistent else (1-t)**1.3
    if persistent or cast:
        for side in (-1,1):
            path=curve((64,99),(64+side*48,85),(64+side*43,39),(64,22))
            p.blade(path,2.4,fade,np.array([.43,.72,1]))
            p.stroke([(x+side*3,y) for x,y in path],.45,p.hot,fade*.75,1)
        for i in range(5):
            a=i*TAU/5+t*TAU;cx=64+math.cos(a)*27;cy=66+math.sin(a)*36
            p.star(cx,cy,3.5,fade*.65)
    if not persistent and not cast:
        path=curve((27,92),(48,93),(85,56),(96,31));p.blade(path,5.5,fade)
        p.star(66,64,12,fade)


def eruption(p,t,meteor=False):
    expand=1-math.exp(-t*10);fade=(1-t)**1.4
    # Fractured stone and heated crevices, separate from the flame density.
    rng=random.Random(p.seed)
    for i in range(11 if meteor else 7):
        a=rng.uniform(0,TAU);dist=rng.uniform(12,44)*expand
        cx=64+math.cos(a)*dist;cy=91+math.sin(a)*dist*.27-(12+rng.random()*18)*math.sin(math.pi*t)
        w=rng.uniform(4,9)*(1-t*.35);h=w*(1.5 if meteor else 4.6)*min(1,t*10+.1)*(1-t*.7)
        polygon=[(cx-w,cy),(cx-w*.7,cy-h*.65),(cx+w*.15,cy-h),(cx+w,cy-h*.5),(cx+w*.65,cy+w*.3)]
        m=np.asarray(p.mask(polygon),dtype=np.float32)/255
        shade=.4+p.n*.65+(X-cx)/w*.1
        p.material(m,np.array([.19,.105,.08]),shade,fade)
        p.stroke(polygon[:3],.65,(1,.34,.045),fade*.7,1.5)
        p.stroke([(cx-w*.2,cy-h*.8),(cx+w*.15,cy-h*.4),(cx-w*.12,cy)],.45,(1,.62,.12),fade,1)
    flame_volume(p,t,'burst')
    if meteor:
        p.glow(64,85,24,15,(1,.7,.26),(1-t)**4*2.5)
        for i in range(12):
            a=i*TAU/12;u=15+36*expand
            path=curve((64,92),(64+math.cos(a)*u*.5,92+math.sin(a)*u*.16),(64+math.cos(a)*u*.9,92+math.sin(a)*u*.32),(64+math.cos(a)*u,92+math.sin(a)*u*.35))
            p.stroke(path,.7,(1,.42,.07),fade*.55,2)


def shadow_hand(p,t,soul=False):
    n=noise(p.seed,t*.4);fade=(1-t)**1.1
    # Cloudy palm and articulated claws emerging from a collapsing dark plume.
    density=np.exp(-((X-64)/22)**2-((Y-78)/27)**2)*smooth(.15,.8,n)
    p.material(density,np.array([.055,.025,.085]),alpha=fade*.8)
    for i in range(5):
        x=43+i*10;lift=math.sin(math.pi*clip(t*.85+.1))*13
        points=curve((x,99),(x-10,78),(x+(i-2)*4,36+abs(i-2)*6),(x+(i-2)*5,49+abs(i-2)*5-lift))
        p.blade(points,4.6-abs(i-2)*.55,fade*.7)
        p.stroke([(x+1,y) for x,y in points],.45,p.hot,fade*.7,1.5,True)
        hook=points[-9:]+[(points[-1][0]+(2-i)*1.3,points[-1][1]+8)]
        p.stroke(hook,1.1,p.hot,fade,1)
    for side in (-1,1):
        p.blade(curve((64,107),(64+side*42,93),(64+side*44,68),(64+side*18,72)),4,fade*.7)
    p.glow(64,82,19,27,p.c,fade*.25)
    p.dust(t,35,(64,95),41,60,fade*.7,True)


def shockwave(p,t):
    n=noise(p.seed,t*.4);r=8+47*(1-math.exp(-t*5));fade=(1-t)**1.3
    xx=X-64;yy=(Y-89)/.34;rho=np.hypot(xx,yy);angle=np.arctan2(yy,xx)
    broken=smooth(.43,.68,n+.12*np.cos(angle*7))
    edge=np.exp(-((rho-r-(n-.5)*7)/1.2)**2)
    p.emit(edge*broken,np.array([1,.64,.23]),fade*.7)
    cloud=np.exp(-((rho-r+5)/7)**2)*smooth(.27,.74,n)
    p.material(cloud,np.array([.39,.31,.21]),alpha=fade*.55)
    p.emit(cloud,p.c,fade*.08)
    rng=random.Random(p.seed)
    for i in range(9):
        a=i*TAU/9+rng.uniform(-.15,.15);d=r*rng.uniform(.6,1.1)
        path=[(64+math.cos(a)*5,89+math.sin(a)*2),(64+math.cos(a+.1)*d*.4,89+math.sin(a+.1)*d*.14),(64+math.cos(a-.05)*d*.7,89+math.sin(a-.05)*d*.24),(64+math.cos(a)*d,89+math.sin(a)*d*.34)]
        p.stroke(path,1.7,np.array([.16,.09,.04]),fade*.7,0)
        p.stroke(path,.4,np.array([1,.57,.16]),fade*.7,1)
        cx=64+math.cos(a)*d;cy=89+math.sin(a)*d*.34-18*math.sin(math.pi*t);w=rng.uniform(1.4,3.7)
        poly=[(cx-w,cy),(cx-w*.4,cy-w),(cx+w,cy-w*.3),(cx+w*.5,cy+w)]
        m=np.asarray(p.mask(poly),dtype=np.float32)/255;p.material(m,np.array([.3,.22,.14]),.4+p.n*.7,fade*.8)
        p.stroke(poly[:3],.35,p.hot,fade*.35,.6)
    p.dust(t,52,(64,89),61,16,fade*.6,True)
    p.glow(64,89,22,5,(1,.7,.3),(1-t)**6*.8)


def heal(p,t,kind='heal',persistent=False):
    fade=.8+.2*math.sin(t*TAU) if persistent else (1-t)**.8
    # Asymmetric rising light streams and fine green motes, not a DNA-shaped icon.
    for i in range(6):
        offset=(i-2.5)*7;phase=i*1.7+t*TAU
        path=[(64+offset*math.sin(math.pi*u)**.6+math.sin(phase+u*6)*2.5,103-u*(58+i%3*8)) for u in np.linspace(0,1,65)]
        p.blade(path,.75+(i%2)*.2,fade*.32)
        p.stroke(path,.2,(.82,1,.66),fade*.4,.7,True)
    for i in range(30):
        q=(i/30+t)%1;a=i*2.399+t*TAU
        x=64+math.cos(a)*(8+17*math.sin(q*math.pi));y=105-q*84
        p.star(x,y,1.3+1.4*math.sin(q*math.pi),fade*math.sin(q*math.pi)*.7)
    p.glow(64,94,19,5,p.c,fade*.6)
    p.glow(64,67,10,32,p.c,fade*.1)
    if kind in ('petals','feathers','life'):
        for i in range(7):
            a=i*TAU/7+t*TAU;x=64+math.cos(a)*24;y=85+math.sin(a)*9-t*45
            leaf=curve((x-3,y+5),(x-8,y-2),(x+1,y-6),(x+4,y-7))+[(x+2,y+1),(x-3,y+5)]
            m=np.asarray(p.mask(leaf),dtype=np.float32)/255;p.emit(m,p.c,fade*.5)
            p.stroke([(x-2,y+2),(x+2,y-4)],.3,p.hot,fade*.7,.6)


def sigil(p,t,program,ground=False):
    # Engraved concentric inscriptions with disconnected flares; no opaque disc.
    cy=96 if ground else 67;ry=.32 if ground else .85;radius=31
    fade=(1-t)**.6
    for ring in [1,.82]:
        for j in range(12):
            a=j*TAU/12+t*.25;path=[(64+math.cos(a+u)*radius*ring,cy+math.sin(a+u)*radius*ring*ry) for u in np.linspace(0,.36,20)]
            p.stroke(path,.45,p.c,fade*.42,1)
    for i in range(12):
        a=i*TAU/12+t*.25;x=64+math.cos(a)*28;y=cy+math.sin(a)*28*ry
        radial=(math.cos(a),math.sin(a)*ry);tangent=(-math.sin(a),math.cos(a)*ry)
        glyph=[(x+radial[0]*u+tangent[0]*v,y+radial[1]*u+tangent[1]*v) for u,v in [(0,-1.5),(-3,-1.5),(-3,1.5),(0,0),(2,1.5)]]
        p.stroke(glyph,.35,p.hot,fade*.65,.7)
    if program in ('rune','enchant','portal','mark','seal','crown'):
        for i in range(5):
            a=i*TAU/5;b=(i+2)*TAU/5
            p.stroke([(64+math.cos(a)*19,cy+math.sin(a)*19*ry),(64+math.cos(b)*19,cy+math.sin(b)*19*ry)],.3,p.c,fade*.3,.5)
    p.glow(64,cy,25,8 if ground else 25,p.c,fade*.09)


def arrow(p,t,bullet=False,impact=False):
    if impact:
        fade=(1-t)**2
        for i in range(13):
            a=i*TAU/13+.15;d=6+31*(1-math.exp(-t*8))
            p.stroke([(64+math.cos(a)*3,64+math.sin(a)*3),(64+math.cos(a)*d,64+math.sin(a)*d*.6)],.4+(i%3)*.15,p.hot,fade,1.3)
        p.star(64,64,12,fade*1.5);p.dust(t,26,(64,64),38,3,fade,True)
        return
    for i in range(12):
        lag=i/12;x=109-lag*83;y=64+math.sin(lag*10-t*TAU)*lag*2
        p.glow(x,y,6,1.3,p.c,(1-lag)*.22)
    p.stroke([(18,64),(111,64)],.75,p.c,.9,2.4)
    p.stroke([(50,64),(112,64)],.42,(1,1,.91),1.8,1)
    if not bullet:
        p.stroke([(73,64),(106,64)],.9,(.7,.56,.29),1,0)
        head=[(112,64),(102,60.9),(104,64),(102,67.1)]
        m=np.asarray(p.mask(head),dtype=np.float32)/255;p.emit(m,p.hot,1.6)
        p.stroke([(77,64),(71,61),(67,61),(73,64),(68,67),(72,67),(78,64)],.5,p.c,.8,1)
    else:p.glow(110,64,4,1.3,(1,.9,.6),2.3)
    p.dust(t,8,(87,64),22,0,.35)


def ice(p,t):
    fade=(1-t)**1.1
    for i in range(8):
        a=i*TAU/8;x=64+math.cos(a)*22;y=87+math.sin(a)*8
        h=(22+(i*13%21))*math.sin(math.pi*clip(t*.8+.12));w=4+(i%3)
        poly=[(x-w,y),(x-w*.6,y-h*.7),(x+w*.15,y-h),(x+w,y-h*.55),(x+w*.65,y)]
        m=np.asarray(p.mask(poly),dtype=np.float32)/255
        p.material(m,np.array([.17,.43,.64]),(.35+p.n*.7),fade*.75)
        p.emit(m*(.25+.5*p.n),p.c,fade*.5)
        p.stroke(poly[:3],.7,(.83,.98,1),fade*1.6,1.4)
        p.stroke([(x,y),(x+w*.15,y-h)],.35,p.hot,fade,1)
    p.glow(64,86,24,5,p.c,fade*.6);p.dust(t,32,(64,84),46,28,fade)


def arcane_shell(p,t,kind,persistent=False):
    fade=(.7+.3*math.sin(t*TAU)) if persistent else (1-t)**.8
    r=np.sqrt(((X-64)/31)**2+((Y-65)/46)**2)
    rim=np.exp(-((r-1)/.026)**2)
    ripple=np.exp(-((r-(.89+.06*math.sin(t*TAU)))/.013)**2)
    p.emit(rim*(.35+.65*p.n),p.c,fade*.6);p.emit(ripple,p.hot,fade*.2)
    for i in range(7):
        a=i*TAU/7+t*TAU
        path=[(64+math.cos(a+u)*30,65+math.sin(a+u)*45) for u in np.linspace(0,.5,24)]
        p.stroke(path,.65,p.hot,fade*.4,1)
    if kind=='barrier':
        for i in range(6):
            a=i*TAU/6;path=[(64+math.cos(a)*28,65+math.sin(a)*42),(64+math.cos(a+TAU/6)*28,65+math.sin(a+TAU/6)*42)]
            p.stroke(path,.45,p.c,fade*.45,1)
    elif kind=='storm_ward':
        for i in range(3):
            a=i*TAU/3+t*TAU;x=64+math.cos(a)*30;y=65+math.sin(a)*43
            p.stroke([(x,y),(x-4,y-7),(x+2,y-12),(x-4,y-20)],.6,p.hot,fade*.65,1.4)
    p.dust(t,16,(64,98),27,61,fade*.3)


def spectral_cloak(p,t,soul=False):
    n=noise(p.seed,t*.7);fade=(1-t*.7)
    cloud=np.exp(-((X-64)/25)**2-((Y-75)/34)**2)*smooth(.2,.73,n)
    p.material(cloud,np.array([.055,.025,.09]),alpha=fade*.65)
    for i in range(7):
        side=(-1)**i;u=i/7
        path=curve((64+side*7,101),(64+side*(25+u*9),88),(64+side*(26-u*8),49),(64+side*4,33))
        p.blade(path,2.5,fade*.2)
    if soul:
        x=64+math.sin(t*TAU)*9;y=56-t*16
        p.glow(x,y,8,12,p.c,fade*.7)
        for side in (-1,1):p.glow(x+side*3,y-2,1.8,1,p.hot,fade)
        p.blade(curve((x,y+5),(x-13,y+18),(x+12,y+30),(x-4,y+44)),3,fade*.4)
    p.dust(t,23,(64,99),31,66,fade*.35)


def chains(p,t):
    fade=(1-t)**1.2;reach=1-math.exp(-t*12)
    for side in (-1,1):
        for i in range(8):
            u=i/8;cx=64+side*(8+40*u)*(1-reach*.35);cy=67+(u-.4)**2*25
            angle=side*.3;w=3.2;h=1.55 if i%2 else 3
            points=[(cx+math.cos(a+angle)*w,cy+math.sin(a+angle)*h) for a in np.linspace(0,TAU,13)]
            p.stroke(points,1.3,np.array([.18,.14,.12]),fade,0)
            p.stroke(points,.65,p.c,fade*.7,1)
            p.stroke(points[:5],.35,p.hot,fade*.9,.5)
        p.star(64+side*8,67,5,fade*.7)
    p.glow(64,68,9,13,p.c,fade*.35)
    p.dust(t,20,(64,73),31,9,fade*.5,True)


def judgement(p,t,kind):
    fade=(1-t)**1.6
    if kind=='lance':
        # A concentrated vertical annihilation beam, not a weapon crescent.
        beam=np.exp(-((X-64)/3.3)**2)*smooth(7,17,Y)*(1-smooth(97,108,Y))
        p.emit(beam,np.array([1,.74,.26]),fade*2)
        p.emit(beam**3,(1,.99,.89),fade*4)
        for side in (-1,1):
            path=curve((64+side*15,11),(64+side*20,44),(64+side*5,68),(64,101))
            p.blade(path,1.9,fade*.55)
        p.star(64,97,17,fade*1.2)
    else:
        cy=48+min(1,t*6)*13
        sword=[(62,16),(66,16),(67,cy),(77,cy-2),(79,cy+2),(67,cy+5),(65,102),(64,108),(62,102),(61,cy+5),(49,cy+2),(51,cy-2),(61,cy)]
        m=np.asarray(p.mask(sword),dtype=np.float32)/255
        p.emit(m*(.3+.7*p.n),p.c,fade*1.1)
        p.stroke([(64,18),(64,104)],.65,(1,1,.9),fade*2,1.5)
        for side in (-1,1):
            path=curve((64+side*6,84),(64+side*37,73),(64+side*44,40),(64+side*35,24));p.blade(path,2.4,fade*.45)
        p.star(64,cy+2,13,fade)
    p.dust(t,31,(64,97),40,22,fade*.65,True)


def earth_prison(p,t):
    fade=(1-t)**.9;rise=1-math.exp(-t*10)
    for i in range(9):
        a=i*TAU/9;cx=64+math.cos(a)*28;cy=88+math.sin(a)*10
        h=(23+i*7%21)*rise
        poly=[(cx-6,cy),(cx-4,cy-h*.7),(cx+1,cy-h),(cx+6,cy-h*.45),(cx+7,cy+2)]
        m=np.asarray(p.mask(poly),dtype=np.float32)/255
        p.material(m,np.array([.34,.26,.17]),.4+p.n*.8,fade*.9)
        p.stroke(poly[:3],.6,(.85,.63,.3),fade*.8,1)
        p.stroke([(64,90),(cx,cy),(cx+math.cos(a)*12,cy+math.sin(a)*4)],.55,p.c,fade*.7,1)
    p.dust(t,40,(64,90),40,27,fade*.6)


def ornament(p,t,kind):
    fade=(1-t)**.9
    if kind in ('mana','blood','bolt'):
        for i in range(5):
            a=i*TAU/5+t*TAU*1.2;r=25*(1-t*.65)
            x=64+math.cos(a)*r;y=70+math.sin(a)*r*.6-t*22
            p.glow(x,y,3.3,4,p.c,fade*.65)
            path=curve((x,y),(x+10,y+9),(64,83),(64,55));p.blade(path,1.25,fade*.4)
        p.star(64,56,8,fade*.7)
    elif kind=='lantern':
        p.glow(64,46,13,19,np.array([1,.7,.25]),.6)
        p.star(64,46,5,1,np.array([1,.96,.7]))
        for i in range(10):
            a=i*TAU/10+t*2;p.glow(64+math.cos(a)*13,46+math.sin(a)*17,1,1.5,p.hot,.45)
    elif kind=='portal':
        for i in range(9):
            a=i*TAU/9+t*4;radius=14+17*math.sin(math.pi*t)
            path=curve((64+math.cos(a)*radius,71+math.sin(a)*radius),(64+math.cos(a+1.4)*28,71+math.sin(a+1.4)*41),(64+math.cos(a+2)*14,71+math.sin(a+2)*20),(64,71))
            p.blade(path,1.8,fade*.5)
        p.glow(64,71,3,29,p.c,math.sin(math.pi*t)*.9)
    elif kind=='crown':
        path=[(42,48),(39,30),(53,39),(64,23),(75,39),(89,30),(85,48),(42,48)]
        p.stroke(path,1,p.c,fade,2);p.stroke([(45,53),(82,53)],.7,p.hot,fade,1)
        for x in (41,64,87):p.star(x,29 if x!=64 else 23,3,fade*.8)
        p.dust(t,20,(64,100),28,65,fade*.6)
    elif kind=='mark':
        path=[(70,28),(54,56),(65,55),(57,84),(78,48),(66,49),(70,28)]
        p.stroke(path,1.2,p.c,fade,2);p.stroke(path,.4,p.hot,fade*1.2,.8)
        p.dust(t,17,(64,74),29,15,fade*.5,True)
    elif kind=='plasma':
        for i in range(6):
            a=i*TAU/6+t*5;path=curve((64+math.cos(a)*32,65+math.sin(a)*24),(39,39),(88,39),(64,99));p.blade(path,2,fade*.6)
        p.blade([(64,19),(64,55),(64,105)],5,fade*.9)
        p.star(64,95,13,fade)
    elif kind=='slow':
        for i in range(3):
            y=57+i*18;path=[(64+math.cos(a)*23,y+math.sin(a)*7) for a in np.linspace(.3+t,TAU-.2+t,60)]
            p.stroke(path,.7,p.c,fade*.55,1.5)
        p.dust(t,28,(64,45),27,-34,fade*.4)
    else:sigil(p,t,kind);p.dust(t,23,(64,91),32,42,fade*.5)

def render(program,palette,seed,phase,t):
    p=Paint(seed,palette)
    melee={'stun','dark_stun','holy_stun','thunder_stun','rune_stun','claw','foe','scythe','axe','excalibur','lance','judgement'}
    storm={'lightning','chain_lightning','storm_field','storm_ward','thunder_stun','plasma'}
    wards={'ward','holy_ward','guardian','barrier','storm_ward'}
    fade=(1-t)**1.4
    if phase=='ground':
        if program not in melee|{'arrow','bullet','shockwave'}:sigil(p,t,program,True)
        else:p.dust(t,14,(64,104),25,6,.3)
    elif phase in ('prepare','cast'):
        if program=='foe':
            for i in range(5):
                x=57+i*3;p.stroke([(x,103),(x,42),(x+1,29)],.35,(.6,.4,1),fade*.55,1.2)
            for side in (-1,1):
                path=curve((64+side*10,98),(64+side*22,75),(64-side*12,56),(64+side*8,34));p.stroke(path,.6,p.hot,fade*.65,1.2)
            p.star(64,28,10,fade*.85)
        elif program in melee:
            for i in range(2):
                path=curve((52,97),(64,81),(73,60),(69,40));p.blade([(x+i*3,y) for x,y in path],1.6,fade*.45)
            p.star(69,53,4,math.sin(math.pi*t)*.5)
        elif program in ('arrow','bullet'):p.star(83,64,5,math.sin(math.pi*t)*.9)
        elif program in storm:
            for i in range(5):
                a=i*TAU/5+t*2;path=curve((64+math.cos(a)*27,88+math.sin(a)*10),(55,69),(81,54),(65,38))
                p.stroke(path,.4,p.c,fade*.65,1.5)
            p.star(65,38,5,fade)
        elif program in wards|{'counter'}:
            if program=='counter':counter(p,t,cast=True)
            elif program in ('holy_ward','guardian'):holy_ward(p,t,program)
            else:arcane_shell(p,t,program)
        elif program in ('firestorm','meteor','eruption'):p.glow(64,72,9,17,(1,.4,.06),math.sin(math.pi*t)*.8);p.dust(t,25,(64,103),24,61,.6)
        else:heal(p,t,program);sigil(p,t,program,True)
    elif phase=='release':
        if program=='bullet':
            for i in range(7):
                a=i*TAU/7;path=[(64,64),(64+math.cos(a)*8,64+math.sin(a)*5),(64+math.cos(a)*19,64+math.sin(a)*12)]
                p.blade(path,3,fade,np.array([1,.58,.17]))
            p.star(64,64,7,fade*2)
        elif program in storm:p.star(64,64,7,fade);p.dust(t,15,(64,64),20,0,fade,True)
        else:p.star(64,64,5,fade*.7);p.dust(t,14,(64,64),18,0,fade*.6,True)
    elif phase=='travel':
        if program in ('arrow','bullet'):arrow(p,t,program=='bullet')
        elif program in ('meteor','firestorm'):
            flame_volume(p,t,travel=True)
            if program=='meteor':
                rho=np.sqrt(((X-106)/10)**2+((Y-64)/9)**2);m=1-smooth(.87,1.07,rho+(p.n-.5)*.24)
                shade=.3+p.n*.6+(106-X)*.025
                p.material(m,np.array([.23,.11,.065]),shade)
                p.emit(np.exp(-((rho-.94)/.07)**2),np.array([1,.57,.13]),1.1)
                cracks=np.maximum(0,.12-np.abs(np.sin((X+Y*.7)*.24+(p.n-.5)*6)))
                p.emit(cracks*m,np.array([1,.72,.26]),1.2)
                p.star(112,64,3,.8)
        elif program=='ice':
            m=np.asarray(p.mask([(112,64),(89,58),(65,64),(89,70)]),dtype=np.float32)/255;p.emit(m,p.c,.7)
            p.stroke([(39,64),(112,64)],.5,p.hot,1,2)
        else:
            for i in range(5):
                p.blade(curve((17+i*4,59+i*2),(48,45+i*5),(77,79-i*5),(112,64)),1.9-i*.2,.5)
            p.glow(109,64,5,5,p.hot,1)
    elif phase=='resist':
        for side in (-1,1):p.blade(curve((64,47),(64+side*14,43),(64+side*23,58),(64+side*(23+12*t),70+9*t)),1.5,fade*.4,np.array([.55,.65,.7]))
    elif phase=='end':p.dust(t,28,(64,84),32,40,fade*.6)
    elif phase=='aftermath':
        if program in ('firestorm','meteor','eruption'):
            p.dust(t,43,(64,90),50,40,fade*.55,True)
            p.glow(64,94,23,4,(1,.24,.02),fade*.18)
        elif program in storm:p.dust(t,24,(64,91),39,19,fade*.5,True)
        else:p.dust(t,25,(64,85),40,22,fade*.45)
    elif phase=='flare':
        if program in ('heal','petals','feathers','life'):
            p.glow(64,83,11,23,p.c,fade*.2)
        elif program in wards|{'counter'}:p.star(64,51,9,fade*.4)
        else:
            origin=(64,64) if program=='chain_lightning' else (64,98) if program in storm else (64,85) if program in ('firestorm','eruption','meteor','shockwave') else (64,70)
            p.star(*origin,17,fade*.8)
            p.stroke([(origin[0]-29,origin[1]),(origin[0]+29,origin[1])],.35,p.hot,fade*.65,2)
    elif phase=='status':
        if 'stun' in program:
            for i in range(3):
                a=i*TAU/3+t*TAU;x=64+math.cos(a)*17;y=41+math.sin(a)*5
                p.star(x,y,3.5,.8);path=[(64+math.cos(a-u)*17,41+math.sin(a-u)*5) for u in np.linspace(0,.7,15)];p.stroke(path,.45,p.c,.5,1)
        elif program=='slow':ornament(p,.5-.5*math.cos(t*TAU),program)
        elif program in ('mark','seal','chains'):sigil(p,0,program)
        else:p.dust(t,18,(64,82),24,38,.6)
    elif phase=='persistent':
        if program=='counter':counter(p,t,True)
        elif program in ('holy_ward','guardian'):holy_ward(p,t,program,True)
        elif program in ('ward','barrier','storm_ward','dark_ward'):arcane_shell(p,t,program,True)
        elif program in ('stealth','shadow','soul','dark_ward'):spectral_cloak(p,.5-.5*math.cos(t*TAU),program=='soul')
        elif program=='blood':ornament(p,t,program)
        else:heal(p,t,program,True)
    elif program in ('lance','excalibur','holy_stun','judgement'):judgement(p,t,program)
    elif program=='earth_prison':earth_prison(p,t)
    elif program in ('ward','barrier','storm_ward','dark_ward'):arcane_shell(p,t,program)
    elif program in ('stealth','shadow','soul'):spectral_cloak(p,t,program=='soul')
    elif program=='chains':chains(p,t)
    elif program in ('mana','blood','bolt','lantern','portal','crown','mark','plasma','slow'):ornament(p,t,program)
    elif program in ('lightning','chain_lightning','storm_field'):lightning(p,t,program=='chain_lightning')
    elif program=='foe':foe_slayer(p,t)
    elif program in melee:
        blade_hit(p,t,program)
        if program=='thunder_stun':lightning(p,t)
    elif program=='counter':counter(p,t)
    elif program in wards:holy_ward(p,t,program)
    elif program=='firestorm':flame_volume(p,t,'storm')
    elif program in ('eruption','meteor'):eruption(p,t,program=='meteor')
    elif program=='ice':ice(p,t)
    elif program in ('hand','shadow','soul','blood'):shadow_hand(p,t)
    elif program=='shockwave':shockwave(p,t)
    elif program in ('arrow','bullet'):arrow(p,t,program=='bullet',True)
    elif program in ('rune','enchant','portal','mark','seal','crown','chains'):
        sigil(p,t,program)
        if program in ('rune','enchant'):blade_hit(p,t,'rune')
        p.dust(t,24,(64,91),34,44,fade*.6)
    elif program=='dragon':
        for side in (-1,1):
            path=curve((64,104),(64+side*48,84),(64+side*44,32),(64+side*13,23));p.blade(path,5,fade*.6)
            p.stroke(path,.55,p.hot,fade,1.3)
        heal(p,t,program)
    else:heal(p,t,program)
    return p.finish()
