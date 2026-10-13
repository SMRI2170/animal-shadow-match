"""Development-only pastel cartoon placeholders (NOT final MiniMax artwork).

This deterministic script is used only to make the initial app playable before
hand-reviewed AI assets are imported. Production should replace every image.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/animals'
SIZE = 512
S = 3

def cv(v): return round(v * S)

def ellipse(d, box, color): d.ellipse(tuple(cv(v) for v in box), fill=color)
def polygon(d, points, color): d.polygon([(cv(x),cv(y)) for x,y in points], fill=color)
def line(d, points, color, width): d.line([(cv(x),cv(y)) for x,y in points], fill=color, width=cv(width), joint='curve')

def draw_one(name):
    image = Image.new('RGBA', (SIZE*S,SIZE*S), (0,0,0,0))
    d=ImageDraw.Draw(image)
    if name=='elephant':
        ellipse(d,(120,209,371,368),'#A2C9CA')
        ellipse(d,(122,179,251,323),'#9AC5C8')
        ellipse(d,(80,187,211,312),'#88B7BF')
        ellipse(d,(132,188,267,316),'#B4D6D8')
        line(d,[(145,273),(131,334),(150,356),(176,345)],'#A2C9CA',49)
        ellipse(d,(163,241,179,259),'#303C4E')
        for x in [170,316]: ellipse(d,(x,325,x+40,422),'#8CB8BE')
    elif name=='giraffe':
        ellipse(d,(164,264,356,365),'#EEC783')
        polygon(d,[(294,294),(297,112),(337,106),(339,290)],'#EEC783')
        ellipse(d,(284,93,388,159),'#EEC783')
        ellipse(d,(345,89,390,111),'#DDAE64')
        polygon(d,[(294,99),(277,54),(302,66),(318,100)],'#E7B874')
        polygon(d,[(341,102),(358,57),(376,71),(373,117)],'#E7B874')
        ellipse(d,(337,121,347,133),'#374452')
        for x,y in [(211,295),(252,320),(205,345),(327,245),(319,186)]: ellipse(d,(x,y,x+25,y+25),'#CC9663')
        for x in [200,310]: polygon(d,[(x,349),(x+28,349),(x+25,434),(x+4,434)],'#E7B874')
        line(d,[(170,292),(139,307),(132,342)],'#E7B874',9)
    elif name=='rabbit':
        ellipse(d,(180,227,347,401),'#DED1EA')
        ellipse(d,(162,185,308,315),'#E8DEF0')
        ellipse(d,(173,60,223,226),'#E1D2ED')
        ellipse(d,(243,63,292,228),'#E1D2ED')
        ellipse(d,(185,83,208,211),'#F2B9CC')
        ellipse(d,(256,86,280,211),'#F2B9CC')
        ellipse(d,(202,261,215,274),'#3C414A')
        ellipse(d,(261,261,274,274),'#3C414A')
        ellipse(d,(233,289,246,302),'#D994A7')
        ellipse(d,(314,345,385,412),'#F2E9F6')
        for x in [209,292]: ellipse(d,(x,377,x+48,434),'#D2C2DE')
    elif name=='cat':
        ellipse(d,(165,256,363,410),'#D6AC97')
        polygon(d,[(145,247),(154,95),(232,169),(268,167),(332,98),(359,251)],'#D6AC97')
        ellipse(d,(146,150,353,337),'#E4BCAC')
        polygon(d,[(168,134),(194,162),(163,193)],'#EDC4CB')
        polygon(d,[(328,134),(297,162),(340,194)],'#EDC4CB')
        ellipse(d,(193,236,213,261),'#343D4D')
        ellipse(d,(287,236,307,261),'#343D4D')
        polygon(d,[(243,273),(257,273),(251,285)],'#9E7685')
        line(d,[(344,352),(403,348),(411,278)],'#D6AC97',25)
        for x in [200,290]: ellipse(d,(x,390,x+39,434),'#C89985')
    elif name=='whale':
        ellipse(d,(93,218,378,366),'#83B7D2')
        polygon(d,[(330,267),(414,176),(412,256),(448,274),(400,316)],'#7DAEC9')
        ellipse(d,(111,296,347,359),'#B9E1E4')
        ellipse(d,(162,266,180,284),'#3B5265')
        polygon(d,[(256,322),(222,402),(285,369)],'#619FBC')
        line(d,[(204,202),(198,183),(189,176)],'#98CCE0',8)
        line(d,[(202,203),(213,169)],'#98CCE0',7)
    elif name=='duck':
        ellipse(d,(148,255,359,390),'#E7D58A')
        ellipse(d,(203,149,337,302),'#F0DD98')
        polygon(d,[(312,240),(392,257),(312,275)],'#E5A56F')
        ellipse(d,(286,214,302,230),'#465468')
        ellipse(d,(170,280,289,346),'#D5BF73')
        for x in [212,288]: line(d,[(x,382),(x,415),(x+20,415)],'#D89265',11)
        polygon(d,[(157,284),(120,260),(127,316)],'#E3CE7F')
    elif name=='butterfly':
        ellipse(d,(120,125,255,281),'#D8B3D9')
        ellipse(d,(113,256,253,395),'#C6AFDB')
        ellipse(d,(257,125,390,281),'#D8B3D9')
        ellipse(d,(256,256,399,395),'#C6AFDB')
        ellipse(d,(232,154,279,378),'#C6A07F')
        ellipse(d,(223,142,288,205),'#B78D7B')
        line(d,[(243,146),(211,103)],'#897C81',6)
        line(d,[(264,146),(300,103)],'#897C81',6)
        for x,y in [(174,201),(325,201),(172,317),(330,317)]: ellipse(d,(x-20,y-20,x+20,y+20),'#F8E8AB')
    elif name=='octopus':
        for x,y in [(156,367),(191,393),(227,398),(267,398),(302,393),(342,367)]:
            line(d,[(256,307),(x,y)],'#C99ABF',30)
        ellipse(d,(150,155,363,353),'#DDB3CD')
        for x in [210,286]: ellipse(d,(x,257,x+19,281),'#495266')
        ellipse(d,(251,294,263,306),'#CA819D')
    else: raise ValueError(name)
    image=image.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
    OUT.mkdir(parents=True,exist_ok=True)
    image.save(OUT/f'{name}.webp',format='WEBP',lossless=True,method=6)
    silhouette=Image.new('RGBA',(SIZE,SIZE),(37,49,52,0))
    silhouette.putalpha(image.getchannel('A'))
    silhouette.save(OUT/f'{name}_shadow.webp',format='WEBP',lossless=True,method=6)

if __name__=='__main__':
    for name in ['elephant','giraffe','rabbit','cat','whale','duck','butterfly','octopus']:
        draw_one(name)
    print('Created 8 demo animal pairs. Replace before release.')
