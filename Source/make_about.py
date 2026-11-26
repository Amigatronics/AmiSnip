#!/usr/bin/env python3
"""Convert the About picture into RGBA + 32-colour indexed data for incbin."""
import sys
from PIL import Image
src, outdir, H = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGBA")
bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
im = im.crop(bbox)
W = max(1, round(im.width * H / im.height))
im = im.resize((W, H), Image.LANCZOS)
open(f"{outdir}/about_rgba.bin", "wb").write(im.tobytes())
# indexed version: opaque pixels quantised to 31 colours, index 31 = transparent
alpha = im.getchannel("A")
rgb = Image.new("RGB", im.size, (170, 170, 170))
rgb.paste(im.convert("RGB"), mask=alpha)
q = rgb.quantize(colors=31, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG)
pal = q.getpalette()[:31 * 3] + [0, 0, 0]
idx = bytearray(q.tobytes())
a = alpha.tobytes()
for i in range(len(idx)):
    if a[i] < 128:
        idx[i] = 31
open(f"{outdir}/about_idx.bin", "wb").write(bytes(idx))
open(f"{outdir}/about_pal.bin", "wb").write(bytes(pal))
open(f"{outdir}/about_img.i", "w").write(
    f"ABOUT_W equ {W}\nABOUT_H equ {H}\nABOUT_NCOL equ 32\nABOUT_TRANSP equ 31\n")
# previews
prev = Image.new("RGB", im.size, (170, 170, 170)); prev.paste(im, mask=alpha)
prev.save(f"{outdir}/about_preview_rgb.png")
p2 = Image.new("P", im.size); p2.putpalette(pal[:93] + [170, 170, 170]); p2.frombytes(bytes(idx))
p2.convert("RGB").save(f"{outdir}/about_preview_32.png")
print("size", W, H)
