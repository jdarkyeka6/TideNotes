#!/usr/bin/env python3
"""Generate TideNotes' temporary 1024px App Store icon without external deps."""

from pathlib import Path
import math
import struct
import zlib

SIZE = 1024
OUT = Path("TideNotes/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def rounded_rect(x: int, y: int, left: int, top: int, right: int, bottom: int, radius: int) -> bool:
    if left + radius <= x <= right - radius and top <= y <= bottom:
        return True
    if left <= x <= right and top + radius <= y <= bottom - radius:
        return True

    corners = [
        (left + radius, top + radius),
        (right - radius, top + radius),
        (left + radius, bottom - radius),
        (right - radius, bottom - radius),
    ]
    return any((x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2 for cx, cy in corners)


def pixel(x: int, y: int) -> tuple[int, int, int]:
    # TideNotes red gradient.
    t = y / (SIZE - 1)
    r = int(92 + 76 * t)
    g = int(8 + 10 * t)
    b = int(18 + 14 * t)

    # Soft red glow behind the note.
    glow = max(0.0, 1.0 - math.hypot(x - 512, y - 470) / 520)
    r = min(255, int(r + 36 * glow))
    g = min(255, int(g + 8 * glow))
    b = min(255, int(b + 10 * glow))

    # Paper card.
    if rounded_rect(x, y, 245, 180, 779, 810, 74):
        paper = (246, 250, 255)

        # Folded upper-right corner.
        if x > 650 and y < 315 and (x + y) > 945:
            return (245, 214, 218)

        # Note lines.
        if 340 <= x <= 675:
            if 368 <= y <= 397 or 478 <= y <= 507 or 588 <= y <= 617:
                return (180, 24, 42)

        # Small wave mark near the bottom.
        if 350 <= x <= 674 and 675 <= y <= 725:
            wave_y = 700 + 18 * math.sin((x - 350) / 42)
            if abs(y - wave_y) <= 8:
                return (220, 38, 55)

        return paper

    return (r, g, b)


raw = bytearray()
for y in range(SIZE):
    raw.append(0)
    for x in range(SIZE):
        raw.extend(pixel(x, y))

png = bytearray(b"\x89PNG\r\n\x1a\n")
png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)))
png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
png.extend(chunk(b"IEND", b""))

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_bytes(png)
print(f"Generated {OUT} ({len(png)} bytes)")
