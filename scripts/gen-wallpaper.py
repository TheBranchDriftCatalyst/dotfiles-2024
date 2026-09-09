#!/usr/bin/env python3
"""Generate the catalyst synthwave wallpaper — sun over a neon grid.

Pure stdlib (zlib + struct): no PIL, no dependencies, deterministic.
The wallpaper is committed as *code* — the repo's pre-commit hook blocks
binaries >1MB, and a generator beats a blob anyway.

  gen-wallpaper.py [out.png] [WxH]     default: wallpaper.png 3456x2234
"""
import struct, sys, zlib

W, H = 3456, 2234
OUT = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png"
if len(sys.argv) > 2:
    W, H = (int(x) for x in sys.argv[2].split("x"))

HORIZON = int(H * 0.62)
CX, CR = W // 2, int(H * 0.26)          # sun center-x, radius
CY = HORIZON - int(CR * 0.35)           # sun sits low, clipped by horizon

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# palette — same neons as ghostty/starship
DEEP    = (13, 2, 33)      # #0d0221
VIOLET  = (43, 12, 74)
PINK    = (255, 46, 151)   # #ff2e97
SUN_TOP = (255, 239, 0)    # #ffef00
SUN_BOT = (255, 46, 151)
GRIDC   = (255, 46, 151)
CYAN    = (94, 231, 255)   # #5ee7ff

rows = []
for y in range(H):
    row = bytearray()
    if y < HORIZON:
        # sky: deep -> violet -> pink glow at horizon
        t = y / HORIZON
        sky = lerp(DEEP, VIOLET, t) if t < 0.7 else lerp(VIOLET, PINK, (t - 0.7) / 0.3 * 0.55)
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
        base = lerp((26, 4, 46), DEEP, t)
        if t < 0.05:
            base = lerp(PINK, base, 0.55 + 9.0 * t)
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
                c = GRIDC if (x + y) % 97 else CYAN
                r, g, b = lerp(base, c, glow * (0.35 + 0.65 * t))
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
