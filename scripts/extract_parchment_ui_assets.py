#!/usr/bin/env python3
"""Utilitário de pipeline de assets: remove o fundo de pergaminho das pranchas
de referência de UI (Meshy AI) e recorta as peças em PNGs transparentes.

Diferente do extrator usado pros kits de prédio/VFX deste projeto (que tem
fundo preto puro e separa por limiar de luminância), as pranchas de UI vêm
sobre papel/pergaminho com vinheta e textura de grão -- a claridade do fundo
varia demais (testado: de ~45 a ~210) pra um limiar único funcionar. Em vez
disso, classifica cada pixel por matiz+saturação+valor (HSV): o pergaminho é
sempre um tom quente (laranja/marrom) de saturação moderada; qualquer pixel
fora dessa faixa (metal escuro, branco de destaque, azul do cristal, etc.) é
tratado como primeiro plano, não importa a claridade.

Uso:
    # uma peça só, com recorte manual (x0,y0,x1,y1)
    python3 extract_parchment_ui_assets.py fatia prancha.png saida.png 100,50,300,250

    # a prancha inteira, separando automaticamente cada peça isolada
    python3 extract_parchment_ui_assets.py prancha prancha.png prefixo pasta_saida/
"""
import colorsys
import sys
from collections import deque
from pathlib import Path

from PIL import Image

HUE_MIN, HUE_MAX = 18, 48  # graus: faixa quente (laranja/marrom) do pergaminho
SAT_MAX = 0.72
VAL_MIN = 0.28
MIN_AREA = 250  # ignora manchas de ruído minúsculas na extração por prancha
PAD = 3


def is_parchment(r: int, g: int, b: int) -> bool:
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hue_deg = h * 360
    return (HUE_MIN <= hue_deg <= HUE_MAX) and s < SAT_MAX and v > VAL_MIN


def key_out_background(im: Image.Image) -> Image.Image:
    """Troca cada pixel de pergaminho por alfa 0, mantendo o resto opaco."""
    im = im.convert("RGB")
    w, h = im.size
    out = Image.new("RGBA", (w, h))
    spx, opx = im.load(), out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = spx[x, y]
            opx[x, y] = (r, g, b, 0) if is_parchment(r, g, b) else (r, g, b, 255)
    return out


def extract_slice(src_path: str, out_path: str, crop: tuple[int, int, int, int] | None) -> None:
    im = Image.open(src_path)
    if crop:
        im = im.crop(crop)
    key_out_background(im).save(out_path)


def extract_sheet(src_path: str, out_prefix: str, out_dir: str) -> None:
    """Separa a prancha inteira em componentes conectados (8-vizinhança),
    cada um recortado e com o fundo já removido."""
    im = Image.open(src_path).convert("RGB")
    w, h = im.size
    px = im.load()

    fg = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b = px[x, y]
            fg[base + x] = 0 if is_parchment(r, g, b) else 1

    visited = bytearray(w * h)
    boxes = []
    for y in range(h):
        base = y * w
        for x in range(w):
            idx = base + x
            if fg[idx] and not visited[idx]:
                q = deque([idx])
                visited[idx] = 1
                minx = maxx = x
                miny = maxy = y
                area = 0
                while q:
                    cur = q.popleft()
                    cy, cx = divmod(cur, w)
                    area += 1
                    minx, maxx = min(minx, cx), max(maxx, cx)
                    miny, maxy = min(miny, cy), max(maxy, cy)
                    for nx, ny in ((cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1),
                                   (cx-1,cy-1),(cx+1,cy-1),(cx-1,cy+1),(cx+1,cy+1)):
                        if 0 <= nx < w and 0 <= ny < h:
                            nidx = ny * w + nx
                            if fg[nidx] and not visited[nidx]:
                                visited[nidx] = 1
                                q.append(nidx)
                if area >= MIN_AREA:
                    boxes.append((minx, miny, maxx, maxy))

    boxes.sort(key=lambda b: (b[1] // 30, b[0]))  # leitura aprox. linha a linha
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    print(f"{len(boxes)} componentes encontrados")
    for i, (minx, miny, maxx, maxy) in enumerate(boxes):
        x0, y0 = max(0, minx - PAD), max(0, miny - PAD)
        x1, y1 = min(w, maxx + 1 + PAD), min(h, maxy + 1 + PAD)
        crop = key_out_background(im.crop((x0, y0, x1, y1)))
        name = f"{out_prefix}_{i:02d}_{x1-x0}x{y1-y0}.png"
        crop.save(Path(out_dir) / name)
        print(f"  {name}")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    mode = sys.argv[1]
    if mode == "fatia":
        crop_arg = sys.argv[4] if len(sys.argv) > 4 else None
        crop = tuple(int(v) for v in crop_arg.split(",")) if crop_arg else None
        extract_slice(sys.argv[2], sys.argv[3], crop)
    elif mode == "prancha":
        extract_sheet(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(f"Modo desconhecido: {mode} (use 'fatia' ou 'prancha')")
        sys.exit(1)
