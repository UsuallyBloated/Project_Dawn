# Shared helpers for the scenery generators (tools/blender/gen_*.py).
#
# Each generator builds a Geometry Nodes group by code, so the group lives as
# text in git and can be rebuilt exactly; the user still gets its sliders and a
# Seed in Blender. Helpers here make a node, link two sockets (failing loudly
# when a link does not hold, which is how a renamed socket in a new Blender
# shows up), read the variant table and put a generated variant on an object.
#
# Runs inside Blender (bpy). Tested on Blender 5.3.

import os
import sys
import tomllib

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
VARIANTS_FILE = os.path.join(HERE, "scenery_variants.toml")


class Graph:
    """A node group being built: nodes are placed left to right as they come."""

    def __init__(self, name):
        old = bpy.data.node_groups.get(name)
        if old is not None:
            bpy.data.node_groups.remove(old)
        self.tree = bpy.data.node_groups.new(name, "GeometryNodeTree")
        self.tree.is_modifier = True
        self._column = 0
        self.inp = self.node("NodeGroupInput")
        self.out = self.node("NodeGroupOutput")
        self.tree.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")

    def slider(self, name, kind, default, lo=None, hi=None):
        """A group input: kind is 'FLOAT', 'INT' or 'BOOL'."""
        socket_type = {"FLOAT": "NodeSocketFloat", "INT": "NodeSocketInt", "BOOL": "NodeSocketBool"}[kind]
        s = self.tree.interface.new_socket(name, in_out="INPUT", socket_type=socket_type)
        s.default_value = default
        if lo is not None:
            s.min_value = lo
        if hi is not None:
            s.max_value = hi
        return self.inp.outputs[name]

    def node(self, bl_idname, **props):
        n = self.tree.nodes.new(bl_idname)
        for key, value in props.items():
            setattr(n, key, value)
        n.location = (self._column * 220, 0)
        self._column += 1
        return n

    def link(self, from_socket, to_socket):
        lk = self.tree.links.new(from_socket, to_socket)
        if not lk.is_valid:
            raise RuntimeError("link %s.%s to %s.%s did not hold" % (
                from_socket.node.name, from_socket.name, to_socket.node.name, to_socket.name))
        return lk

    # --- small builders, each returning the output socket -----------------

    def math(self, op, a, b=None, c=None):
        n = self.node("ShaderNodeMath", operation=op)
        for i, v in enumerate((a, b, c)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n.outputs[0]

    def vec(self, x=0.0, y=0.0, z=0.0):
        n = self.node("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)):
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n.outputs[0]

    def vmath(self, op, a, b=None, scale=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self.link(a, n.inputs[0])
        if b is not None:
            if isinstance(b, (tuple, list)):
                n.inputs[1].default_value = b
            else:
                self.link(b, n.inputs[1])
        if scale is not None:
            sock = n.inputs["Scale"]
            if isinstance(scale, (int, float)):
                sock.default_value = scale
            else:
                self.link(scale, sock)
        return n.outputs[0]

    def random(self, data_type, lo, hi, seed, offset, fixed=False):
        """A seeded random value per element; `offset` keeps two draws apart.
        `fixed` gives every element the same value (one draw for the whole
        object, such as a trunk's girth)."""
        n = self.node("FunctionNodeRandomValue", data_type=data_type)
        if fixed:
            n.inputs["ID"].default_value = 0
            self.link(self.node("FunctionNodeInputInt").outputs[0], n.inputs["ID"])
        mins = [s for s in n.inputs if s.name == "Min" and s.enabled]
        maxs = [s for s in n.inputs if s.name == "Max" and s.enabled]
        for sock, v in ((mins[0], lo), (maxs[0], hi)):
            if isinstance(v, (int, float, tuple, list)):
                sock.default_value = v
            else:
                self.link(v, sock)
        seed_sum = self.math("ADD", seed, float(offset))
        self.link(seed_sum, n.inputs["Seed"])
        outs = [s for s in n.outputs if s.enabled]
        return outs[0]

    def finish(self, geometry):
        self.link(geometry, self.out.inputs["Geometry"])
        return self.tree


def variants(kind):
    """The rows of scenery_variants.toml for one kind, in variant order."""
    with open(VARIANTS_FILE, "rb") as f:
        table = tomllib.load(f)
    rows = table.get(kind, [])
    if not rows:
        raise SystemExit("scenery_variants.toml has no [[%s]] rows" % kind)
    return rows


def apply_variant(tree, name, row, location):
    """An object carrying the group as a modifier, its sliders set from `row`."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    mod = obj.modifiers.new("Generator", "NODES")
    mod.node_group = tree
    by_name = {s.name: s.identifier for s in tree.interface.items_tree
               if getattr(s, "in_out", None) == "INPUT"}
    for key, value in row.items():
        if key == "variant":
            continue
        if key not in by_name:
            raise SystemExit("%s: %s has no slider called %r" % (name, tree.name, key))
        # Blender 5 keeps a modifier's input values on properties.inputs,
        # one entry per socket identifier, each holding a `value`.
        getattr(mod.properties.inputs, by_name[key]).value = value
    return obj


def triangles(obj):
    """Triangles of an object as evaluated, the way the game will draw them."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    m = ev.to_mesh()
    count = sum(len(p.vertices) - 2 for p in m.polygons)
    ev.to_mesh_clear()
    return count


def script_args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
