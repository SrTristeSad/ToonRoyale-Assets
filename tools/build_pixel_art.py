#!/usr/bin/env python3
"""ToonRoyale: authorial chibi pixel-art treatment for real game sprites.

Keeps original filenames, canvas dimensions and transparent backgrounds.
Soft civilians, grumpy dangerous mobs, eerie charming monsters.
"""
from __future__ import annotations
import io, hashlib, json, sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from chibi_animals import redraw

SRC_ZIP = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('moomoo-io(1).zip')
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('assets/pixel-art/img')
PALETTE_COLORS = {'animals':22, 'weapons':24,'hats':22,'accessories':22,'resources':18,'icons':18,'promotion':28,'root':20}
HOSTILE = {'bull_1.png','bull_2.png','wolf_1.png','wolf_2.png'}
MONSTER = {'enemy.png','sid.png','vince.png'}
# Approximate iris centers in local sprite coordinates, before chibi proportions.
EYES = {
 'pig_1.png':((.43,.77),(.58,.77)), 'cow_1.png':((.45,.78),(.56,.78)),
 'bull_1.png':((.43,.76),(.59,.76)), 'bull_2.png':((.43,.76),(.59,.76)),
 'sheep_1.png':((.45,.82),(.55,.82)),
 'wolf_1.png':((.41,.82),(.59,.82)), 'wolf_2.png':((.43,.75),(.57,.75)),
 'duck_1.png':((.46,.83),(.56,.83)), 'chicken_1.png':((.45,.83),(.54,.83)),
 'fish_1.png':((.46,.85),(.56,.85)),
}

def box_alpha(img):
    return img.getchannel('A').getbbox()

def chibi_warp(im, group, basename):
    if group != 'animals' or basename in {'crate_1.png', 'enemy.png', 'sid.png', 'vince.png'}:
        return im
    # Slightly more prominent face and abbreviated body, while preserving the
    # original top-down silhouette and the canvas anchor used by the client.
    w,h=im.size
    split=.59 if 'wolf' not in basename else .67
    target=.53 if 'wolf' not in basename else .60
    src=im.load(); dest=Image.new('RGBA',(w,h),(0,0,0,0));dst=dest.load()
    for y in range(h):
        fy=y/(h-1) if h>1 else 0
        if fy<target: sy=fy*split/target
        else: sy=split+(fy-target)*(1-split)/(1-target)
        yi=max(0,min(h-1,round(sy*(h-1))))
        for x in range(w):
            if fy > target:
                # 8% wider cheeks and eyes; retain centered silhouette
                grow=1+.075*min(1,(fy-target)/max(.1,(1-target)))
                xx=round((x-(w-1)/2)/grow+(w-1)/2)
            else: xx=x
            if 0<=xx<w:dst[x,y]=src[xx,yi]
    return dest

