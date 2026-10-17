"""tilemap.py - assemble one Arena map from tiles built out of the bricks kit.

The idea (Chalce, 2026-10-17): tiles are grouped; the map picks the best
fitting tile next to the last one and keeps that group going for a while,
then an obvious built wall ends the run and the next group starts. The seed
is fixed, so this bakes ONE map - it does not change per load.

Everything is data in the .blend, so tiles can be edited or added by hand:

    TILES (collection, excluded from the view layer)
      <group>            e.g. "jump"
        <tile>           a collection of kit pieces around (0,0), 16 x 16 m
                         custom props: edges "N,E,S,W", order, weight

  edges   floor height (m) where the tile meets each neighbour, or X when that
          side cannot be walked through (half ramp, half floor). Two tiles join
          openly only when their facing edges are the same height.
  order   inside one run, tiles with a higher order are preferred after lower
          ones - jump gaps get wider as you go.
  weight  how often the tile is picked against the others in its group.

A tile's "flow" is south -> north: you enter on S and leave on N. The
generator turns tiles in 90 degree steps so that matches the run.

Run inside Blender (Claude Bridge or the Text editor):
    exec(open(r"...\\tilemap.py").read()); build(kit_path, seed=7)
"""
import math
import random

import bpy

T = 16.0                      # tile size, metres
HALF = T / 2
WALL_T = 1.0                  # barrier thickness
WALL_UP = 1.6                 # inner barrier above the higher floor: over the
                              # 1.26 m jump, under the 1.65 m eye - you can't
                              # cross it but you can see the next area
EDGE_UP = 4.0                 # the map's outer wall
DOOR = 4.0                    # doorway width in a barrier
X = None                      # a closed edge

DIRS = [(0, 1), (1, 0), (0, -1), (-1, 0)]   # N E S W, matching the edges order

# kit object names in bricks.blend -> short names used below
KIT = {
    "cube": "cubeMain",            # 2x2x2
    "slab": "Slab_1-col",          # 2x2x1, also the generic box
    "wall": "wall_obstacle_1-col", # 1x2x2
    "wall_low": "wall_obstacle_2-col",  # 1x2x1
    "post": "wall_obstacle_3-col", # 0.5x2x1
    "ramp45": "ramp_1-col",        # 2 deep, rises 2 toward +Y
    "ramp63": "ramp_2-col",        # 1 deep, rises 2
    "ramp27": "ramp_3-col",        # 2 deep, rises 1
    "kicker": "ramp_4-col",        # 1 deep, rises 1
}

COLOURS = {
    "floor":   (0.23, 0.26, 0.31),
    "deck":    (0.34, 0.38, 0.45),
    "barrier": (0.11, 0.13, 0.18),
    "cover":   (0.55, 0.59, 0.66),
    "ramp":    (0.17, 0.66, 0.62),
    "ok":      (0.25, 0.75, 0.42),    # reachable with the GDD numbers
    "edge":    (0.88, 0.63, 0.19),    # right at the limit
    "no":      (0.85, 0.33, 0.31),    # past the limit, on purpose
    "marker":  (0.92, 0.92, 0.95),
}

# GDD "Player limits": jump 1.26 m high, 12.8 m sprint jump, 16.7 m slide.
JUMP_H, JUMP_L, SLIDE_L = 1.26, 12.8, 16.7


# ---------------------------------------------------------------- helpers

def _mat(role):
    name = "arena_" + role
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        c = COLOURS[role]
        m.diffuse_color = (*c, 1.0)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*c, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
    return m


def _coll(name, parent):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        parent.children.link(c)
    return c


def _clear(coll):
    for ch in list(coll.children):
        _clear(ch)
        bpy.data.collections.remove(ch)
    for o in list(coll.objects):
        bpy.data.objects.remove(o)


