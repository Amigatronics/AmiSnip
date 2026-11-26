#!/usr/bin/env python3
"""Turn a picture into a .info with an OS3.5+ ColorIcon (IFF FORM ICON) plus a
4-colour planar fallback for OS 3.0/3.1.  Usage: src.png H out.info tool|project
[tooltype ...]"""
import struct, sys
from PIL import Image, ImageEnhance

WBPAL = [(170, 170, 170), (0, 0, 0), (255, 255, 255), (102, 136, 187)]

def packbits(d):
    out, i, n = bytearray(), 0, len(d)
    while i < n:
        j = i
        while j + 1 < n and d[j + 1] == d[i] and j - i < 127:
            j += 1
        if j - i + 1 >= 3:
            out += bytes([(257 - (j - i + 1)) & 255, d[i]]); i = j + 1; continue
        k = i
        while k < n and k - i < 128:
            if k + 2 < n and d[k] == d[k + 1] == d[k + 2]:
                break
            k += 1
        out += bytes([k - i - 1]) + bytes(d[i:k]); i = k
    return bytes(out)

def imag(idx, pal, ncol):
    data = packbits(idx)
    p = bytes(sum(([r, g, b] for r, g, b in pal[:ncol]), []))
    hdr = struct.pack(">BBBBBBHH", 0, ncol - 1, 3, 1, 0, 8, len(data) - 1, len(p) - 1)
    body = hdr + data + p
    ch = b"IMAG" + struct.pack(">L", len(body)) + body
    return ch + (b"\0" if len(body) & 1 else b"")

def coloricon(im):
    w, h = im.size
    alpha = im.getchannel("A")
    rgb = Image.new("RGB", im.size, (0, 0, 0)); rgb.paste(im.convert("RGB"), mask=alpha)
    q = rgb.quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = [tuple(q.getpalette()[i * 3:i * 3 + 3]) for i in range(255)]
    a = alpha.tobytes()
    idx = bytes(0 if a[i] < 128 else q.tobytes()[i] + 1 for i in range(w * h))
    pal = [(0, 0, 0)] + pal
    sel = [(0, 0, 0)] + [tuple(min(255, int(c * 0.65)) for c in p) for p in pal[1:]]
    face = struct.pack(">BBBBH", w - 1, h - 1, 0, 0x11, 256 * 3 - 1)
    body = b"ICON" + b"FACE" + struct.pack(">L", len(face)) + face \
        + imag(idx, pal, 256) + imag(idx, sel, 256)
    return b"FORM" + struct.pack(">L", len(body)) + body

def fallback(im):
    w, h = im.size
    alpha = im.getchannel("A")
    bg = Image.new("RGB", im.size, WBPAL[0]); bg.paste(im.convert("RGB"), mask=alpha)
    pimg = Image.new("P", (1, 1)); pimg.putpalette(sum(map(list, WBPAL), []) + [0] * 756)
    q = bg.quantize(palette=pimg, dither=Image.FLOYDSTEINBERG)
    px = q.tobytes(); a = alpha.tobytes()
    px = bytes(0 if a[i] < 128 else px[i] for i in range(w * h))
    rb = ((w + 15) // 16) * 2
    planes = b""
    for p in range(2):
        for y in range(h):
            row = bytearray(rb)
            for x in range(w):
                if (px[y * w + x] >> p) & 1:
                    row[x // 8] |= 0x80 >> (x % 8)
            planes += bytes(row)
    return planes, q

def build(src, H, out, typ, tooltypes, preview=None):
    im = Image.open(src).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    W = round(im.width * H / im.height)
    im = im.resize((W, H), Image.LANCZOS)
    planes, q = fallback(im)
    t = {"tool": 3, "project": 4}[typ]
    o = bytearray()
    o += struct.pack(">HH", 0xE310, 1)
    o += struct.pack(">LhhhhHHHLLLLLHL", 0, 0, 0, W, H + 1, 4, 3, 1, 1, 0, 0, 0, 0, 0, 1)
    o += struct.pack(">BB", t, 0)
    o += struct.pack(">LL", 0, 1 if tooltypes else 0)
    o += struct.pack(">ll", -0x80000000, -0x80000000)
    o += struct.pack(">LLL", 0, 0, 8192)
    o += struct.pack(">hhhhhLBBL", 0, 0, W, H, 2, 1, 3, 0, 0)
    o += planes
    if tooltypes:
        o += struct.pack(">L", (len(tooltypes) + 1) * 4)
        for tt in tooltypes:
            b = tt.encode("latin-1") + b"\0"
            o += struct.pack(">L", len(b)) + b
    o += coloricon(im)
    open(out, "wb").write(o)
    if preview:
        big = Image.new("RGB", (W * 2 + 8, H), (170, 170, 170))
        big.paste(im, (0, 0), im)
        big.paste(q.convert("RGB"), (W + 8, 0))
        big.resize((big.width * 3, big.height * 3), Image.NEAREST).save(preview)
    print(out, W, H, len(o), "bytes")

if __name__ == "__main__":
    src, H, out, typ = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    build(src, H, out, typ, sys.argv[5:], out + ".preview.png")
