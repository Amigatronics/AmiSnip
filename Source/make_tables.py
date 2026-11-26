#!/usr/bin/env python3
"""Generate constant tables (tables.i) for the JPEG, PNG/deflate and GIF encoders."""
import math, sys

out = []
def words(label, vals, per=8):
    out.append(f"{label}:")
    for i in range(0, len(vals), per):
        out.append("        dc.w    " + ",".join(str(v) for v in vals[i:i + per]))
def bytes_(label, vals, per=16):
    out.append(f"{label}:")
    for i in range(0, len(vals), per):
        out.append("        dc.b    " + ",".join(str(v & 255) for v in vals[i:i + per]))

# ---- JPEG ----------------------------------------------------------
M = []
for u in range(8):
    cu = 1 / math.sqrt(2) if u == 0 else 1.0
    for x in range(8):
        M.append(round(4096 * cu / 2 * math.cos((2 * x + 1) * u * math.pi / 16)))
words("DCTM", M)

zz = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
      41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15,
      23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63]
bytes_("ZigZag", zz)

lumq = [16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, 14, 13, 16, 24, 40,
        57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62, 18, 22, 37, 56, 68, 109, 103, 77, 24, 35,
        55, 64, 81, 104, 113, 92, 49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112,
        100, 103, 99]
chrq = [17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, 24, 26, 56, 99, 99,
        99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99] + [99] * 32
bytes_("StdLumQ", lumq)
bytes_("StdChrQ", chrq)

dc_l_bits = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
dc_l_vals = list(range(12))
dc_c_bits = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
dc_c_vals = list(range(12))
ac_l_bits = [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d]
ac_l_vals = [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
    0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
    0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
    0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
    0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
    0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa]
ac_c_bits = [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77]
ac_c_vals = [
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
    0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
    0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
    0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
    0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
    0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
    0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
    0xf9, 0xfa]

def derive(bits, vals):
    code, k, co, si = 0, 0, [0] * 256, [0] * 256
    for l in range(1, 17):
        for _ in range(bits[l - 1]):
            co[vals[k]] = code; si[vals[k]] = l; code += 1; k += 1
        code <<= 1
    return co, si

dht = []
for cls, tid, b, v in [(0, 0, dc_l_bits, dc_l_vals), (1, 0, ac_l_bits, ac_l_vals),
                       (0, 1, dc_c_bits, dc_c_vals), (1, 1, ac_c_bits, ac_c_vals)]:
    dht += [(cls << 4) | tid] + b + v
seglen = 2 + len(dht)
bytes_("DHTSeg", [0xFF, 0xC4, seglen >> 8, seglen & 255] + dht)
out.append(f"DHTSEGLEN equ {seglen + 2}")
for name, b, v in [("DCL", dc_l_bits, dc_l_vals), ("ACL", ac_l_bits, ac_l_vals),
                   ("DCC", dc_c_bits, dc_c_vals), ("ACC", ac_c_bits, ac_c_vals)]:
    co, si = derive(b, v)
    words(name + "Code", co)
    bytes_(name + "Size", si)

# ---- deflate (fixed Huffman) ----------------------------------------
def rev(c, n):
    r = 0
    for _ in range(n):
        r = (r << 1) | (c & 1); c >>= 1
    return r
lc, ll = [], []
for s in range(288):
    if s < 144: c, n = 0x30 + s, 8
    elif s < 256: c, n = 0x190 + s - 144, 9
    elif s < 280: c, n = s - 256, 7
    else: c, n = 0xC0 + s - 280, 8
    lc.append(rev(c, n)); ll.append(n)
words("LitCode", lc)
bytes_("LitLen", ll)
lbase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99,
         115, 131, 163, 195, 227, 258]
lext = [0] * 8 + [1] * 4 + [2] * 4 + [3] * 4 + [4] * 4 + [5] * 4 + [0]
# length -> code index (0..28), for lengths 0..258
lsym = [0] * 259
for i in range(29):
    top = lbase[i + 1] if i < 28 else 259
    if i == 27: top = 258
    for L in range(lbase[i], top):
        lsym[L] = i
lsym[258] = 28
bytes_("LenSym", lsym)
words("LenBase", lbase)
bytes_("LenExtra", lext)
dbase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025,
         1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
dext = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12,
        13, 13]
words("DistBase", dbase)
bytes_("DistExtra", dext)
bytes_("DistCode", [rev(i, 5) for i in range(30)])
# distance -> code for d=1..512 via (d-1) and for larger via (d-1)>>7 (zlib style)
dcode = []
for d in range(1, 513):
    i = max(k for k in range(30) if dbase[k] <= d); dcode.append(i)
bytes_("DistLo", dcode)
dhi = []
for k in range(256):
    d = (k << 7) + 1
    i = max(j for j in range(30) if dbase[j] <= d); dhi.append(i)
bytes_("DistHi", dhi)

# ---- dithering ------------------------------------------------------
bytes_("Bayer4", [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5])

out.append("        even")
open(sys.argv[1], "w").write("\n".join(out) + "\n")

# sanity: DCT round trip with the integer matrix
import random
blk = [random.randint(-128, 127) for _ in range(64)]
tmp = [0] * 64
for y in range(8):
    for u in range(8):
        s = sum(M[u * 8 + x] * blk[y * 8 + x] for x in range(8))
        tmp[y * 8 + u] = (s + 256) >> 9
coef = [0] * 64
for u in range(8):
    for v in range(8):
        s = sum(M[v * 8 + y] * tmp[y * 8 + u] for y in range(8))
        coef[v * 8 + u] = (s + (1 << 14)) >> 15
ref = [0] * 64
for v in range(8):
    for u in range(8):
        cu = 1 / math.sqrt(2) if u == 0 else 1; cv = 1 / math.sqrt(2) if v == 0 else 1
        ref[v * 8 + u] = 0.25 * cu * cv * sum(blk[y * 8 + x] * math.cos((2 * x + 1) * u * math.pi / 16)
                                             * math.cos((2 * y + 1) * v * math.pi / 16)
                                             for y in range(8) for x in range(8))
print("max DCT error:", max(abs(coef[i] - ref[i]) for i in range(64)))
# DistLo/DistHi check
for d in range(1, 32769):
    i = dcode[d - 1] if d <= 512 else dhi[(d - 1) >> 7]
    assert dbase[i] <= d and (i == 29 or dbase[i + 1] > d), d
print("tables ok")