class Tile:
    """Collects the kit pieces of one tile while it is being authored."""

    def __init__(self, coll):
        self.coll = coll

    def piece(self, kind, loc, scale=(1, 1, 1), rot=0.0, role="cover"):
        src = bpy.data.objects[KIT[kind]]
        o = bpy.data.objects.new(f"{self.coll.name}.{kind}", src.data)
        o.location, o.scale = loc, scale
        o.rotation_euler = (0, 0, math.radians(rot))
        # the kit meshes are shared, so the colour lives on the object
        if not o.material_slots:
            o.data.materials.append(None)
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = _mat(role)
        o["role"] = role
        self.coll.objects.link(o)
        return o

    def box(self, x0, x1, y0, y1, z0, z1, role="cover"):
        """An axis-aligned box from the kit slab (2x2x1, origin bottom centre)."""
        return self.piece("slab", ((x0 + x1) / 2, (y0 + y1) / 2, z0),
                          ((x1 - x0) / 2, (y1 - y0) / 2, z1 - z0), role=role)

    def ramp(self, x0, x1, y0, y1, z0, rise, kind="ramp27", role="ramp", rot=0.0):
        """A ramp across x0..x1 climbing `rise` from y0 to y1 (toward +Y).
        rot=180 turns a centred ramp (ramp27/ramp45) to climb toward -Y."""
        deep, high = {"ramp27": (2, 1), "ramp45": (2, 2), "ramp63": (1, 2), "kicker": (1, 1)}[kind]
        cy = (y0 + y1) / 2 if deep == 2 else y0
        return self.piece(kind, ((x0 + x1) / 2, cy, z0),
                          ((x1 - x0) / 2, (y1 - y0) / deep, rise / high), rot=rot, role=role)

    def floor(self, y0=-HALF, y1=HALF, x0=-HALF, x1=HALF, h=0.0, role=None):
        return self.box(x0, x1, y0, y1, -1.0, h, role or ("deck" if h > 0 else "floor"))

    def label(self, text, loc, size=1.2):
        cu = bpy.data.curves.new(f"lbl_{self.coll.name}", "FONT")
        cu.body, cu.size, cu.align_x = text, size, "CENTER"
        o = bpy.data.objects.new(f"lbl_{self.coll.name}", cu)
        o.location = loc
        o.data.materials.append(_mat("marker"))
        self.coll.objects.link(o)


# ---------------------------------------------------------------- the tile set

def _tile(lib, group, name, edges, order=0, weight=1.0):
    g = _coll(group, lib)
    c = bpy.data.collections.new(name)
    g.children.link(c)
    c["group"], c["order"], c["weight"] = group, order, weight
    c["edges"] = ",".join("X" if e is X else f"{e:g}" for e in edges)
    return Tile(c)


