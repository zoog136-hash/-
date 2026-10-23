#!/usr/bin/env python3
"""Independently drawn TWILIGHT VFX. No publisher image is an input.

These are authored fallback studies, NOT measured Lineage M reconstructions.
Pillow >= 10; deterministic analytic ribbons, crystal facets and particle paths.
"""
from __future__ import annotations
import argparse, hashlib, json, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

TAU = math.tau
CELL = 128
AA = 3
CLIPS = {
    'prepare': (0, [30, 35]), 'cast': (2, [40, 45, 55, 70]),
    'release': (6, [25, 40]), 'travel': (8, [40, 35, 45, 40]),
    'impact': (12, [25, 25, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80]),
    'persistent': (24, [140, 170, 150, 180]), 'status': (28, [75, 85, 85, 95]),
    'resist': (32, [45, 55, 65, 85]), 'end': (36, [45, 60, 75, 100]),
    'aftermath': (40, [45, 50, 55, 60, 65, 70, 80, 95]),
    'flare': (48, [25, 25, 35, 40, 50, 60, 70, 80]),
    'ground': (56, [35, 40, 45, 50, 55, 60, 65, 80]),
}
PALETTES = {
    'steel': ('84c7ed', 'eafaff', '294b78'), 'gold': ('ffcf63', 'fff8d5', 'ad6530'),
    'holy': ('ffe18a', 'fffde6', 'b89449'), 'nature': ('72edac', 'edfff4', '268e72'),
    'fire': ('ff7a31', 'fff2ac', 'a52433'), 'ice': ('69cefa', 'edffff', '356aba'),
    'storm': ('7cafff', 'f1fcff', '594bd6'), 'shadow': ('b171ec', 'e8ceff', '3a285e'),
    'blood': ('e65764', 'ffd2b9', '792753'), 'ether': ('55e6e4', 'e9ffff', '5365b4'),
    'soul': ('75d4c7', 'dcfff7', '435c87'), 'earth': ('dfaa65', 'ffe8bb', '72534c'),
}
PROGRAMS = {
    'bolt':'bolt', 'light':'lantern', 'shield':'ward', 'teleport':'portal',
    'cleanse':'petals', 'weight':'feathers', 'earth':'eruption', 'crown':'crown',
    'sword':'excalibur', 'stun':'stun', 'counter':'counter', 'taunt':'shockwave',
    'arrows':'arrow', 'blood':'blood', 'heal':'heal', 'buff':'enchant', 'ice':'ice',
    'seal':'seal', 'stealth':'shadow', 'lance':'lance', 'flame':'firestorm',
    'meteor':'meteor', 'shadow':'hand', 'barrier':'barrier', 'dodge':'shadow',
    'claw':'claw', 'bullets':'bullet', 'mana':'mana', 'wind':'feathers',
    'chain':'chains', 'dragon':'dragon', 'soul':'soul', 'dark_stun':'dark_stun',
    'axe':'axe', 'howl':'shockwave', 'grip':'chains', 'holy_shield':'holy_ward',
    'holy_stun':'holy_stun', 'scythe':'scythe', 'lightning':'lightning', 'mark':'mark',
    'chain_lightning':'chain_lightning', 'thunder_armor':'storm_ward', 'field':'storm_field',
    'thunder_stun':'thunder_stun', 'plasma':'plasma', 'rune':'rune', 'life':'life',
    'rune_stun':'rune_stun', 'illusion':'counter', 'phalanx':'ward', 'ether':'enchant',
    'nomad':'petals', 'guardian':'guardian', 'turn_undead':'judgement',
    'turn_undead_ancient':'judgement',
}

def rgb(s): return tuple(bytes.fromhex(s))
def xy(p): return tuple(round(v * AA) for v in p)
def clamp(x): return max(0., min(1., x))
def bezier(p0,p1,p2,p3,n=36):
    return [tuple((1-t)**3*p0[k]+3*(1-t)**2*t*p1[k]+3*(1-t)*t*t*p2[k]+t**3*p3[k] for k in (0,1)) for t in [i/(n-1) for i in range(n)]]

