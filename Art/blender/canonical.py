"""Writes a glTF binary out again in one fixed order, so that the same model
always makes the same bytes. Blender's exporter shares some accessors
between animation channels, and which it shares, and in what order it
lays them out, changes from run to run though what they hold does not;
here the data of every accessor is laid out in the order the file first
refers to it (meshes, then skins, then animations), each identical run of
bytes kept once. So a change to a model's file is a change to the model.

Plain Python, without Blender: `python3 Art/blender/canonical.py <model.glb>`
rewrites a file in place; common.export does it after every export.
"""
import json
import struct
import sys

GLB = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
SIZES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


def chunks(data):
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != GLB or version != 2 or length != len(data):
        raise ValueError("not a glTF 2 binary")
    json_length, kind = struct.unpack_from("<II", data, 12)
    if kind != JSON_CHUNK:
        raise ValueError("no JSON chunk first")
    gltf = json.loads(data[20:20 + json_length])
    at = 20 + json_length
    binary = b""
    if at < len(data):
        bin_length, kind = struct.unpack_from("<II", data, at)
        if kind != BIN_CHUNK:
            raise ValueError("no binary chunk second")
        binary = data[at + 8:at + 8 + bin_length]
    return gltf, binary


def accessor_bytes(gltf, binary, index):
    """An accessor's elements, tightly packed."""
    accessor = gltf["accessors"][index]
    if "sparse" in accessor or "bufferView" not in accessor:
        raise ValueError(f"accessor {index} is sparse or empty, which this doesn't keep")
    view = gltf["bufferViews"][accessor["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise ValueError("more than one buffer")
    element = SIZES[accessor["componentType"]] * COMPONENTS[accessor["type"]]
    if accessor["type"].startswith("MAT") and SIZES[accessor["componentType"]] < 4:
        raise ValueError("small-component matrices are padded by column, which this doesn't keep")
    stride = view.get("byteStride") or element
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return b"".join(binary[start + i * stride:start + i * stride + element] for i in range(accessor["count"]))


def influences(gltf, primitive, joints, weights, joint_bytes, weight_bytes, count):
    """Each vertex's bones heaviest first, bones of equal weight by their
    number, and a bone of no weight given as bone 0: which of two equal
    bones the exporter lists first changes from run to run."""
    joint_form = {5121: "B", 5123: "H"}[gltf["accessors"][primitive["attributes"][joints]]["componentType"]]
    weight_form = {5126: "f", 5121: "B", 5123: "H"}[gltf["accessors"][primitive["attributes"][weights]]["componentType"]]
    js = struct.unpack(f"<{count * 4}{joint_form}", joint_bytes)
    ws = struct.unpack(f"<{count * 4}{weight_form}", weight_bytes)
    out_j, out_w = [], []
    for v in range(count):
        pairs = sorted(((w, j) if w else (0, 0) for j, w in zip(js[4 * v:4 * v + 4], ws[4 * v:4 * v + 4])),
                       key=lambda p: (-p[0], p[1]))
        out_j.extend(j for _, j in pairs)
        out_w.extend(w for w, _ in pairs)
    return struct.pack(f"<{count * 4}{joint_form}", *out_j), struct.pack(f"<{count * 4}{weight_form}", *out_w)


def ordered(gltf, binary, primitive):
    """A primitive's vertices in the order of what they hold, and its
    triangles in order, each begun at its least vertex, its winding kept:
    the same shape always written the same way, whatever order its faces
    were made or merged in. Returns each attribute's bytes by name, and the
    indices' bytes (None if it has none)."""
    names = sorted(primitive["attributes"])
    columns = {name: accessor_bytes(gltf, binary, primitive["attributes"][name]) for name in names}
    count = gltf["accessors"][primitive["attributes"][names[0]]]["count"]
    for set_ in range(4):
        joints, weights = f"JOINTS_{set_}", f"WEIGHTS_{set_}"
        if joints in columns and weights in columns:
            columns[joints], columns[weights] = influences(gltf, primitive, joints, weights,
                                                           columns[joints], columns[weights], count)
    if any(gltf["accessors"][primitive["attributes"][name]]["count"] != count for name in names):
        raise ValueError("attributes of unequal counts")
    if primitive.get("mode", 4) != 4:
        raise ValueError("primitives other than triangles aren't kept")
    if "indices" not in primitive:
        return columns, None  # its triangles are its vertices' order, so that order stays
    width = {name: len(columns[name]) // count for name in names}
    rows = [b"".join(columns[name][i * width[name]:(i + 1) * width[name]] for name in names) for i in range(count)]
    order = sorted(range(count), key=lambda i: rows[i])
    place = [0] * count
    for new, old in enumerate(order):
        place[old] = new
    attributes = {name: b"".join(columns[name][i * width[name]:(i + 1) * width[name]] for i in order) for name in names}
    accessor = gltf["accessors"][primitive["indices"]]
    form = {5121: "B", 5123: "H", 5125: "I"}[accessor["componentType"]]
    indices = struct.unpack(f"<{accessor['count']}{form}", accessor_bytes(gltf, binary, primitive["indices"]))
    triangles = []
    for t in range(0, len(indices), 3):
        a, b, c = (place[i] for i in indices[t:t + 3])
        least = min(a, b, c)
        triangles.append((a, b, c) if least == a else (b, c, a) if least == b else (c, a, b))
    triangles.sort()
    flat = [i for triangle in triangles for i in triangle]
    return attributes, struct.pack(f"<{len(flat)}{form}", *flat)


def canonical(data):
    gltf, binary = chunks(data)
    if gltf.get("images") or len(gltf.get("buffers", [])) > 1:
        raise ValueError("images and further buffers aren't kept")
    accessors, views, out = [], [], bytearray()
    made = {}

    def keep(index, raw=None):
        """The new number of accessor `index`, holding `raw` if given (its
        elements put in order) or else what it holds now."""
        old = gltf["accessors"][index]
        if raw is None:
            raw = accessor_bytes(gltf, binary, index)
        target = gltf["bufferViews"][old["bufferView"]].get("target")
        described = {k: v for k, v in old.items() if k not in ("bufferView", "byteOffset", "name")}
        key = (json.dumps(described, sort_keys=True), target, raw)
        if key in made:
            return made[key]
        while len(out) % 4:
            out.append(0)
        view = {"buffer": 0, "byteOffset": len(out), "byteLength": len(raw)}
        if target is not None:
            view["target"] = target
        out.extend(raw)
        views.append(view)
        accessor = dict(described)
        accessor["bufferView"] = len(views) - 1
        accessors.append(accessor)
        made[key] = len(accessors) - 1
        return made[key]

    for mesh in gltf.get("meshes", []):
        for primitive in mesh["primitives"]:
            if primitive.get("targets"):
                raise ValueError("morph targets aren't kept")
            attributes, indices = ordered(gltf, binary, primitive)
            primitive["attributes"] = {name: keep(index, attributes[name])
                                       for name, index in sorted(primitive["attributes"].items())}
            if indices is not None:
                primitive["indices"] = keep(primitive["indices"], indices)
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = keep(skin["inverseBindMatrices"])
    for animation in gltf.get("animations", []):
        # The samplers in the order of the channels that use them.
        samplers, renumbered = [], {}
        for channel in animation["channels"]:
            old = channel["sampler"]
            if old not in renumbered:
                renumbered[old] = len(samplers)
                samplers.append(animation["samplers"][old])
            channel["sampler"] = renumbered[old]
        animation["samplers"] = samplers
        for sampler in samplers:
            sampler["input"] = keep(sampler["input"])
            sampler["output"] = keep(sampler["output"])

    while len(out) % 4:
        out.append(0)
    gltf["accessors"], gltf["bufferViews"] = accessors, views
    if out:
        gltf["buffers"] = [{"byteLength": len(out)}]
    else:
        gltf.pop("buffers", None)
    text = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    body = struct.pack("<II", len(text), JSON_CHUNK) + text
    if out:
        body += struct.pack("<II", len(out), BIN_CHUNK) + bytes(out)
    return struct.pack("<III", GLB, 2, 12 + len(body)) + body


def rewrite(path):
    with open(path, "rb") as f:
        data = f.read()
    again = canonical(data)
    with open(path, "wb") as f:
        f.write(again)
    return len(data), len(again)


if __name__ == "__main__":
    for path in sys.argv[1:]:
        before, after = rewrite(path)
        print(f"{path}: {before} bytes, {after} written in order")
