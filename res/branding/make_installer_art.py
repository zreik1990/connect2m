"""connect2m installer artwork.

Renders, from vector drawings, at several Windows display scales:
  side_<pct>.bmp            full welcome/finish sidebar (164x314 at 100%)
  anim_<pct>_<nn>.bmp       animation frames for the icon region of the sidebar
  header_<pct>.bmp          inner-page header image (150x57 at 100%)
plus MSI dialog/banner bitmaps and a preview GIF.

usage: make_installer_art.py <icon.svg-unused> <nsis_art_dir> <msi_dir> <preview_dir>
"""
import io, math, os, sys
import cairosvg
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

_, ART, MSI, PREVIEW = sys.argv[1:5]
for d in (ART, MSI, PREVIEW):
    os.makedirs(d, exist_ok=True)

SCALES = [100, 125, 150, 175, 200]
FRAMES = 24
SW, SH = 164, 314                      # sidebar at 100%
RX0, RY0, RX1, RY1 = 8, 44, 156, 176   # animated region at 100%
BOLD = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
REG = "/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf"
MED = "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf"


def text_path(text, font_file, size, x, y, anchor="middle"):
    f = TTFont(font_file)
    gs, cmap, hmtx = f.getGlyphSet(), f.getBestCmap(), f["hmtx"]
    sc = size / f["head"].unitsPerEm
    width = sum(hmtx[cmap[ord(c)]][0] for c in text) * sc
    cx = x - width / 2 if anchor == "middle" else x
    parts = []
    for ch in text:
        g = cmap[ord(ch)]
        pen = SVGPathPen(gs)
        gs[g].draw(TransformPen(pen, (sc, 0, 0, -sc, cx, y)))
        parts.append(pen.getCommands())
        cx += hmtx[g][0] * sc
    return " ".join(parts), width


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def seg(t, a, b):
    return ease((t - a) / (b - a)) if b > a else 0.0


BG_DEFS = """
  <linearGradient id="bg" x1="0" y1="0" x2="0.55" y2="1">
    <stop offset="0" stop-color="#0A2FB8"/>
    <stop offset="0.45" stop-color="#1463F3"/>
    <stop offset="1" stop-color="#12B3A2"/>
  </linearGradient>
  <radialGradient id="glowA" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="glowB" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#5EEAD4" stop-opacity="0.35"/>
    <stop offset="1" stop-color="#5EEAD4" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="mk" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#1463F3"/><stop offset="1" stop-color="#0FA394"/>
  </linearGradient>
"""

WORD, _ = text_path("connect", BOLD, 25, 0, 0, anchor="left")
w_connect = text_path("connect", BOLD, 25, 0, 0, anchor="left")[1]
w_2m = text_path("2m", BOLD, 25, 0, 0, anchor="left")[1]
start = SW / 2 - (w_connect + w_2m) / 2
P_CONNECT, _ = text_path("connect", BOLD, 25, start, 214, anchor="left")
P_2M, _ = text_path("2m", BOLD, 25, start + w_connect, 214, anchor="left")
P_TAG, _ = text_path("Remote support, made simple", REG, 9.4, SW / 2, 236)
P_BY, _ = text_path("by Abdallah Zreik", MED, 8.5, SW / 2, 298)


def icon_layer(t):
    """The animated icon motif; t in [0, 1)."""
    # Breathing glow behind the icon.
    g = 0.85 + 0.15 * math.sin(2 * math.pi * t)
    out = [f'<circle cx="84" cy="114" r="{60 * g:.2f}" fill="url(#glowA)"/>']
    # Back screen (outline) and front screen (filled).
    out.append('<rect x="30" y="64" width="80" height="60" rx="13" fill="none" '
               'stroke="#FFFFFF" stroke-opacity="0.78" stroke-width="10"/>')
    out.append('<rect x="66" y="100" width="80" height="60" rx="13" fill="#FFFFFF"/>')
    # File travelling from the back screen to the front screen.
    travel = seg(t, 0.08, 0.55)
    appear = seg(t, 0.0, 0.10) * (1 - seg(t, 0.55, 0.66))
    if appear > 0.01:
        x0, y0, x1, y1 = 66, 92, 88, 128
        x = x0 + (x1 - x0) * travel
        y = y0 + (y1 - y0) * travel - 26 * math.sin(math.pi * travel)
        s = 1.3 - 0.55 * seg(t, 0.5, 0.66)
        out.append(
            f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.3f})" opacity="{appear:.3f}">'
            '<path d="M-9 -12 h11 l7 7 v17 h-18 z" fill="#FFFFFF" stroke="#1463F3" stroke-opacity="0.35" stroke-width="1"/>'
            '<path d="M2 -12 v7 h7" fill="#C7DBFF"/>'
            '<rect x="-5" y="-1" width="10" height="2" rx="1" fill="#1463F3"/>'
            '<rect x="-5" y="4" width="8" height="2" rx="1" fill="#1463F3"/>'
            '</g>')
    # Ripple when the file arrives.
    r = seg(t, 0.6, 0.9)
    if 0 < r < 1:
        pad = 2 + 7 * r
        out.append(f'<rect x="{66 - pad:.2f}" y="{100 - pad:.2f}" width="{80 + 2 * pad:.2f}" '
                   f'height="{60 + 2 * pad:.2f}" rx="{13 + pad:.2f}" fill="none" stroke="#FFFFFF" '
                   f'stroke-opacity="{0.7 * (1 - r):.3f}" stroke-width="2.4"/>')
    # Cursor with a small click at the end.
    click = 1 - 0.12 * math.sin(math.pi * seg(t, 0.66, 0.8))
    out.append(f'<g transform="translate(108 128) scale({click:.3f}) translate(-108 -128)">'
               '<path d="M98 112 L98 146 L107 138 L113 151 L120 148 L114 135 L126 134 Z" '
               'fill="url(#mk)" stroke="url(#mk)" stroke-width="3" stroke-linejoin="round"/></g>')
    return "\n".join(out)


