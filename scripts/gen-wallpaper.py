#!/usr/bin/env python3
"""Generate the catalyst synthwave wallpaper — sun over a neon grid.

Pure stdlib (zlib + struct): no PIL, no dependencies, deterministic.
The wallpaper is committed as *code* — the repo's pre-commit hook blocks
binaries >1MB, and a generator beats a blob anyway.

  gen-wallpaper.py [out.png] [WxH] [palette] [text]
    palette: 7 comma-separated hex colors —
             deep,mid,glow,sunTop,sunBot,grid,accent
    text:    optional livery title, overlaid below the horizon in
             chrome-split outrun caps with a neon glow
    default: the pink synthwave set (see PALETTE below)
"""
import struct, sys, zlib

W, H = 3456, 2234
OUT = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png"
if len(sys.argv) > 2:
    W, H = (int(x) for x in sys.argv[2].split("x"))

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

PALETTE = "0d0221,2b0c4a,ff2e97,ffef00,ff2e97,ff2e97,5ee7ff"
if len(sys.argv) > 3:
    PALETTE = sys.argv[3]
DEEP, MID, GLOW, SUN_TOP, SUN_BOT, GRIDC, ACCENT = (hex2rgb(c) for c in PALETTE.split(","))

HORIZON = int(H * 0.62)
CX, CR = W // 2, int(H * 0.26)          # sun center-x, radius
CY = HORIZON - int(CR * 0.35)           # sun sits low, clipped by horizon

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ── livery title ─────────────────────────────────────────────────────────────
# Hand-authored 5x7 blockface (caps + digits). Text renders in outrun chrome:
# sunTop above the split line, sunBot below, an accent scanline at the split,
# and a dilated glow ring in the glow color. Pure pixels, zero dependencies.
TEXT = sys.argv[4].upper() if len(sys.argv) > 4 else ""

FONT = {  # each glyph: 7 rows x 5 cols, '#' = pixel
 "A": ["01110","10001","10001","11111","10001","10001","10001"],
 "B": ["11110","10001","10001","11110","10001","10001","11110"],
 "C": ["01111","10000","10000","10000","10000","10000","01111"],
 "D": ["11110","10001","10001","10001","10001","10001","11110"],
 "E": ["11111","10000","10000","11110","10000","10000","11111"],
 "F": ["11111","10000","10000","11110","10000","10000","10000"],
 "G": ["01111","10000","10000","10111","10001","10001","01111"],
 "H": ["10001","10001","10001","11111","10001","10001","10001"],
 "I": ["11111","00100","00100","00100","00100","00100","11111"],
 "J": ["00111","00010","00010","00010","00010","10010","01100"],
 "K": ["10001","10010","10100","11000","10100","10010","10001"],
 "L": ["10000","10000","10000","10000","10000","10000","11111"],
 "M": ["10001","11011","10101","10101","10001","10001","10001"],
 "N": ["10001","11001","10101","10011","10001","10001","10001"],
 "O": ["01110","10001","10001","10001","10001","10001","01110"],
 "P": ["11110","10001","10001","11110","10000","10000","10000"],
 "Q": ["01110","10001","10001","10001","10101","10010","01101"],
 "R": ["11110","10001","10001","11110","10100","10010","10001"],
 "S": ["01111","10000","10000","01110","00001","00001","11110"],
 "T": ["11111","00100","00100","00100","00100","00100","00100"],
 "U": ["10001","10001","10001","10001","10001","10001","01110"],
 "V": ["10001","10001","10001","10001","10001","01010","00100"],
 "W": ["10001","10001","10001","10101","10101","11011","10001"],
 "X": ["10001","01010","00100","00100","00100","01010","10001"],
 "Y": ["10001","01010","00100","00100","00100","00100","00100"],
 "Z": ["11111","00001","00010","00100","01000","10000","11111"],
 "0": ["01110","10001","10011","10101","11001","10001","01110"],
 "1": ["00100","01100","00100","00100","00100","00100","01110"],
 "2": ["01110","10001","00001","00110","01000","10000","11111"],
 "3": ["11110","00001","00001","01110","00001","00001","11110"],
 "4": ["00010","00110","01010","10010","11111","00010","00010"],
 "5": ["11111","10000","11110","00001","00001","10001","01110"],
 "6": ["01110","10000","11110","10001","10001","10001","01110"],
 "7": ["11111","00001","00010","00100","01000","01000","01000"],
 "8": ["01110","10001","10001","01110","10001","10001","01110"],
 "9": ["01110","10001","10001","01111","00001","00001","01110"],
 "-": ["00000","00000","00000","11111","00000","00000","00000"],
 ".": ["00000","00000","00000","00000","00000","00110","00110"],
 " ": ["00000","00000","00000","00000","00000","00000","00000"],
}