def author_tiles(lib):
    """The starter tile set. Every tile is plain kit pieces - edit freely."""
    # --- sprint: open ground with posts every 4 m to read speed against
    t = _tile(lib, "sprint", "sprint_open", (0, 0, 0, 0))
    t.floor()
    for y in range(-6, 8, 4):
        for x in (-7.5, 7.5):
            t.piece("post", (x, y, 0), role="marker")

    t = _tile(lib, "sprint", "sprint_slalom", (0, 0, 0, 0))
    t.floor()
    for i, y in enumerate(range(-5, 7, 3)):
        t.piece("wall", ((-2.5 if i % 2 else 2.5), y, 0), (1, 1, 1), rot=90)

    # --- jump: a gap across the whole tile, wider as the run goes on.
    # Green = makeable, amber = right at the limit, red = past it on purpose.
    for w in (2, 4, 6, 8, 10, 12):
        role = "ok" if w <= JUMP_L - 2 else "edge"
        t = _tile(lib, "jump", f"jump_gap_{w}", (0, 0, 0, 0), order=w)
        t.floor(-HALF, -w / 2)
        t.floor(w / 2, HALF, role=role)
        t.label(f"{w} m", (0, -w / 2 - 2, 0.05))
    # 14 m cannot be made (12.8 m limit): half the tile is a walkway round it
    t = _tile(lib, "jump", "jump_gap_14", (0, 0, 0, 0), order=14, weight=0.6)
    t.floor(-HALF, -7, 0, HALF)
    t.floor(7, HALF, 0, HALF, role="no")
    t.floor(x0=-HALF, x1=0)
    t.label("14 m (no)", (4, -9, 0.05))

    t = _tile(lib, "jump", "jump_islands", (0, 0, 0, 0), order=5, weight=0.8)
    t.floor(-HALF, -4)
    t.floor(4, HALF)
    t.box(-5, -1, -1, 3, -1, 0.5, "ok")       # 3 m hop, half a metre up
    t.box(1, 5, -2, 2, -1, 1.0, "ok")         # side island, one metre up

    # --- steps: what a 1.26 m jump clears
    t = _tile(lib, "steps", "steps_heights", (0, 0, 0, 0))
    t.floor()
    for x, h in zip((-6, -3, 0, 3, 6), (0.5, 1.0, 1.25, 1.5, 2.0)):
        role = "ok" if h < JUMP_H - 0.05 else ("edge" if h <= JUMP_H else "no")
        t.box(x - 1, x + 1, -1, 1, 0, h, role)
        t.label(f"{h:g}", (x, -2.5, 0.05), 0.8)

    t = _tile(lib, "steps", "steps_climb", (2, X, 0, X), weight=0.7)
    t.floor(-HALF, 0)
    t.box(-4, 4, -4, 0, 0, 1.0, "ok")         # two 1 m jumps up to the deck
    t.floor(0, HALF, h=2.0)

    # --- slide: a lane between low walls, one slide (16.7 m) long
    t = _tile(lib, "slide", "slide_lane", (0, 0, 0, 0))
    t.floor()
    for y in range(-7, 9, 2):
        for x in (-3.5, 3.5):
            t.piece("wall_low", (x, y, 0))
    t.piece("post", (0, -7.5, 0), (2, 0.1, 0.05), rot=90, role="marker")

    t = _tile(lib, "slide", "slide_downhill", (0, X, 2, X), weight=0.6)
    t.floor(-HALF, -4, h=2.0)                  # enter high, slide down the slope
    t.floor(-4, HALF)
    t.ramp(-4, 4, -4, 4, 0, 2.0, rot=180)

    # --- ramp: the ways between ground (0) and decks (2)
    t = _tile(lib, "ramp", "ramp_gentle", (2, X, 0, X))
    t.floor(-HALF, 4)
    t.ramp(-4, 4, -4, 4, 0, 2.0)               # 8 m long, ~14 degrees
    t.floor(4, HALF, h=2.0)

    t = _tile(lib, "ramp", "ramp_steep", (2, X, 0, X), weight=0.7)
    t.floor(-HALF, 2)
    t.ramp(-2, 2, 0, 2, 0, 2.0, kind="ramp45")
    t.floor(2, HALF, h=2.0)

    t = _tile(lib, "ramp", "ramp_kickers", (0, 0, 0, 0), weight=0.8)
    t.floor()
    t.ramp(-5, -1, -4, -3, 0, 1.0, kind="kicker")   # launch onto the ledge
    t.box(-5, -1, 0, 4, 0, 1.0, "ok")
    t.ramp(1, 5, -4, -3, 0, 2.0, kind="ramp63")     # too steep to run up
    t.box(1, 5, -3, 4, 0, 2.0, "no")

    # --- deck: the raised level
    t = _tile(lib, "deck", "deck_open", (2, 2, 2, 2))
    t.floor(h=2.0)

    t = _tile(lib, "deck", "deck_cover", (2, 2, 2, 2))
    t.floor(h=2.0)
    t.piece("wall", (-3, 2, 2), rot=0)
    t.piece("wall", (3, -2, 2), rot=0)
    t.piece("cube", (0, 5, 2))

    t = _tile(lib, "deck", "deck_drop", (0, X, 2, X), weight=0.7)
    t.floor(-HALF, 0, h=2.0)                   # walk off the end: a 2 m drop
    t.floor(0, HALF)

    # --- cover: things to fight around
    t = _tile(lib, "cover", "cover_lines", (0, 0, 0, 0))
    t.floor()
    t.piece("wall", (-4, 0, 0), (1, 2, 1))
    t.piece("wall", (4, 3, 0), (1, 1.5, 1))
    t.piece("wall_low", (0, -4, 0), (1, 1.5, 1), rot=90)

    t = _tile(lib, "cover", "cover_blocks", (0, 0, 0, 0))
    t.floor()
    t.piece("cube", (-4, -4, 0))
    t.piece("cube", (4, 4, 0))
    t.box(-1, 1, -1, 1, 0, 0.5, "ok")
    t.piece("wall_low", (3, -4, 0), rot=90)
    t.piece("wall_low", (-3, 4, 0), rot=90)

    t = _tile(lib, "cover", "cover_tower", (0, 0, 0, 0), weight=0.7)
    t.floor()
    t.box(-2, 2, -2, 2, 0, 1.0, "ok")
    t.box(-1, 1, -1, 1, 1.0, 2.0, "ok")
    t.piece("wall_low", (-5, 5, 0), rot=45)
    t.piece("wall_low", (5, -5, 0), rot=45)


# ---------------------------------------------------------------- generation

def _edges(coll, r):
    e = [X if v == "X" else float(v) for v in coll["edges"].split(",")]
    return [e[(j + r) % 4] for j in range(4)]


def _library(lib):
    groups = {}
    for g in lib.children:
        groups[g.name] = [c for c in g.children]
    return groups