class Ink:
    def __init__(self,palette):
        self.image=Image.new('RGBA',(CELL*AA,CELL*AA));self.d=ImageDraw.Draw(self.image)
        self.c,self.hot,self.dark=map(rgb,PALETTES[palette])
    def polygon(self,pts,color,alpha=255):
        self.d.polygon([xy(p) for p in pts],fill=(*color,round(clamp(alpha/255)*255)))
    def line(self,pts,w=1,color=None,a=255,glow=True):
        color=color or self.c
        points=[xy(p) for p in pts]
        layer=Image.new('RGBA',self.image.size);draw=ImageDraw.Draw(layer)
        if glow:
            for spread,opacity in [(6,.055),(3.5,.15),(1.8,.36)]:
                draw.line(points,fill=(*color,round(a*opacity)),width=max(1,round(w*AA*spread)),joint='curve')
        draw.line(points,fill=(*color,round(a)),width=max(1,round(w*AA)),joint='curve')
        self.image.alpha_composite(layer)
    def ribbon(self,pts,w,fade=1.,hot=True):
        left=[];right=[]
        for i,p in enumerate(pts):
            before=pts[max(0,i-1)];after=pts[min(len(pts)-1,i+1)]
            dx,dy=after[0]-before[0],after[1]-before[1];length=max(.01,math.hypot(dx,dy))
            width=w*(math.sin(math.pi*i/(len(pts)-1))**.7+.035)
            left.append((p[0]-dy/length*width,p[1]+dx/length*width));right.append((p[0]+dy/length*width,p[1]-dx/length*width))
        self.polygon(left+right[::-1],self.c,180*fade)
        self.line(pts,max(.8,w*.23),self.hot if hot else self.c,240*fade)
    def spark(self,x,y,r=3,a=1.):
        if r<=0 or a<=0:return
        self.polygon([(x-r,y),(x,y-r*.24),(x+r,y),(x,y+r*.24)],self.c,130*a)
        self.polygon([(x,y-r),(x+r*.23,y),(x,y+r),(x-r*.23,y)],self.hot,240*a)
    def finish(self):
        glow=self.image.filter(ImageFilter.GaussianBlur(2.5*AA))
        glow.putalpha(glow.getchannel('A').point(lambda v:round(v*.85)))
        glow.alpha_composite(self.image)
        return glow.resize((CELL,CELL),Image.Resampling.LANCZOS)

def volume(ink,t,seed,program,travel=False):
    """Advected density with hot cores and cooling edges, drawn from scratch."""
    yy,xx=np.mgrid[0:CELL,0:CELL].astype(float)
    phase=(seed%1009)/73
    noise=(np.sin(xx*.23+np.sin(yy*.11+t*3)*2+phase)+np.sin(xx*.077+yy*.17-t*5+phase)*.6+np.sin(xx*.49-yy*.3+t*9)*.23)/1.83
    density=np.zeros_like(xx)
    if travel:
        density=np.exp(-((xx-104)/12)**2-((yy-64)/10)**2)*1.3
        for i in range(6):
            x=91-i*12;y=64+math.sin(i*.8+t*5)*i*1.2
            density+=np.exp(-((xx-x)/(11-i*.6))**2-((yy-y)/(9-i*.7))**2)*(.8-i*.09)
    else:
        for i in range(9):
            a=i*TAU/9+t*1.8;rad=9+24*t
            cx=64+math.cos(a)*rad;cy=85+math.sin(a)*rad*.38-(18+12*math.sin(a))*t
            sx=9+6*math.sin(math.pi*t);sy=14+9*math.sin(a+t*3)**2
            density+=np.exp(-((xx-cx)/sx)**2-((yy-cy)/sy)**2)*(.6+.3*math.cos(a))
        density*=max(0,1-t*.9)
    density=np.maximum(0,density+noise*.19)
    edge=np.clip((density-.18)*2,0,1)
    hot=np.clip((density-.63)*1.8,0,1)
    c=np.array(ink.c);hi=np.array(ink.hot);lo=np.array(ink.dark)
    color=lo[None,None,:]*(1-edge[:,:,None])+c[None,None,:]*edge[:,:,None]
    color=color*(1-hot[:,:,None])+hi[None,None,:]*hot[:,:,None]
    alpha=np.clip((density-.23)*1.4,0,.92)*255
    pixels=np.dstack((np.clip(color,0,255),alpha)).astype('uint8')
    layer=Image.fromarray(pixels,'RGBA').resize(ink.image.size,Image.Resampling.BICUBIC)
    ink.image.alpha_composite(layer)

