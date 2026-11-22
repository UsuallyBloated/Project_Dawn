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
    """A node group being built. Nodes are tagged with the section they were
    made in (see `section`); `finish` lays them out in columns by how far they
    sit from the inputs, each section in its own labelled frame, so the group
    reads left to right in Blender's node editor."""

    def __init__(self, name):
        old = bpy.data.node_groups.get(name)
        if old is not None:
            bpy.data.node_groups.remove(old)
        self.tree = bpy.data.node_groups.new(name, "GeometryNodeTree")
        self.tree.is_modifier = True
        self._section = None
        self._sections = []
        self._section_of = {}
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
        if self._section is not None:
            self._section_of[n.name] = self._section
        return n

    def section(self, label):
        """Nodes made from here on belong to a frame called `label`."""
        self._section = label
        self._sections.append(label)

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

    def dot(self, a, b):
        n = self.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        self.link(a, n.inputs[0])
        self.link(b, n.inputs[1])
        return n.outputs["Value"]

    def xyz(self, vector):
        """The X, Y and Z sockets of a vector."""
        n = self.node("ShaderNodeSeparateXYZ")
        self.link(vector, n.inputs[0])
        return n.outputs["X"], n.outputs["Y"], n.outputs["Z"]

    def position(self):
        return self.node("GeometryNodeInputPosition").outputs["Position"]

    def store(self, geometry, name, data_type, domain, value):
        """Stores a named attribute; returns the geometry with it."""
        n = self.node("GeometryNodeStoreNamedAttribute", data_type=data_type, domain=domain)
        n.inputs["Name"].default_value = name
        self.link(geometry, n.inputs["Geometry"])
        sock = n.inputs["Value"]
        if isinstance(value, (int, float, tuple, list)):
            sock.default_value = value
        else:
            self.link(value, sock)
        return n.outputs["Geometry"]

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
        self._layout()
        return self.tree

    # Spacing of the layout, in node editor units.
    COLUMN_WIDTH = 210
    ROW_HEIGHT = 175
    SECTION_GAP = 140

    def _layout(self):
        nodes = self.tree.nodes
        feeds = {n.name: [] for n in nodes}
        for lk in self.tree.links:
            feeds[lk.to_node.name].append(lk.from_node.name)
        depth = {}

        def depth_of(name):
            if name not in depth:
                depth[name] = 0  # guards a cycle, which a node tree cannot have
                parents = [p for p in feeds[name] if p != self.inp.name]
                depth[name] = 1 + max((depth_of(p) for p in parents), default=0)
            return depth[name]

        for n in nodes:
            depth_of(n.name)
        depth[self.inp.name] = 0
        last = max(depth.values()) + 1
        depth[self.out.name] = last

        # Each section is a band: its nodes in columns by depth, stacked.
        y = 0.0
        frames = {}
        for label in self._sections:
            members = [n for n in nodes if self._section_of.get(n.name) == label]
            if not members:
                continue
            rows = {}
            for n in sorted(members, key=lambda n: n.name):
                d = depth[n.name]
                n.location = (d * self.COLUMN_WIDTH, y - rows.get(d, 0) * self.ROW_HEIGHT)
                rows[d] = rows.get(d, 0) + 1
            frame = nodes.new("NodeFrame")
            frame.label = label
            frame.label_size = 28
            frames[label] = (frame, members)
            y -= max(rows.values()) * self.ROW_HEIGHT + self.SECTION_GAP
        self.inp.location = (-self.COLUMN_WIDTH * 1.5, 0)
        self.out.location = (last * self.COLUMN_WIDTH, y / 2)
        for frame, members in frames.values():
            for n in members:
                where = n.location.copy()
                n.parent = frame
                # Blender 4.4 and later: a framed node's location is relative
                # to its frame, so the absolute place is set separately.
                n.location_absolute = where


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