text_px, glow_px = {}, {}     # y -> set(x)
TXT_TOP = TXT_BOT = 0
if TEXT:
    scale = max(2, H // 110)                    # commanding, not shy
    gw = 6 * scale                              # 5 cols + 1 gap
    total_w = len(TEXT) * gw - scale
    x0 = (W - total_w) // 2
    y0 = HORIZON + int((H - HORIZON) * 0.32) - (7 * scale) // 2
    TXT_TOP, TXT_BOT = y0, y0 + 7 * scale
    d = max(1, scale // 2)                      # glow dilation radius

    def fill(rows_map, rx, ry, rw, rh):
        for yy in range(ry, ry + rh):
            rows_map.setdefault(yy, set()).update(range(rx, rx + rw))

    # Rect-level rasterization: one filled rect per lit glyph CELL, and one
    # d-expanded rect for its glow. O(cells), not O(pixels x radius^2) —
    # the per-pixel version cost ~30M set-inserts at full resolution.
    for i, ch in enumerate(TEXT):
        glyph = FONT.get(ch, FONT[" "])
        for gy, grow in enumerate(glyph):
            for gx, bit in enumerate(grow):
                if bit == "1":
                    cx0 = x0 + i * gw + gx * scale
                    cy0 = y0 + gy * scale
                    fill(text_px, cx0, cy0, scale, scale)
                    fill(glow_px, cx0 - d, cy0 - d, scale + 2 * d, scale + 2 * d)

def overlay(x, y, r, g, b):
    """Chrome-split title + glow, applied over any background pixel."""
    tp = text_px.get(y)
    if tp and x in tp:
        ty = (y - TXT_TOP) / max(1, TXT_BOT - TXT_TOP)
        if abs(ty - 0.52) < 0.05:
            return ACCENT                       # scanline at the chrome split
        return SUN_TOP if ty < 0.52 else SUN_BOT
    gp = glow_px.get(y)
    if gp and x in gp:
        return lerp((r, g, b), GLOW, 0.55)
    return (r, g, b)

rows = []
for y in range(H):
    row = bytearray()
    if y < HORIZON:
        # sky: deep -> violet -> pink glow at horizon
        t = y / HORIZON
        sky = lerp(DEEP, MID, t) if t < 0.7 else lerp(MID, GLOW, (t - 0.7) / 0.3 * 0.55)
        # deterministic star field (hash-based, upper sky only)
        for x in range(W):
            r, g, b = sky
            dx, dy = x - CX, y - CY
            d2 = dx * dx + dy * dy
            if d2 < CR * CR:
                # sun with the classic horizontal cut lines, denser near bottom
                sy = (y - (CY - CR)) / (2 * CR)
                gap = int(6 + 26 * sy)
                if sy < 0.45 or ((y % gap) > max(2, int(gap * 0.35))):
                    r, g, b = lerp(SUN_TOP, SUN_BOT, sy)
            elif d2 < CR * CR * 2.4:
                # glow falloff around the sun
                gt = (d2 / (CR * CR) - 1) / 1.4
                r, g, b = lerp(lerp(SUN_BOT, sky, 0.5), sky, min(1.0, gt))
            elif y < HORIZON * 0.75 and (x * 2654435761 ^ y * 40503) % 9973 < 2:
                r, g, b = (200, 220, 255)
            row += bytes((r, g, b))
    else:
        # floor: perspective grid racing to the horizon
        t = (y - HORIZON) / (H - HORIZON)          # 0 at horizon -> 1 at bottom
        base = lerp(lerp(MID, DEEP, 0.55), DEEP, t)
        if t < 0.05:
            base = lerp(GLOW, base, 0.55 + 9.0 * t)
        # horizontal lines: spacing grows with distance from horizon
        z = 1.0 / (t + 0.02)
        # haze band at the horizon: grid lines alias into noise at tiny
        # depth, so fade them out entirely for the first few percent.
        haze = t < 0.05
        hline = (not haze) and (int(z * 26) % 24) < 2
        for x in range(W):
            r, g, b = base
            # vertical lines converge on the vanishing point (CX, HORIZON):
            # project screen x into "floor space" — equal spacing there fans
            # out on screen as t (depth toward viewer) grows.
            v = abs(x - CX) / (t + 0.045)
            vline = (not haze) and (int(v) % 420) < 6
            if hline or vline:
                glow = 0.85 if hline else 0.7
                c = GRIDC if (x + y) % 97 else ACCENT
                r, g, b = lerp(base, c, glow * (0.35 + 0.65 * t))
            if TEXT:
                r, g, b = overlay(x, y, r, g, b)
            row += bytes((r, g, b))
    rows.append(bytes(row))

raw = b"".join(b"\x00" + r for r in rows)

def chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))

with open(OUT, "wb") as f:
    f.write(png)
print(f"wrote {OUT} ({W}x{H}, {len(png)//1024}KB)")