def particles(ink,t,seed,count=15,origin=(64,70),up=False,fade=1):
    rng=random.Random(seed)
    for i in range(count):
        angle=rng.uniform(0,TAU);v=rng.uniform(16,47);lag=rng.uniform(0,.2)
        q=clamp((t-lag)/(1-lag));x=origin[0]+math.cos(angle)*v*q
        y=origin[1]+math.sin(angle)*v*q*(.6 if up else 1)-(q*45 if up else -q*q*10)
        ink.spark(x,y,(1.3+1.5*rng.random())*math.sin(math.pi*clamp(q+.1)),(1-q)*fade)

def crescent(ink,t,seed,style):
    # A travelling blade edge, not an animated single still.
    theta=-2.6+t*3.6+(seed%5)*.08
    span=2.4 if style=='scythe' else 1.7
    pts=[(64+43*math.cos(theta-span+span*i/39),66+31*math.sin(theta-span+span*i/39)) for i in range(40)]
    ink.ribbon(pts,7.5 if style=='scythe' else 5.5,(1-t)**.5)
    if style in ('claw','foe'):
        for j in range(2):
            shifted=[(x-5*(j+1),y+8*(j+1)) for x,y in pts[8:]]
            ink.ribbon(shifted,1.5,(1-t)*.4)
    if style=='axe':
        pts=bezier((30,18),(48,39),(71,59),(85,83))
        ink.ribbon(pts,7*(1-t),1-t)
        ink.polygon([(74,69),(97,58),(91,81),(77,93)],ink.c,180*(1-t))
    particles(ink,t,seed,14,fade=.75)

def lightning(ink,t,seed,horizontal=False):
    rng=random.Random(seed+int(t*6))
    start,end=((8,64),(120,64)) if horizontal else ((63,8),(64,101))
    pts=[start]
    for i in range(1,13):
        f=i/13;j=rng.uniform(-11,11)*math.sin(math.pi*f)
        pts.append((start[0]+(end[0]-start[0])*f+(0 if horizontal else j),start[1]+(end[1]-start[1])*f+(j if horizontal else 0)))
    pts.append(end); fade=(1-t)**.7
    for i in (3,6,9):
        p=pts[i];sign=(-1)**i
        branch=[p,(p[0]+sign*10,p[1]+8),(p[0]+sign*22,p[1]+5),(p[0]+sign*27,p[1]+15)]
        ink.line(branch,.7,ink.c,140*fade)
    ink.line(pts,6,ink.c,115*fade);ink.line(pts,2,ink.hot,255*fade)
    if not horizontal:
        for i in range(5):
            a=i*TAU/5+.4;ink.line([(64,101),(64+15*math.cos(a),101+5*math.sin(a)),(64+29*math.cos(a),101+10*math.sin(a))],1,ink.c,150*fade)

def flame(ink,t,seed,vortex=False):
    volume(ink,t,seed,'flame')
    rng=random.Random(seed)
    for i in range(9):
        a=i*TAU/9+t*3;r=(15+22*t)*(1 if vortex else .65)
        x=64+math.cos(a)*r;y=83+math.sin(a)*r*.4
        h=(20+rng.random()*32)*math.sin(math.pi*clamp(t*.85+.13))
        pts=bezier((x,y),(x-18*math.sin(a),y-h*.25),(x+14*math.sin(a+t*3),y-h*.8),(x+10*math.sin(a+t*4),y-h))
        ink.ribbon(pts,4.5*(1-t)**.4,1-t*.75)
        if i%3==0:ink.line(pts[3:],.9,ink.hot,220*(1-t))
    particles(ink,t,seed+400,22,(64,77),True)

def crystal(ink,t,seed,earth=False):
    rng=random.Random(seed)
    for i in range(7):
        a=i*TAU/7;x=64+math.cos(a)*(18+8*t);y=86+math.sin(a)*9
        h=(23+rng.random()*28)*math.sin(math.pi*clamp(t*.75+.18))
        pts=[(x-6,y),(x-5,y-h*.7),(x+2,y-h),(x+8,y-h*.65),(x+6,y)]
        ink.polygon(pts,ink.dark,165*(1-t));ink.polygon([(x-5,y-h*.7),(x+2,y-h),(x+1,y)],ink.c,220*(1-t))
        ink.line([pts[0],pts[2],pts[3]],1,ink.hot,200*(1-t))
        if earth:ink.line([(64,89),(x, y),(x+15*math.cos(a),y+7*math.sin(a))],1.4,ink.c,200*(1-t))
    particles(ink,t,seed,12,(64,82))