def pixel_art(im, group, filename):
    im=im.convert('RGBA')
    w,h=im.size
    if group=='promotion':
        # Keep UI banner lettering legible; pixel grid still evident.
        scale=3
    elif w<=32 or h<=32: scale=1
    else: scale=4
    lw,lh=max(1,round(w/scale)),max(1,round(h/scale))
    im=im.resize((lw,lh), Image.Resampling.LANCZOS)
    im=chibi_warp(im,group,filename)
    # Enhance the art, not just enlarge the existing anti-aliasing.
    alpha=im.getchannel('A')
    opaque=Image.new('RGB',im.size,(241,235,230))
    opaque.paste(im,mask=alpha)
    saturation=1.24 if group in ('animals','resources') else 1.16
    if filename in HOSTILE: saturation=1.16
    opaque=ImageEnhance.Color(opaque).enhance(saturation)
    opaque=ImageEnhance.Contrast(opaque).enhance(1.09)
    opaque=ImageEnhance.Brightness(opaque).enhance(1.045)
    n=PALETTE_COLORS.get(group,20)
    opaque=opaque.quantize(colors=n,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
    # Crisp alpha edges. Preserve transparent pixel areas on all sprites.
    alpha=alpha.point(lambda v: 255 if v>=118 else 0)
    opaque.putalpha(alpha)
    # Source shapes retain their dark original ink. Strengthen edges with a
    # per-sprite outer 1-pixel contour without flattening interior details.
    if group!='promotion' and lw>32:
        spread=alpha.filter(ImageFilter.MaxFilter(3))
        outline=Image.new('RGBA',(lw,lh),(41,39,54,0))
        outline.putalpha(spread)
        outline.alpha_composite(opaque)
        opaque=outline
    if group=='animals':
        cute_details(opaque,filename)
    # Exactly the original pixel canvas, nearest-neighbour scaled.
    return opaque.resize((w,h),Image.Resampling.NEAREST)

def inside(im,x,y):
    return 0<=x<im.width and 0<=y<im.height and im.getpixel((x,y))[3]>=180

def cute_details(im,filename):
    if filename not in EYES:return
    hostile=filename in HOSTILE
    dr=ImageDraw.Draw(im,'RGBA'); w,h=im.size
    eyes=EYES[filename]
    # Small highlight beads read clearly at 64-pixel base size.
    for xx,yy in eyes:
        x=int(xx*w);y=int(yy*h)
        if inside(im,x,y):
            # Lively pupils: red catches light for mobs, almost-black for friends
            pupil=(121,43,58,255) if hostile else (37,36,56,255)
            # Do not obscure silhouette; translucent darkening improves expression
            dr.rectangle((x-1,y-1,x+1,y+1),fill=pupil)
            dr.point((x,y-1),fill=(255,255,247,255))
            if hostile:
                # Distinct angry eyebrows while retaining cute round body.
                dr.line((x-3,y-4,x+2,y-3),fill=(53,34,36,255),width=1)
        # Delicate blush on neutral animals, muted fierce cheek on violent mobs.
    for xx in (.33,.67):
        y=.84 if 'wolf' not in filename else .88
        if 'chicken' in filename or 'duck' in filename:y=.88
        x=int(xx*w);cy=int(y*h)
        if inside(im,x,cy):
            blush=(201,84,98,190) if hostile else (245,120,139,157)
            dr.rectangle((x-2,cy,x+1,cy+1),fill=blush)
            if not hostile:dr.point((x-2,cy-1),fill=(250,180,179,145))
    # The menacing creatures remain visibly dangerous, not smiling farm pets.
    if hostile:
        # Short scarlet cheek sparks deliberately small enough not to erase faces.
        px=int(.51*w); py=int(.865*h)
        if inside(im,px,py): dr.point((px,py),fill=(228,108,99,255))

def convert(raw, name):
    with Image.open(io.BytesIO(raw)) as original:
        original.load();w,h=original.size
        im=original.convert('RGBA')
    category=name.split('/')[0] if '/' in name else 'root'
    # Original pixel-drawn designs for all creatures, not simple pixelation.
    if category == 'animals':
        converted=redraw(name.rsplit('/',1)[-1],(w,h))
    else:
        converted=pixel_art(im,category,name.rsplit('/',1)[-1])
    if converted.size != (w,h):raise ValueError('dimension changed: '+name)
    if name!='promotion/banner_4.png' and converted.getchannel('A').getbbox() is None:
        raise ValueError('sprite lost all pixels: '+name)
    buffer=io.BytesIO(); converted.save(buffer,format='PNG',optimize=True)
    png=buffer.getvalue()
    with Image.open(io.BytesIO(png)) as verify:
        verify.verify()
        if verify.format!='PNG':raise ValueError('non-png: '+name)
    return png,(w,h)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    count={}; records=[]
    with zipfile.ZipFile(SRC_ZIP) as z:
        names=sorted(n for n in z.namelist() if n.lower().endswith('.png') and not n.startswith('__MACOSX/'))
        if len(names)!=176:raise ValueError(f'Expected 176 supplied assets, got {len(names)}')
        for name in names:
            data=z.read(name)
            png,dims=convert(data,name)
            p=OUT/name;p.parent.mkdir(exist_ok=True,parents=True);p.write_bytes(png)
            category=name.split('/')[0] if '/' in name else 'root'
            count[category]=count.get(category,0)+1
            records.append(dict(path=name,original_size=dims,sha256=hashlib.sha256(png).hexdigest()))
    manifest={'edition':'cute-chibi-pixel-art-v1','pixel_art_sprites':len(records),'categories':count,'preserves_canvas':True,'transparency':True,'assets':records}
    (OUT.parent/'pixel-art-manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('SUCCESS',len(records),'sprites',count)

if __name__=='__main__':main()
