#!/usr/bin/env python3
"""Pixel art fiel: reconstroi cores e contornos em celulas inteiras, sem blur."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image

SRC = Path('assets/img')
OUT = Path('assets/pixel-art-fiel/img')
META = Path('assets/pixel-art-fiel/manifest.json')

def block_size(path):
    if path == 'favicon.png' or path.startswith('promotion/'): return 1
    if path.startswith('weapons/') or path.startswith('icons/') or path.startswith('resources/'): return 2
    return 3

def redraw(im, scale, effects=False):
    a = np.asarray(im.convert('RGBA'), dtype=np.uint8)
    h,w=a.shape[:2]
    if scale == 1: return im.convert('RGBA'), 1.0
    opaque = a[a[:,:,3]>=245,:3]
    if not len(opaque): return im.convert('RGBA'), 1.0
    count = Counter(map(tuple, opaque))
    threshold = max(5, int(len(opaque)*0.0004))
    palette = np.array([rgb for rgb,freq in count.most_common() if freq >= threshold][:64 if effects else 32], dtype=np.int32)
    if not len(palette): palette = np.array([count.most_common(1)[0][0]], dtype=np.int32)
    y = np.minimum(h-1, np.arange(math.ceil(h/scale))*scale+scale//2)
    x = np.minimum(w-1, np.arange(math.ceil(w/scale))*scale+scale//2)
    small = a[y[:,None],x[None,:]].copy()
    occupied = small[:,:,3]>=128
    pixels = small[:,:,:3][occupied].astype(np.int32)
    if len(pixels):
        converted = []
        for chunk in np.array_split(pixels,max(1,math.ceil(len(pixels)/4096))):
            distance = np.sum((chunk[:,None,:]-palette[None,:,:])**2,axis=2)
            converted.append(palette[np.argmin(distance,axis=1)].astype(np.uint8))
        small[:,:,:3][occupied] = np.vstack(converted)
    if effects:
        small[:,:,3] = np.minimum(255, ((small[:,:,3].astype(np.uint16)+31)//64*64)).astype(np.uint8)
    else:
        small[:,:,3] = np.where(occupied, 255, 0).astype(np.uint8)
    small[:,:,:3][small[:,:,3]==0] = 0
    rendered = np.repeat(np.repeat(small,scale,axis=0),scale,axis=1)[:h,:w]
    before = a[:,:,3]>=128
    after = rendered[:,:,3]>=128
    union = np.count_nonzero(before | after)
    overlap = np.count_nonzero(before & after)/union if union else 1.0
    return Image.fromarray(rendered, 'RGBA'), round(float(overlap),5)

def main():
    source = sorted(SRC.rglob('*.png'))
    if len(source)!=176: raise RuntimeError(f'Esperadas 176 imagens, encontradas {len(source)}')
    OUT.mkdir(parents=True,exist_ok=True)
    records = []
    for path in source:
        rel=path.relative_to(SRC).as_posix()
        with Image.open(path) as origin:
            origin.load()
            if origin.format!='PNG': raise ValueError(f'Fonte nao e PNG: {rel}')
            dimensions=origin.size
            original=origin.convert('RGBA')
        cell=block_size(rel)
        fx=rel.startswith('weapons/') and (rel.endswith('_e.png') or rel.endswith('_r.png'))
        result,overlap=redraw(original,cell,fx)
        while overlap < .88 and cell > 1:
            cell-=1
            result,overlap=redraw(original,cell,fx)
        if overlap < .88: raise ValueError('Visual muito alterado: '+rel)
        out=OUT/rel
        out.parent.mkdir(parents=True,exist_ok=True)
        result.save(out,'PNG',compress_level=9)
        with Image.open(out) as verify:
            verify.load()
            assert verify.format=='PNG' and verify.size==dimensions and verify.mode=='RGBA'
        records.append({'path':rel,'size':list(dimensions),'pixel_cell':cell,'shape_overlap':overlap,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    META.parent.mkdir(parents=True, exist_ok=True)
    META.write_text(json.dumps({'edition':'pixel-art-fiel-v1','source':'assets/img','total':len(records),'files':records},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('PASS',len(records),'PNG sem alterar dimensoes; pior sobreposicao visual',min(x['shape_overlap'] for x in records))

if __name__=='__main__': main()
