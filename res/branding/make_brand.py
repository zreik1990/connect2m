"""Generate connect2m brand assets: icon SVG/PNG/ICO, outlined wordmark logos."""
import sys, os, io
import cairosvg
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
BLUE, TEAL, NAVY = "#1463F3", "#14B8A6", "#0B2545"

MARK = f'''
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient>
    <linearGradient id="mk" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="#0FA394"/></linearGradient>
  </defs>
  <rect width="512" height="512" rx="116" fill="url(#bg)"/>
  <g transform="translate(6 16)">
    <rect x="84" y="96" width="232" height="176" rx="34" fill="none" stroke="#FFFFFF" stroke-opacity="0.72" stroke-width="34"/>
    <rect x="196" y="212" width="236" height="180" rx="36" fill="#FFFFFF"/>
    <path d="M276 250 L276 352 L302 328 L320 368 L342 358 L324 318 L360 316 Z" fill="url(#mk)" stroke="url(#mk)" stroke-width="10" stroke-linejoin="round"/>
  </g>'''
ICON = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{MARK}\n</svg>\n'

# Tray: simplified, heavier shapes so it stays legible at 16px.
TRAY = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient></defs>
  <rect width="512" height="512" rx="110" fill="url(#bg)"/>
  <rect x="70" y="80" width="250" height="190" rx="36" fill="none" stroke="#FFFFFF" stroke-width="52"/>
  <rect x="186" y="206" width="266" height="214" rx="40" fill="#FFFFFF"/>
  <path d="M272 248 L272 380 L306 348 L330 396 L360 382 L336 336 L384 332 Z" fill="{BLUE}"/>
</svg>
'''

def text_path(text, font_file, size, x, y):
    f = TTFont(font_file)
    gs, cmap = f.getGlyphSet(), f.getBestCmap()
    upm = f["head"].unitsPerEm
    sc = size / upm
    hmtx = f["hmtx"]
    paths, cx = [], x
    for ch in text:
        g = cmap[ord(ch)]
        pen = SVGPathPen(gs)
        gs[g].draw(TransformPen(pen, (sc, 0, 0, -sc, cx, y)))
        paths.append(pen.getCommands())
        cx += hmtx[g][0] * sc
    return " ".join(paths), cx

FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
def wordmark(text_color):
    # icon 512 scaled to 120, text baseline aligned
    p1, x1 = text_path("connect", FONT, 104, 148, 92)
    p2, x2 = text_path("2m", FONT, 104, x1 + 2, 92)
    w = int(x2 + 8)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} 120" width="{w}" height="120">
  <defs><linearGradient id="tx" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BLUE}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient></defs>
  <g transform="scale({120/512})">{MARK}</g>
  <path d="{p1}" fill="{text_color}"/>
  <path d="{p2}" fill="url(#tx)"/>
</svg>
''', w

def write(name, s):
    open(os.path.join(OUT, name), "w").write(s)

def png(svg, w, h=None):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h or w))).convert("RGBA")

write("icon.svg", ICON); write("tray.svg", TRAY)
light, w = wordmark(NAVY); dark, _ = wordmark("#FFFFFF")
write("logo.svg", light); write("logo_dark.svg", dark)
for n, s in (("logo.png", light), ("logo_light.png", light), ("logo_dark.png", dark)):
    png(s, w * 2, 240).save(os.path.join(OUT, n))
for s in (16, 24, 32, 48, 64, 128, 256, 512, 1024):
    png(ICON, s).save(os.path.join(OUT, f"icon_{s}.png"))
big = png(ICON, 256)
big.save(os.path.join(OUT, "icon.ico"), sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
png(TRAY, 256).save(os.path.join(OUT, "tray-icon.ico"), sizes=[(16,16),(20,20),(24,24),(32,32),(48,48),(64,64)])
for s in (16, 32): png(TRAY, s).save(os.path.join(OUT, f"tray_{s}.png"))
print("done", w)