RUNS = {  # group: (shortest, longest) run in tiles, pick weight
    "sprint": (2, 3, 1.0), "jump": (3, 5, 1.2), "steps": (1, 2, 0.8),
    "slide": (2, 3, 0.8), "ramp": (1, 1, 1.3), "deck": (2, 4, 1.0), "cover": (2, 4, 1.2),
}


def generate(groups, size, seed):
    """Fill a size x size grid with runs of tiles. Returns cells, links."""
    rng = random.Random(seed)
    cells = {}            # (x,y) -> dict(tile, r, edges, run)
    links = set()         # frozenset({a,b}) joined openly inside a run
    junctions = set()     # frozenset({a,b}) where one run hands over to the next
    used = {g: 0 for g in groups}
    tile_used = {}
    inside = lambda c: 0 <= c[0] < size and 0 <= c[1] < size
    free = lambda c: inside(c) and c not in cells

    def candidates(cell, frm, d, group, last_order, last_tile=None):
        """Every (tile, turn) of the group that fits here, best first."""
        out = []
        ex = DIRS.index(d)                         # the side the run leaves by
        nxt = (cell[0] + d[0], cell[1] + d[1])
        for tile in groups[group]:
            for r in range(4):
                e = _edges(tile, r)
                score = rng.random() * 0.5
                if frm is not None:
                    fi = DIRS.index((frm[0] - cell[0], frm[1] - cell[1]))
                    want = cells[frm]["edges"][(fi + 2) % 4]
                    if e[fi] is X or e[fi] != want:
                        continue
                    if (fi + r) % 4 == 2:          # entered on the tile's own south
                        score += 3
                    # a tile that changes level is only worth it with
                    # somewhere to go at the new level
                    if e[ex] != e[fi] and not (e[ex] is not X and free(nxt)):
                        continue
                if e[ex] is not X and free(nxt):
                    score += 1.5                   # the run can keep going
                o = tile["order"]
                if o > last_order:                 # the next step up, not a leap
                    score += max(0.0, 2.0 - 0.25 * (o - last_order))
                if tile == last_tile:
                    score -= 2.0
                score -= 0.6 * tile_used.get(tile.name, 0)
                score *= tile["weight"]
                out.append((score, tile, r, e))
        out.sort(key=lambda t: -t[0])
        return out

    def pick_group(prev):
        """Groups to try, weighted, least used first; the last one only as a
        fallback (a deck surrounded by walls has nowhere else to go)."""
        options = [g for g in groups if g != prev]
        w = [RUNS[g][2] / (1 + used[g]) for g in options]
        order = []
        while options:
            g = rng.choices(options, w)[0]
            i = options.index(g)
            order.append(g); options.pop(i); w.pop(i)
        return order + ([prev] if prev in groups else [])

    run = 0
    start = (0, 0)
    frm = None
    d = (0, 1)
    prev_group = None
    tail = start
    for _guard in range(size * size * 4):
        if len(cells) >= size * size:
            break
        placed = False
        for group in pick_group(prev_group):
            lo, hi, _ = RUNS[group]
            cands = candidates(start, frm, d, group, -1)
            if not cands:
                continue
            length = rng.randint(lo, hi)
            # the same group again just carries on the old run: no wall between
            rid = run - 1 if group == prev_group else run
            cell, last, last_order, cd = start, frm, -1, d
            for _ in range(length):
                if not cands:
                    break
                _, tile, r, e = cands[0]
                cells[cell] = dict(tile=tile, r=r, edges=e, run=rid)
                tile_used[tile.name] = tile_used.get(tile.name, 0) + 1
                tail = cell
                if last is not None:
                    (links if cells[last]["run"] == rid else junctions).add(frozenset((cell, last)))
                last_order, last = tile["order"], cell
                # keep heading the same way; turn when blocked
                sides = [(cd[1], -cd[0]), (-cd[1], cd[0])]
                rng.shuffle(sides)
                nxt = None
                for t in [cd] + sides:
                    c2 = (cell[0] + t[0], cell[1] + t[1])
                    if inside(c2) and c2 not in cells and e[DIRS.index(t)] is not X:
                        nxt, cd = c2, t
                        break
                if nxt is None:
                    break
                cands = candidates(nxt, cell, cd, group, last_order, tile)
                cell = nxt
            used[group] += 1
            prev_group, run, placed = group, rid + 1, True
            break
        # next run starts next to the end of this one if it can
        start = None
        for c in [tail] + sorted(cells, key=lambda c: -cells[c]["run"]):
            e = cells[c]["edges"]
            opts = [(i, (c[0] + dx, c[1] + dy)) for i, (dx, dy) in enumerate(DIRS)
                    if e[i] is not X and inside((c[0] + dx, c[1] + dy)) and (c[0] + dx, c[1] + dy) not in cells]
            if opts:
                i, start = rng.choice(opts)
                frm, d = c, DIRS[i]
                break
        if start is None:
            # whatever is left is only reachable through closed edges
            left = [(x, y) for x in range(size) for y in range(size) if (x, y) not in cells]
            if not left:
                break
            start, frm, d = left[0], None, (0, 1)
        if not placed and frm is None:
            # nothing fits even with no neighbour: give up on this cell
            tile = groups["cover"][0]
            cells[start] = dict(tile=tile, r=0, edges=_edges(tile, 0), run=run)
            run += 1
    return cells, links, junctions


