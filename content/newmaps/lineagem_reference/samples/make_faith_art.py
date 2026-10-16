#!/usr/bin/env python3
"""Procedural ORIGINAL 2D architecture sprites, no Lineage M bitmap imports.
Run from the isolated PR121 sample build; Pillow is the only optional dependency.
"""
from PIL import Image,ImageDraw,ImageFilter
from pathlib import Path
import math,random,hashlib,json,sys

def canvas(w,h):return Image.new('RGBA',(w,h),(0,0,0,0))
def polygon(d,points,color,edge=(15,14,20,255),weight=2):
 d.polygon(points,fill=color);d.line(points+[points[0]],fill=edge,width=weight,joint='curve')
def shadow(image,rect,blur=15):
 layer=canvas(*image.size);ImageDraw.Draw(layer).ellipse(rect,fill=(0,0,0,160));image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
def floor(out):
 im=Image.new('RGBA',(512,512),(23,24,27,255));d=ImageDraw.Draw(im,'RGBA');r=random.Random(48)
 for y in range(0,512,64):
  for x in range(-68,578,68):
   xx=x+(-34 if (y//64)%2 else 0);v=r.randint(-13,13)
   d.rectangle((xx+2,y+2,xx+65,y+61),fill=(74+v,71+v,72+v,255))
   d.line((xx+3,y+3,xx+63,y+3),fill=(150,140,128,130),width=2)
   d.line((xx+65,y+3,xx+65,y+62,xx+3,y+62),fill=(9,9,14,180),width=3)
   if r.random()<.33:
    px=xx+r.randint(12,35);py=y+r.randint(14,45)
    d.line((px,py,px+r.randint(9,25),py-4,px+r.randint(22,44),py+10),fill=(20,19,24,170),width=2)
 for i in range(9000):
  x=r.randrange(512);y=r.randrange(512);d.point((x,y),fill=(2,2,4,r.randrange(10,70)))
 im.save(out)
def carpet(out):
 im=Image.new('RGBA',(512,256),(69,18,30,255));d=ImageDraw.Draw(im,'RGBA');r=random.Random(67)
 for y in range(256):d.line((0,y,511,y),fill=(135+int(17*math.sin(y/12)),32,41,r.randrange(7,36)))
 for x in (10,25,38,476,489,502):d.line((x,0,x,255),fill=(186,139,65,172),width=2)
 for y in range(36,256,73):
  for x in range(80,480,99):polygon(d,[(x,y-12),(x+12,y),(x,y+12),(x-12,y)],(155,117,75,69),(176,142,85,85))
 for i in range(11000):d.point((r.randrange(512),r.randrange(256)),fill=(7,3,7,r.randrange(7,50)))
 im.save(out)
def ring(out):
 im=canvas(960,640);d=ImageDraw.Draw(im,'RGBA');shadow(im,(100,100,870,600),28)
 for xy,c,wide in [((105,68,855,562),(22,22,26,245),9),((132,96,829,540),(166,124,72,245),5),((165,120,798,511),(37,35,40,255),12),((195,138,765,495),(148,110,68,235),4),((225,157,735,473),(49,44,49,255),3)]:d.ellipse(xy,fill=c,outline=(196,154,83,215),width=wide)
 for i in range(36):
  a=math.tau*i/36
  d.line((480+216*math.cos(a),312+133*math.sin(a),480+285*math.cos(a),312+181*math.sin(a)),fill=(190,136,73,145),width=3)
 for i in range(8):
  a=math.tau*i/8;x=480+94*math.cos(a);y=316+60*math.sin(a)
  d.line((480,316,x,y),fill=(182,132,75,180),width=4)
 d.ellipse((361,238,598,394),fill=(83,21,37,226),outline=(187,143,86,255),width=5)
 im.save(out)
def wall(out):
 im=canvas(1024,330);d=ImageDraw.Draw(im,'RGBA');shadow(im,(20,265,1004,335),16)
 polygon(d,[(10,261),(43,57),(976,57),(1014,261),(989,313),(38,313)],(51,49,54,255),(139,120,89,255),5)
 polygon(d,[(29,69),(77,24),(948,24),(996,69),(962,96),(64,96)],(100,93,90,255),(189,146,93,220),3)
 for x in range(92,1000,175):
  polygon(d,[(x,242),(x+5,125),(x+68,88),(x+136,126),(x+138,242)],(15,17,25,255),(145,114,70,190),4)
  polygon(d,[(x+18,232),(x+26,142),(x+67,114),(x+118,140),(x+121,232)],(31,29,36,255),(99,83,75,155),2)
  for y in range(153,230,20):d.line((x+28,y,x+121,y),fill=(98,95,95,80),width=2)
  d.rectangle((x-2,65,x+14,293),fill=(88,82,83,255),outline=(37,35,40,255),width=2)
 for y in range(115,295,37):d.line((45,y,977,y),fill=(15,15,20,80),width=2)
 im.save(out)
def pillar(out):
 im=canvas(240,368);d=ImageDraw.Draw(im,'RGBA');shadow(im,(25,319,223,375))
 polygon(d,[(39,327),(72,288),(174,288),(211,327),(174,348),(76,348)],(43,42,49,255),(160,136,102,220),3)
 polygon(d,[(80,278),(94,96),(146,96),(163,278),(137,302),(100,302)],(76,74,80,255),(28,28,34,255),5)
 polygon(d,[(92,260),(101,110),(119,105),(113,280)],(139,129,119,125),(139,129,119,60),1)
 polygon(d,[(132,111),(148,104),(160,264),(142,284)],(20,21,28,170),(20,21,28,140),1)
 for x in (99,118,137,154):d.line((x,123,x-3,256),fill=(36,35,43,170),width=3)
 polygon(d,[(75,101),(91,75),(158,75),(181,101),(157,123),(82,123)],(89,77,81,255),(189,146,79,220),3)
 polygon(d,[(84,71),(113,36),(145,36),(174,71)],(57,55,64,255),(183,145,82,220),3)
 light=canvas(*im.size);a=ImageDraw.Draw(light,'RGBA')
 for rad in range(64,3,-3):a.ellipse((127-rad,43-rad,127+rad,43+rad),fill=(22,191,173,max(0,37-rad//2)))
 im.alpha_composite(light.filter(ImageFilter.GaussianBlur(12)))
 polygon(d,[(125,58),(108,34),(118,9),(129,0),(141,21),(145,43)],(57,237,209,248),(169,255,243,230),3)
 im.save(out)
def rail(out):
 im=canvas(470,155);d=ImageDraw.Draw(im,'RGBA');shadow(im,(4,118,468,154),11)
 d.rectangle((8,91,462,117),fill=(66,60,66,255),outline=(160,126,88,255),width=3)
 for x in range(22,470,27):
  polygon(d,[(x,90),(x-5,75),(x-4,27),(x+4,5),(x+12,28),(x+12,74),(x+8,90)],(29,32,40,255),(134,130,113,200),2)
 d.rectangle((3,78,467,92),fill=(84,76,73,255),outline=(173,142,98,255),width=3)
 for x in range(15,470,120):polygon(d,[(x-8,118),(x-8,58),(x+16,43),(x+39,60),(x+40,120)],(90,86,91,255),(172,140,94,205),3)
 im.save(out)
def statue(out):
 im=canvas(220,340);d=ImageDraw.Draw(im,'RGBA');shadow(im,(18,309,204,338),12)
 polygon(d,[(23,290),(56,272),(170,272),(199,293),(185,323),(30,323)],(59,56,63,255),(177,153,116,250),4)
 polygon(d,[(68,258),(75,149),(111,92),(145,155),(160,279)],(55,53,64,255),(149,129,98,230),4)
 polygon(d,[(78,144),(113,162),(140,146),(148,231),(110,283),(70,225)],(43,43,56,255),(138,127,121,190),2)
 d.ellipse((82,58,140,126),fill=(45,43,54,255),outline=(161,145,118,255),width=4)
 polygon(d,[(82,69),(109,23),(151,69),(143,92),(115,57),(86,92)],(49,46,56,255),(170,139,91,245),3)
 im.save(out)
def altar(out):
 im=canvas(480,300);d=ImageDraw.Draw(im,'RGBA');shadow(im,(62,239,429,299),19)
 polygon(d,[(67,210),(130,148),(360,148),(421,210),(363,255),(113,255)],(67,57,62,255),(178,131,81,230),5)
 polygon(d,[(83,199),(140,151),(344,151),(406,200),(353,219),(145,219)],(128,101,76,255),(212,153,86,255),4)
 polygon(d,[(148,152),(155,83),(325,83),(332,157)],(48,42,49,255),(156,124,79,255),5)
 polygon(d,[(171,87),(190,35),(290,35),(310,86)],(73,60,62,255),(190,136,79,220),4)
 im.save(out)
def candles(out):
 im=canvas(200,228);d=ImageDraw.Draw(im,'RGBA');shadow(im,(16,193,191,225),12)
 d.line((99,189,103,76),fill=(91,69,54,255),width=10)
 d.rectangle((48,194,149,211),fill=(74,60,54,255),outline=(177,142,92,255),width=3)
 for x,y in ((40,99),(80,65),(120,65),(159,99)):
  d.line((100,115,x,y+15),fill=(143,106,68,235),width=6)
  d.rectangle((x-5,y+12,x+5,y+32),fill=(200,182,153,255))
  polygon(d,[(x-6,y+12),(x,y-19),(x+5,y+12)],(251,183,80,252),(255,244,165,210),2)
 im.save(out)
def rubble(out):
 im=canvas(200,120);d=ImageDraw.Draw(im,'RGBA');shadow(im,(9,77,190,116),11);r=random.Random(33)
 for _ in range(28):
  x=r.randrange(14,187);y=r.randrange(50,106);s=r.randrange(5,20)
  polygon(d,[(x-s,y),(x-s//3,y-s),(x+s//2,y-s//2),(x+s,y+2)],(r.randrange(43,97),r.randrange(39,83),r.randrange(42,81),r.randrange(145,242)),(24,24,29,140),1)
 im.save(out)
def glow(out):
 im=canvas(384,384);p=im.load()
 for y in range(384):
  for x in range(384):
   radius=math.hypot((x-192)/192,(y-192)/192)
   p[x,y]=(31,210,187,int(110*max(0,1-radius)**2.2))
 im.save(out)

def main(path):
 out=Path(path);out.mkdir(parents=True,exist_ok=True)
 tasks={'floor_tile.png':floor,'carpet_tile.png':carpet,'ritual_ring.png':ring,'teal_pillar.png':pillar,'gothic_wall.png':wall,'balustrade.png':rail,'guardian_statue.png':statue,'stone_altar.png':altar,'candelabra.png':candles,'rubble.png':rubble,'teal_glow.png':glow}
 catalog={}
 for key,fn in tasks.items():
  fn(out/key);v=(out/key).read_bytes()
  catalog[key]={'bytes':len(v),'sha256':hashlib.sha256(v).hexdigest()}
 (out/'ASSETS.json').write_text(json.dumps({'origin':'TWILIGHT_OWN_PROCEDURAL_2D','files':catalog},indent=2),encoding='utf8')
 print('FAITH4_ART_READY',len(catalog))
if __name__=='__main__': main(sys.argv[1] if len(sys.argv)>1 else 'assets/faith04')
