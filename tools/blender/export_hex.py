"""export_hex.py - write a tilemap.py map out as a Hex scene.

Every kit piece in the MAP collection (tile instances and barriers) becomes
one Hex entity:

  boxes (slab, cube, walls, posts)  -> the built-in "cube", solid
  ramps no steeper than MAX_SLOPE   -> "ramp.glb", floor: stood on, walked through
  steeper ramps                     -> "ramp.glb", solid: a wall you can't run up
  markers                           -> floor, so they never trip you

The player, camera and scripts come from the arena scene, so it plays with
arena.lua. Blender is Z-up and Hex is Y-up: (x, y, z) -> (x, z, -y), and a
turn about Blender Z is the same turn about Hex Y.

Run inside Blender with movement_map.blend open:
    exec(open(r"...\\export_hex.py").read())
    export(r"...\\hex")       # writes scenes/movement.hexscene + assets/ramp.glb
"""
import json
import math
import os

import bpy
from mathutils import Vector

MAX_SLOPE = 55.0              # matches arena.lua / player.lua
VISIBLE, STATIC, COLLIDES, FLOOR = 1, 2, 16, 256

KIT_KIND = {                  # kit object name -> what Hex makes of it
    "cubeMain": "box", "Slab_1-col": "box", "slab_2-col": "box",
    "wall_obstacle_1-col": "box", "wall_obstacle_2-col": "box",
    "wall_obstacle_3-col": "box",
    "ramp_1-col": "ramp", "ramp_2-col": "ramp", "ramp_3-col": "ramp", "ramp_4-col": "ramp",
}
WEDGE = "ramp_1-col"          # the 2 x 2 x 2 wedge every ramp is a scaled copy of


def _hex(c):
    return "#%02x%02x%02x" % tuple(round(max(0, min(1, v)) * 255) for v in c[:3])


def _to_hex(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def _export_wedge(path):
    """The kit's 45 degree ramp as a glTF, the mesh every ramp entity scales."""
    src = bpy.data.objects[WEDGE]
    tmp = bpy.data.objects.new("ramp", src.data)
    bpy.context.scene.collection.objects.link(tmp)
    try:
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        tmp.select_set(True)
        bpy.context.view_layer.objects.active = tmp
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_materials="NONE", export_yup=True)
    finally:
        bpy.data.objects.remove(tmp)


def _pieces():
    """(kit name, world matrix, role) for every kit piece the map shows."""
    mesh_kit = {bpy.data.objects[n].data.name: n for n in KIT_KIND if n in bpy.data.objects}
    deps = bpy.context.evaluated_depsgraph_get()
    for inst in deps.object_instances:
        ob = inst.object.original
        # KIT and TILES are excluded from the view layer, so a kit mesh seen
        # here is either a barrier or a piece of a placed tile
        if ob.type != "MESH" or ob.data.name not in mesh_kit:
            continue
        yield mesh_kit[ob.data.name], inst.matrix_world.copy(), ob.get("role", "cover")


def _entity(name, mesh, mw, local_min, local_max, flags, colour, base_centre):
    """One Hex entity filling the kit mesh's bounds under matrix mw."""
    loc, rot, scl = mw.decompose()
    size = Vector([(local_max[i] - local_min[i]) * scl[i] for i in range(3)])
    centre_l = Vector([(local_min[i] + local_max[i]) / 2 for i in range(3)])
    if base_centre:
        centre_l.z = local_min[2]
    centre = mw @ centre_l
    yaw = math.degrees(rot.to_euler().z)
    return {
        "name": name, "parent": -1,
        "pos": _to_hex(centre),
        "euler": [0, round(yaw, 3), 0],
        # local X stays X, local Z (height) is Hex Y, local Y (depth) is Hex Z
        "scale": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
        "mesh": mesh, "flags": flags,
        "material": {"base": _hex(colour), "emit": _hex(colour), "emit_energy": 0,
                     "rim": _hex([min(1, c * 1.6 + 0.08) for c in colour]),
                     "rim_power": 3, "emit_vc": False},
    }


def export(hex_root, scene_name="movement", template="arena"):
    tpl_path = os.path.join(hex_root, "scenes", template + ".hexscene")
    with open(tpl_path, encoding="utf-8") as f:
        tpl = json.load(f)
    graph = next((e["material"]["graph"] for e in tpl["entities"] if "graph" in e.get("material", {})), None)

    _export_wedge(os.path.join(hex_root, "assets", "ramp.glb"))

    bounds = {}
    for n in KIT_KIND:
        if n not in bpy.data.objects:          # a kit piece no tile uses
            continue
        vs = [v.co for v in bpy.data.objects[n].data.vertices]
        bounds[n] = ([min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)])

    ents, counts = [], {"box": 0, "floor_ramp": 0, "steep_ramp": 0}
    for i, (kit, mw, role) in enumerate(_pieces()):
        mat = bpy.data.materials.get("arena_" + role)
        colour = list(mat.diffuse_color) if mat else [0.5, 0.5, 0.5]
        lo, hi = bounds[kit]
        if KIT_KIND[kit] == "ramp":
            _, _, scl = mw.decompose()
            rise = (hi[2] - lo[2]) * scl.z
            run = (hi[1] - lo[1]) * scl.y
            steep = math.degrees(math.atan2(rise, run)) > MAX_SLOPE
            flags = VISIBLE | STATIC | (COLLIDES if steep else FLOOR)
            counts["steep_ramp" if steep else "floor_ramp"] += 1
            e = _entity(f"ramp.{i}", "ramp.glb", mw, lo, hi, flags, colour, True)
            # the glTF wedge is 2 m each way; the entity scale is relative to it
            e["scale"] = [round(s / 2, 4) for s in e["scale"]]
        else:
            flags = VISIBLE | STATIC | (FLOOR if role == "marker" else COLLIDES)
            counts["box"] += 1
            e = _entity(f"{role}.{i}", "cube", mw, lo, hi, flags, colour, False)
        if graph:
            e["material"]["graph"] = graph
        ents.append(e)

    # the player and its camera, as the arena template has them, at the spawn
    sp = bpy.data.objects["spawn"].location
    player = next(e for e in tpl["entities"] if "player" in (e.get("tags") or []))
    p_old = tpl["entities"].index(player)
    cams = [e for e in tpl["entities"] if e.get("parent") == p_old]
    player = dict(player, pos=_to_hex(Vector((sp.x, sp.y, sp.z + 0.3))), euler=[0, 0, 0])
    ents.append(player)
    for c in cams:
        ents.append(dict(c, parent=len(ents) - 1))

    scene = {
        "version": 3,
        "tagnames": tpl.get("tagnames", {}),
        "entities": ents,
        "scripts": tpl.get("scripts", ["arena", "player", "interact"]),
    }
    out = os.path.join(hex_root, "scenes", scene_name + ".hexscene")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(scene, f, indent="\t")
    return {"scene": out, "entities": len(ents), **counts}