# ---------------------------------------------------------------- building

def _wall(coll, x0, x1, y0, y1, z0, z1, n):
    """One merged barrier box between world points (kit wall mesh, 1x2x2)."""
    src = bpy.data.objects[KIT["wall"]]
    o = bpy.data.objects.new(f"barrier.{n}", src.data)
    sx, sy = x1 - x0, y1 - y0
    o.location = ((x0 + x1) / 2, (y0 + y1) / 2, z0)
    if sx > sy:   # running along X: turn the wall (its length is local Y)
        o.rotation_euler.z = math.pi / 2
        o.scale = (sy, sx / 2, (z1 - z0) / 2)
    else:
        o.scale = (sx, sy / 2, (z1 - z0) / 2)
    o.material_slots[0].link = "OBJECT"
    o.material_slots[0].material = _mat("barrier")
    o["role"] = "barrier"
    coll.objects.link(o)


def _edge_wall(coll, cell, i, ea, eb, kind, gap, n, up=WALL_UP):
    """kind: 'solid', 'door' (gap at floor level) or 'drop' (gap = a ledge
    you can only go down). `gap` is where the 4 m opening starts along the edge."""
    cx, cy = cell[0] * T, cell[1] * T
    hs = [e for e in (ea, eb) if e is not X]
    hi = max(hs + [2.0] * (X in (ea, eb))) if hs else 2.0
    top = hi + up
    dx, dy = DIRS[i]
    if dx:   # E or W edge, runs along Y
        ex = cx + dx * HALF
        seg = lambda a0, a1, z0, z1: _wall(coll, ex - WALL_T / 2, ex + WALL_T / 2,
                                           cy - HALF + a0, cy - HALF + a1, z0, z1, n)
    else:
        ey = cy + dy * HALF
        seg = lambda a0, a1, z0, z1: _wall(coll, cx - HALF + a0, cx - HALF + a1,
                                           ey - WALL_T / 2, ey + WALL_T / 2, z0, z1, n)
    if kind == "solid":
        seg(0, T, -1.0, top)
        return
    seg(0, gap, -1.0, top)
    seg(gap + DOOR, T, -1.0, top)
    if kind == "drop":
        seg(gap, gap + DOOR, -1.0, hi)      # filled up to the higher floor: a ledge


def plan_edges(cells, links, junctions, size, seed):
    """What stands on every tile edge: (cell, side, ea, eb, kind, gap).
    open = nothing, door = wall with a walk-through gap, drop = wall whose gap
    is a ledge (down only), solid = wall. Map edges are solid."""
    rng = random.Random(seed * 31 + 1)
    out = []
    for (x, y), c in sorted(cells.items()):
        for i, (dx, dy) in enumerate(DIRS):
            nb = (x + dx, y + dy)
            ea = c["edges"][i]
            if nb not in cells:
                out.append(((x, y), i, ea, ea, "solid", 0))
                continue
            if i in (2, 3):            # each shared edge once, from its S/W cell
                continue
            eb = cells[nb]["edges"][(i + 2) % 4]
            pair = frozenset(((x, y), nb))
            gap = 2.0 * rng.randint(1, 5)          # off the corners
            if pair in links or (ea == eb and ea is not X and c["run"] == cells[nb]["run"]):
                kind = "open"
            elif pair in junctions:
                kind, gap = "door", HALF - DOOR / 2   # in the flow: centred
            elif ea is X or eb is X:
                kind = "solid"
            elif ea == eb:
                kind = "door" if rng.random() < 0.75 else "solid"
            else:
                kind = "drop" if rng.random() < 0.6 else "solid"
            out.append(((x, y), i, ea, eb, kind, gap))
    return out