def ward(ink,t,seed,holy=False):
    pulse=.7+.3*math.sin(t*TAU);alpha=140*pulse
    shape=[(64,17),(92,31),(94,65),(85,87),(64,104),(43,87),(34,65),(36,31)]
    ink.polygon(shape,ink.dark,24*pulse);ink.line(shape+[shape[0]],1.1,ink.c,alpha)
    inner=[(64+(x-64)*.87,61+(y-61)*.87) for x,y in shape]
    ink.line(inner+[inner[0]],.6,ink.hot,alpha*.7)
    if holy:
        for side in (-1,1):
            for i in range(5):
                pts=bezier((64+side*22,75-i*6),(64+side*41,67-i*7),(64+side*49,44-i*3),(64+side*(38+i*3),35-i*3))
                ink.ribbon(pts,2.4-i*.25,.45*pulse)
        ink.line([(64,36),(64,80)],1.4,ink.hot,180*pulse);ink.line([(52,51),(76,51)],1.2,ink.hot,180*pulse)
    else:
        for i in range(4):
            y=37+i*14;ink.line([(48,y),(64,y-8),(80,y)],.9,ink.c,alpha)
    particles(ink,t,seed,6,(64,77),True,.5)

def sigil(ink,t,seed,ground=False):
    radius=27+5*math.sin(math.pi*t);squash=.36 if ground else 1.;cy=89 if ground else 64
    # Broken double inscriptions with individually drawn rune strokes.
    for i in range(8):
        a=i*TAU/8+t*.35
        points=[(64+math.cos(a+j*.024)*radius,cy+math.sin(a+j*.024)*radius*squash) for j in range(20)]
        ink.line(points,.8,ink.c,140*(1-t*.6))
        x=64+math.cos(a)*radius*.78;y=cy+math.sin(a)*radius*.78*squash
        ink.line([(x-2,y+3*squash),(x-2,y-4*squash),(x+2,y),(x+3,y-3*squash)],.7,ink.hot,160)
    n=5+seed%3
    for i in range(n):
        a=i*TAU/n+t*.15;b=(i+2)*TAU/n+t*.15
        ink.line([(64+math.cos(a)*radius*.6,cy+math.sin(a)*radius*.6*squash),(64+math.cos(b)*radius*.6,cy+math.sin(b)*radius*.6*squash)],.55,ink.c,100)

def heal(ink,t,seed,program):
    for strand in range(4):
        a=strand*TAU/4+t*4
        pts=[(64+math.sin(a+u*2.4)*(13+u*9),96-u*65) for u in [i/29 for i in range(30)]]
        ink.ribbon(pts,1.6,.7*(1-t*.5))
    particles(ink,t,seed,14,(64,85),True)
    if program in ('petals','feathers','life'):
        for i in range(5):
            a=i*TAU/5+t*2;x=64+math.cos(a)*23;y=71+math.sin(a)*16-t*15
            ink.polygon([(x-4,y+4),(x-3,y-4),(x+1,y-7),(x+4,y-2),(x+2,y+3)],ink.c,160*(1-t))

def hand(ink,t,seed,program):
    for i in range(5):
        x=43+i*9;pts=bezier((x,101),(x-14,76),(x+13,44),(x+(i-2)*5,35+i%2*6))
        ink.ribbon(pts,2.8,1-t*.7)
    for side in (-1,1):
        pts=bezier((64,92),(64+side*40,82),(64+side*35,65),(64+side*19,57))
        ink.ribbon(pts,3,1-t)
    particles(ink,t,seed,10,(64,79),True)

