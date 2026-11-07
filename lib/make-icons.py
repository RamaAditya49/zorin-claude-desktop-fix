#!/usr/bin/env python3
"""Make one coloured icon for each Claude Desktop profile.

Usage: make-icons.py <out-hicolor-dir> <N> [N...]

The script reads the Claude icon that the user already has installed.
It shifts the hue of every coloured pixel to the colour of the profile.
It writes <out>/<S>x<S>/apps/claude-profile-N.png.
If the script cannot read the icon, it writes <out>/scalable/apps/claude-profile-N.svg.
This is a round badge with the profile number. The script always exits with 0.

Environment:
  CLAUDE_ICON_SOURCE  One PNG file to use for every size.
"""
import colorsys
import os
import struct
import sys
import zlib

SIZES = (16, 24, 32, 48, 64, 128, 256)
HUES = {2: 45, 3: 140, 4: 210, 5: 275, 6: 330, 7: 180, 8: 0, 9: 90}
PNG_SIG = b"\x89PNG\r\n\x1a\n"


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def decode_png(data):
    """Return (width, height, rows of RGBA bytes). Raise ValueError if not supported."""
    if data[:8] != PNG_SIG:
        raise ValueError("not a PNG file")
    pos, idat, ihdr = 8, [], None
    while pos + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if not ihdr:
        raise ValueError("no header")
    w, h, depth, ctype, _, _, interlace = ihdr
    if depth != 8 or ctype not in (2, 6) or interlace != 0:
        raise ValueError("unsupported PNG format")
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    if len(raw) < (stride + 1) * h:
        raise ValueError("short image data")
    rows, prev = [], bytearray(stride)
    for y in range(h):
        base = y * (stride + 1)
        ft = raw[base]
        line = bytearray(raw[base + 1:base + 1 + stride])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ft == 1:
                line[i] = (line[i] + a) & 255
            elif ft == 2:
                line[i] = (line[i] + b) & 255
            elif ft == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif ft == 4:
                line[i] = (line[i] + paeth(a, b, c)) & 255
            elif ft != 0:
                raise ValueError("bad filter")
        prev = line
        if bpp == 3:
            rgba = bytearray(w * 4)
            for x in range(w):
                rgba[x * 4:x * 4 + 3] = line[x * 3:x * 3 + 3]
                rgba[x * 4 + 3] = 255
            rows.append(rgba)
        else:
            rows.append(line)
    return w, h, rows


def encode_png(w, h, rows):
    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    return (PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def recolour(rows, hue):
    """Set the hue of every pixel with saturation above 0.15. Keep lightness and saturation."""
    out = []
    for row in rows:
        new = bytearray(row)
        for i in range(0, len(new), 4):
            r, g, b = new[i] / 255, new[i + 1] / 255, new[i + 2] / 255
            hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
            if ss > 0.15:
                r, g, b = colorsys.hls_to_rgb(hue / 360, ll, ss)
                new[i], new[i + 1], new[i + 2] = round(r * 255), round(g * 255), round(b * 255)
        out.append(new)
    return out


def source_icons():
    """Return {size: path} of the installed Claude icon."""
    one = os.environ.get("CLAUDE_ICON_SOURCE")
    if one:
        return {s: one for s in SIZES}
    found = {}
    dirs = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    for s in SIZES:
        for d in dirs:
            p = os.path.join(d, "icons", "hicolor", f"{s}x{s}", "apps", "claude-desktop.png")
            if d and os.path.isfile(p):
                found[s] = p
                break
    return found


def write_svg(out, n):
    hue = HUES.get(n, 20)
    r, g, b = colorsys.hls_to_rgb(hue / 360, 0.45, 0.65)
    colour = "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n'
           f'  <rect width="256" height="256" rx="56" fill="{colour}"/>\n'
           '  <text x="128" y="128" font-family="sans-serif" font-size="150" font-weight="bold" '
           f'fill="#ffffff" text-anchor="middle" dominant-baseline="central">{n}</text>\n'
           '</svg>\n')
    d = os.path.join(out, "scalable", "apps")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, f"claude-profile-{n}.svg"), "w") as f:
        f.write(svg)


def main():
    if len(sys.argv) < 3:
        sys.stderr.write("usage: make-icons.py <out-hicolor-dir> <N> [N...]\n")
        return 2
    out = sys.argv[1]
    try:
        profiles = [int(a) for a in sys.argv[2:]]
    except ValueError:
        sys.stderr.write("profile numbers must be integers\n")
        return 2
    decoded = {}
    try:
        for size, path in source_icons().items():
            with open(path, "rb") as f:
                decoded[size] = decode_png(f.read())
        if not decoded:
            raise ValueError("no Claude icon found")
    except Exception as e:
        decoded = {}
        reason = str(e) or type(e).__name__
    if decoded:
        for n in profiles:
            for size, (w, h, rows) in decoded.items():
                d = os.path.join(out, f"{size}x{size}", "apps")
                os.makedirs(d, exist_ok=True)
                with open(os.path.join(d, f"claude-profile-{n}.png"), "wb") as f:
                    f.write(encode_png(w, h, recolour(rows, HUES.get(n, 20))))
        print(f"icons: recoloured the installed Claude icon ({len(decoded)} sizes)")
    else:
        for n in profiles:
            write_svg(out, n)
        print(f"icons: made number badges (SVG), because the Claude icon could not be used ({reason})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
