#!/usr/bin/env python3
"""Generates the placeholder pixel art for the prototype.

Run from anywhere:   python3 tools/gen_assets.py

Outputs:
  assets/sprites/*.png        sprite sheets / props / tiles / icons
  assets/backgrounds/*.png    parallax layers
  scripts/generated/sprite_meta.gd   frame + animation metadata used by SpriteLib

Every sprite is drawn at 1x with PIL primitives so the art stays crisp pixel art.
To replace a placeholder with hand-made art, keep the same frame size and frame
order (see sprite_meta.gd) and overwrite the PNG; do not re-run this script
afterwards or it will overwrite your art (or delete the matching entry below).
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BGD = os.path.join(ROOT, "assets", "backgrounds")
META_OUT = os.path.join(ROOT, "scripts", "generated", "sprite_meta.gd")
os.makedirs(SPR, exist_ok=True)
os.makedirs(BGD, exist_ok=True)
os.makedirs(os.path.dirname(META_OUT), exist_ok=True)

random.seed(7)


def c(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


P = dict(
    ol=c("2b1d14"), skin=c("f6e7cf"), skin_d=c("d9bf9e"), red=c("c8423b"), red_d=c("8a2b2b"),
    cream=c("f4e6c4"), green=c("5e9c4a"), green_d=c("3b6b35"), green_l=c("8cc65a"), green_dd=c("24452a"),
    brown=c("8a5a36"), brown_d=c("5c3a22"), brown_l=c("b07a4a"), stone=c("8b8b93"), stone_d=c("5a5a66"),
    stone_l=c("b4b4bc"), water=c("4a8fc2"), water_l=c("7fb8e0"), yellow=c("f2c14e"), yellow_d=c("c98f2a"),
    purple=c("6b4a8a"), purple_d=c("45305a"), white=c("ffffff"), blue=c("3f6fb5"), blue_d=c("2a4a80"),
    pink=c("e88a9a"), gray=c("6e6e6e"), orange=c("e07b39"), straw=c("e3c27a"), dark=c("1a1210"),
)
OL = P["ol"]
META = {}


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, name, folder=SPR):
    img.save(os.path.join(folder, name + ".png"))


def single(name, img):
    """Registers a one-frame image so SpriteLib can find it too."""
    save(img, name)
    META[name] = dict(path=f"res://assets/sprites/{name}.png", fw=img.width, fh=img.height, cols=1,
                      anims={"default": dict(frames=[0], fps=1, loop=True)})


class Sheet:
    def __init__(self, name, fw, fh):
        self.name, self.fw, self.fh = name, fw, fh
        self.frames, self.anims = [], {}

    def add(self, anim, imgs, fps=8, loop=True):
        start = len(self.frames)
        self.frames += imgs
        self.anims[anim] = dict(frames=list(range(start, start + len(imgs))), fps=fps, loop=loop)

    def alias(self, anim, src, order, fps=8, loop=True):
        base = self.anims[src]["frames"]
        self.anims[anim] = dict(frames=[base[i] for i in order], fps=fps, loop=loop)

    def save(self, cols=8):
        n = len(self.frames)
        cols = min(cols, n)
        rows = math.ceil(n / cols)
        img = new(cols * self.fw, rows * self.fh)
        for i, f in enumerate(self.frames):
            img.paste(f, ((i % cols) * self.fw, (i // cols) * self.fh))
        save(img, self.name)
        META[self.name] = dict(path=f"res://assets/sprites/{self.name}.png", fw=self.fw, fh=self.fh,
                               cols=cols, anims=self.anims)


def line(d, a, b, col, w=1):
    d.line([a, b], fill=col, width=w)


def oval(d, box, fill, outline=OL):
    x0, y0, x1, y1 = box
    d.ellipse((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)), fill=fill, outline=outline)


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


# --------------------------------------------------------------------------------------------
# Player "Pip" — side view, 32x32, faces right, feet on y=31
# --------------------------------------------------------------------------------------------
def draw_eyes(d, x, y, kind):
    if kind == "open":
        for ex in (x, x + 4):
            d.rectangle((ex, y, ex + 1, y + 3), fill=OL)
            d.point((ex + 1, y), fill=P["white"])
    elif kind == "x":
        for ex in (x, x + 4):
            d.point([(ex, y), (ex + 2, y), (ex + 1, y + 1), (ex, y + 2), (ex + 2, y + 2)], fill=OL)
    elif kind == "closed":
        for ex in (x, x + 4):
            line(d, (ex, y + 2), (ex + 1, y + 2), OL)
    elif kind == "angry":
        for ex in (x, x + 4):
            d.rectangle((ex, y + 1, ex + 1, y + 3), fill=OL)
        line(d, (x - 1, y - 1), (x + 1, y), OL)
        line(d, (x + 6, y - 1), (x + 4, y), OL)


def draw_pip(bob=0, lean=0, feet=((13, 30), (19, 30)), hands=((10, 22), (22, 22)), eyes="open",
             glove_big=False, mouth="smile", fx=None):
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    L, b = lean, bob
    tl = L // 2
    if fx:
        fx(d)
    sh_back, sh_front = (14 + tl, 19 + b), (18 + tl, 19 + b)
    # back arm + glove
    line(d, sh_back, hands[0], OL)
    oval(d, (hands[0][0] - 1, hands[0][1] - 1, hands[0][0] + 1, hands[0][1] + 1), P["skin_d"])
    # legs (rubber hose)
    hips = ((14 + tl, min(24 + b, 29)), (18 + tl, min(24 + b, 29)))
    for hip, foot in zip(hips, feet):
        line(d, hip, foot, OL, 2)
        oval(d, (foot[0] - 2, foot[1] - 2, foot[0] + 3, foot[1]), P["brown"])
    # torso
    oval(d, (11 + tl, 15 + b, 21 + tl, 25 + b), P["red"])
    line(d, (13 + tl, 17 + b), (19 + tl, 17 + b), P["cream"])
    d.point([(17 + tl, 20 + b), (17 + tl, 22 + b)], fill=P["yellow"])
    # head
    oval(d, (9 + L, 2 + b, 22 + L, 15 + b), P["skin"])
    d.point((10 + L, 10 + b), fill=P["skin_d"])
    # leaf hat
    d.polygon([(13 + L, 3 + b), (16 + L, -2 + b), (22 + L, 0 + b), (18 + L, 4 + b)], fill=P["green"], outline=OL)
    line(d, (15 + L, 2 + b), (19 + L, 1 + b), P["green_d"])
    draw_eyes(d, 15 + L, 6 + b, eyes)
    d.point((21 + L, 11 + b), fill=P["pink"])
    if mouth == "smile":
        line(d, (17 + L, 12 + b), (19 + L, 12 + b), OL)
    elif mouth == "open":
        oval(d, (17 + L, 11 + b, 20 + L, 13 + b), P["red_d"])
    elif mouth == "grit":
        line(d, (16 + L, 12 + b), (20 + L, 12 + b), OL)
    # front arm + glove
    line(d, sh_front, hands[1], OL)
    r = 2 if glove_big else 1
    oval(d, (hands[1][0] - r, hands[1][1] - r, hands[1][0] + r, hands[1][1] + r), P["white"])
    return im


def draw_pip_crawl(phase, eyes="open"):
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    s = 1 if phase else -1
    # back leg + foot
    line(d, (10, 27), (4, 29 + (phase % 2)), OL, 2)
    oval(d, (2, 27, 6, 30), P["brown"])
    oval(d, (6, 22, 20, 30), P["red"])
    line(d, (12, 27), (12 + s * 2, 30), OL, 2)
    oval(d, (18, 18, 30, 30), P["skin"])
    d.polygon([(21, 19), (24, 14), (29, 16), (26, 20)], fill=P["green"], outline=OL)
    draw_eyes(d, 23, 21, eyes)
    d.point((29, 26), fill=P["pink"])
    hx = 22 - s * 3
    oval(d, (hx - 1, 28, hx + 1, 30), P["white"])
    return im


def build_player():
    sh = Sheet("player", 32, 32)
    sh.add("idle", [draw_pip(0), draw_pip(1, hands=((10, 23), (22, 23)))], fps=3)
    run = []
    for i in range(6):
        p = i / 6 * math.tau
        f1 = (16 + round(5 * math.sin(p)), 30 - max(0, round(3 * math.cos(p))))
        f2 = (16 + round(5 * math.sin(p + math.pi)), 30 - max(0, round(3 * math.cos(p + math.pi))))
        h1 = (14 - round(4 * math.sin(p)), 22)
        h2 = (18 - round(4 * math.sin(p + math.pi)), 22)
        run.append(draw_pip(bob=-(i % 3 == 0), lean=1, feet=(f1, f2), hands=(h1, h2)))
    sh.add("run", run, fps=12)
    sh.add("jump", [draw_pip(-1, feet=((13, 27), (19, 28)), hands=((10, 13), (23, 14)), mouth="open")], fps=1)
    sh.add("fall", [draw_pip(0, feet=((13, 30), (19, 29)), hands=((8, 12), (24, 12)), mouth="open")], fps=1)
    sh.add("crouch", [draw_pip(7, feet=((12, 30), (20, 30)), hands=((11, 27), (21, 27)))], fps=1)
    sh.add("crawl", [draw_pip_crawl(0), draw_pip_crawl(1)], fps=6)
    sh.add("climb", [draw_pip(0, feet=((13, 28), (19, 31)), hands=((12, 7), (20, 14)), eyes="closed"),
                     draw_pip(0, feet=((13, 31), (19, 28)), hands=((12, 14), (20, 7)), eyes="closed")], fps=6)
    sh.add("hurt", [draw_pip(0, lean=-2, feet=((10, 29), (17, 30)), hands=((6, 14), (24, 13)), eyes="x", mouth="open")], fps=1)
    sh.add("trip", [draw_pip(2, lean=4, feet=((8, 28), (14, 30)), hands=((26, 18), (28, 20)), eyes="x", mouth="open"),
                    draw_pip_crawl(0, eyes="x")], fps=5, loop=False)

    def speed_lines(d):
        for y in (14, 19, 24):
            line(d, (0, y), (6, y), P["cream"])

    sh.add("dash", [draw_pip(0, lean=3, feet=((8, 29), (12, 27)), hands=((7, 20), (26, 18)), eyes="angry", fx=speed_lines)], fps=1)
    sh.add("jab", [draw_pip(0, lean=-1, hands=((12, 21), (16, 20)), eyes="angry"),
                   draw_pip(0, lean=2, feet=((12, 30), (21, 30)), hands=((10, 21), (29, 18)), eyes="angry", glove_big=True, mouth="grit"),
                   draw_pip(0, lean=1, hands=((10, 22), (24, 19)), eyes="angry")], fps=14, loop=False)
    sh.add("up", [draw_pip(1, hands=((12, 22), (20, 15)), eyes="angry"),
                  draw_pip(-1, feet=((14, 30), (18, 29)), hands=((12, 20), (19, 1)), eyes="angry", glove_big=True, mouth="grit"),
                  draw_pip(0, hands=((11, 21), (21, 9)), eyes="angry")], fps=12, loop=False)

    def arc(d):
        d.arc((12, 4, 31, 30), -70, 60, fill=P["cream"])

    sh.add("heavy", [draw_pip(1, lean=-3, feet=((10, 30), (18, 30)), hands=((5, 18), (7, 15)), eyes="angry", mouth="grit"),
                     draw_pip(1, lean=-3, feet=((10, 30), (18, 30)), hands=((4, 17), (6, 13)), eyes="closed", mouth="grit"),
                     draw_pip(0, lean=4, feet=((10, 30), (23, 30)), hands=((12, 22), (30, 16)), eyes="angry", glove_big=True, mouth="open", fx=arc),
                     draw_pip(0, lean=2, feet=((11, 30), (21, 30)), hands=((11, 22), (26, 21)), eyes="angry")], fps=10, loop=False)

    def seed(d):
        oval(d, (25, 15, 30, 20), P["yellow"])
        d.point((27, 16), fill=P["white"])

    sh.add("special", [draw_pip(0, lean=-1, hands=((10, 22), (14, 20)), eyes="angry"),
                       draw_pip(0, lean=2, hands=((10, 22), (25, 18)), eyes="angry", mouth="open", fx=seed)], fps=10, loop=False)
    sh.add("air", [draw_pip(-1, lean=0, feet=((4, 26), (29, 26)), hands=((9, 14), (23, 14)), eyes="angry", mouth="grit"),
                   draw_pip(-1, lean=0, feet=((6, 22), (27, 29)), hands=((8, 18), (24, 12)), eyes="angry", mouth="grit")], fps=10)
    sh.add("shield", [draw_pip(1, lean=-1, feet=((12, 30), (20, 30)), hands=((19, 17), (20, 21)), eyes="closed", mouth="grit")], fps=1)
    sh.add("roll", [draw_pip_crawl(0, eyes="closed"), draw_pip_crawl(1, eyes="closed")], fps=12)
    sh.add("victory", [draw_pip(-1, hands=((10, 22), (22, 3)), mouth="open"), draw_pip(0, hands=((10, 22), (23, 5)), mouth="open")], fps=4)
    sh.save()


# --------------------------------------------------------------------------------------------
# Overworld chibi characters — 16x24, feet at y=23
# --------------------------------------------------------------------------------------------
def chibi(direction, step, skin, body, hat=None, beard=None, extra=None, small=False):
    im = new(16, 24)
    d = ImageDraw.Draw(im)
    oy = 2 if small else 0
    # legs
    l1 = 23 - (1 if step == 1 else 0)
    l2 = 23 - (1 if step == 2 else 0)
    line(d, (6, 18), (6, l1), OL, 1)
    line(d, (9, 18), (9, l2), OL, 1)
    d.rectangle((5, l1 - 1, 7, l1), fill=P["brown"])
    d.rectangle((8, l2 - 1, 10, l2), fill=P["brown"])
    oval(d, (3, 12 + oy, 12, 20), body)
    oval(d, (2, 1 + oy, 13, 13 + oy), skin)
    if beard:
        d.polygon([(4, 9 + oy), (11, 9 + oy), (7, 16 + oy)], fill=beard, outline=OL)
    if direction == "down":
        d.rectangle((5, 6 + oy, 5, 8 + oy), fill=OL)
        d.rectangle((10, 6 + oy, 10, 8 + oy), fill=OL)
        d.point([(4, 9 + oy), (11, 9 + oy)], fill=P["pink"])
    elif direction == "side":
        d.rectangle((9, 6 + oy, 9, 8 + oy), fill=OL)
        d.rectangle((12, 6 + oy, 12, 8 + oy), fill=OL)
        d.point((12, 10 + oy), fill=P["pink"])
    if hat:
        hat(d, oy, direction)
    if extra:
        extra(d, oy, direction)
    return im


def leaf_hat(d, oy, direction):
    d.polygon([(5, 2 + oy), (8, -1 + oy + 1), (13, 0 + oy + 1), (10, 3 + oy)], fill=P["green"], outline=OL)


def build_chibis():
    def make(name, skin, body, hat=None, beard=None, extra=None, small=False, full=False):
        sh = Sheet(name, 16, 24)
        if full:
            for dname in ("down", "up", "side"):
                sh.add("idle_" + dname, [chibi(dname, 0, skin, body, hat, beard, extra, small)], fps=1)
                sh.add("walk_" + dname, [chibi(dname, 1, skin, body, hat, beard, extra, small),
                                          chibi(dname, 0, skin, body, hat, beard, extra, small),
                                          chibi(dname, 2, skin, body, hat, beard, extra, small),
                                          chibi(dname, 0, skin, body, hat, beard, extra, small)], fps=8)
        else:
            a = chibi("down", 0, skin, body, hat, beard, extra, small)
            b = chibi("down", 0, skin, body, hat, beard, extra, small)
            b2 = new(16, 24)
            b2.paste(b, (0, 1))
            sh.add("idle", [a, b2], fps=2)
            sh.add("talk", [chibi("side", 0, skin, body, hat, beard, extra, small), a], fps=4)
        sh.save()

    make("ow_player", P["skin"], P["red"], hat=leaf_hat, full=True)

    def wizard_hat(d, oy, direction):
        d.polygon([(2, 4 + oy), (13, 4 + oy), (8, -4 + oy + 4)], fill=P["purple"], outline=OL)

    def cane(d, oy, direction):
        line(d, (14, 10), (14, 23), P["brown_d"])
        d.point((13, 10), fill=P["brown_d"])

    make("npc_elder", P["skin_d"], P["purple"], hat=wizard_hat, beard=P["white"], extra=cane)

    def straw_hat(d, oy, direction):
        d.rectangle((0, 3 + oy, 15, 4 + oy), fill=P["straw"], outline=OL)
        oval(d, (4, 0 + oy, 11, 4 + oy), P["straw"])

    make("npc_villager", P["skin"], P["blue"], hat=straw_hat)

    def cap(d, oy, direction):
        oval(d, (3, 1 + oy, 12, 6 + oy), P["orange"])

    make("npc_kid", P["skin"], P["yellow"], hat=cap, small=True)

    def helmet(d, oy, direction):
        oval(d, (2, 0 + oy, 13, 7 + oy), P["stone_l"])
        line(d, (7, 0 + oy), (7, 6 + oy), P["stone_d"])

    def spear(d, oy, direction):
        line(d, (14, 0), (14, 23), P["brown"])
        d.polygon([(13, 2), (15, 2), (14, -1 + 1)], fill=P["stone_l"], outline=OL)

    make("npc_guard", P["skin_d"], P["stone_d"], hat=helmet, extra=spear)


# --------------------------------------------------------------------------------------------
# Thornling enemy — 32x32
# --------------------------------------------------------------------------------------------
def thornling(bob=0, step=0, eyes="angry", lunge=0, mouth=False):
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    cx = 16 + lunge
    cy = 18 + bob
    # feet
    d.rectangle((cx - 6 + step, 28, cx - 3 + step, 30), fill=P["brown_d"], outline=OL)
    d.rectangle((cx + 3 - step, 28, cx + 6 - step, 30), fill=P["brown_d"], outline=OL)
    # thorns
    for i in range(10):
        a = i / 10 * math.tau + 0.3
        bx, by = cx + math.cos(a) * 9, cy + math.sin(a) * 8
        tx, ty = cx + math.cos(a) * 14, cy + math.sin(a) * 13
        px, py = -math.sin(a) * 2, math.cos(a) * 2
        d.polygon([(bx + px, by + py), (bx - px, by - py), (tx, ty)], fill=P["brown_l"], outline=OL)
    oval(d, (cx - 11, cy - 10, cx + 11, cy + 10), P["green_d"])
    oval(d, (cx - 8, cy - 8, cx + 4, cy + 1), P["green"], outline=P["green"])
    # eyes
    if eyes == "x":
        for ex in (cx - 5, cx + 2):
            d.point([(ex, cy - 3), (ex + 2, cy - 3), (ex + 1, cy - 2), (ex, cy - 1), (ex + 2, cy - 1)], fill=P["white"])
    else:
        for ex in (cx - 6, cx + 1):
            oval(d, (ex, cy - 5, ex + 4, cy), P["white"])
            d.rectangle((ex + 2, cy - 3, ex + 3, cy - 1), fill=OL)
        line(d, (cx - 7, cy - 7), (cx - 2, cy - 5), OL)
        line(d, (cx + 7, cy - 7), (cx + 2, cy - 5), OL)
    if mouth:
        oval(d, (cx - 3, cy + 2, cx + 4, cy + 7), P["red_d"])
        d.point([(cx - 1, cy + 3), (cx + 2, cy + 3)], fill=P["white"])
    else:
        line(d, (cx - 3, cy + 4), (cx + 3, cy + 4), OL)
    return im


def build_thornling():
    sh = Sheet("thornling", 32, 32)
    sh.add("idle", [thornling(0), thornling(1)], fps=4)
    sh.add("run", [thornling(0, 1), thornling(1, 0), thornling(0, -1), thornling(1, 0)], fps=10)
    sh.add("attack", [thornling(1, lunge=-2), thornling(0, lunge=4, mouth=True)], fps=10, loop=False)
    sh.add("hurt", [thornling(0, eyes="x", mouth=True)], fps=1)
    sh.add("jump", [thornling(-1)], fps=1)
    sh.save()


# --------------------------------------------------------------------------------------------
# Boss: The Bramble King — 80x80, feet at y=79
# --------------------------------------------------------------------------------------------
def bramble_king(bob=0, arms="down", eyes="glow", mouth="closed", lean=0, flash=False):
    im = new(80, 80)
    d = ImageDraw.Draw(im)
    cx, cy = 40 + lean, 46 + bob
    body = P["green_dd"]
    # legs (roots)
    for lx in (-12, -4, 4, 12):
        d.polygon([(cx + lx - 3, cy + 20), (cx + lx + 3, cy + 20), (cx + lx + 5 * (1 if lx > 0 else -1), 79), (cx + lx, 79)],
                  fill=P["brown_d"], outline=OL)
    # back thorns
    rnd = random.Random(3)
    for i in range(16):
        a = math.pi + i / 15 * math.pi
        r1, r2 = 22, 30 + rnd.randint(0, 6)
        bx, by = cx + math.cos(a) * r1, cy - 4 + math.sin(a) * r1
        tx, ty = cx + math.cos(a) * r2, cy - 4 + math.sin(a) * r2
        px, py = -math.sin(a) * 3, math.cos(a) * 3
        d.polygon([(bx + px, by + py), (bx - px, by - py), (tx, ty)], fill=P["brown_l"], outline=OL)
    oval(d, (cx - 25, cy - 26, cx + 25, cy + 24), body)
    oval(d, (cx - 20, cy - 22, cx + 6, cy - 4), P["green_d"], outline=P["green_d"])
    for i in range(7):
        x = cx - 18 + i * 6
        d.point([(x, cy + 8 + (i % 2) * 3), (x + 1, cy + 9 + (i % 2) * 3)], fill=P["green"])
    # crown
    crown = [(cx - 14, cy - 24), (cx - 14, cy - 34), (cx - 8, cy - 28), (cx - 2, cy - 38), (cx + 4, cy - 28),
             (cx + 10, cy - 34), (cx + 12, cy - 23)]
    d.polygon(crown, fill=P["yellow"], outline=OL)
    d.point([(cx - 2, cy - 30), (cx - 9, cy - 27)], fill=P["red"])
    # face
    ec = P["white"] if flash else (P["red"] if eyes == "glow" else P["yellow"])
    for ex in (cx - 12, cx + 4):
        if eyes == "closed":
            line(d, (ex, cy - 10), (ex + 7, cy - 8), OL, 2)
        else:
            d.polygon([(ex, cy - 13), (ex + 8, cy - 10), (ex + 6, cy - 6), (ex + 1, cy - 7)], fill=ec, outline=OL)
            d.rectangle((ex + 3, cy - 10, ex + 4, cy - 8), fill=OL)
    line(d, (cx - 14, cy - 17), (cx - 4, cy - 13), OL, 2)
    line(d, (cx + 14, cy - 17), (cx + 4, cy - 13), OL, 2)
    if mouth == "open":
        oval(d, (cx - 10, cy - 3, cx + 10, cy + 13), P["dark"])
        for tx in range(cx - 8, cx + 9, 4):
            d.polygon([(tx, cy - 1), (tx + 2, cy - 1), (tx + 1, cy + 3)], fill=P["cream"])
    else:
        line(d, (cx - 9, cy + 4), (cx + 9, cy + 4), OL, 2)
        for tx in range(cx - 7, cx + 8, 5):
            d.polygon([(tx, cy + 3), (tx + 2, cy + 3), (tx + 1, cy + 6)], fill=P["cream"])
    # arms
    if arms == "down":
        hands = [(cx - 32, cy + 14), (cx + 32, cy + 14)]
    elif arms == "up":
        hands = [(cx - 30, cy - 34), (cx + 30, cy - 34)]
    elif arms == "forward":
        hands = [(cx - 20, cy + 6), (cx + 38, cy + 2)]
    else:  # wide
        hands = [(cx - 37, cy - 6), (cx + 37, cy - 6)]
    for sx, h in zip((cx - 20, cx + 20), hands):
        line(d, (sx, cy), h, OL, 5)
        line(d, (sx, cy), h, P["brown"], 3)
        oval(d, (h[0] - 4, h[1] - 4, h[0] + 4, h[1] + 4), P["brown_l"])
        for k in range(3):
            a = k * 2.1
            line(d, h, (h[0] + round(math.cos(a) * 7), h[1] + round(math.sin(a) * 7)), OL, 1)
    if flash:
        px = im.load()
        for y in range(80):
            for x in range(80):
                if px[x, y][3] > 0:
                    px[x, y] = (255, 255, 255, 255)
    return im


def build_boss():
    sh = Sheet("bramble_king", 80, 80)
    sh.add("idle", [bramble_king(0), bramble_king(1, arms="wide")], fps=3)
    sh.add("run", [bramble_king(0, arms="forward", lean=4, eyes="glow"), bramble_king(2, arms="forward", lean=5)], fps=10)
    sh.add("cast", [bramble_king(-1, arms="up", mouth="open"), bramble_king(-2, arms="up", eyes="bright", mouth="open")], fps=8)
    sh.add("jump", [bramble_king(-2, arms="up", eyes="bright")], fps=1)
    sh.add("slam", [bramble_king(3, arms="down", mouth="open")], fps=1)
    sh.add("hurt", [bramble_king(1, arms="wide", eyes="closed", mouth="open")], fps=1)
    sh.add("roar", [bramble_king(-1, arms="wide", mouth="open", eyes="bright"),
                    bramble_king(0, arms="up", mouth="open", eyes="bright")], fps=10)
    sh.add("flash", [bramble_king(0, flash=True)], fps=1)
    sh.add("dead", [bramble_king(6, arms="down", eyes="closed")], fps=1)
    sh.save()


# --------------------------------------------------------------------------------------------
# Training dummy — 32x32
# --------------------------------------------------------------------------------------------
def dummy(tilt=0, hit=False):
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    line(d, (16, 31), (16 + tilt, 12), P["brown_d"], 3)
    d.rectangle((10, 29, 22, 31), fill=P["brown"], outline=OL)
    oval(d, (9 + tilt, 12, 23 + tilt, 26), P["straw"])
    line(d, (6 + tilt, 16), (26 + tilt, 16), P["brown"], 2)
    oval(d, (11 + tilt, 2, 21 + tilt, 12), P["straw"])
    oval(d, (13 + tilt, 15, 19 + tilt, 21), P["red"])
    d.point((16 + tilt, 18), fill=P["white"])
    if hit:
        draw_eyes(d, 13 + tilt, 5, "x")
    else:
        d.point([(14 + tilt, 6), (18 + tilt, 6)], fill=OL)
    return im


def build_dummy():
    sh = Sheet("dummy", 32, 32)
    sh.add("idle", [dummy(0), dummy(0)], fps=1)
    sh.add("hurt", [dummy(3, True)], fps=1)
    sh.add("run", [dummy(-1), dummy(1)], fps=6)
    sh.add("jump", [dummy(0)], fps=1)
    sh.save()


# --------------------------------------------------------------------------------------------
# Platformer tiles — 16x16 strip
# --------------------------------------------------------------------------------------------
TILE_NAMES = ["grass", "dirt", "stone_top", "stone", "plank", "vine", "cave_back", "brick", "thorns", "dirt_dark"]


def build_tiles():
    img = new(16 * len(TILE_NAMES), 16)
    rnd = random.Random(1)

    def tile(i):
        t = new(16, 16)
        return t, ImageDraw.Draw(t)

    tiles = []
    # grass top
    t, d = tile(0)
    d.rectangle((0, 0, 15, 15), fill=P["brown"])
    for _ in range(14):
        x, y = rnd.randint(0, 15), rnd.randint(6, 15)
        d.point((x, y), fill=P["brown_d"])
    d.rectangle((0, 0, 15, 4), fill=P["green"])
    for x in range(16):
        d.point((x, 5 + (x * 7 % 3 == 0)), fill=P["green_d"])
        if x % 3 == 0:
            d.point((x, 0), fill=P["green_l"])
    line(d, (0, 0), (15, 0), P["green_l"])
    tiles.append(t)
    # dirt
    t, d = tile(1)
    d.rectangle((0, 0, 15, 15), fill=P["brown"])
    for _ in range(18):
        d.point((rnd.randint(0, 15), rnd.randint(0, 15)), fill=P["brown_d"])
    for _ in range(4):
        d.point((rnd.randint(0, 15), rnd.randint(0, 15)), fill=P["brown_l"])
    tiles.append(t)
    # stone top
    t, d = tile(2)
    d.rectangle((0, 0, 15, 15), fill=P["stone"])
    d.rectangle((0, 0, 15, 3), fill=P["green_d"])
    line(d, (0, 0), (15, 0), P["green"])
    line(d, (0, 9), (15, 9), P["stone_d"])
    line(d, (7, 4), (7, 9), P["stone_d"])
    line(d, (12, 9), (12, 15), P["stone_d"])
    tiles.append(t)
    # stone
    t, d = tile(3)
    d.rectangle((0, 0, 15, 15), fill=P["stone"])
    line(d, (0, 7), (15, 7), P["stone_d"])
    line(d, (0, 15), (15, 15), P["stone_d"])
    line(d, (5, 0), (5, 7), P["stone_d"])
    line(d, (11, 8), (11, 15), P["stone_d"])
    d.point([(2, 2), (9, 11), (13, 3)], fill=P["stone_l"])
    tiles.append(t)
    # plank (one-way)
    t, d = tile(4)
    d.rectangle((0, 0, 15, 4), fill=P["brown_l"], outline=OL)
    line(d, (1, 2), (14, 2), P["brown"])
    line(d, (3, 5), (3, 9), P["brown_d"])
    line(d, (12, 5), (12, 9), P["brown_d"])
    tiles.append(t)
    # vine
    t, d = tile(5)
    for x in (5, 10):
        for y in range(16):
            d.point((x + (1 if (y // 3) % 2 else 0), y), fill=P["green_d"])
    for y in (2, 8, 13):
        oval(d, (6, y, 9, y + 2), P["green_l"], outline=P["green_d"])
    tiles.append(t)
    # cave back
    t, d = tile(6)
    d.rectangle((0, 0, 15, 15), fill=c("3a2e2a"))
    for _ in range(10):
        d.point((rnd.randint(0, 15), rnd.randint(0, 15)), fill=c("2a201c"))
    tiles.append(t)
    # brick
    t, d = tile(7)
    d.rectangle((0, 0, 15, 15), fill=P["red_d"])
    for y in (0, 8):
        line(d, (0, y), (15, y), P["brown_d"])
    for x, y in ((4, 1), (12, 1), (0, 9), (8, 9)):
        line(d, (x, y), (x, y + 6), P["brown_d"])
    tiles.append(t)
    # thorns (visual for spike hazard)
    t, d = tile(8)
    for i in range(4):
        x = i * 4
        d.polygon([(x, 15), (x + 2, 5 + (i % 2) * 3), (x + 4, 15)], fill=P["brown_l"], outline=OL)
    line(d, (0, 15), (15, 15), P["green_d"])
    tiles.append(t)
    # dark dirt
    t, d = tile(9)
    d.rectangle((0, 0, 15, 15), fill=P["brown_d"])
    for _ in range(14):
        d.point((rnd.randint(0, 15), rnd.randint(0, 15)), fill=c("3f2817"))
    tiles.append(t)
    for i, t in enumerate(tiles):
        img.paste(t, (i * 16, 0))
    single("tiles", img)


# --------------------------------------------------------------------------------------------
# Overworld ground tiles — 16x16 strip
# --------------------------------------------------------------------------------------------
OW_TILES = ["grass", "grass2", "path", "water", "flowers", "bridge", "water2"]


def build_ow_tiles():
    img = new(16 * len(OW_TILES), 16)
    rnd = random.Random(2)
    out = []
    for name in OW_TILES:
        t = new(16, 16)
        d = ImageDraw.Draw(t)
        if name in ("grass", "grass2", "flowers"):
            d.rectangle((0, 0, 15, 15), fill=P["green"])
            for _ in range(8 if name != "grass2" else 14):
                x, y = rnd.randint(0, 14), rnd.randint(1, 15)
                d.point([(x, y), (x + 1, y - 1)], fill=P["green_l"] if rnd.random() < 0.5 else P["green_d"])
            if name == "flowers":
                for _ in range(4):
                    x, y = rnd.randint(1, 13), rnd.randint(1, 13)
                    col = rnd.choice([P["yellow"], P["pink"], P["white"]])
                    d.point([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], fill=col)
                    d.point((x, y), fill=P["orange"])
        elif name == "path":
            d.rectangle((0, 0, 15, 15), fill=P["straw"])
            for _ in range(12):
                d.point((rnd.randint(0, 15), rnd.randint(0, 15)), fill=P["brown_l"])
        elif name in ("water", "water2"):
            d.rectangle((0, 0, 15, 15), fill=P["water"])
            off = 0 if name == "water" else 4
            for y in (3, 10):
                line(d, ((2 + off) % 16, y), ((6 + off) % 16, y), P["water_l"])
                line(d, ((10 + off) % 16, y + 3), ((13 + off) % 16, y + 3), P["water_l"])
        elif name == "bridge":
            d.rectangle((0, 0, 15, 15), fill=P["brown_l"])
            for x in (0, 4, 8, 12):
                line(d, (x, 0), (x, 15), P["brown"])
            line(d, (0, 0), (15, 0), P["brown_d"])
            line(d, (0, 15), (15, 15), P["brown_d"])
        out.append(t)
    for i, t in enumerate(out):
        img.paste(t, (i * 16, 0))
    single("ow_tiles", img)


# --------------------------------------------------------------------------------------------
# Props (overworld + platformer)
# --------------------------------------------------------------------------------------------
def build_props():
    # tree 32x48, trunk base at bottom center
    for name, leaf, leaf_l in (("tree", P["green"], P["green_l"]), ("tree_dark", P["green_d"], P["green"])):
        im = new(32, 48)
        d = ImageDraw.Draw(im)
        d.polygon([(13, 47), (19, 47), (18, 30), (14, 30)], fill=P["brown"], outline=OL)
        line(d, (16, 33), (16, 45), P["brown_d"])
        for box in ((2, 14, 18, 32), (14, 14, 30, 32), (6, 2, 26, 24), (9, 18, 23, 34)):
            oval(d, box, leaf)
        for x, y in ((10, 7), (18, 10), (7, 19), (22, 20), (14, 26)):
            d.point([(x, y), (x + 1, y), (x, y + 1)], fill=leaf_l)
        single(name, im)
    # house 48x48
    im = new(48, 48)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 22, 41, 47), fill=P["cream"], outline=OL)
    for x in range(8, 41, 6):
        line(d, (x, 23), (x, 46), P["skin_d"])
    d.polygon([(1, 24), (24, 3), (47, 24)], fill=P["red"], outline=OL)
    for y in range(9, 24, 4):
        line(d, (24 - (y - 3), y), (24 + (y - 3), y), P["red_d"])
    d.rectangle((20, 33, 28, 47), fill=P["brown"], outline=OL)
    d.point((26, 40), fill=P["yellow"])
    d.rectangle((9, 28, 16, 35), fill=P["water_l"], outline=OL)
    d.rectangle((32, 28, 39, 35), fill=P["water_l"], outline=OL)
    line(d, (12, 28), (12, 35), OL)
    line(d, (35, 28), (35, 35), OL)
    d.rectangle((33, 6, 38, 16), fill=P["brick"] if "brick" in P else P["red_d"], outline=OL)
    single("house", im)
    # rock / bush
    im = new(16, 12)
    d = ImageDraw.Draw(im)
    oval(d, (0, 2, 15, 11), P["stone"])
    d.point([(4, 4), (5, 4), (9, 5)], fill=P["stone_l"])
    single("rock", im)
    im = new(16, 14)
    d = ImageDraw.Draw(im)
    oval(d, (0, 3, 9, 13), P["green_d"])
    oval(d, (6, 3, 15, 13), P["green_d"])
    oval(d, (3, 0, 12, 10), P["green"])
    d.point([(5, 3), (9, 4)], fill=P["green_l"])
    single("bush", im)
    # fence 16x16
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    for x in (2, 12):
        d.rectangle((x, 3, x + 2, 15), fill=P["brown_l"], outline=OL)
    d.rectangle((0, 6, 15, 8), fill=P["brown"], outline=OL)
    single("fence", im)
    # bench (save point) 24x16
    im = new(24, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((1, 3, 22, 6), fill=P["brown_l"], outline=OL)
    d.rectangle((1, 8, 22, 10), fill=P["brown_l"], outline=OL)
    for x in (3, 18):
        d.rectangle((x, 10, x + 2, 15), fill=P["brown_d"], outline=OL)
    d.point([(11, 1), (12, 0), (13, 1), (12, 2)], fill=P["yellow"])
    single("bench", im)
    # sign 16x16
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 8, 8, 15), fill=P["brown_d"])
    d.rectangle((1, 1, 14, 9), fill=P["brown_l"], outline=OL)
    for y in (3, 6):
        line(d, (3, y), (12, y), P["brown_d"])
    single("sign", im)
    # level flags 16x24 x2 frames in different colors
    for name, col in (("flag_red", P["red"]), ("flag_gold", P["yellow"]), ("flag_blue", P["blue"]), ("flag_gray", P["stone"])):
        sh = Sheet(name, 16, 24)
        fr = []
        for k in range(2):
            im = new(16, 24)
            d = ImageDraw.Draw(im)
            oval(d, (1, 19, 14, 23), P["brown_d"], outline=P["brown_d"])
            line(d, (4, 22), (4, 1), OL, 1)
            if k == 0:
                d.polygon([(5, 1), (15, 4), (5, 9)], fill=col, outline=OL)
            else:
                d.polygon([(5, 1), (14, 6), (5, 9)], fill=col, outline=OL)
            d.point((4, 0), fill=P["yellow"])
            fr.append(im)
        sh.add("default", fr, fps=3)
        sh.save()
    # tower (locked stage) 32x40
    im = new(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 12, 25, 39), fill=P["stone"], outline=OL)
    for x in range(6, 26, 5):
        d.rectangle((x, 8, x + 2, 12), fill=P["stone"], outline=OL)
    d.rectangle((13, 27, 18, 39), fill=P["dark"], outline=OL)
    d.rectangle((14, 17, 17, 21), fill=P["yellow"], outline=OL)
    for _ in range(6):
        x = random.randint(6, 24)
        line(d, (x, 39), (x + random.randint(-3, 3), 25 + random.randint(0, 8)), P["green_d"], 1)
    single("tower", im)
    # twig 16x8
    im = new(16, 8)
    d = ImageDraw.Draw(im)
    line(d, (1, 6), (14, 4), P["brown_d"], 2)
    line(d, (6, 5), (9, 1), P["brown_d"], 1)
    d.point([(9, 0), (10, 1)], fill=P["green"])
    single("twig", im)
    # seed turret (plant pod) 16x16, 2 frames
    sh = Sheet("turret", 16, 16)
    fr = []
    for k in range(2):
        im = new(16, 16)
        d = ImageDraw.Draw(im)
        d.rectangle((5, 11, 10, 15), fill=P["brown"], outline=OL)
        oval(d, (1, 2 + k, 14, 13), P["purple"])
        oval(d, (9, 5 + k, 15, 10 + k), P["purple_d"] if k == 0 else P["dark"])
        d.point([(4, 5), (6, 4)], fill=P["pink"])
        fr.append(im)
    sh.add("idle", [fr[0]], fps=1)
    sh.add("shoot", [fr[1], fr[0]], fps=8, loop=False)
    sh.save()
    # seed projectile 8x8
    im = new(8, 8)
    d = ImageDraw.Draw(im)
    oval(d, (0, 1, 7, 6), P["yellow"])
    d.point([(2, 2), (3, 2)], fill=P["white"])
    single("seed", im)
    # acorn 8x10
    im = new(8, 10)
    d = ImageDraw.Draw(im)
    oval(d, (0, 3, 7, 9), P["brown_l"])
    d.rectangle((0, 2, 7, 4), fill=P["brown_d"], outline=OL)
    d.point((4, 0), fill=OL)
    single("acorn", im)
    # dropper nest (ceiling) 16x10
    im = new(16, 10)
    d = ImageDraw.Draw(im)
    oval(d, (0, 0, 15, 9), P["brown"])
    for x in range(2, 14, 3):
        line(d, (x, 1), (x + 2, 8), P["brown_d"])
    single("nest", im)
    # checkpoint bench in level reuses "bench"; goal flag 16x32
    sh = Sheet("goal", 16, 32)
    fr = []
    for k in range(2):
        im = new(16, 32)
        d = ImageDraw.Draw(im)
        line(d, (3, 31), (3, 1), OL, 2)
        d.polygon([(5, 2), (15, 6 + k), (5, 11)], fill=P["yellow"], outline=OL)
        d.point([(8, 6), (9, 6)], fill=P["red"])
        oval(d, (1, 0, 5, 3), P["yellow"])
        fr.append(im)
    sh.add("default", fr, fps=3)
    sh.save()
    # boss gate 32x48
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 8, 31, 47), fill=P["stone_d"], outline=OL)
    d.pieslice((0, 0, 31, 22), 180, 360, fill=P["stone_d"], outline=OL)
    d.rectangle((6, 14, 25, 47), fill=P["dark"], outline=OL)
    d.pieslice((6, 6, 25, 24), 180, 360, fill=P["dark"], outline=OL)
    for i in range(6):
        x = 6 + i * 4
        line(d, (x, 47), (x + 3, 12 + (i % 3) * 5), P["green_d"], 1)
        d.point((x + 2, 18 + (i % 3) * 5), fill=P["brown_l"])
    d.point([(13, 24), (18, 24)], fill=P["red"])
    single("boss_gate", im)


# --------------------------------------------------------------------------------------------
# Items / UI / FX
# --------------------------------------------------------------------------------------------
def build_items():
    sh = Sheet("items", 16, 16)
    imgs = []
    # 0 berry tonic
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 1, 9, 4), fill=P["brown_l"], outline=OL)
    oval(d, (2, 4, 13, 15), P["red"])
    oval(d, (4, 6, 7, 9), P["pink"], outline=P["pink"])
    imgs.append(im)
    # 1 gale boots
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(3, 2), (8, 2), (8, 10), (14, 11), (14, 14), (3, 14)], fill=P["blue"], outline=OL)
    line(d, (4, 6), (7, 6), P["water_l"])
    d.polygon([(0, 4), (3, 6), (0, 8)], fill=P["white"], outline=OL)
    imgs.append(im)
    # 2 thorn charm
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    line(d, (4, 0), (8, 4), P["yellow_d"])
    line(d, (12, 0), (8, 4), P["yellow_d"])
    oval(d, (3, 4, 12, 13), P["green"])
    for a in range(6):
        ang = a * math.tau / 6
        d.point((round(7.5 + math.cos(ang) * 7), round(8.5 + math.sin(ang) * 7)), fill=P["brown_l"])
    d.point([(6, 7), (7, 7)], fill=P["green_l"])
    imgs.append(im)
    # 3 rusty key
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    oval(d, (1, 1, 7, 7), P["yellow_d"])
    d.point((4, 4), fill=(0, 0, 0, 0))
    line(d, (6, 6), (14, 14), P["yellow_d"], 2)
    line(d, (11, 13), (13, 11), P["yellow_d"], 2)
    imgs.append(im)
    # 4 heart seed
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 14), (1, 7), (1, 4), (4, 1), (8, 4), (12, 1), (15, 4), (15, 7)], fill=P["red"], outline=OL)
    line(d, (8, 4), (8, 0), P["green_d"])
    d.point([(9, 0), (10, 0)], fill=P["green"])
    d.point([(4, 4), (4, 5)], fill=P["pink"])
    imgs.append(im)
    sh.add("default", imgs, fps=1)
    sh.save()

    # hearts 12x12: full / empty
    sh = Sheet("heart", 12, 12)
    hs = []
    for full in (True, False):
        im = new(12, 12)
        d = ImageDraw.Draw(im)
        pts = [(6, 11), (0, 5), (0, 3), (2, 1), (4, 1), (6, 3), (8, 1), (10, 1), (11, 3), (11, 5)]
        d.polygon(pts, fill=P["red"] if full else P["dark"], outline=OL if full else P["stone_d"])
        if full:
            d.point([(2, 3), (3, 3), (2, 4)], fill=P["pink"])
        hs.append(im)
    sh.add("default", hs, fps=1)
    sh.save()

    # fx: hit spark 24x24 x4, dust 16x16 x3
    sh = Sheet("fx_spark", 24, 24)
    fr = []
    for k in range(4):
        im = new(24, 24)
        d = ImageDraw.Draw(im)
        r = 3 + k * 3
        for a in range(8):
            ang = a * math.tau / 8 + k * 0.2
            r0 = max(1, r - 5)
            line(d, (12 + math.cos(ang) * r0, 12 + math.sin(ang) * r0),
                 (12 + math.cos(ang) * r, 12 + math.sin(ang) * r), P["yellow"] if k < 2 else P["cream"], 2 if k < 2 else 1)
        if k < 2:
            oval(d, (12 - 3 + k, 12 - 3 + k, 12 + 3 - k, 12 + 3 - k), P["white"], outline=P["yellow"])
        fr.append(im)
    sh.add("default", fr, fps=20, loop=False)
    sh.save()
    sh = Sheet("fx_dust", 16, 16)
    fr = []
    for k in range(3):
        im = new(16, 16)
        d = ImageDraw.Draw(im)
        r = 2 + k * 2
        col = (244, 230, 196, 255 - k * 70)
        d.ellipse((8 - r, 14 - r, 8 + r, 15), fill=col)
        fr.append(im)
    sh.add("default", fr, fps=12, loop=False)
    sh.save()

    # soft shadow + cloud shadow
    im = new(16, 6)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 15, 5), fill=(20, 10, 5, 90))
    single("shadow", im)
    im = new(96, 48)
    d = ImageDraw.Draw(im)
    for box in ((0, 14, 50, 46), (30, 0, 80, 40), (50, 16, 95, 47)):
        d.ellipse(box, fill=(20, 30, 40, 50))
    single("cloud_shadow", im)

    # root spike (boss hazard) 16x48 and warning 16x8
    im = new(16, 48)
    d = ImageDraw.Draw(im)
    d.polygon([(1, 47), (8, 0), (15, 47)], fill=P["brown"], outline=OL)
    line(d, (8, 6), (8, 44), P["brown_d"])
    d.polygon([(4, 30), (0, 24), (5, 26)], fill=P["green_d"], outline=OL)
    d.polygon([(12, 20), (15, 14), (11, 16)], fill=P["green_d"], outline=OL)
    single("root_spike", im)
    im = new(24, 8)
    d = ImageDraw.Draw(im)
    for k in range(5):
        x = 2 + k * 5
        d.polygon([(x, 7), (x + 2, 2 + (k % 2) * 2), (x + 4, 7)], fill=P["brown_d"])
    single("root_warning", im)
    # shockwave 24x16
    im = new(24, 16)
    d = ImageDraw.Draw(im)
    for k in range(4):
        x = k * 6
        d.polygon([(x, 15), (x + 3, 2 + k * 2), (x + 6, 15)], fill=P["cream"] if k % 2 else P["straw"], outline=OL)
    single("shockwave", im)


# --------------------------------------------------------------------------------------------
# Parallax backgrounds — 640 wide, seamless horizontally
# --------------------------------------------------------------------------------------------
def seamless_noise(x, period, seeds):
    v = 0.0
    for k, (amp, freq, ph) in enumerate(seeds):
        v += amp * math.sin(x / period * math.tau * freq + ph)
    return v


def build_backgrounds():
    W = 640
    # sky gradient + sun + clouds
    im = Image.new("RGBA", (W, 360))
    d = ImageDraw.Draw(im)
    top, bot = c("7fc4e0"), c("f7e2b0")
    for y in range(360):
        t = y / 359
        t = round(t * 12) / 12  # banded = pixel-art dithering feel
        col = tuple(round(top[i] * (1 - t) + bot[i] * t) for i in range(3)) + (255,)
        line(d, (0, y), (W, y), col)
    d.ellipse((470, 40, 530, 100), fill=c("fff2c4"))
    d.ellipse((478, 48, 522, 92), fill=c("ffe08a"))
    rnd = random.Random(11)
    for _ in range(7):
        cx, cy = rnd.randint(0, W), rnd.randint(30, 150)
        for k in range(4):
            r = rnd.randint(10, 20)
            for ox in (0, -W, W):
                d.ellipse((cx + ox + k * 14 - r, cy - r // 2, cx + ox + k * 14 + r, cy + r // 2 + 4), fill=c("fdf7e8"))
    im.save(os.path.join(BGD, "sky.png"))

    def ridge(name, h, base, amp, seeds, fill, fill2, deco=None):
        im = new(W, h)
        d = ImageDraw.Draw(im)
        for x in range(W):
            y = base + seamless_noise(x, W, seeds) * amp
            line(d, (x, int(y)), (x, h), fill)
            line(d, (x, int(y)), (x, int(y) + 2), fill2)
        if deco:
            deco(d, im)
        im.save(os.path.join(BGD, name + ".png"))

    ridge("hills_far", 220, 90, 30, [(1, 2, 0.3), (0.5, 5, 1.1), (0.25, 11, 2.0)], c("8db7a8"), c("a7cbbb"))

    def trees_deco(d, im):
        rnd = random.Random(5)
        for i in range(26):
            x = rnd.randint(0, W)
            hgt = rnd.randint(50, 90)
            for ox in (0, -W, W):
                xx = x + ox
                d.polygon([(xx - 14, 200), (xx, 200 - hgt), (xx + 14, 200)], fill=c("4f7d5a"))
                d.polygon([(xx - 10, 200 - hgt // 2), (xx, 200 - hgt - 8), (xx + 10, 200 - hgt // 2)], fill=c("5f8f66"))

    ridge("hills_mid", 240, 160, 18, [(1, 3, 0.9), (0.6, 7, 0.2)], c("4f7d5a"), c("6a9a6e"), trees_deco)

    def near_deco(d, im):
        rnd = random.Random(9)
        for i in range(14):
            x = rnd.randint(0, W)
            for ox in (0, -W, W):
                xx = x + ox
                d.rectangle((xx - 4, 110, xx + 4, 240), fill=c("3a2a20"))
                for box in ((xx - 30, 50, xx + 30, 120), (xx - 22, 30, xx + 18, 90), (xx - 10, 60, xx + 36, 125)):
                    d.ellipse(box, fill=c("2f5a3a"))
                for _ in range(6):
                    px, py = xx + rnd.randint(-24, 24), rnd.randint(40, 110)
                    d.point([(px, py), (px + 1, py)], fill=c("3f7048"))

    ridge("trees_near", 260, 200, 10, [(1, 4, 0.0), (0.4, 9, 1.0)], c("2f5a3a"), c("3f7048"), near_deco)

    # foreground: hanging leaves at top and grass/bushes at the bottom, mostly transparent
    im = new(W, 360)
    d = ImageDraw.Draw(im)
    rnd = random.Random(21)
    for i in range(9):
        x = rnd.randint(0, W)
        for ox in (0, -W, W):
            xx = x + ox
            for k in range(rnd.randint(2, 4)):
                r = rnd.randint(16, 30)
                d.ellipse((xx + k * 18 - r, -r, xx + k * 18 + r, r + rnd.randint(0, 10)), fill=c("1d3324"))
            vx = xx + rnd.randint(-6, 30)
            line(d, (vx, 0), (vx, rnd.randint(40, 90)), c("1d3324"), 2)
    for i in range(10):
        x = rnd.randint(0, W)
        for ox in (0, -W, W):
            xx = x + ox
            for k in range(3):
                r = rnd.randint(14, 26)
                d.ellipse((xx + k * 16 - r, 360 - r, xx + k * 16 + r, 360 + r), fill=c("1d3324"))
    im.save(os.path.join(BGD, "foreground.png"))

    # cave far wall (for darker sections / arena)
    im = Image.new("RGBA", (W, 360), c("2b2230"))
    d = ImageDraw.Draw(im)
    for i in range(40):
        x, y = rnd.randint(0, W), rnd.randint(0, 360)
        d.ellipse((x - 20, y - 12, x + 20, y + 12), fill=c("332838"))
    im.save(os.path.join(BGD, "dusk_sky.png"))


def build_title_art():
    # small decorative banner used behind the title
    im = new(160, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 8), (10, 0), (150, 0), (160, 8), (160, 32), (150, 40), (10, 40), (0, 32)], fill=P["red_d"], outline=OL)
    d.polygon([(4, 9), (12, 3), (148, 3), (156, 9), (156, 31), (148, 37), (12, 37), (4, 31)], fill=P["red"], outline=P["yellow"])
    single("banner", im)


def write_meta():
    body = json.dumps(META, indent="\t")
    with open(META_OUT, "w") as f:
        f.write("# AUTO-GENERATED by tools/gen_assets.py — frame layout of every sprite sheet.\n")
        f.write("# If you replace a PNG with hand-made art, keep the frame size/order or edit this file.\n")
        f.write("class_name SpriteMeta\n\n")
        f.write("const SHEETS := " + body + "\n")


if __name__ == "__main__":
    build_player()
    build_chibis()
    build_thornling()
    build_boss()
    build_dummy()
    build_tiles()
    build_ow_tiles()
    build_props()
    build_items()
    build_backgrounds()
    build_title_art()
    write_meta()
    print(f"Generated {len(META)} sprite entries.")