def meteor(ink,t,seed,travel=False):
    rng=random.Random(seed)
    if travel:
        volume(ink,t,seed,'meteor',True)
        for i in range(7):
            pts=bezier((100,64),(79,55+i*3),(50,42+i*7),(12+7*i,49+i*5))
            ink.ribbon(pts,3.2,1-i*.08)
        rock=[(107+13*math.cos(i*TAU/7),64+11*math.sin(i*TAU/7)) for i in range(7)]
        ink.polygon(rock,ink.dark);ink.line(rock+[rock[0]],1.5,ink.hot)
        ink.line([(99,58),(108,63),(102,71)],1,ink.c)
    else:
        flame(ink,t,seed)
        for i in range(11):
            a=rng.uniform(0,TAU);dist=rng.uniform(20,48)*t;x=64+math.cos(a)*dist;y=81+math.sin(a)*dist*.6-40*t+45*t*t
            size=(2+rng.random()*4)*(1-t*.8)
            pts=[(x-size,y),(x-size*.5,y-size),(x+size,y-size*.5),(x+size*.5,y+size)]
            ink.polygon(pts,ink.dark,230*(1-t));ink.line(pts[:3],.7,ink.c,190*(1-t))

def render(program,palette,seed,phase,t):
    ink=Ink(palette);fade=max(0,1-t)
    if phase in ('prepare','cast','ground'):
        sigil(ink,t,seed,True)
        if phase!='ground':
            if program in ('lightning','chain_lightning','storm_field','storm_ward'): lightning(ink,t*.35,seed)
            elif program in ('arrow','bullet'): particles(ink,t,seed,7,(80,64),False)
            else:particles(ink,t,seed,10,(64,84),True)
    elif phase=='resist':
        ink.c=(135,160,180);ink.hot=(206,223,230)
        for side in (-1,1):ink.ribbon(bezier((64,47),(64+side*13,43),(64+side*25,57),(64+side*(25+10*t),69+8*t)),1.4,fade)
    elif phase=='end': particles(ink,t,seed,10,(64,66),True,fade)
    elif phase=='aftermath':
        particles(ink,t,seed,20,(64,81),program in ('heal','holy_ward','soul'),fade*.65)
    elif phase=='flare':
        if program in ('lightning','chain_lightning','storm_field','thunder_stun'):lightning(ink,t,seed,program=='chain_lightning')
        else:
            for i in range(6):
                a=i*TAU/6+.2;ink.ribbon([(64,68),(64+math.cos(a)*8,68+math.sin(a)*8),(64+math.cos(a)*(12+18*t),68+math.sin(a)*(12+18*t))],2*(1-t),fade*.55)
    elif phase=='status':
        if 'stun' in program or program in ('mark','seal','chains'):
            for i in range(4):
                a=i*TAU/4+t*TAU;x=64+math.cos(a)*20;y=52+math.sin(a)*7
                ink.spark(x,y,3,.85)
            if program in ('mark','seal'):sigil(ink,t,seed)
        else:particles(ink,t,seed,9,(64,64),True)
    elif phase=='release':
        if program in ('lightning','chain_lightning','storm_ward'):
            for i in range(4):
                a=i*TAU/4;ink.line([(64,64),(64+12*math.cos(a+.3),64+12*math.sin(a+.3)),(64+20*math.cos(a),64+20*math.sin(a))],1,ink.hot,200*fade)
        else:
            particles(ink,t,seed,8,(64,64),False,fade)
            ink.spark(64,64,7*fade)
    elif phase=='travel':
        if program=='meteor':meteor(ink,t,seed,True)
        elif program in ('arrow','bullet'):
            ink.line([(18,64),(108,64)],1.4,ink.c,190)
            if program=='arrow':
                ink.polygon([(112,64),(100,60),(103,64),(100,68)],ink.hot)
                for j in range(4):ink.line([(25+j*4,64),(19+j*4,59)],.8,ink.c,170)
            else:
                ink.ribbon([(26,64),(72,64),(113,64)],2.6)
                ink.polygon([(108,62),(117,64),(108,66)],ink.hot)
        elif program in ('ice','eruption'):
            ink.polygon([(114,64),(83,56),(62,64),(83,72)],ink.c,210)
            ink.line([(25,64),(105,64)],1.1,ink.hot)
        else:
            for i in range(3):
                pts=bezier((20,64+i*3),(43,43+i*11),(74,80-i*10),(110,64))
                ink.ribbon(pts,2.5-i*.5,.8)
            ink.spark(107,64,6)
    elif program in ('stun','dark_stun','holy_stun','thunder_stun','rune_stun','excalibur','lance','judgement'):
        if program=='thunder_stun':lightning(ink,t,seed)
        else:
            y=20+min(1,t*6)*25
            pts=[(64,10),(60,39),(62,72),(64,96),(67,72),(68,39)]
            if program in ('excalibur','holy_stun','judgement'):
                ink.polygon(pts,ink.c,220*fade);ink.line([(64,14),(64,92)],1.4,ink.hot,240*fade)
                ink.line([(48,40),(80,40)],2,ink.hot,210*fade)
                if program=='judgement':
                    for side in (-1,1):ink.ribbon(bezier((64+side*7,66),(64+side*37,58),(64+side*44,26),(64+side*51,20)),3.5,fade)
            else:
                crescent(ink,t,seed,'claw' if program=='dark_stun' else 'blade')
                ink.ribbon([(53,y),(64,y+30),(73,y+44),(64,98)],3.5,fade)
        particles(ink,t,seed,18,(64,87))
    elif program in ('counter','ward','holy_ward','barrier','storm_ward','guardian'):
        ward(ink,t,seed,program in ('holy_ward','guardian'))
        if program=='counter':crescent(ink,t,seed,'blade')
        if program=='storm_ward':lightning(ink,t,seed)
    elif program in ('claw','foe','scythe','axe'): crescent(ink,t,seed,program)
    elif program in ('lightning','chain_lightning','storm_field'):
        lightning(ink,t,seed,program=='chain_lightning')
        if program=='storm_field':
            for i in range(3):
                a=i*TAU/3;ink.line([(64,83),(64+35*math.cos(a),83+12*math.sin(a))],1,ink.c,170*fade)
    elif program in ('firestorm','flame'):flame(ink,t,seed,True)
    elif program=='meteor':meteor(ink,t,seed)
    elif program in ('ice','eruption'):crystal(ink,t,seed,program=='eruption')
    elif program in ('hand','shadow','soul','blood'):hand(ink,t,seed,program)
    elif program in ('shockwave','chains'):
        for i in range(9):
            a=i*TAU/9+.12;rad=12+t*43
            if program=='chains':
                for j in range(5):
                    x=64+math.cos(a)*(j*8+5);y=70+math.sin(a)*(j*8+5)*.5
                    ink.line([(x-2,y-3),(x+3,y-1),(x+2,y+3),(x-3,y+1),(x-2,y-3)],1,ink.c,140*fade)
            else:
                pts=[(64+math.cos(a)*7,80+math.sin(a)*3),(64+math.cos(a+.1)*rad*.7,80+math.sin(a+.1)*rad*.3),(64+math.cos(a)*rad,80+math.sin(a)*rad*.4)]
                ink.ribbon(pts,3.7*fade,fade)
        particles(ink,t,seed,17,(64,80))
    elif program in ('arrow','bullet'):
        for i in range(8):
            a=i*TAU/8;ink.ribbon([(64,64),(64+math.cos(a)*12,64+math.sin(a)*12),(64+math.cos(a)*(14+22*t),64+math.sin(a)*(14+22*t))],1.5,fade)
        particles(ink,t,seed,12,(64,64))
    elif program in ('rune','enchant','portal','mark','seal','crown'):
        sigil(ink,t,seed)
        if program in ('rune','enchant'):crescent(ink,t,seed,'blade')
        if program=='crown':
            ink.line([(44,58),(40,39),(54,47),(64,31),(75,47),(88,39),(84,58),(44,58)],1.2,ink.hot,210*fade)
        particles(ink,t,seed,12,(64,72),True)
    elif program=='dragon':
        for side in (-1,1):
            pts=bezier((64,94),(64+side*44,90),(64+side*41,27),(64+side*12,22))
            ink.ribbon(pts,4,1-t*.7)
            ink.polygon([(64+side*12,22),(64+side*23,26),(64+side*12,32),(64+side*17,38)],ink.c,220*fade)
        heal(ink,t,seed,'life')
    else:heal(ink,t,seed,program)
    return ink.finish()

