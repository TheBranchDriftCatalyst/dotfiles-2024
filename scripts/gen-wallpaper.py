#!/usr/bin/env python3
"""Generate the catalyst synthwave wallpaper — sun over a neon grid.

Pure stdlib (zlib + struct): no PIL, no dependencies, deterministic.
The wallpaper is committed as *code* — the repo's pre-commit hook blocks
binaries >1MB, and a generator beats a blob anyway.

  gen-wallpaper.py [out.png] [WxH] [palette]
    palette: 7 comma-separated hex colors —
             deep,mid,glow,sunTop,sunBot,grid,accent
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
