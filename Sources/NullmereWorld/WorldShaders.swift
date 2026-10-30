/// Metal source for the world in three dimensions: the land, the still
/// water, and every model on them.
///
/// The land is one mesh, raised where the keeper knows it and lying flat
/// under mist where they don't; each hex is read from the tile texture
/// (see `TileTexture`) for whose land it is, what the keeper knows of it,
/// and whether it is under the pointer or chosen. The Nullmere is a black,
/// perfectly still mirror: it gives back the stars and the moon as the eye
/// sees them over it. Models are drawn many at a time, each part moved by
/// its pose, swaying in the wind, rising as they are built, and hidden
/// where the keeper knows nothing.
///
/// The code between the SCENE markers is written in the subset shared by
/// Metal and GLSL, so Tools/world3d-preview can render it in a browser.
public enum WorldShaders {
    public static let landVertex = "nm_land_vertex"
    public static let landFragment = "nm_land_fragment"
    public static let waterVertex = "nm_water_vertex"
    public static let waterFragment = "nm_water_fragment"
    public static let modelVertex = "nm_model_vertex"
    public static let modelFragment = "nm_model_fragment"

    public static let functions = [landVertex, landFragment, waterVertex, waterFragment, modelVertex, modelFragment]

    public static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    #define NM_CONST constant
    #define NM_TEXTURE_ARGUMENT , texture2d<float, access::read> tiles
    #define NM_TEXTURE_PASS , tiles
    #define NM_TILE(cell) tiles.read(uint2(cell))
    #define NM_ATAN2(y, x) atan2(y, x)

    // BEGIN SCENE
    NM_CONST float kRoot3 = 1.7320508;
    NM_CONST float kTau = 6.2831853;
    // SceneClock's period, after which the map's clock starts over: every
    // motion below comes round a whole number of times in it, so none
    // jumps then.
    NM_CONST float kClockPeriod = 10575.0;
    // Where the mist lies over what the keeper has never seen: just above
    // the water's face, so it hides the lake as well as the land.
    NM_CONST float kMistLevel = 0.02;
    NM_CONST float3 kMoonColour = float3(0.56, 0.66, 0.92);
    NM_CONST float3 kMoonFace = float3(0.80, 0.82, 0.84);
    NM_CONST float3 kSkyLight = float3(0.034, 0.044, 0.085);
    NM_CONST float3 kGroundLight = float3(0.012, 0.013, 0.018);
    // Starlight off the lake, from the south-east: enough to read the
    // faces turned from the moon.
    NM_CONST float3 kFillDirection = float3(0.47, 0.53, 0.70);
    NM_CONST float3 kFillColour = float3(0.050, 0.062, 0.100);
    NM_CONST float3 kHaze = float3(0.0040, 0.0050, 0.0095);
    NM_CONST float3 kMist = float3(0.0026, 0.0031, 0.0050);
    NM_CONST float3 kGlow = float3(0.95, 0.80, 0.52);
    NM_CONST float3 kHearth = float3(1.0, 0.62, 0.30);
    NM_CONST float3 kDeepWater = float3(0.0004, 0.0006, 0.0012);

    // An angle that turns `perSecond` radians a second, near enough, and a
    // whole number of times in the clock's period.
    float nm_spin(float time, float perSecond) {
        float turns = floor(perSecond * kClockPeriod / kTau + 0.5);
        return kTau * fract((time / kClockPeriod) * turns);
    }

    // A drift of `speed` units a second, round a circle once in the clock's
    // period: what drifts on it never jumps as the clock starts over.
    float2 nm_drift(float time, float speed) {
        float turn = kTau * time / kClockPeriod;
        return float2(sin(turn), 1.0 - cos(turn)) * (speed * kClockPeriod / kTau);
    }

    float nm_hash12(float2 p) {
        float3 q = fract(float3(p.x, p.y, p.x) * 0.1031);
        q += dot(q, float3(q.y, q.z, q.x) + 33.33);
        return fract((q.x + q.y) * q.z);
    }

    float nm_hash13(float3 p) {
        float3 q = fract(p * 0.1031);
        q += dot(q, float3(q.z, q.y, q.x) + 31.32);
        return fract((q.x + q.y) * q.z);
    }