def choose(row,legacy):
    name=row['name'];motif=legacy.get('motif','');program=PROGRAMS.get(motif,'enchant')
    if name=='포우 슬레이어':program='foe'
    if name=='이럽션':program='eruption'
    palette='ether'
    if program in ('stun','counter','ward','arrow'):palette='steel' if program!='arrow' else 'nature'
    elif program in ('excalibur','crown','bullet','axe','shockwave'):palette='gold'
    elif program.startswith('holy') or program in ('judgement','guardian','lance','barrier'):palette='holy'
    elif program in ('firestorm','meteor','foe','eruption'):palette='fire'
    elif program=='ice':palette='ice'
    elif program in ('lightning','chain_lightning','mark','storm_field','storm_ward','thunder_stun','plasma'):palette='storm'
    elif program in ('dark_stun','hand','shadow','scythe'):palette='shadow'
    elif program=='blood':palette='blood'
    elif program in ('heal','life','petals','feathers'):palette='nature'
    elif program in ('soul','dragon'):palette='soul'
    if name=='어스 재일':palette='earth'
    return program,palette

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);args=parser.parse_args();root=args.root
    data=root/'data/skills';assets=root/'assets/skills/authored_vfx';assets.mkdir(parents=True,exist_ok=True)
    rows=json.loads((data/'master.json').read_text())['records'];legacy=json.loads((data/'vfx.json').read_text());relations=json.loads((data/'relations.json').read_text())
    profiles={};art=[]
    dormant={'stats','stack_defense','stack_attack','amplify'}
    for row in rows:
        sid=row['id'];program,palette=choose(row,legacy[sid]);seed=int(sid[-8:],16)
        p={'name':row['name'],'class':row['class'],'mode':row['mode'],'program':program,'palette':palette,
           'color':'#'+PALETTES[palette][0], 'reference_status':'UNVERIFIED','fidelity_approval':'PENDING',
           'standalone_event':row['mode'] not in dormant and row['mode']!='upgrade',
           'directional':program in ('arrow','bullet','claw','foe','scythe','axe','counter','rune'),
           'impact_offset':[0,-37] if program in ('lightning','storm_field','thunder_stun') else [0,0],
           'persistent_offset':[0,-22], 'scale':1.0,
           'clips':{k:{'first':v[0],'durations_ms':v[1],'loop':k in ('travel','persistent')} for k,v in CLIPS.items()}}
        if row['mode']=='upgrade':p['inherits_visual']=relations[sid]['upgrades_from'];p['upgrade_visual_difference']='UNVERIFIED_KEEP_BASE'
        elif row['mode'] not in dormant:
            atlas=Image.new('RGBA',(CELL*8,CELL*8))
            for phase,(first,times) in CLIPS.items():
                for i in range(len(times)):
                    t=i/max(1,len(times)-1)
                    if phase in ('persistent','travel'):t=i/len(times)
                    pic=render(program,palette,seed,phase,t)
                    atlas.paste(pic,((first+i)%8*CELL,(first+i)//8*CELL))
            path=assets/(sid+'.png')
            temporary=path.with_suffix('.png.tmp')
            atlas.save(temporary,format='PNG',optimize=True)
            temporary.replace(path)
            p['atlas']='res://'+str(path.relative_to(root));p['atlas_rgba_bytes']=CELL*CELL*64*4
            art.append({'id':sid,'path':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'frames':64})
        profiles[sid]=p
    manifest={'schema':1,'cell_size':CELL,'columns':8,'max_cached_atlases':12,'max_resident_rgba_bytes':12*1024*1024*4,
              'authorship':'Independent analytic raster artwork created for TWILIGHT; no external bitmap input.',
              'warning':'Fallback studies, not original fidelity approval. No publisher timing is asserted.',
              'profiles':profiles,'assets':art,
              'preview_profiles':{
                  'lm_42262935d6f53b07':{'name':'포우 슬레이어(임팩트)','preview_only':True,'runtime_status':'BLOCKED','inherits_visual':'lm_45d35daedfc527c9','visual_status':'UNVERIFIED_KEEP_BASE'},
                  'lm_816e9fd2e2e8a4e8':{'name':'아우라키아','preview_only':True,'runtime_status':'BLOCKED','inherits_visual':'lm_517ca31126a31b45','visual_status':'UNVERIFIED_SHARED_DRAGON_STUDY_NOT_FINISHED_AURAKIYA'}
              }}
    (data/'authored_vfx.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'profiles':len(profiles),'atlases':len(art),'frames':len(art)*64,'png_bytes':sum(x['bytes'] for x in art)}))

if __name__=='__main__':main()
