#!/usr/bin/env python3
"""Minimal LHA archiver: -lh5- compression, level-1 headers (OS 'A'),
plus a verifying decoder.  Usage: mklha.py archive.lha root_dir entry..."""
import os, sys, time, struct, heapq

DICBIT, DICSIZ, MAXMATCH, THRESHOLD = 13, 1 << 13, 256, 3
NC, CBIT, NP, PBIT, NT, TBIT = 510, 9, 14, 4, 19, 5

# ------------------------------------------------------------------ CRC16
CRCT = []
for i in range(256):
    c = i
    for _ in range(8):
        c = (c >> 1) ^ 0xA001 if c & 1 else c >> 1
    CRCT.append(c)
def crc16(data):
    c = 0
    for b in data:
        c = CRCT[(c ^ b) & 0xFF] ^ (c >> 8)
    return c

# ------------------------------------------------------------ bit writer
class BW:
    def __init__(self): self.out, self.acc, self.n = bytearray(), 0, 0
    def put(self, n, v):
        if n == 0: return
        assert 0 <= v < (1 << n)
        self.acc = (self.acc << n) | v; self.n += n
        while self.n >= 8:
            self.n -= 8; self.out.append((self.acc >> self.n) & 255)
        self.acc &= (1 << self.n) - 1
    def flush(self):
        if self.n: self.out.append((self.acc << (8 - self.n)) & 255)
        self.n = 0; return bytes(self.out)

# ---------------------------------------------------- Huffman lengths
def lengths(freq, maxlen=16):
    syms = [i for i, f in enumerate(freq) if f]
    L = [0] * len(freq)
    if len(syms) < 2:
        return L, (syms[0] if syms else 0)
    # package-merge for length-limited optimal codes
    items = sorted((freq[s], [s]) for s in syms)
    cur = list(items)
    for _ in range(maxlen - 1):
        pk = [(cur[i][0] + cur[i + 1][0], cur[i][1] + cur[i + 1][1])
              for i in range(0, len(cur) - 1, 2)]
        cur = sorted(items + pk, key=lambda t: t[0])
    for w, ss in cur[:2 * len(syms) - 2]:
        for s in ss: L[s] += 1
    assert sum(2.0 ** -L[s] for s in syms) == 1.0
    return L, None

def codes(L):
    cnt = [0] * 18
    for l in L: cnt[l] += 1
    cnt[0] = 0
    start = [0] * 18
    for i in range(1, 17):
        start[i + 1] = (start[i] + cnt[i]) << 1
    C = [0] * len(L)
    for s, l in enumerate(L):
        if l: C[s] = start[l]; start[l] += 1
    return C

# ------------------------------------------------------------ encoder
def lzss(data):
    """yield ('L', byte) or ('M', length, distance)"""
    head, prev = {}, [0] * len(data)
    i, n = 0, len(data)
    def ins(p):
        if p + 2 < n:
            k = data[p:p + 3]
            prev[p] = head.get(k, -1); head[k] = p
    while i < n:
        best, bd = 0, 0
        if i + 2 < n:
            c = head.get(data[i:i + 3], -1); depth = 128
            maxl = min(MAXMATCH, n - i)
            while c >= 0 and i - c <= DICSIZ and depth:
                if data[c + best:c + best + 1] == data[i + best:i + best + 1]:
                    l = 0
                    while l < maxl and data[c + l] == data[i + l]: l += 1
                    if l > best:
                        best, bd = l, i - c
                        if l == maxl: break
                c = prev[c]; depth -= 1
        if best >= THRESHOLD:
            yield ('M', best, bd)
            for p in range(i, i + best): ins(p)
            i += best
        else:
            yield ('L', data[i]); ins(i); i += 1

def plen(p):
    c = 0
    while p: p >>= 1; c += 1
    return c