    float nm_noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = nm_hash12(i);
        float b = nm_hash12(i + float2(1.0, 0.0));
        float c = nm_hash12(i + float2(0.0, 1.0));
        float d = nm_hash12(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    float nm_fbm(float2 p) {
        float total = 0.0;
        float amplitude = 0.5;
        for (int octave = 0; octave < 4; octave++) {
            total += amplitude * nm_noise(p);
            p = p * 2.03 + float2(17.1, 9.2);
            amplitude *= 0.5;
        }
        return total / 0.9375;
    }

    float3 nm_linear(float3 c) {
        return pow(max(c, float3(0.0)), float3(2.2));
    }

    float3 nm_encode(float3 c) {
        return pow(clamp(c, float3(0.0), float3(1.0)), float3(1.0 / 2.2));
    }

    // The fractional axial coordinates of a map point.
    float2 nm_axial(float2 p) {
        return float2(kRoot3 / 3.0 * p.x - p.y / 3.0, 2.0 / 3.0 * p.y);
    }

    int2 nm_hexRound(float2 a) {
        float3 cube = float3(a.x, a.y, -a.x - a.y);
        float3 r = floor(cube + 0.5);
        float3 d = abs(r - cube);
        if (d.x > d.y && d.x > d.z) {
            r.x = -r.y - r.z;
        } else if (d.y > d.z) {
            r.y = -r.x - r.z;
        }
        return int2(int(r.x), int(r.y));
    }

    float2 nm_hexCentre(int2 h) {
        return float2(kRoot3 * (float(h.x) + float(h.y) * 0.5), 1.5 * float(h.y));
    }

    int nm_hexDistance(int2 h) {
        return (abs(h.x) + abs(h.y) + abs(h.x + h.y)) / 2;
    }

    // The tile texture's four bytes for a hex: terrain, feature, relief,
    // and what the keeper knows of it with whose land it is; beyond the map,
    // the Spine, always known and never watched.
    float4 nm_tileAt(int2 h, float radius NM_TEXTURE_ARGUMENT) {
        int r = int(radius);
        if (nm_hexDistance(h) > r) {
            return float4(7.0, 0.0, 0.0, 16.0);
        }
        return floor(NM_TILE(h + int2(r, r)) * 255.0 + 0.5);
    }

    // Whether the keeper knows a hex at all, and whether they watch it now.
    float2 nm_knowledge(int2 h, float radius NM_TEXTURE_ARGUMENT) {
        float seen = floor(nm_tileAt(h, radius NM_TEXTURE_PASS).w / 16.0);
        return float2(seen > 0.5 ? 1.0 : 0.0, seen > 1.5 ? 1.0 : 0.0);
    }

    // What the keeper knows at a point, blended from the three hexes whose
    // hearts surround it, as the land itself is.
    float2 nm_knowledgeAround(float2 p, float radius NM_TEXTURE_ARGUMENT) {
        float2 a = nm_axial(p);
        float2 base = floor(a);
        float2 f = a - base;
        int2 h0 = int2(int(base.x), int(base.y));
        if (f.x + f.y <= 1.0) {
            return (1.0 - f.x - f.y) * nm_knowledge(h0, radius NM_TEXTURE_PASS)
                + f.x * nm_knowledge(h0 + int2(1, 0), radius NM_TEXTURE_PASS)
                + f.y * nm_knowledge(h0 + int2(0, 1), radius NM_TEXTURE_PASS);
        }
        return (f.x + f.y - 1.0) * nm_knowledge(h0 + int2(1, 1), radius NM_TEXTURE_PASS)
            + (1.0 - f.x) * nm_knowledge(h0 + int2(0, 1), radius NM_TEXTURE_PASS)
            + (1.0 - f.y) * nm_knowledge(h0 + int2(1, 0), radius NM_TEXTURE_PASS);
    }

    // How far a point lies inside its hex's edge, and the axial step to
    // the neighbour across the nearest edge.
    float3 nm_hexEdge(float2 p, int2 h) {
        float2 d = p - nm_hexCentre(h);
        float e0 = d.x;
        float e1 = 0.5 * d.x + 0.8660254 * d.y;
        float e2 = -0.5 * d.x + 0.8660254 * d.y;
        float m = abs(e0);
        float2 neighbour = float2(e0 > 0.0 ? 1.0 : -1.0, 0.0);
        if (abs(e1) > m) {
            m = abs(e1);
            neighbour = float2(0.0, e1 > 0.0 ? 1.0 : -1.0);
        }
        if (abs(e2) > m) {
            m = abs(e2);
            neighbour = e2 > 0.0 ? float2(-1.0, 1.0) : float2(1.0, -1.0);
        }
        return float3(0.8660254 - m, neighbour.x, neighbour.y);
    }

    float3 nm_light(float3 albedo, float3 n, float3 moon, float strength) {
        float moonLight = max(dot(n, moon), 0.0) * strength;
        float fill = max(dot(n, kFillDirection), 0.0);
        float3 sky = mix(kGroundLight, kSkyLight, n.y * 0.5 + 0.5);
        return albedo * (kMoonColour * moonLight + kFillColour * fill + sky);
    }

    // Remembered, not watched: as it was last seen, greyed and dim.
    float3 nm_remembered(float3 c) {
        float grey = dot(c, float3(0.3, 0.5, 0.2));
        return mix(float3(grey), c, 0.35) * 0.42 + kMist * 0.4;
    }

    // The mist over what the keeper has never seen, drifting slowly.
    float3 nm_mist(float2 p, float time) {
        float drift = nm_fbm(p * 0.18 + nm_drift(time, 0.012));
        float wisp = nm_fbm(p * 0.6 - nm_drift(time + 2600.0, 0.024));
        return kMist * (0.7 + 0.9 * drift) + float3(0.004, 0.0048, 0.0068) * smoothstep(0.55, 0.85, wisp);
    }

    // The night sky in a direction: the dark, the stars, warm and cold,
    // and the moon with its halo.
    float3 nm_sky(float3 d, float3 moon, float time) {
        float up = max(d.y, 0.0);
        float3 colour = mix(float3(0.0030, 0.0042, 0.0085), float3(0.0010, 0.0014, 0.0034), sqrt(up));
        float3 grid = d * 150.0;
        float3 cell = floor(grid);
        float chance = nm_hash13(cell);
        if (chance > 0.9) {
            float3 spot = cell + 0.5 + (float3(nm_hash13(cell + 7.1), nm_hash13(cell + 3.7), nm_hash13(cell + 1.3)) - 0.5) * 0.6;
            float far = length(grid - spot);
            float bright = (chance - 0.9) / 0.1;
            float twinkle = 0.75 + 0.25 * sin(nm_spin(time, 1.3 + 2.0 * chance) + chance * 40.0);
            float warm = nm_hash13(cell + 11.0);
            float3 tint = mix(float3(0.70, 0.80, 1.0), float3(1.0, 0.86, 0.66), warm * warm);
            colour += tint * (1.0 - smoothstep(0.0, 0.2, far)) * (0.35 + 2.2 * bright * bright) * twinkle;
        }
        float facing = dot(d, moon);
        float disc = smoothstep(0.99975, 0.99982, facing);
        float3 face = kMoonFace;
        // Its seas, worked out only on its face.
        if (facing > 0.9997) {
            float2 onFace = float2(dot(d - moon, float3(1.0, 0.0, 0.0)), dot(d - moon, float3(0.0, 1.0, 0.0))) * 60.0;
            float seas = nm_fbm(onFace * 3.0 + 4.0);
            face = kMoonFace * (0.78 + 0.22 * smoothstep(0.35, 0.7, seas));
        }
        float halo = pow(max(facing, 0.0), 2400.0) * 0.55 + pow(max(facing, 0.0), 160.0) * 0.07 + pow(max(facing, 0.0), 18.0) * 0.012;
        return colour + face * disc * 1.6 + kMoonColour * halo;
    }

    // The night's haze between the eye and what it sees far off.
    float3 nm_haze(float3 c, float distance, float start, float density) {
        float amount = 1.0 - exp(-max(distance - start, 0.0) * density);
        return mix(c, kHaze, clamp(amount, 0.0, 0.85));
    }

    // The flicker of a flame.
    float nm_flicker(float t) {
        return 0.55 * sin(nm_spin(t, 7.3)) + 0.3 * sin(nm_spin(t, 13.1) + 1.7) + 0.15 * sin(nm_spin(t, 23.7) + 0.3);
    }

    // How a model sways in the wind at a point: leaves and banners.
    float3 nm_wind(float3 p, float sway, float material, float t) {
        float gust = 0.6 + 0.4 * sin(nm_spin(t, 0.37) + p.x * 0.11);
        float3 offset = float3(sin(nm_spin(t, 1.3) + p.x * 3.1 + p.z * 1.7), 0.0, cos(nm_spin(t, 1.1) + p.z * 2.3)) * 0.018 * gust;
        if (material > 3.5 && material < 4.5) {
            offset += float3(0.0, 0.012 * sin(nm_spin(t, 4.0) + p.x * 14.0), 0.035 * sin(nm_spin(t, 3.2) + p.x * 9.0 + p.y * 3.0)) * gust;
        }
        return offset * sway;
    }

    // An ordered pattern for fading by leaving pixels out.
    float nm_bayer(float2 pixel) {
        float2 p = floor(pixel - 4.0 * floor(pixel / 4.0));
        float index = p.x + p.y * 4.0;
        return nm_hash12(float2(index, 3.0)) * 0.94 + 0.03;
    }
    // END SCENE

    struct FrameUniforms {
        float4x4 viewProjection;
        float4x4 inverseViewProjection;
        float4 eye;        // the eye's position, and the map's clock
        float4 moon;       // toward the moon, and its strength
        float4 viewport;   // width, height, and their reciprocals, in pixels
        float4 world;      // map radius, tile texture side, pixels per world unit, motion
        float4 highlight;  // hovered q and r, chosen q and r; 999 for none
        float4 extent;     // the land's corner and far corner (x, z)
        float4 haze;       // haze start, density, exposure, heights spacing
        float4 heights;    // the heights grid's corner (x, z), columns, rows
        float4 houses[16]; // each House's colour, by sigil plus one
    };

    struct ModelVertex {
        packed_float3 position;
        packed_char4 normalMaterial;
        packed_uchar4 colorSway;
        ushort part;
        ushort spare;
    };

    struct ModelInstance {
        float4x4 model;
        float4 colour;
        float4 params;     // risen to, opacity, phase, emphasis
        int2 hex;
        uint palette;
        uint flags;
    };

    // MARK: The land

    struct LandOut {
        float4 position [[position]];
        float3 world;
        float3 normal;
        float3 colour;
        float known;
        float watched;
    };

    vertex LandOut nm_land_vertex(uint vid [[vertex_id]],
                                  const device ModelVertex *vertices [[buffer(0)]],
                                  constant FrameUniforms &frame [[buffer(3)]],
                                  texture2d<float, access::read> tiles [[texture(0)]]) {
        ModelVertex v = vertices[vid];
        float3 p = float3(v.position);
        char4 packedNormal = char4(v.normalMaterial);
        uchar4 packedColour = uchar4(v.colorSway);
        float2 knowledge = nm_knowledgeAround(p.xz, frame.world.x, tiles);
        float known = smoothstep(0.0, 1.0, knowledge.x);
        // The unknown lies flat under the mist: its shape is not given away.
        p.y = mix(kMistLevel, p.y, known);
        float3 n = normalize(float3(packedNormal.xyz) / 127.0);
        LandOut out;
        out.position = frame.viewProjection * float4(p, 1.0);
        out.world = p;
        out.normal = normalize(mix(float3(0.0, 1.0, 0.0), n, known));
        out.colour = nm_linear(float3(packedColour.xyz) / 255.0);
        out.known = knowledge.x;
        out.watched = knowledge.y;
        return out;
    }

    fragment float4 nm_land_fragment(LandOut in [[stage_in]],
                                     constant FrameUniforms &frame [[buffer(0)]],
                                     texture2d<float, access::read> tiles [[texture(0)]]) {
        float time = frame.eye.w;
        float radius = frame.world.x;
        float3 n = normalize(in.normal);
        float2 p = in.world.xz;
        int2 h = nm_hexRound(nm_axial(p));
        float4 tile = nm_tileAt(h, radius, tiles);
        float owner = tile.w - 16.0 * floor(tile.w / 16.0);
        float3 albedo = in.colour;
        float3 edge = nm_hexEdge(p, h);
        float pixel = max(fwidth(p.x), fwidth(p.y));

        // Whose land: a faint wash of the House's colour, and a line where
        // it meets another's.
        float3 lit = float3(0.0);
        if (owner > 0.5 && in.known > 0.5) {
            float3 house = frame.houses[int(owner)].rgb;
            albedo = mix(albedo, house * 0.5, 0.14);
            int2 across = h + int2(int(edge.y), int(edge.z));
            float4 other = nm_tileAt(across, radius, tiles);
            float otherOwner = other.w - 16.0 * floor(other.w / 16.0);
            if (abs(otherOwner - owner) > 0.5) {
                float line = 1.0 - smoothstep(pixel * 0.6, pixel * 2.2, edge.x);
                lit += house * line * 0.35;
            }
        }
        lit += nm_light(albedo, n, frame.moon.xyz, frame.moon.w);

        // A hold's hearths light the country round it.
        for (int i = 0; i < 7; i++) {
            int2 toward = int2(0, 0);
            if (i == 1) { toward = int2(1, 0); }
            if (i == 2) { toward = int2(-1, 0); }
            if (i == 3) { toward = int2(0, 1); }
            if (i == 4) { toward = int2(0, -1); }
            if (i == 5) { toward = int2(1, -1); }
            if (i == 6) { toward = int2(-1, 1); }
            float4 near = nm_tileAt(h + toward, radius, tiles);
            if (near.y >= 128.0) {
                float far = length(p - nm_hexCentre(h + toward));
                lit += albedo * kHearth * 0.55 * exp(-far * far * 1.6);
            }
        }

        // The hex under the pointer, and the one chosen.
        float hovered = (abs(float(h.x) - frame.highlight.x) < 0.5 && abs(float(h.y) - frame.highlight.y) < 0.5) ? 1.0 : 0.0;
        float chosen = (abs(float(h.x) - frame.highlight.z) < 0.5 && abs(float(h.y) - frame.highlight.w) < 0.5) ? 1.0 : 0.0;
        float ring = 1.0 - smoothstep(pixel * 0.8, pixel * 2.4, edge.x);
        lit += float3(0.20, 0.22, 0.26) * ring * hovered * 0.6;
        lit += kGlow * (ring * 0.9 + (1.0 - smoothstep(0.0, 0.35, edge.x)) * 0.08) * chosen;

        lit = mix(nm_remembered(lit), lit, smoothstep(0.15, 0.85, in.watched));
        if (in.known < 0.999) {
            lit = mix(nm_mist(p, time), lit, smoothstep(0.0, 1.0, in.known));
        }
        // Past the map's edge the Spine goes on into the dark.
        float beyond = float(nm_hexDistance(h)) - radius;
        lit *= clamp(1.0 - 0.13 * beyond, 0.18, 1.0);
        lit = nm_haze(lit, distance(in.world, frame.eye.xyz), frame.haze.x, frame.haze.y);
        return float4(nm_encode(lit * frame.haze.z), 1.0);
    }

    // MARK: The still water

    struct WaterOut {
        float4 position [[position]];
        float3 world;
    };

    vertex WaterOut nm_water_vertex(uint vid [[vertex_id]], constant FrameUniforms &frame [[buffer(3)]]) {
        float2 corner = float2(float(vid & 1u), float(vid >> 1u));
        float2 xz = mix(frame.extent.xy, frame.extent.zw, corner);
        WaterOut out;
        out.world = float3(xz.x, 0.0, xz.y);
        out.position = frame.viewProjection * float4(out.world, 1.0);
        return out;
    }

    fragment float4 nm_water_fragment(WaterOut in [[stage_in]],
                                      constant FrameUniforms &frame [[buffer(0)]],
                                      texture2d<float, access::read> tiles [[texture(0)]],
                                      texture2d<float> heights [[texture(1)]]) {
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        float2 grid = (in.world.xz - frame.heights.xy) / frame.haze.w + 0.5;
        float ground = heights.sample(smooth, grid / frame.heights.zw).r;
        float depth = -ground;
        if (depth <= 0.0) {
            discard_fragment();
        }
        float time = frame.eye.w;
        float3 look = normalize(in.world - frame.eye.xyz);
        float3 mirrored = float3(look.x, -look.y, look.z);
        float facing = 1.0 - max(-look.y, 0.0);
        float fresnel = 0.30 + 0.70 * facing * facing * facing * facing * facing;
        float3 colour = kDeepWater + nm_sky(mirrored, frame.moon.xyz, time) * fresnel;
        // Where it is shallow the shingle shows through, darkened and wet.
        float clear = smoothstep(0.0, 0.14, depth);

        int2 h = nm_hexRound(nm_axial(in.world.xz));
        float2 knowledge = nm_knowledge(h, frame.world.x, tiles);
        colour = mix(nm_remembered(colour), colour, knowledge.y);
        colour = nm_haze(colour, distance(in.world, frame.eye.xyz), frame.haze.x, frame.haze.y);
        return float4(nm_encode(colour * frame.haze.z), clear);
    }

    // MARK: Models

    struct ModelOut {
        float4 position [[position]];
        float3 world;
        float3 normal;
        float3 colour;
        float localY;
        float material [[flat]];
        float4 params [[flat]];
        float watched [[flat]];
    };

    vertex ModelOut nm_model_vertex(uint vid [[vertex_id]],
                                    uint iid [[instance_id]],
                                    const device ModelVertex *vertices [[buffer(0)]],
                                    const device ModelInstance *instances [[buffer(1)]],
                                    const device float4x4 *palette [[buffer(2)]],
                                    constant FrameUniforms &frame [[buffer(3)]],
                                    texture2d<float, access::read> tiles [[texture(0)]]) {
        ModelVertex v = vertices[vid];
        ModelInstance instance = instances[iid];
        char4 packedNormal = char4(v.normalMaterial);
        uchar4 packedColour = uchar4(v.colorSway);
        float material = float(packedNormal.w);
        float sway = float(packedColour.w) / 255.0;
        float time = frame.eye.w + instance.params.z;
        float3 local = float3(v.position);
        if (sway > 0.0) {
            local += nm_wind(local, sway, material, time) * frame.world.w;
        }
        float4x4 part = palette[instance.palette + uint(v.part)];
        float4 posed = part * float4(local, 1.0);
        float4 world = instance.model * posed;
        float3 normal = (instance.model * (part * float4(float3(packedNormal.xyz) / 127.0, 0.0))).xyz;

        float watched = 1.0;
        if ((instance.flags & 1u) == 0u) {
            float2 knowledge = nm_knowledge(instance.hex, frame.world.x, tiles);
            watched = knowledge.y > 0.5 ? 1.0 : (knowledge.x > 0.5 ? 0.5 : 0.0);
        }
        float3 albedo = nm_linear(float3(packedColour.xyz) / 255.0);
        if ((material > 0.5 && material < 1.5) || (material > 3.5 && material < 4.5)) {
            if (instance.colour.a > 0.5) {
                float shade = dot(albedo, float3(0.30, 0.55, 0.15));
                albedo = instance.colour.rgb * shade * 2.0;
            }
        }
        ModelOut out;
        // What the keeper has never seen is not drawn: put past the far plane.
        out.position = watched > 0.25 ? frame.viewProjection * world : float4(0.0, 0.0, 2.0, 1.0);
        out.world = world.xyz;
        out.normal = normalize(normal);
        out.colour = albedo;
        out.localY = posed.y;
        out.material = material;
        out.params = instance.params;
        out.watched = watched;
        return out;
    }

    fragment float4 nm_model_fragment(ModelOut in [[stage_in]], constant FrameUniforms &frame [[buffer(0)]]) {
        if (in.localY > in.params.x) {
            discard_fragment();
        }
        if (in.params.y < 0.999 && in.params.y <= nm_bayer(in.position.xy)) {
            discard_fragment();
        }
        float time = frame.eye.w + in.params.z;
        float3 n = normalize(in.normal);
        float3 toEye = normalize(frame.eye.xyz - in.world);
        if (dot(n, toEye) < 0.0) {
            n = -n;
        }
        float3 lit = nm_light(in.colour, n, frame.moon.xyz, frame.moon.w);
        float facing = 1.0 - max(dot(n, toEye), 0.0);
        // The moon behind outlines what stands against it.
        float behind = max(dot(-toEye, frame.moon.xyz), 0.0);
        lit += kMoonColour * facing * facing * facing * (0.04 + 0.22 * behind) * frame.moon.w;
        if (in.material > 5.5) {
            float3 halfway = normalize(toEye + frame.moon.xyz);
            lit += kMoonColour * pow(max(dot(n, halfway), 0.0), 48.0) * 0.9 * frame.moon.w;
        } else if (in.material > 4.5) {
            float glint = pow(max(dot(n, normalize(toEye + frame.moon.xyz)), 0.0), 20.0);
            lit += in.colour * (0.16 + 0.1 * sin(nm_spin(time, 1.7) + in.world.x * 5.0)) + float3(0.6, 0.7, 0.9) * glint * 0.5;
        } else if (in.material > 1.5 && in.material < 2.5) {
            lit = in.colour * (1.55 + 0.35 * nm_flicker(time + in.world.x * 3.0 + in.world.z * 2.0) * frame.world.w);
        }
        // A work being raised: its newest course pale and fresh.
        if (in.params.x < 50.0 && in.localY > in.params.x - 0.025) {
            lit += float3(0.05, 0.042, 0.03);
        }
        // Chosen, or under the pointer: a light about its edges.
        lit += kGlow * in.params.w * facing * facing * 0.45;
        if (in.watched < 0.75) {
            lit = nm_remembered(lit);
        }
        lit = nm_haze(lit, distance(in.world, frame.eye.xyz), frame.haze.x, frame.haze.y);
        return float4(nm_encode(lit * frame.haze.z), 1.0);
    }
    """#
}