def sidebar_svg(t):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SW} {SH}" width="{SW}" height="{SH}">
<defs>{BG_DEFS}</defs>
<rect width="{SW}" height="{SH}" fill="url(#bg)"/>
<circle cx="150" cy="18" r="95" fill="url(#glowA)"/>
<circle cx="10" cy="300" r="110" fill="url(#glowB)"/>
{icon_layer(t)}
<path d="{P_CONNECT}" fill="#FFFFFF"/>
<path d="{P_2M}" fill="#A7F3EA"/>
<path d="{P_TAG}" fill="#FFFFFF" fill-opacity="0.88"/>
<rect x="{SW/2 - 14}" y="252" width="28" height="2" rx="1" fill="#FFFFFF" fill-opacity="0.45"/>
<path d="{P_BY}" fill="#FFFFFF" fill-opacity="0.62"/>
</svg>"""


def render(svg, w, h):
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h)
    return Image.open(io.BytesIO(png)).convert("RGB")


preview = []
for pct in SCALES:
    w, h = round(SW * pct / 100), round(SH * pct / 100)
    box = tuple(round(v * pct / 100) for v in (RX0, RY0, RX1, RY1))
    base = render(sidebar_svg(0.0), w, h)
    base.save(f"{ART}/side_{pct}.bmp")
    for i in range(FRAMES):
        frame = render(sidebar_svg(i / FRAMES), w, h)
        frame.crop(box).save(f"{ART}/anim_{pct}_{i:02d}.bmp")
        if pct == 200:
            preview.append(frame)
    # Header for inner pages: white, icon on the right.
    hw, hh = round(150 * pct / 100), round(57 * pct / 100)
    header = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 57" width="150" height="57">
<defs>{BG_DEFS}</defs><rect width="150" height="57" fill="#FFFFFF"/>
<g transform="translate(100 5.5) scale(0.0898)">
<rect width="512" height="512" rx="116" fill="url(#bg)"/>
<g transform="translate(6 16)"><rect x="84" y="96" width="232" height="176" rx="34" fill="none" stroke="#FFFFFF" stroke-opacity="0.72" stroke-width="34"/>
<rect x="196" y="212" width="236" height="180" rx="36" fill="#FFFFFF"/>
<path d="M276 250 L276 352 L302 328 L320 368 L342 358 L324 318 L360 316 Z" fill="url(#mk)" stroke="url(#mk)" stroke-width="10" stroke-linejoin="round"/></g></g></svg>"""
    render(header, hw, hh).save(f"{ART}/header_{pct}.bmp")

# MSI (WiX): dialog 493x312 with the brand panel on the left 164px, banner 493x58.
side = render(sidebar_svg(0.0), 164, 314).crop((0, 1, 164, 313))
dlg = Image.new("RGB", (493, 312), "white")
dlg.paste(side, (0, 0))
dlg.save(f"{MSI}/connect2m-dialog.bmp")
ban = Image.new("RGB", (493, 58), "white")
hdr = Image.open(f"{ART}/header_100.bmp")
ban.paste(hdr.crop((90, 0, 150, 57)), (493 - 66, 0))
ban.save(f"{MSI}/connect2m-banner.bmp")

preview[0].save(f"{PREVIEW}/sidebar-animation.gif", save_all=True, append_images=preview[1:],
                duration=83, loop=0)
print("frames:", FRAMES, "scales:", SCALES)
