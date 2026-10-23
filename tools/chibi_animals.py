"""Original, hand-built top-down pixel characters for ToonRoyale."""
from PIL import Image, ImageDraw
import math

INK='#302e40'
LIGHT='#fffefa'

def redraw(name, size):
    base=Image.new('RGBA',(72,82),(0,0,0,0));d=ImageDraw.Draw(base)
    def e(b, fill, border=INK, width=2):
        d.ellipse(tuple(map(int,b)), fill=fill, outline=border, width=width)
    def r(b, fill, border=INK, width=2):
        d.rounded_rectangle(tuple(map(int,b)), radius=3,fill=fill,outline=border,width=width)
    def poly(p,fill,border=INK,width=2):
        d.polygon(p,fill=fill)
        if border:d.line(p+[p[0]],fill=border,width=width,joint='curve')
    def line(coords,color=INK,w=2):d.line(coords,fill=color,width=w,joint='curve')
    def gl(x,y,color='#221f35',angry=False):
        e((x-5,y-5,x+5,y+6),'#fff9f1',width=2)
        e((x-2,y-3,x+3,y+4),color,border=color,width=1)
        e((x-1,y-3,x,y-1),'#ffffff',border='#ffffff',width=1)
        d.point((x+3,y+3),fill='#ffffff')
        if angry:
            line((x-6,y-9,x+4,y-6),INK,3)
    def cheeks(y=66, mood='normal'):
        c='#c35266' if mood=='angry' else '#f3a1ad'
        e((17,y-1,24,y+3),c,border=None)
        e((48,y-1,55,y+3),c,border=None)
    def highlight(b):e(b,'#ffffff',border=None)
    def body(fill,patch=None):
        e((17,8,55,59),fill,width=3)
        e((21,10,49,30),patch or fill,border=None)
        # little paws at sides -- top down
        e((13,32,23,47),fill,width=2);e((49,32,59,47),fill,width=2)
        e((17,51,29,63),fill,width=2);e((44,51,56,63),fill,width=2)
    def head(fill,ear='#eda4ad',eyes='#272437',mood='normal'):
        # big plushy ears under the broad rounded face
        e((8,43,25,61),ear,width=3);e((47,43,64,61),ear,width=3)
        e((15,39,57,77),fill,width=3)
        e((19,43,52,52),fill,border=None)
        gl(27,59,eyes,mood=='angry');gl(45,59,eyes,mood=='angry')
        cheeks(mood=mood)
    if name=='pig_1.png':
        # playful curl, distinctive white forehead tuft and candy-colored body
        line((40,10,43,2,36,2,32,7,36,10),'#b5677d',4)
        line((40,10,43,2,36,2,32,7,36,10),'#ffbac8',2)
        body('#ffc4d1','#ffdae0')
        e((26,15,32,20),'#fff1f4',border=None)
        head('#ffd1dc','#fa92b2')
        poly([(32,43),(35,39),(38,44),(41,42),(40,48),(33,49)],'#fff2ed',border=None)
        e((25,66,47,79),'#e98da3',width=2)
        e((30,71,34,76),INK,border=None);e((39,71,43,76),INK,border=None)
    elif name=='cow_1.png':
        body('#fff6e9','#fff9f5')
        e((19,15,32,32),'#625b72',width=0,border=None)
        e((43,28,55,48),'#625b72',width=0,border=None)
        e((28,35,37,44),'#b8a4aa',width=0,border=None)
        poly([(15,45),(11,35),(17,32),(24,41)],'#f0e3cb')
        poly([(57,45),(61,35),(55,32),(48,41)],'#f0e3cb')
        head('#fffbf1','#f1adb9')
        e((20,43,34,53),'#676071',width=0,border=None)
        e((25,66,48,79),'#f6a9b7',width=2)
        e((30,72,33,76),INK,border=None);e((40,72,43,76),INK,border=None)
        poly([(38,42),(43,39),(43,45)],'#f3d19b',border=None)
    elif name in ('bull_1.png','bull_2.png'):
        is_brown=name=='bull_2.png'
        fill='#ab7455' if is_brown else '#767b90';lit='#cc9772' if is_brown else '#9ea3b1';face='#c48d66' if is_brown else '#999eab'
        body(fill,lit)
        # massive tufts/horns separate the boss silhouette
        poly([(20,50),(9,47),(5,40),(9,27),(15,31),(15,38),(23,42)],'#f4e2bb')
        poly([(52,50),(63,47),(67,40),(63,27),(57,31),(57,38),(49,42)],'#f4e2bb')
        head(face,'#b38c7a',eyes='#bd3447',mood='angry')
        poly([(29,43),(34,38),(36,45),(43,40),(45,50),(30,51)],lit)
        e((27,67,46,79),'#ddbaa0',width=2)
        e((31,71,34,76),INK,border=None);e((40,71,43,76),INK,border=None)
        # signature nose ring
        line((32,77,32,80,40,80,40,77),'#ffda6e',2)
    elif name in ('wolf_1.png','wolf_2.png'):
        shadow=name=='wolf_2.png';fur='#3e645d' if shadow else '#8b93ad';edge='#304b49' if shadow else '#68738f'
        body(fur,edge)
        poly([(15,50),(15,18),(24,32),(32,24),(38,30),(49,18),(58,39),(60,59),(52,72),(21,72)],fur)
        # triangular pointed ears and forehead jagged bangs
        poly([(13,52),(13,33),(25,42)],fur)
        poly([(59,52),(59,33),(47,42)],fur)
        poly([(20,43),(31,39),(38,43),(48,37),(55,49),(52,67),(45,76),(26,76),(18,64)],fur)
        poly([(25,47),(31,42),(37,49),(43,44),(48,48),(46,54),(26,54)],edge,border=None)
        gl(27,59,'#ee3f59' if shadow else '#297f9b',angry=shadow)
        gl(45,59,'#ee3f59' if shadow else '#297f9b',angry=shadow)
        cheeks(mood='angry' if shadow else 'normal')
        e((32,66,40,72),'#2c283a',width=1)
        poly([(28,71),(33,73),(33,77)],'#fffaf1',border=None)
        poly([(44,71),(39,73),(39,77)],'#fffaf1',border=None)
        if shadow:
            poly([(31,17),(36,2),(41,17)],'#5c9e8e')
            e((33,14,39,22),'#dd4855',border=None)
    elif name=='sheep_1.png':
        body('#f6f1df','#ffffff')
        # segmented wool loops surround a smaller caramel face
        for x,y in [(22,14),(37,13),(50,16),(18,29),(54,30),(20,44),(52,43),(26,51),(45,51)]:
            e((x-9,y-8,x+9,y+9),'#f9f3e7',width=2)
        e((19,45,53,76),'#dfb58b',width=3)
        e((9,46,24,59),'#f0c2be',width=2);e((48,46,63,59),'#f0c2be',width=2)
        gl(28,59);gl(44,59);cheeks()
        e((32,68,41,74),'#6f4c48',border=None)
    elif name in ('chicken_1.png','duck_1.png'):
        duck=name=='duck_1.png'
        shell='#c8a36f' if duck else '#fff0ae';wing='#e4c28b' if duck else '#ffdd74'
        body(shell,'#f7dea0' if duck else '#fff6bf')
        e((13,29,27,51),wing,width=2);e((45,29,59,51),wing,width=2)
        if not duck:
            for xx,yy,rr in [(31,41,8),(37,37,9),(43,42,7)]:e((xx-rr,yy-rr,xx+rr,yy+rr),'#ffd36e',width=2)
            e((16,44,56,77),'#ffeda5',width=3)
            for dx,dy in [(29,37),(35,31),(41,36)]:e((dx-5,dy-5,dx+5,dy+5),'#ed6d59',width=2)
        else:
            head('#7fae89','#cdbb7b')
            e((19,44,53,76),'#7faa87',width=2)
        gl(27,57);gl(45,57);cheeks(y=64)
        poly([(30,65),(42,65),(36,76)],'#ff9f54')
        line((32,70,40,70),'#c65f49',1)
    elif name=='fish_1.png':
        poly([(36,8),(28,21),(44,21)],'#ffd577')
        poly([(22,36),(5,22),(13,50),(23,55)],'#fa9658')
        poly([(50,36),(67,22),(59,50),(50,55)],'#fa9658')
        e((20,19,52,75),'#ffa863',width=3)
        e((25,22,47,45),'#ffd593',border=None)
        e((16,61,56,76),'#f5c78a',width=2)
        gl(28,58);gl(44,58);cheeks(y=66)
        e((32,70,40,74),'#b95f51',border=None)
    elif name=='crate_1.png':
        r((8,21,64,61),'#7f5949',width=3)
        r((12,24,60,57),'#bc8560',width=2)
        r((18,25,24,59),'#e0bc7d',width=2);r((48,25,54,59),'#e0bc7d',width=2)
        line((26,27,45,54),'#83523d',2);line((45,27,26,54),'#83523d',2)
        e((29,34,43,49),'#e9ce7a',width=2)
        r((33,39,39,48),'#614737',width=1)
        highlight((17,25,22,27))
    elif name in ('enemy.png','sid.png','vince.png'):
        # Individually recognizable fantasy foes, all miniature and charming.
        if name=='enemy.png':
            body('#63766c','#89a193')
            poly([(12,48),(8,33),(21,41)],'#7a8b7f')
            poly([(60,48),(64,33),(51,41)],'#7a8b7f')
            head('#8da6a0','#6b827d',eyes='#ea4b61',mood='angry')
            poly([(31,44),(36,31),(40,44)],'#586b60')
            poly([(14,45),(20,30),(24,43)],'#526961')
            poly([(58,45),(53,30),(48,43)],'#526961')
            poly([(31,69),(34,77),(36,70)],'#fff9dd')
            poly([(41,69),(38,77),(36,70)],'#fff9dd')
            # small club on his right
            line((54,38,67,70),'#785949',4)
            poly([(54,28),(65,22),(71,32),(67,45),(57,45),(51,37)],'#8b8eaa')
        elif name=='sid.png':
            body('#45765c','#6caa7b')
            e((16,38,57,76),'#407253',width=3)
            e((13,12,59,60),'#8bba6c',width=3)
            e((20,20,52,57),'#283d42',width=3)
            gl(28,45,'#f2bf4e');gl(44,45,'#f2bf4e')
            e((31,59,42,69),'#ffd272',width=2)
            # small lucky leaf pin
            for x,y in [(55,31),(63,30),(58,25),(59,37)]:e((x-4,y-4,x+4,y+4),'#a5e079',border=None)
            line((60,38,64,44),'#4d8a53',2)
        else:
            body('#665a62','#a29991')
            head('#e4caa0','#a09291',eyes='#a95064',mood='angry')
            e((24,49,48,64),'#57505e',width=2)
            gl(27,57,'#e84b5e',True);gl(45,57,'#e84b5e',True)
            r((29,66,43,74),'#fff4d9',width=2)
            for x in (33,38):line((x,68,x,73),'#6b5964',1)
            # unique hooked pirate moustache on both sides
            line((32,65,23,63,18,66),'#59515d',2)
            line((40,65,49,63,54,66),'#59515d',2)
    else:
        raise ValueError('Unknown animal sprite '+name)
    return base.resize(size,Image.Resampling.NEAREST)
