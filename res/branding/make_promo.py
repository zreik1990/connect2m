"""connect2m promo video frames (1280x720, 30fps). Motion graphics, not a
screen recording. Outputs PNG frames to <outdir>."""
import io, math, os, sys
import cairosvg
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
W, H, FPS = 1280, 720, 30
BOLD = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
XBOLD = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
MED = "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf"
REG = "/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf"
BLUE, TEAL, NAVY = (0x14, 0x63, 0xF3), (0x14, 0xB8, 0xA6), (0x0B, 0x25, 0x45)

def font(f, s): return ImageFont.truetype(f, s)
def ease(t): t = max(0, min(1, t)); return t*t*(3-2*t)
def seg(t, a, b): return ease((t-a)/(b-a)) if b > a else (1.0 if t >= b else 0.0)

MARK = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="{s}" height="{s}">
<defs><linearGradient id="mk" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1463F3"/><stop offset="1" stop-color="#0FA394"/></linearGradient></defs>
<rect width="512" height="512" rx="116" fill="{bg}"/>
<g transform="translate(6 16)"><rect x="84" y="96" width="232" height="176" rx="34" fill="none" stroke="#FFFFFF" stroke-opacity="0.80" stroke-width="34"/>
<rect x="196" y="212" width="236" height="180" rx="36" fill="#FFFFFF"/>
<path d="M276 250 L276 352 L302 328 L320 368 L342 358 L324 318 L360 316 Z" fill="url(#mk)" stroke="url(#mk)" stroke-width="10" stroke-linejoin="round"/></g></svg>'''

def icon_img(size, bg="#FFFFFF"):
    png = cairosvg.svg2png(bytestring=MARK.format(s=size, bg=bg).encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")

def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def gradient(shift=0.0):
    im = Image.new("RGB", (W, H))
    px = im.load()
    a, b, c = (0x0A, 0x2F, 0xB8), BLUE, (0x12, 0xB3, 0xA2)
    for y in range(H):
        ty = y / H
        for x in range(0, W, 2):
            t = (x / W * 0.45 + ty * 0.55 + shift) % 1.0
            col = lerp(a, b, t*2) if t < 0.5 else lerp(b, c, (t-0.5)*2)
            px[x, y] = col
            if x+1 < W: px[x+1, y] = col
    return im

def glow(im, cx, cy, r, color, alpha):
    o = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(o)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=color+(alpha,))
    o = o.filter(ImageFilter.GaussianBlur(r/2))
    im.alpha_composite(o)

def text(draw, xy, s, f, fill, anchor="mm", ls=0):
    if ls == 0:
        draw.text(xy, s, font=f, fill=fill, anchor=anchor)
    else:
        # letter-spacing
        total = sum(draw.textlength(ch, font=f)+ls for ch in s) - ls
        x = xy[0] - total/2
        for ch in s:
            draw.text((x, xy[1]), ch, font=f, fill=fill, anchor="lm")
            x += draw.textlength(ch, font=f) + ls

def card(base, x, y, w, h, title, body, icon_svg, op):
    if op <= 0: return
    o = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(o)
    yoff = int((1-ease(op))*24)
    rr = [x, y+yoff, x+w, y+h+yoff]
    d.rounded_rectangle(rr, 22, fill=(255,255,255,int(255*min(1,op))))
    # icon chip
    chip = Image.new("RGBA",(64,64),(0,0,0,0))
    cd = ImageDraw.Draw(chip); cd.rounded_rectangle([0,0,63,63],16,fill=BLUE)
    glyphs = {
      "ctrl": "M14 20 h36 a4 4 0 0 1 4 4 v16 a4 4 0 0 1 -4 4 h-36 a4 4 0 0 1 -4 -4 v-16 a4 4 0 0 1 4 -4 z M26 50 h12",
      "file": "M24 14 h12 l8 8 v26 h-28 v-34 z",
      "list": "M14 22 h36 M14 32 h36 M14 42 h24",
    }
    gd = ImageDraw.Draw(chip)
    if icon_svg == "ctrl":
        gd.rounded_rectangle([14,18,50,40],4,outline="white",width=4); gd.line([26,48,38,48],fill="white",width=4); gd.line([32,40,32,48],fill="white",width=4)
    elif icon_svg == "file":
        gd.line([(22,14),(38,14),(46,22),(46,50),(18,50),(18,14),(22,14)],fill="white",width=4,joint="curve")
    else:
        gd.line([14,20,46,20],fill="white",width=4); gd.line([14,30,46,30],fill="white",width=4); gd.line([14,40,36,40],fill="white",width=4)
    o.alpha_composite(chip, (x+22, y+yoff+22))
    cd2 = ImageDraw.Draw(o)
    tf = font(BOLD, 26); bf = font(REG, 19)
    cd2.text((x+24, y+yoff+104), title, font=tf, fill=NAVY, anchor="lm")
    # wrap body
    words = body.split(); line=""; ly=y+yoff+140
    for wd in words:
        if cd2.textlength(line+" "+wd, font=bf) > w-48:
            cd2.text((x+24, ly), line, font=bf, fill=(0x51,0x60,0x7A)); ly+=26; line=wd
        else:
            line = (line+" "+wd).strip()
    cd2.text((x+24, ly), line, font=bf, fill=(0x51,0x60,0x7A))
    if op < 1:
        o = Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)), o, min(1,op))
    base.alpha_composite(o)

DUR = 16.0
N = int(DUR*FPS)

for i in range(N):
    t = i / FPS
    bg = gradient(shift=(t*0.01)).convert("RGBA")
    glow(bg, 1050, 120, 260, (255,255,255), 40)
    glow(bg, 160, 620, 300, (94,234,212), 55)
    d = ImageDraw.Draw(bg)

    # Scene 1: logo reveal 0-3
    if t < 3.4:
        a = seg(t, 0.2, 1.0)
        sz = int(130*a)
        if sz > 4:
            ic = icon_img(sz, "#FFFFFF")
            bg.alpha_composite(ic, (W//2-sz//2, 200-sz//2+40))
        if t > 0.9:
            o2 = seg(t, 0.9, 1.6)
            lay = Image.new("RGBA",(W,H),(0,0,0,0)); dl = ImageDraw.Draw(lay)
            text(dl,(W//2,330),"connect2m",font(XBOLD,64),(255,255,255,255))
            text(dl,(W//2,392),"Remote support, made simple",font(REG,26),(230,245,255,255))
            bg.alpha_composite(Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)),lay,o2))
        if t > 3.0:
            fade = seg(t,3.0,3.4)
            bg.alpha_composite(Image.new("RGBA",(W,H),(*lerp((10,20,40),(10,20,40),0),int(0))))

    # Scene 2: headline 3.2-6
    elif t < 6.2:
        o2 = seg(t,3.3,3.9)
        lay = Image.new("RGBA",(W,H),(0,0,0,0)); dl = ImageDraw.Draw(lay)
        for k,line in enumerate(["Remote support that","stays on your network"]):
            text(dl,(W//2,300+k*62),line,font(XBOLD,54),(255,255,255,255))
        text(dl,(W//2,430),"On your own network. No microphone. No camera.",font(REG,24),(225,240,255,255))
        bg.alpha_composite(Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)),lay,o2*(1-seg(t,5.8,6.2))))

    # Scene 3: feature cards 6-10.5
    elif t < 10.6:
        lay = Image.new("RGBA",(W,H),(0,0,0,0)); dl=ImageDraw.Draw(lay)
        text(dl,(W//2,110),"Everything a support desk needs",font(BOLD,40),(255,255,255,255))
        bg.alpha_composite(Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)),lay,seg(t,6.2,6.7)*(1-seg(t,10.2,10.6))))
        cw,ch,gap = 360,250,30
        x0 = (W-(cw*3+gap*2))//2
        feats=[("Full remote control","See and control any PC. Install software as if you were there.","ctrl"),
               ("Send & receive files","Move files both ways with a simple transfer window.","file"),
               ("Shared client list","Rename, tag and favourite every client in one place.","list")]
        for k,(ti,bo,ic) in enumerate(feats):
            op = seg(t, 6.6+k*0.4, 7.2+k*0.4)*(1-seg(t,10.2,10.6))
            card(bg, x0+k*(cw+gap), 200, cw, ch, ti, bo, ic, op)

    # Scene 4: locked + price 10.6-13
    elif t < 13.2:
        o2 = seg(t,10.7,11.3)*(1-seg(t,12.8,13.2))
        lay=Image.new("RGBA",(W,H),(0,0,0,0)); dl=ImageDraw.Draw(lay)
        text(dl,(W//2,250),"Locked-down clients",font(XBOLD,52),(255,255,255,255))
        text(dl,(W//2,320),"They see only an ID and a password you set.",font(REG,26),(225,240,255,255))
        # price pill
        pill=Image.new("RGBA",(W,H),(0,0,0,0)); dp=ImageDraw.Draw(pill)
        dp.rounded_rectangle([W//2-200,400,W//2+200,476],38,fill=(255,255,255,255))
        text(dp,(W//2,430),"$4.99 per PC",font(XBOLD,32),NAVY+(255,))
        text(dp,(W//2,460),"one-time · for life",font(REG,17),(0x51,0x60,0x7A,255))
        lay.alpha_composite(pill)
        bg.alpha_composite(Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)),lay,o2))

    # Scene 5: CTA 13.2-16
    else:
        o2 = seg(t,13.3,13.9)
        sz=96; ic=icon_img(sz,"#FFFFFF"); bg.alpha_composite(ic,(W//2-sz//2,200))
        lay=Image.new("RGBA",(W,H),(0,0,0,0)); dl=ImageDraw.Draw(lay)
        text(dl,(W//2,340),"connect2m",font(XBOLD,58),(255,255,255,255))
        text(dl,(W//2,406),"github.com/zreik1990/connect2m",font(MED,26),(225,240,255,255))
        text(dl,(W//2,470),"by Abdallah Zreik",font(REG,20),(200,225,255,230))
        bg.alpha_composite(Image.blend(Image.new("RGBA",(W,H),(0,0,0,0)),lay,o2))

    bg.convert("RGB").save(f"{OUT}/f{i:04d}.png")

print("frames", N)