def reachable(cells, plan, start):
    """Cells you can walk to from `start`, and cells you can walk back from."""
    fwd = {c: set() for c in cells}
    for cell, i, ea, eb, kind, _ in plan:
        nb = (cell[0] + DIRS[i][0], cell[1] + DIRS[i][1])
        if nb not in cells:
            continue
        if kind in ("open", "door"):
            fwd[cell].add(nb); fwd[nb].add(cell)
        elif kind == "drop":
            (fwd[cell] if ea > eb else fwd[nb]).add(nb if ea > eb else cell)
    def walk(graph, s):
        seen, todo = {s}, [s]
        while todo:
            for n in graph[todo.pop()]:
                if n not in seen:
                    seen.add(n); todo.append(n)
        return seen
    back = {c: set() for c in cells}
    for a, ns in fwd.items():
        for b in ns:
            back[b].add(a)
    return walk(fwd, start), walk(back, start)


def best_seed(groups, size, seeds):
    """The seed whose map you can walk all of, with the most tile variety."""
    best = None
    for seed in seeds:
        cells, links, junctions = generate(groups, size, seed)
        if len(cells) < size * size:
            continue
        plan = plan_edges(cells, links, junctions, size, seed)
        first = min(cells, key=lambda k: cells[k]["run"])
        there, back = reachable(cells, plan, first)
        kinds = len({c["tile"].name for c in cells.values()})
        reps = max(sum(1 for c in cells.values() if c["tile"] == t["tile"]) for t in cells.values())
        score = (len(there) + len(back), kinds, -reps)
        if best is None or score > best[0]:
            best = (score, seed)
    return best[1]


def build(kit_path, size=6, seed=None):
    """seed=None tries seeds 1..200 and keeps the best walkable one."""
    scene = bpy.context.scene
    root = scene.collection

    # the kit, kept out of sight
    kit = _coll("KIT", root)
    missing = [n for n in KIT.values() if n not in bpy.data.objects]
    if missing:
        with bpy.data.libraries.load(kit_path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in missing]
        for o in dst.objects:
            kit.objects.link(o)

    lib = _coll("TILES", root)
    _clear(lib)
    author_tiles(lib)
    groups = _library(lib)

    if seed is None:
        seed = best_seed(groups, size, range(1, 201))
    cells, links, junctions = generate(groups, size, seed)
    plan = plan_edges(cells, links, junctions, size, seed)

    out = _coll("MAP", root)
    _clear(out)
    tiles = _coll("MAP.tiles", out)
    walls = _coll("MAP.barriers", out)
    out["seed"] = seed
    for (x, y), c in cells.items():
        inst = bpy.data.objects.new(f"tile.{x}.{y}.{c['tile'].name}", None)
        inst.instance_type = "COLLECTION"
        inst.instance_collection = c["tile"]
        inst.location = (x * T, y * T, 0)
        inst.rotation_euler.z = c["r"] * math.pi / 2
        inst["run"], inst["group"] = c["run"], c["tile"]["group"]
        tiles.objects.link(inst)

    for n, (cell, i, ea, eb, kind, gap) in enumerate(plan):
        nb = (cell[0] + DIRS[i][0], cell[1] + DIRS[i][1])
        if kind != "open":
            _edge_wall(walls, cell, i, ea, eb, kind, gap, n, WALL_UP if nb in cells else EDGE_UP)

    # where you start: the first tile of the first run
    first = min(cells, key=lambda k: cells[k]["run"])
    sp = bpy.data.objects.get("spawn") or bpy.data.objects.new("spawn", None)
    if sp.name not in out.objects:
        out.objects.link(sp)
    sp.empty_display_type, sp.empty_display_size = "ARROWS", 1.5
    sp.location = (first[0] * T, first[1] * T - 5, cells[first]["edges"][2] or 0.0)

    for v in scene.view_layers:
        v.layer_collection.children["KIT"].exclude = True
        v.layer_collection.children["TILES"].exclude = True

    there, back = reachable(cells, plan, first)
    return {
        "seed": seed,
        "tiles": len(cells),
        "runs": len({c["run"] for c in cells.values()}),
        "barrier_boxes": len(walls.objects),
        "reachable": len(there), "can_get_back": len(back),
        "layout": [[f"{cells[(x, y)]['tile'].name}@{cells[(x, y)]['r']}" for x in range(size)]
                   for y in reversed(range(size))],
    }