def send_block(bw, syms):
    cf, pf = [0] * NC, [0] * NP
    for s in syms:
        cf[s[0]] += 1
        if s[0] >= 256: pf[plen(s[1])] += 1
    bw.put(16, len(syms))
    cl, cone = lengths(cf)
    if cone is None:
        # temp tree for c_len
        n = NC
        while n > 0 and cl[n - 1] == 0: n -= 1
        tf = [0] * NT; i = 0
        while i < n:
            k = cl[i]; i += 1
            if k == 0:
                cnt = 1
                while i < n and cl[i] == 0: i += 1; cnt += 1
                if cnt <= 2: tf[0] += cnt
                elif cnt <= 18: tf[1] += 1
                elif cnt == 19: tf[0] += 1; tf[1] += 1
                else: tf[2] += 1
            else: tf[k + 2] += 1
        tl, tone = lengths(tf)
        if tone is None:
            write_pt_len(bw, tl, NT, TBIT, 3)
            tc = codes(tl)
        else:
            bw.put(TBIT, 0); bw.put(TBIT, tone); tl = [0] * NT; tc = [0] * NT
        # write c_len
        bw.put(CBIT, n); i = 0
        while i < n:
            k = cl[i]; i += 1
            if k == 0:
                cnt = 1
                while i < n and cl[i] == 0: i += 1; cnt += 1
                if cnt <= 2:
                    for _ in range(cnt): bw.put(tl[0], tc[0])
                elif cnt <= 18:
                    bw.put(tl[1], tc[1]); bw.put(4, cnt - 3)
                elif cnt == 19:
                    bw.put(tl[0], tc[0]); bw.put(tl[1], tc[1]); bw.put(4, 15)
                else:
                    bw.put(tl[2], tc[2]); bw.put(CBIT, cnt - 20)
            else:
                bw.put(tl[k + 2], tc[k + 2])
        cc = codes(cl)
    else:
        bw.put(TBIT, 0); bw.put(TBIT, 0); bw.put(CBIT, 0); bw.put(CBIT, cone)
        cl, cc = [0] * NC, [0] * NC
    pl, pone = lengths(pf)
    if pone is None:
        write_pt_len(bw, pl, NP, PBIT, -1); pc = codes(pl)
    else:
        bw.put(PBIT, 0); bw.put(PBIT, pone); pl, pc = [0] * NP, [0] * NP
    for s in syms:
        bw.put(cl[s[0]], cc[s[0]])
        if s[0] >= 256:
            p = s[1]; c = plen(p)
            bw.put(pl[c], pc[c])
            if c > 1: bw.put(c - 1, p & ((1 << (c - 1)) - 1))

def write_pt_len(bw, L, nn, nbit, special):
    n = nn
    while n > 0 and L[n - 1] == 0: n -= 1
    bw.put(nbit, n); i = 0
    while i < n:
        k = L[i]; i += 1
        if k <= 6: bw.put(3, k)
        else: bw.put(k - 3, (1 << (k - 3)) - 2)
        if i == special:
            while i < 6 and L[i] == 0: i += 1
            bw.put(2, (i - 3) & 3)

def lh5_encode(data):
    bw, blk = BW(), []
    for t in lzss(data):
        blk.append((t[1], 0) if t[0] == 'L' else (t[1] - THRESHOLD + 256, t[2] - 1))
        if len(blk) == 16384:
            send_block(bw, blk); blk = []
    if blk: send_block(bw, blk)
    return bw.flush()

# ------------------------------------------------------------ decoder
class BR:
    def __init__(self, d): self.d, self.pos = d, 0
    def bit(self):
        b = (self.d[self.pos >> 3] >> (7 - (self.pos & 7))) & 1 if (self.pos >> 3) < len(self.d) else 0
        self.pos += 1; return b
    def get(self, n):
        v = 0
        for _ in range(n): v = (v << 1) | self.bit()
        return v

def mkdec(L):
    C = codes(L); return {(L[s], C[s]): s for s in range(len(L)) if L[s]}

def rdsym(br, dec, one):
    if one is not None: return one
    v = l = 0
    while True:
        v = (v << 1) | br.bit(); l += 1
        if (l, v) in dec: return dec[(l, v)]
        assert l <= 16, "bad code"

def read_pt_len(br, nn, nbit, special):
    n = br.get(nbit)
    if n == 0:
        return [0] * nn, br.get(nbit)
    L, i = [0] * nn, 0
    while i < n:
        c = br.get(3)
        if c == 7:
            while br.bit(): c += 1
        L[i] = c; i += 1
        if i == special:
            z = br.get(2)
            for _ in range(z): L[i] = 0; i += 1
    return L, None

