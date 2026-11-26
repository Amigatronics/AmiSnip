#!/usr/bin/env python3
"""Build all AmiSnip icons (OS 2/3 style, 4 colours: grey, black, white, blue)."""
import struct, sys, os
from PIL import Image

PAL = [(170, 170, 170), (0, 0, 0), (255, 255, 255), (102, 136, 187)]
WBTOOL, WBPROJECT, WBDRAWER = 3, 4, 2


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[0] * w for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def box(self, x0, y0, x1, y1, c):
        for x in range(x0, x1 + 1):
            self.px(x, y0, c); self.px(x, y1, c)
        for y in range(y0, y1 + 1):
            self.px(x0, y, c); self.px(x1, y, c)

    def planes(self):
        rb = ((self.w + 15) // 16) * 2
        out = b""
        for p in range(2):
            for y in range(self.h):
                row = bytearray(rb)
                for x in range(self.w):
                    if (self.p[y][x] >> p) & 1:
                        row[x // 8] |= 0x80 >> (x % 8)
                out += bytes(row)
        return out

    def preview(self, path):
        im = Image.new("RGB", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                im.putpixel((x, y), PAL[self.p[y][x]])
        im.resize((self.w * 6, self.h * 6), Image.NEAREST).save(path)


def snip_frame(c, x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        if (x - x0) % 4 < 2:
            c.px(x, y0, 1); c.px(x, y1, 1)
    for y in range(y0, y1 + 1):
        if (y - y0) % 4 < 2:
            c.px(x0, y, 1); c.px(x1, y, 1)
    xm, ym = (x0 + x1) // 2, (y0 + y1) // 2
    for cx, cy in [(x0, y0), (x1, y0), (x0, y1), (x1, y1), (xm, y0), (xm, y1), (x0, ym), (x1, ym)]:
        c.rect(cx - 1, cy - 1, cx + 1, cy + 1, 1)
        c.px(cx, cy, 2)


def icon_commodity():
    c = Canvas(40, 22)
    c.rect(4, 3, 35, 18, 3)
    c.rect(8, 6, 17, 9, 2)
    c.rect(20, 11, 30, 15, 2)
    snip_frame(c, 6, 4, 33, 17)
    return c


def icon_prefs():
    c = Canvas(40, 22)
    c.rect(3, 2, 36, 19, 2)
    c.box(3, 2, 36, 19, 1)
    for i, k in enumerate([24, 12, 30]):
        y = 6 + i * 5
        c.rect(7, y, 32, y, 1)
        c.rect(k - 1, y - 2, k + 1, y + 2, 3)
        c.box(k - 1, y - 2, k + 1, y + 2, 1)
    return c


def icon_install():
    c = Canvas(40, 22)
    c.rect(6, 13, 33, 19, 3)
    c.box(6, 13, 33, 19, 1)
    c.rect(10, 15, 29, 16, 1)
    for y in range(1, 9):
        c.rect(18, y, 21, y, 1)
    for i in range(5):
        c.rect(15 + i, 9 + i, 24 - i, 9 + i, 1)
    c.px(19, 13, 2); c.px(20, 13, 2)
    return c


def icon_readme():
    c = Canvas(30, 24)
    c.rect(6, 1, 23, 22, 2)
    c.box(6, 1, 23, 22, 1)
    for y in range(4, 20, 3):
        c.rect(9, y, 20 if y % 2 else 17, y, 3)
    return c


def icon_drawer():
    c = Canvas(44, 22)
    c.rect(4, 4, 39, 19, 3)
    c.box(4, 4, 39, 19, 1)
    c.rect(4, 4, 39, 6, 1)
    c.rect(15, 11, 28, 13, 2)
    c.box(15, 11, 28, 13, 1)
    snip_frame(c, 8, 8, 35, 17)
    return c


def diskobject(c, typ, tooltypes=None, default_tool=None, stack=8192, drawer=False):
    out = bytearray()
    out += struct.pack(">HH", 0xE310, 1)
    out += struct.pack(">LhhhhHHHLLLLLHL",
                       0, 0, 0, c.w, c.h + 1, 4, 3, 1, 1, 0, 0, 0, 0, 0, 1)
    out += struct.pack(">BB", typ, 0)
    out += struct.pack(">LL", 1 if default_tool else 0, 1 if tooltypes else 0)
    out += struct.pack(">ll", -0x80000000, -0x80000000)
    out += struct.pack(">LLL", 1 if drawer else 0, 0, stack)
    assert len(out) == 78
    if drawer:
        # OldDrawerData: NewWindow (48) + CurrentX/Y
        out += struct.pack(">hhhhBBLLLLLLLhhHHH",
                           60, 40, 420, 160, 255, 255, 0, 0,
                           0, 0, 0, 0, 0, 90, 40, 0xFFFF, 0xFFFF, 1)
        out += struct.pack(">ll", 0, 0)
    out += struct.pack(">hhhhhLBBL", 0, 0, c.w, c.h, 2, 1, 3, 0, 0)
    out += c.planes()
    if default_tool:
        b = default_tool.encode("latin-1") + b"\0"
        out += struct.pack(">L", len(b)) + b
    if tooltypes:
        out += struct.pack(">L", (len(tooltypes) + 1) * 4)
        for t in tooltypes:
            b = t.encode("latin-1") + b"\0"
            out += struct.pack(">L", len(b)) + b
    if drawer:
        out += struct.pack(">LH", 0, 0)      # DrawerData2: flags, viewmodes
    return bytes(out)


def main(dest, prev):
    os.makedirs(prev, exist_ok=True)
    icons = {
        "AmiSnip.info": (icon_commodity(), WBTOOL,
                         ["DONOTWAIT", "CX_PRIORITY=0"], None, False),
        "AmiSnipPrefs.info": (icon_prefs(), WBTOOL, None, None, False),
        "Install-AmiSnip.info": (icon_install(), WBPROJECT,
                                 ["APPNAME=AmiSnip", "SCRIPT=Install-AmiSnip",
                                  "MINUSER=AVERAGE", "DEFUSER=AVERAGE"], "Installer", False),
        "AmiSnip.readme.info": (icon_readme(), WBPROJECT, None, "SYS:Utilities/MultiView", False),
        "drawer.info": (icon_drawer(), WBDRAWER, None, None, True),
    }
    for name, (c, typ, tt, dt, drw) in icons.items():
        open(os.path.join(dest, name), "wb").write(
            diskobject(c, typ, tt, dt, drawer=drw))
        c.preview(os.path.join(prev, name.replace(".info", ".png")))
    print("ok")


main(sys.argv[1], sys.argv[2])