def lh5_decode(comp, size):
    br, out = BR(comp), bytearray()
    while len(out) < size:
        bs = br.get(16)
        tl, tone = read_pt_len(br, NT, TBIT, 3)
        tdec = mkdec(tl) if tone is None else None
        n = br.get(CBIT)
        if n == 0:
            cone, cl = br.get(CBIT), [0] * NC
        else:
            cone, cl, i = None, [0] * NC, 0
            while i < n:
                c = rdsym(br, tdec, tone)
                if c <= 2:
                    c = 1 if c == 0 else (br.get(4) + 3 if c == 1 else br.get(CBIT) + 20)
                    i += c
                else:
                    cl[i] = c - 2; i += 1
        cdec = mkdec(cl) if cone is None else None
        pl, pone = read_pt_len(br, NP, PBIT, -1)
        pdec = mkdec(pl) if pone is None else None
        for _ in range(bs):
            c = rdsym(br, cdec, cone)
            if c < 256: out.append(c)
            else:
                ln = c - 256 + THRESHOLD
                j = rdsym(br, pdec, pone)
                if j: j = (1 << (j - 1)) + br.get(j - 1)
                st = len(out) - j - 1
                for k in range(ln): out.append(out[st + k])
    return bytes(out[:size])

# ------------------------------------------------------------ archive
def dostime(t):
    lt = time.localtime(t)
    return ((lt.tm_year - 1980) << 25) | (lt.tm_mon << 21) | (lt.tm_mday << 16) | \
        (lt.tm_hour << 11) | (lt.tm_min << 5) | (lt.tm_sec // 2)

def header(name, dirpart, method, csize, osize, mtime, crc):
    nm = name.encode("latin-1")
    ext = b""
    if dirpart:
        d = dirpart.replace("/", "\xff").encode("latin-1") + b"\xff"
        ext = bytes([0x02]) + d
        ext = struct.pack("<H", len(ext) + 2)[:0] + ext  # size added below
    exts = []
    if dirpart:
        body = bytes([0x02]) + dirpart.replace("/", "\xff").encode("latin-1") + b"\xff"
        exts.append(body)
    extbytes = b""
    sizes = [len(e) + 2 for e in exts]
    # next-size field after the base header points at the first ext header
    first = sizes[0] if sizes else 0
    for k, e in enumerate(exts):
        nxt = sizes[k + 1] if k + 1 < len(exts) else 0
        extbytes += e + struct.pack("<H", nxt)
    base = method + struct.pack("<LLLBB", csize + len(extbytes), osize, mtime, 0x20, 1) \
        + bytes([len(nm)]) + nm + struct.pack("<H", crc) + b"A" + struct.pack("<H", first)
    hdr = bytes([len(base), sum(base) & 255]) + base
    return hdr + extbytes

def build(arc, root, entries):
    out = bytearray(); log = []
    for rel in entries:
        full = os.path.join(root, rel)
        data = open(full, "rb").read()
        dirpart, name = os.path.split(rel)
        comp = lh5_encode(data)
        method = b"-lh5-"
        if len(comp) >= len(data):
            comp, method = data, b"-lh0-"
        else:
            assert lh5_decode(comp, len(data)) == data, rel
        out += header(name, dirpart, method, len(comp), len(data),
                      dostime(os.path.getmtime(full)), crc16(data)) + comp
        log.append((rel, len(data), len(comp), method.decode()))
    out += b"\0"
    open(arc, "wb").write(out)
    return log

def verify(arc, root):
    d = open(arc, "rb").read(); p = 0; n = 0
    while d[p]:
        hs = d[p]; base = d[p:p + 2 + hs]
        assert sum(base[2:]) & 255 == base[1]
        method = base[2:7]
        csize, osize = struct.unpack("<LL", base[7:15])
        nl = base[21]; name = base[22:22 + nl].decode("latin-1")
        crc = struct.unpack("<H", base[22 + nl:24 + nl])[0]
        nxt = struct.unpack("<H", base[25 + nl:27 + nl])[0]
        q = p + 2 + hs; dirp = ""; extlen = 0
        while nxt:
            e = d[q:q + nxt]
            if e[0] == 2: dirp = e[1:-2].decode("latin-1").replace("\xff", "/").rstrip("/")
            extlen += nxt; q += nxt; nxt = struct.unpack("<H", e[-2:])[0]
        comp = d[q:q + csize - extlen]
        data = lh5_decode(comp, osize) if method == b"-lh5-" else comp
        rel = os.path.join(dirp, name)
        assert crc16(data) == crc and data == open(os.path.join(root, rel), "rb").read(), rel
        p = q + csize - extlen; n += 1
    return n

if __name__ == "__main__":
    arc, root = sys.argv[1], sys.argv[2]
    entries = sys.argv[3:]
    for rel, o, c, m in build(arc, root, entries):
        print(f"{m} {o:8d} -> {c:8d}  {rel}")
    print("verified", verify(arc, root), "files,", os.path.getsize(arc), "bytes")
