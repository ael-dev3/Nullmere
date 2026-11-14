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
/// where the keeper knows nothing. Last, the motes the world throws up
/// (sparks, dust, smoke, embers, the flash of a blow, fireflies) are drawn
/// as soft discs facing the eye; fires and blows also light the land and
/// the models round them, as four lights of the world's own.
///
/// The code between the SCENE markers, and the fragments' own between the
/// SHADING markers, is written in the subset shared by Metal and GLSL: what
/// a fragment is lit by is written once, there, and the Metal fragment
/// functions and Tools/world3d-preview's both only hand their inputs to it,
/// so the browser preview draws what the game draws.
public enum WorldShaders {
    public static let landVertex = "nm_land_vertex"
    public static let landFragment = "nm_land_fragment"
    public static let waterVertex = "nm_water_vertex"
    public static let waterFragment = "nm_water_fragment"
    public static let modelVertex = "nm_model_vertex"
    public static let modelFragment = "nm_model_fragment"
    public static let shadowVertex = "nm_shadow_vertex"
    public static let moteVertex = "nm_mote_vertex"
    public static let moteFragment = "nm_mote_fragment"
    public static let skyVertex = "nm_sky_vertex"
    public static let skyFragment = "nm_sky_fragment"

    public static let functions = [landVertex, landFragment, waterVertex, waterFragment, modelVertex, modelFragment,
                                   shadowVertex, moteVertex, moteFragment, skyVertex, skyFragment]

    public static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    #define NM_CONST constant
    #define NM_TEXTURE_ARGUMENT , texture2d<float, access::read> tiles
    #define NM_TEXTURE_PASS , tiles
    #define NM_TILE(cell) tiles.read(uint2(cell))
    #define NM_ATAN2(y, x) atan2(y, x)
    // The moon's shadow map, felt through a sampler that compares as it
    // filters: 1 where the point is no further from the moon than what the
    // map holds there, 0 where something nearer stands between. Its rows run
    // down where the clip space's y runs up; its depth is the clip space's.
    #define NM_SHADOW_ARGUMENT , depth2d<float> shadows
    #define NM_SHADOW_PASS , shadows
    #define NM_SHADOW_TEST(uv, depth) shadows.sample_compare(nm_shadowSampler, uv, depth)
    #define NM_SHADOW_V -0.5
    #define NM_SHADOW_DEPTH(z) (z)
    constexpr sampler nm_shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less_equal);
    // What the fragments' shared code is handed here and finds for itself
    // in the browser: the frame, the Houses' colours (64 to a row, see
    // HousePalette), the land's heights, a pixel left out, and a list of six.
    #define NM_FRAME_UNIFORM
    #define NM_FRAME_ARGUMENT , constant FrameUniforms &frame
    #define NM_FRAME_PASS , frame
    #define NM_PALETTE_ARGUMENT , texture2d<float, access::read> housePalette
    #define NM_HOUSE(slot) housePalette.read(uint2(slot % 64u, slot / 64u)).rgb
    #define NM_HEIGHTS_ARGUMENT , texture2d<float> heights
    #define NM_HEIGHT(uv) heights.sample(nm_smoothSampler, uv).r
    constexpr sampler nm_smoothSampler(filter::linear, address::clamp_to_edge);
    #define NM_DISCARD discard_fragment()
    #define NM_ARRAY6(type, name, a, b, c, d, e, f) constant type name[6] = { a, b, c, d, e, f };

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
    // The moon's own light and its face, whatever lights the land: the
    // hour's key light, its sky and ground, its haze and its cloud are the
    // frame's (see Daylight).
    NM_CONST float3 kMoonColour = float3(0.56, 0.66, 0.92);
    NM_CONST float3 kMoonFace = float3(0.80, 0.82, 0.84);
    // A fill from the south-east: enough to read the faces turned from
    // the key light.
    NM_CONST float3 kFillDirection = float3(0.47, 0.53, 0.70);
    NM_CONST float3 kGlow = float3(0.95, 0.80, 0.52);
    NM_CONST float3 kHearth = float3(1.0, 0.62, 0.30);

    // The frame's own numbers, as every shader reads them.
    struct FrameUniforms {
        float4x4 viewProjection;
        float4x4 inverseViewProjection;
        float4 eye;        // the eye's position, and the map's clock
        float4 key;        // toward the key light (the sun by day, the moon by night), and its strength
        float4 viewport;   // width, height, and their reciprocals, in pixels
        float4 world;      // map radius, tile texture side, pixels per world unit, motion
        float4 highlight;  // hovered q and r, chosen q and r; 999 for none
        float4 extent;     // the land's corner and far corner (x, z)
        float4 haze;       // haze start, density, exposure, heights spacing
        float4 heights;    // the heights grid's corner (x, z), columns, rows
        float4 lights[8];  // the world's own lights: where and how far, then colour
        float4 still;      // the Still's calm, 0 to 1; whether the key light casts shadows; a shadow texel, in world units and in the map's
        float4x4 shadow;   // the key light's view and projection, from the world to its shadow map
        // The hour's light (see Daylight).
        float4 keyColour;   // the key light's colour; how much of the night's own shows, 0 to 1
        float4 skyLight;    // the sky's light; how bright the picture stands, 1 at night
        float4 groundLight; // the ground's light; how much of the filmic curve sets the picture down
        float4 fillColour;  // the fill's colour; how strongly the key light outlines things
        float4 hazeColour;  // the far air's colour; the most of it over a thing
        float4 mistColour;  // the cloud's colour over the unknown; how much of it veils the remembered
        float4 mist;        // the key light on the cloud's hollows, on its tops; the light the remembered keeps
        float4 zenith;      // the sky overhead
        float4 horizon;     // the sky along the horizon
        float4 sun;         // toward the sun; how much of it shows
        float4 moonFace;    // toward the moon; how much of its face shows
        float4 water;       // deep water's colour
        float4 land;        // how far the land's slopes are stood upright; the key light the land takes; its hearths' glow
        float4 glow;        // how brightly a lit window shows; how much it flickers
    };
    NM_FRAME_UNIFORM

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

    // The ground's own grain: broad patches of richer and poorer earth, and
    // a fine speckle over them, darker and lighter about the land's colour
    // and never changing its mean.
    float3 nm_grain(float2 p, float3 albedo) {
        // Patches the size of a hex, swinging the shade by half, were the
        // lake view's grey banks: seen low across the shore they drew out
        // into streaks of cloud (run 540 without the land's light lost
        // them). The ground's grain is now at the scale of tussocks and
        // stones, and its shade swings little.
        float patches = nm_fbm(p * 4.2 + float2(3.7, 1.3));
        float speckle = nm_noise(p * 11.0 + float2(11.0, 5.0));
        float shade = 0.88 + 0.14 * patches + 0.1 * speckle;
        // The poorer patches lean a little toward earth, the richer toward moss.
        float3 earth = albedo * float3(1.06, 0.98, 0.9);
        float3 moss = albedo * float3(0.94, 1.04, 0.98);
        return mix(earth, moss, smoothstep(0.35, 0.65, patches)) * shade;
    }

    // The ground by day, over its grain: the country it lies in, and the
    // stone of its slopes. Whole reaches of the land are lusher or drier
    // than the rest, several hexes across, so no plain is one flat green;
    // where the ground is bare stone and steep, it shows its beds, darker
    // in the clefts; and the finest grain of all, blades and grit, shows
    // close to and fades before it is smaller than a pixel. `day` is how
    // much of this the hour shows: all of it under the sun, none of it by
    // the moon, whose land is drawn as it always was.
    float3 nm_ground(float3 world, float3 n, float3 albedo, float pixel, float day) {
        float2 p = world.xz;
        float3 c = nm_grain(p, albedo);
        if (day <= 0.0) {
            return c;
        }
        float most = max(albedo.r, max(albedo.g, albedo.b));
        float least = min(albedo.r, min(albedo.g, albedo.b));
        // How much of the ground is growth, and how much bare stone, by
        // its own colour: green stands over red and blue; stone is grey.
        float growth = clamp((albedo.g - max(albedo.r, albedo.b)) * 7.0, 0.0, 1.0);
        float stone = 1.0 - clamp((most - least) * 9.0, 0.0, 1.0);
        float country = nm_fbm(p * 0.23 + float2(17.3, 5.1));
        float3 lush = float3(0.80, 0.96, 0.78);
        float3 dry = float3(1.04, 0.99, 0.76);
        float3 reach = mix(dry, lush, smoothstep(0.3, 0.7, country));
        // Glades: paler grass in rounds a hex or so across.
        float glade = smoothstep(0.6, 0.8, nm_fbm(p * 0.9 + float2(41.0, 8.0)));
        reach = mix(reach, float3(1.05, 1.03, 0.86), glade * 0.55);
        float3 shown = c * mix(float3(1.0), reach, growth);
        // The land's colours were chosen to be read by the moon, whose
        // light is a tenth of the sun's: in full sun they stand at the top
        // of the picture, every green a pale lime. Under the sun they are
        // set deeper, the darker the more, so a meadow is a deep green and
        // snow and salt stay bright.
        shown = pow(max(shown, float3(0.0)), float3(1.45));
        // Stone's beds across a slope, broken where the rock is sound.
        float steep = clamp((1.0 - n.y) * 3.0, 0.0, 1.0);
        float beds = 0.5 + 0.5 * sin(world.y * 15.0 + nm_fbm(p * 2.3 + float2(2.0, 31.0)) * 9.0);
        float broken = smoothstep(0.3, 0.7, nm_noise(p * 1.1 + float2(23.0, 4.0)));
        shown *= mix(1.0, 0.72 + 0.4 * beds, stone * steep * broken);
        // Blades and grit, close to.
        float fine = nm_noise(p * 43.0 + float2(7.0, 19.0)) - 0.5;
        shown *= 1.0 + 0.16 * fine * (1.0 - smoothstep(0.012, 0.045, pixel));
        return mix(c, shown, day);
    }

    // The grain a model's surface is drawn with, on the model's own
    // coordinates so it keeps to the model: stone laid in courses, each
    // block its own shade and mortar between; timber in planks, a grain
    // down each; thatch in fine straws; slates in rows, each lapping the
    // one below; earth in clods and grit. `p` is the point on the model,
    // `n` the face's normal there, `footprint` how much of the model one
    // pixel covers: grain finer than a pixel fades to its mean, so it
    // never shimmers. The colour's mean is kept, near enough.
    float3 nm_surface(float3 albedo, float3 p, float3 n, float surface, float footprint) {
        if (surface < 0.5) {
            return albedo;
        }
        float3 a = abs(n);
        // Across the face, and up it (or along it, on a face turned up).
        float2 uv = a.y > max(a.x, a.z) ? float2(p.x, p.z) : (a.x > a.z ? float2(p.z, p.y) : float2(p.x, p.y));
        float shade = 1.0;
        float scale = 0.02;
        if (surface < 1.5) {
            float2 size = float2(0.04, 0.021);
            float row = floor(uv.y / size.y);
            float2 cell = float2(uv.x / size.x + 0.5 * (row - 2.0 * floor(row * 0.5)), uv.y / size.y);
            float2 f = fract(cell);
            float edge = min(min(f.x, 1.0 - f.x) * size.x, min(f.y, 1.0 - f.y) * size.y);
            float mortar = smoothstep(0.0006, 0.002, edge);
            shade = (0.86 + 0.26 * nm_hash12(floor(cell))) * (0.62 + 0.38 * mortar) * (0.92 + 0.16 * nm_noise(uv * 110.0));
            scale = size.y;
        } else if (surface < 2.5) {
            float width = 0.018;
            float plank = floor(uv.x / width);
            float f = fract(uv.x / width);
            float seam = smoothstep(0.0, 0.1, min(f, 1.0 - f));
            float grain = nm_noise(float2(uv.x * 300.0, uv.y * 16.0 + plank * 7.3));
            shade = (0.86 + 0.24 * nm_hash12(float2(plank, 3.0))) * (0.68 + 0.32 * seam) * (0.86 + 0.28 * grain);
            scale = width;
        } else if (surface < 3.5) {
            float straw = nm_noise(float2(uv.x * 480.0, uv.y * 30.0));
            float tuft = nm_noise(uv * 70.0);
            shade = 0.8 + 0.28 * straw + 0.12 * tuft;
            scale = 0.006;
        } else if (surface < 4.5) {
            float2 size = float2(0.026, 0.016);
            float row = floor(uv.y / size.y);
            float2 cell = float2(uv.x / size.x + 0.5 * (row - 2.0 * floor(row * 0.5)), uv.y / size.y);
            float2 f = fract(cell);
            shade = (0.84 + 0.28 * nm_hash12(floor(cell))) * (0.7 + 0.3 * smoothstep(0.0, 0.3, f.y))
                * (0.8 + 0.2 * smoothstep(0.0, 0.08, min(f.x, 1.0 - f.x)));
            scale = size.y;
        } else {
            shade = 0.78 + 0.3 * nm_fbm(uv * 36.0) + 0.1 * nm_noise(uv * 180.0);
            scale = 0.01;
        }
        // Seen from far, a pixel spans many blocks: their mean, unflickering.
        float near = 1.0 - smoothstep(scale * 0.35, scale * 1.2, footprint);
        return albedo * mix(0.95, shade, near);
    }

    float3 nm_encode(float3 c) {
        return pow(clamp(c, float3(0.0), float3(1.0)), float3(1.0 / 2.2));
    }

    // The night's light as the keeper chooses it (Night): every colour
    // lifted `e` times where it is darkest and less the brighter it is,
    // full light kept full, so the dark ground comes up into sight while
    // a lit window or a fire never burns white. It is the colour itself
    // where `e` is 1, the night as the lake was made.
    float3 nm_expose(float3 c, float e) {
        float3 l = max(c, float3(0.0));
        return l * e / (float3(1.0) + l * (e - 1.0));
    }

    // A filmic curve for the day's range: its sunlit whites rolled off
    // into the top of the picture rather than burnt out, its shadows kept.
    float3 nm_filmic(float3 c) {
        float3 x = max(c, float3(0.0));
        return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), float3(0.0), float3(1.0));
    }

    // A colour as the picture holds it: lifted as the keeper chooses, set
    // down by as much of the filmic curve as the hour asks (none at night,
    // whose colours are kept as they are), and encoded.
    float3 nm_output(float3 c NM_FRAME_ARGUMENT) {
        float3 lifted = nm_expose(c, frame.haze.z);
        return nm_encode(mix(lifted, nm_filmic(lifted), frame.groundLight.a));
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

    // The tile texture's four bytes for a hex: terrain; feature, with what
    // the keeper knows of it (sixteen a step) and a hold's flag; relief; and
    // whose land it is. Beyond the map, the Spine, always known and never
    // watched.
    float4 nm_tileAt(int2 h, float radius NM_TEXTURE_ARGUMENT) {
        int r = int(radius);
        if (nm_hexDistance(h) > r) {
            return float4(7.0, 16.0, 0.0, 0.0);
        }
        return floor(NM_TILE(h + int2(r, r)) * 255.0 + 0.5);
    }

    // Whose land a tile is, from its bytes as nm_tileAt gives them: a
    // House's sigil plus one, its low eight bits the fourth byte and its
    // high four the first byte's high half, over the terrain's code; none
    // is zero (see TileTexture).
    float nm_owner(float4 tile) {
        return tile.w + 256.0 * floor(tile.x / 16.0);
    }

    // Whether the keeper knows a hex at all, and whether they watch it now.
    float2 nm_knowledge(int2 h, float radius NM_TEXTURE_ARGUMENT) {
        float feature = nm_tileAt(h, radius NM_TEXTURE_PASS).y;
        float seen = floor((feature - 128.0 * floor(feature / 128.0)) / 16.0);
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

    // A colour lit by the hour: the key light on what faces it (`strength`
    // of it), the fill, and the sky's light above and the ground's below.
    float3 nm_light(float3 albedo, float3 n, float strength NM_FRAME_ARGUMENT) {
        float keyLight = max(dot(n, frame.key.xyz), 0.0) * strength;
        float fill = max(dot(n, kFillDirection), 0.0);
        float3 sky = mix(frame.groundLight.rgb, frame.skyLight.rgb, n.y * 0.5 + 0.5);
        return albedo * (frame.keyColour.rgb * keyLight + frame.fillColour.rgb * fill + sky);
    }

    // How much of the moon's light reaches a point of the world facing `n`,
    // 0 none to 1 all, by the moon's shadow map (`moonView` takes the world
    // to its clip space; `casting.y` is 1 where the moon casts shadows,
    // `casting.z` a texel's width in world units and `casting.w` in the
    // map's own): what
    // stands nearer the moon on the same line keeps it off. The point is
    // taken a texel and a half out from its face, so no face shadows itself,
    // and the map felt at four points a texel apart, each filtered, so a
    // shadow's edge falls soft; toward the map's edge it fades to full light.
    float nm_moonlit(float3 p, float3 n, float4x4 moonView, float4 casting NM_SHADOW_ARGUMENT) {
        if (casting.y < 0.5) {
            return 1.0;
        }
        float4 s = moonView * float4(p + n * casting.z * 1.5, 1.0);
        float2 uv = float2(s.x * 0.5 + 0.5, s.y * NM_SHADOW_V + 0.5);
        float2 inside = min(uv, 1.0 - uv);
        float edge = smoothstep(0.0, 0.08, min(inside.x, inside.y));
        if (edge <= 0.0) {
            return 1.0;
        }
        float depth = NM_SHADOW_DEPTH(s.z) - 0.0004;
        float t = casting.w;
        float lit = NM_SHADOW_TEST(uv + float2(-0.75, -0.25) * t, depth) + NM_SHADOW_TEST(uv + float2(0.25, -0.75) * t, depth)
                  + NM_SHADOW_TEST(uv + float2(0.75, 0.25) * t, depth) + NM_SHADOW_TEST(uv + float2(-0.25, 0.75) * t, depth);
        return mix(1.0, lit * 0.25, edge);
    }

    // Remembered, not watched: as it was last seen, greyed and dim.
    // One of the world's own lights, a fire or a blow, falling on a point
    // of colour `albedo` facing `n`: `place` is where it is and how far it
    // reaches, `colour` its colour times its strength.
    float3 nm_pointLight(float3 albedo, float3 p, float3 n, float4 place, float4 colour) {
        float3 toward = place.xyz - p;
        float d = length(toward);
        float fall = max(1.0 - d / max(place.w, 0.001), 0.0);
        float facing = 0.35 + 0.65 * max(dot(n, toward / max(d, 0.0001)), 0.0);
        return albedo * colour.rgb * fall * fall * facing;
    }

    float3 nm_remembered(float3 c NM_FRAME_ARGUMENT) {
        float grey = dot(c, float3(0.3, 0.5, 0.2));
        // Remembered ground keeps most of its colour, only darker and
        // cooler: out of sight, not out of the world.
        return mix(float3(grey), c, 0.7) * frame.mist.z + frame.mistColour.rgb * frame.mistColour.a;
    }

    // The night sky in a direction, but for the moon: the dark, and the
    // stars, warm and cold.
    float3 nm_stars(float3 d, float time) {
        float up = max(d.y, 0.0);
        float3 colour = mix(float3(0.0030, 0.0042, 0.0085), float3(0.0010, 0.0014, 0.0034), sqrt(up));
        float3 grid = d * 150.0;
        float3 cell = floor(grid);
        float chance = nm_hash13(cell);
        if (chance > 0.9) {
            // The star's place in its cell, carried onto the sky's sphere,
            // so every star whose cell the sky passes through shows.
            float3 spot = cell + 0.5 + (float3(nm_hash13(cell + 7.1), nm_hash13(cell + 3.7), nm_hash13(cell + 1.3)) - 0.5) * 0.6;
            float far = length(grid - normalize(spot) * 150.0);
            float bright = (chance - 0.9) / 0.1;
            float twinkle = 0.75 + 0.25 * sin(nm_spin(time, 1.3 + 2.0 * chance) + chance * 40.0);
            float warm = nm_hash13(cell + 11.0);
            float3 tint = mix(float3(0.70, 0.80, 1.0), float3(1.0, 0.86, 0.66), warm * warm);
            colour += tint * (1.0 - smoothstep(0.0, 0.2, far)) * (0.35 + 2.2 * bright * bright) * twinkle;
        }
        return colour;
    }

    // The moon in a direction: its face, and the bright ring close about it.
    float3 nm_moonlight(float3 d, float3 moon) {
        float facing = dot(d, moon);
        float disc = smoothstep(0.99975, 0.99982, facing);
        float3 face = kMoonFace;
        // Its seas, worked out only on its face.
        if (facing > 0.9997) {
            float2 onFace = float2(dot(d - moon, float3(1.0, 0.0, 0.0)), dot(d - moon, float3(0.0, 1.0, 0.0))) * 60.0;
            float seas = nm_fbm(onFace * 3.0 + 4.0);
            face = kMoonFace * (0.78 + 0.22 * smoothstep(0.35, 0.7, seas));
        }
        float halo = pow(max(facing, 0.0), 2400.0) * 0.55;
        return face * disc * 2.6 + kMoonColour * halo;
    }

    // The moon's broad glow about it in the night's air.
    float3 nm_moonGlow(float3 d, float3 moon) {
        float facing = max(dot(d, moon), 0.0);
        return kMoonColour * (pow(facing, 160.0) * 0.07 + pow(facing, 18.0) * 0.012);
    }

    // The whole night sky in a direction.
    float3 nm_sky(float3 d, float3 moon, float time) {
        return nm_stars(d, time) + nm_moonGlow(d, moon) + nm_moonlight(d, moon);
    }

    // The hour's sky by day in a direction: its blue deepening overhead,
    // pale along the horizon, the sun and its glow. Nothing at night, when
    // the sky is its stars.
    float3 nm_daySky(float3 d NM_FRAME_ARGUMENT) {
        float up = max(d.y, 0.0);
        float3 colour = mix(frame.horizon.rgb, frame.zenith.rgb, 1.0 - pow(1.0 - up, 3.0));
        // Below the horizon, past the land's last edge: the far air.
        colour = mix(colour, frame.hazeColour.rgb, (1.0 - smoothstep(-0.08, 0.0, d.y)) * frame.groundLight.a);
        float facing = max(dot(d, frame.sun.xyz), 0.0);
        float disc = smoothstep(0.99955, 0.99975, facing);
        colour += frame.keyColour.rgb * frame.sun.w * (disc * 14.0 + pow(facing, 420.0) * 1.6 + pow(facing, 28.0) * 0.22);
        return colour;
    }

    // The air between the eye and what it sees far off.
    float3 nm_haze(float3 c, float distance NM_FRAME_ARGUMENT) {
        float amount = 1.0 - exp(-max(distance - frame.haze.x, 0.0) * frame.haze.y);
        return mix(c, frame.hazeColour.rgb, clamp(amount, 0.0, frame.hazeColour.a));
    }

    // The Still's mist over all the keeper has never seen, at a point `p`
    // of it: the same over land and water, so it gives nothing of either
    // away. Broad banks of it drift one way and finer wisps another, the
    // moon catching their tops and the hollows between left dark; and along
    // the edge of what is known (`known`, 0 to 1, as nm_knowledgeAround
    // has it) it gathers thicker, as mist lies along a shore. Its palest
    // tops are no brighter than the moonlit ground the keeper knows, so
    // what is known always stands out of it.
    float3 nm_mist(float2 p, float time, float known NM_FRAME_ARGUMENT) {
        float banks = nm_fbm(p * 0.21 + nm_drift(time, 0.03));
        float wisps = nm_noise(p * 0.8 + float2(41.0, 17.0) - nm_drift(time, 0.05));
        float shore = smoothstep(0.05, 0.5, known);
        float thick = smoothstep(0.42, 0.66, banks + 0.18 * wisps + 0.22 * shore - 0.08);
        return frame.mistColour.rgb * 0.35 + frame.keyColour.rgb * (frame.mist.x + frame.mist.y * thick);
    }

    // How far out from the strand water lies, in the world's units: its
    // depth over how steeply the bed falls there (`fall`, depth for each
    // unit out), so the waves run up the last of every shore alike, steep
    // or shelving, and leave the open water over a shoal alone.
    float nm_offshore(float depth, float fall) {
        return depth / max(fall, 0.05);
    }

    // The strand's small waves over its last half unit of water (`offshore`,
    // from nm_offshore): each washing up in a moment and drawing back
    // slowly, a line of froth at its edge and a thinner foam behind it,
    // every stretch of shore in its own time so none keeps a beat, fainter
    // the calmer the Still lies (`calm`, 0 to 1), as the shore is heard.
    // 0 none, to 1 a wave's full froth.
    float nm_wash(float2 p, float offshore, float time, float calm) {
        if (offshore >= 0.55) {
            return 0.0;
        }
        // Each wave comes round about every eleven seconds, a whole number
        // of times in the clock's period, so none jumps as it starts over.
        float cycle = fract(nm_spin(time, 0.09 * kTau) / kTau + 1.5 * nm_noise(p * 0.35));
        float reach = cycle < 0.2 ? cycle / 0.2 : 1.0 - (cycle - 0.2) / 0.8;
        float front = 0.45 * (1.0 - reach);
        float line = 1.0 - smoothstep(0.0, 0.08, abs(offshore - front));
        float foam = offshore > front ? 0.35 * (1.0 - smoothstep(front, front + 0.18, offshore)) : 0.0;
        // Broken into flecks and gaps, as froth lies.
        float grain = smoothstep(0.2, 0.8, nm_noise(p * 11.0 + nm_drift(time, 0.3)));
        float rise = 1.0 - smoothstep(0.35, 0.55, offshore);
        return min(1.0, (line + foam) * (0.2 + 0.8 * grain)) * rise * (1.0 - 0.85 * calm);
    }

    // A light by the water lying on it (`place`, where it is and how far it
    // reaches; `colour`, its light), seen from the eye at `eye` on the
    // water at `p`, the look's way over the ground `along`: where the faint
    // swell turns the light's image to the eye, a short trembling streak of
    // its own colour from under it toward the eye, narrowing to a mirror's
    // point as the Still lies calm (`calm`, 0 to 1), fainter the farther
    // the light is past its reach.
    float3 nm_lightOnWater(float3 p, float3 eye, float2 along, float4 place, float4 colour, float calm) {
        if (place.w <= 0.0) {
            return float3(0.0);
        }
        float2 toward = place.xz - p.xz;
        float far = max(length(toward), 0.0001);
        // Nothing to be seen of it far past its reach, or well off its line
        // from the eye: most of the water, left at once.
        float aside = (1.0 - max(dot(toward / far, along), 0.0)) / mix(0.012, 0.002, calm);
        if (far > 6.0 * place.w || aside > 9.0) {
            return float3(0.0);
        }
        float down = NM_ATAN2(eye.y - p.y, max(length(eye.xz - p.xz), 0.0001));
        float up = NM_ATAN2(place.y - p.y, far);
        float tilt = (up - down) / mix(0.24, 0.06, calm);
        return colour.rgb * exp(-aside - tilt * tilt) / (1.0 + far * far / (place.w * place.w));
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

    // An ordered pattern for fading by leaving pixels out, as the browser's
    // preview fades a model; the game covers fewer of a pixel's samples.
    float nm_bayer(float2 pixel) {
        float2 p = floor(pixel - 4.0 * floor(pixel / 4.0));
        float index = p.x + p.y * 4.0;
        return nm_hash12(float2(index, 3.0)) * 0.94 + 0.03;
    }
    // Each people's slates and walls, linear, in the order of their
    // heritages: the Saltborn's white, the Fenfolk's reed, the Blackwood
    // Kin's black, the Spinewardens' slate, the Mound Clans' turf, the
    // Strandfolk's sea-grey; then their walls.
    NM_ARRAY6(float3, kPeopleRoof,
              float3(0.68, 0.68, 0.646), float3(0.19, 0.173, 0.087), float3(0.0078, 0.0063, 0.0063),
              float3(0.0394, 0.0434, 0.0606), float3(0.0324, 0.0516, 0.0358), float3(0.0516, 0.0761, 0.1119))
    NM_ARRAY6(float3, kPeopleWall,
              float3(0.612, 0.664, 0.718), float3(0.148, 0.126, 0.099), float3(0.026, 0.0133, 0.0078),
              float3(0.133, 0.133, 0.148), float3(0.428, 0.414, 0.375), float3(0.456, 0.414, 0.325))

    // How much of the land's own shape a point keeps: all of it where the
    // keeper knows the ground, none where they don't, where it lies flat
    // under the mist and gives nothing of itself away.
    float nm_landKnown(float2 knowledge) {
    #ifndef NM_NO_FOG
        return smoothstep(0.0, 1.0, knowledge.x);
    #else
        return 1.0;
    #endif
    }

    // Whether a model is watched now (1), remembered (0.5) or never seen
    // (0): by its hex, unless its flags say it always shows.
    float nm_modelWatched(uint flags, int2 hex, float radius NM_TEXTURE_ARGUMENT) {
        if ((flags & 1u) != 0u) {
            return 1.0;
        }
        float2 knowledge = nm_knowledge(hex, radius NM_TEXTURE_PASS);
        return knowledge.y > 0.5 ? 1.0 : (knowledge.x > 0.5 ? 0.5 : 0.0);
    }

    // A model's own colour at a vertex, linear: its cloth and banners in
    // its House's colour (`tint`, where its alpha says so), and a hold's
    // works as its House's people build them (the flags' second byte, one
    // more than the people): their slates take the people's roofs, their
    // stone and timber lean to its walls.
    float3 nm_modelAlbedo(float3 colour, float material, float surface, float4 tint, uint flags) {
        float3 albedo = nm_linear(colour);
        if ((material > 0.5 && material < 1.5) || (material > 3.5 && material < 4.5)) {
            if (tint.a > 0.5) {
                float shade = dot(albedo, float3(0.30, 0.55, 0.15));
                albedo = tint.rgb * shade * 2.0;
            }
        }
        uint people = (flags >> 8u) & 255u;
        if (people > 0u && people <= 6u && material < 0.5) {
            int which = int(people) - 1;
            if (surface > 3.5 && surface < 4.5) {
                albedo = mix(albedo, kPeopleRoof[which], 0.8);
            } else if (surface > 0.5 && surface < 2.5) {
                albedo = mix(albedo, kPeopleWall[which], surface < 1.5 ? 0.4 : 0.3);
            }
        }
        return albedo;
    }
    // END SCENE

    // What each fragment is given, between the SHADING markers: written in
    // the same shared subset, for fragments alone (it asks how fast things
    // change across a pixel, and leaves pixels out). The Metal fragment
    // functions below and the browser preview's both only hand their
    // inputs to these, so what the preview draws is what the game draws.
    // BEGIN SHADING

    // The land at a point of it: `known` as the mesh's corner had it.
    float4 nm_landShade(float3 world, float3 normal, float3 colour, float known
                        NM_FRAME_ARGUMENT NM_TEXTURE_ARGUMENT NM_SHADOW_ARGUMENT NM_PALETTE_ARGUMENT) {
        float time = frame.eye.w;
        float radius = frame.world.x;
        float2 p = world.xz;
        int2 h = nm_hexRound(nm_axial(p));
        float3 edge = nm_hexEdge(p, h);
        float pixel = max(fwidth(p.x), fwidth(p.y));
        // What the keeper knows of the ground, blended between hexes here
        // and not from the mesh's corners, so the edge of sight is a soft
        // falling-off and never a terrace of lit and grey hexes.
    #ifndef NM_NO_FOG
        float2 knows = nm_knowledgeAround(p, radius NM_TEXTURE_PASS);
    #else
        float2 knows = float2(1.0, 1.0);
    #endif
        // How much of the ground shows through the mist: none over the
        // unknown, which is never drawn under it, and the known ground's own
        // colour fading into it over its outer half.
        float clear = smoothstep(0.55, 1.0, knows.x);

        // The hex under the pointer, and the one chosen.
        float hovered = (abs(float(h.x) - frame.highlight.x) < 0.5 && abs(float(h.y) - frame.highlight.y) < 0.5) ? 1.0 : 0.0;
        float chosen = (abs(float(h.x) - frame.highlight.z) < 0.5 && abs(float(h.y) - frame.highlight.w) < 0.5) ? 1.0 : 0.0;
        float ring = 1.0 - smoothstep(pixel * 0.8, pixel * 2.4, edge.x);
        // Lit of themselves, as bright against the day as against the night.
        float level = frame.skyLight.a;
        float3 marked = (float3(0.20, 0.22, 0.26) * ring * hovered * 0.6
            + kGlow * (ring * 0.9 + (1.0 - smoothstep(0.0, 0.35, edge.x)) * 0.08) * chosen) * level;

        float3 lit = float3(0.0);
        if (clear > 0.0) {
            float3 n = normalize(normal);
            float4 tile = nm_tileAt(h, radius NM_TEXTURE_PASS);
            float owner = nm_owner(tile);
        #ifndef NM_NO_GRAIN
            // All of it at noon, some of it at dusk and dawn (by how
            // brightly the hour's marks are lit), none of it at night.
            float3 albedo = nm_ground(world, n, colour, pixel, frame.groundLight.a * clamp((frame.skyLight.a - 1.0) / 7.0, 0.0, 1.0));
        #else
            float3 albedo = colour;
        #endif

            // Whose land: a faint wash of the House's colour, and a line
            // where it meets another's.
            if (owner > 0.5 && known > 0.5) {
                // Each House's colour a texel past its sigil, 64 to a row
                // (see HousePalette).
                uint slot = uint(owner);
                float3 house = NM_HOUSE(slot);
                // The wash is the faintest breath of the House's colour,
                // broken by the ground's own grain, so the land reads as land.
                float breath = 0.035 + 0.025 * nm_hash12(floor(p * 7.0));
                // From afar, as the eye draws back over the realm (the haze
                // begins at nine tenths of its distance), it deepens, so
                // whose land is whose reads at a glance across the lake as
                // a map of war shows it; close in it stays a breath.
                breath = mix(breath, 0.3, smoothstep(60.0, 120.0, frame.haze.x / 0.9));
                albedo = mix(albedo, house * 0.5, breath);
                // The neighbour is the hex just outside the nearest edge: a
                // point pushed out past it, so a line falls only where the
                // land truly meets another's, never between hexes of one.
                float2 centre = nm_hexCentre(h);
                int2 across = nm_hexRound(nm_axial(centre + (p - centre) * 1.45));
                if (across.x != h.x || across.y != h.y) {
                    float otherOwner = nm_owner(nm_tileAt(across, radius NM_TEXTURE_PASS));
                    if (abs(otherOwner - owner) > 0.5) {
                        float line = 1.0 - smoothstep(pixel * 0.8, pixel * 3.2, edge.x);
                        lit += house * line * 0.22 * level;
                    }
                }
            }
        #ifndef NM_NO_LIGHT
            // Ground the keeper half knows is laid flat toward the mist and
            // turned to face the sky: the moon lit it full on, brighter than
            // any true slope, and along the edge of what is known it lay in
            // pale banks over the shore (run 543: gone without the light,
            // kept without the grain). The moon and the sky light only what
            // is known.
            float shown = smoothstep(0.35, 1.0, known);
            // The moon low over the far shore lit the slopes facing it into
            // pale banks against the rest (run 546: kept without the fog,
            // lost without the light); on the land it falls softer than on
            // models. Softer alone kept them (run 546 after 543): the slope
            // itself turned the land toward the moon and the fill. The land
            // is lit by its normal bent most of the way upright, so a
            // hillside's whole face can never stand pale against the flats
            // beside it; the fine grain of the ground still shades within it.
            // By day the sun stands high and the land takes it on its own
            // slopes, all of it (the frame's land says how far, and how much).
            float3 ln = normalize(mix(n, float3(0.0, 1.0, 0.0), frame.land.x));
            // What stands on the land keeps the key light off the ground behind it.
            float moonlit = nm_moonlit(world, n, frame.shadow, frame.still NM_SHADOW_PASS);
            lit += nm_light(albedo, ln, frame.key.w * frame.land.y * moonlit NM_FRAME_PASS) * shown;
            for (int i = 0; i < 4; i++) {
                lit += nm_pointLight(albedo, world, n, frame.lights[i], frame.lights[i + 4]);
            }
        #else
            lit += albedo * 0.02;
        #endif

            // A hold's hearths light the country round it.
            for (int i = 0; i < 7; i++) {
                int2 toward = int2(0, 0);
                if (i == 1) { toward = int2(1, 0); }
                if (i == 2) { toward = int2(-1, 0); }
                if (i == 3) { toward = int2(0, 1); }
                if (i == 4) { toward = int2(0, -1); }
                if (i == 5) { toward = int2(1, -1); }
                if (i == 6) { toward = int2(-1, 1); }
                float4 near = nm_tileAt(h + toward, radius NM_TEXTURE_PASS);
                if (near.y >= 128.0) {
                    float far = length(p - nm_hexCentre(h + toward));
                    lit += albedo * kHearth * 0.55 * exp(-far * far * 1.6) * frame.land.z;
                }
            }
            lit += marked;
            // Remembered, not watched: as it was last seen.
            lit = mix(nm_remembered(lit NM_FRAME_PASS), lit, smoothstep(0.0, 1.0, knows.y));
        }
    #ifndef NM_NO_FOG
        if (knows.x < 0.999) {
            // The unknown lies under the Still's mist, the pointer's and the
            // chosen hex's ring showing faintly through it.
            float3 mist = nm_mist(p, time, knows.x NM_FRAME_PASS)
                + (nm_remembered(marked NM_FRAME_PASS) - frame.mistColour.rgb * frame.mistColour.a) * 0.18;
            lit = mix(mist, lit, clear);
        }
    #endif
        // Past the map's edge the Spine goes on: into the dark at night, by
        // day into the far air.
        float beyond = float(nm_hexDistance(h)) - radius;
        float kept = clamp(1.0 - 0.13 * beyond, 0.18, 1.0);
        lit = lit * kept + frame.hazeColour.rgb * (1.0 - kept) * frame.groundLight.a;
    #ifndef NM_NO_HAZE
        lit = nm_haze(lit, distance(world, frame.eye.xyz) NM_FRAME_PASS);
    #endif
        return float4(nm_output(lit NM_FRAME_PASS), 1.0);
    }

    // The still water at a point of its face; nothing where the land
    // stands above it.
    float4 nm_waterShade(float3 world NM_FRAME_ARGUMENT NM_TEXTURE_ARGUMENT NM_HEIGHTS_ARGUMENT) {
        float2 grid = (world.xz - frame.heights.xy) / frame.haze.w + 0.5;
        float ground = NM_HEIGHT(grid / frame.heights.zw);
        float depth = -ground;
        if (depth <= 0.0) {
            NM_DISCARD;
        }
        float time = frame.eye.w;
        float3 look = normalize(world - frame.eye.xyz);
        float3 mirrored = float3(look.x, -look.y, look.z);
        float facing = 1.0 - max(-look.y, 0.0);
        float fresnel = 0.30 + 0.70 * facing * facing * facing * facing * facing;
        // The sky it gives back: by night its stars and the moon, by day
        // its blue and the sun, each as much as the hour shows of it.
        float night = frame.keyColour.a;
        // By day it is a dark glass: looked down into it gives back little
        // of the sky, and all of it only where the look runs low across it.
        float glass = 0.03 + 0.97 * facing * facing * facing * facing * facing;
        // And under the sun it has a colour of its own, as the night's
        // black water has none: clear and green-blue over the shallows,
        // where the light comes back off the bed, a deep blue over the
        // deeps; as bright as the hour's sky, and nothing at all by night.
        float sunlit = (1.0 - night) * dot(frame.skyLight.rgb, float3(0.3, 0.5, 0.2)) / 0.44;
        float3 body = mix(float3(0.075, 0.30, 0.32), float3(0.016, 0.08, 0.21), smoothstep(0.04, 0.8, depth)) * sunlit;
        float3 starlit = frame.water.rgb + body
            + (nm_stars(mirrored, time) + nm_moonGlow(mirrored, frame.moonFace.xyz)) * night * fresnel
            + nm_daySky(mirrored NM_FRAME_PASS) * glass;
        float3 moonlit = nm_moonlight(mirrored, frame.moonFace.xyz) * fresnel * frame.moonFace.w;
        // The moon's road: on the still water's faint swell, a broken glitter
        // of its light along its bearing from the eye, narrow near the moon's
        // image and widening toward the shore the eye stands on.
        float2 toMoon = normalize(frame.key.xz);
        float2 along = normalize(look.xz);
        float across = 1.0 - max(dot(toMoon, along), 0.0);
        float near = clamp(distance(world, frame.eye.xyz) / 40.0, 0.05, 1.0);
        // The calmer the Still, the narrower and whole the road: at its
        // deepest calm the moon lies on the water as in a mirror.
        float calm = clamp(frame.still.x, 0.0, 1.0);
        float road = exp(-across * across / ((0.00001 + 0.0002 * (1.0 - near)) * (1.0 - 0.6 * calm)));
        float swell = nm_fbm(world.xz * float2(9.0, 2.2) + nm_drift(time, 0.03 * (1.0 - calm)));
        float glint = mix(smoothstep(0.66, 0.86, swell), 0.75, calm);
        moonlit += frame.keyColour.rgb * road * glint * 0.09 * fresnel * (frame.key.w / 1.5);
        // And the lights by the water lie on it as the moon does: a
        // fisher's lantern, a fire on the shore, each broken by the same
        // swell, whole at the calm.
        for (int i = 0; i < 4; i++) {
            moonlit += nm_lightOnWater(world, frame.eye.xyz, along, frame.lights[i], frame.lights[i + 4], calm)
                * mix(0.3 + glint, 1.0, calm) * 0.14 * fresnel;
        }
        // Where it is shallow the shingle shows through, darkened and wet.
        float clear = smoothstep(0.0, 0.14, depth);

        // Blended between hexes, so the edge of sight is no row of steps.
        float2 knowledge = nm_knowledgeAround(world.xz, frame.world.x NM_TEXTURE_PASS);
        // The lake lies open to every shore: its water is never grey with
        // memory, only a little dimmer out of sight; and the moon's image
        // lies whole on all of it, seen or not.
        float3 colour = starlit * mix(0.72, 1.0, knowledge.y) + moonlit;
        // At the strand the small waves wash up pale with the moon and draw
        // back, the froth hiding the shingle under it; the lake's own water
        // only, never the skin over a ford or a stream's shoals. How far out
        // the water lies is read from how the bed falls a cell east and a
        // cell south, only where it is shallow enough to be near a shore.
        float froth = 0.0;
    #ifndef NM_NO_WASH
        if (depth < 0.6) {
            float4 tile = nm_tileAt(nm_hexRound(nm_axial(world.xz)), frame.world.x NM_TEXTURE_PASS);
            float kind = tile.x - 16.0 * floor(tile.x / 16.0);
            if (kind < 7.5) {
                float east = NM_HEIGHT((grid + float2(1.0, 0.0)) / frame.heights.zw);
                float south = NM_HEIGHT((grid + float2(0.0, 1.0)) / frame.heights.zw);
                float fall = length(float2(east - ground, south - ground)) / frame.haze.w;
                froth = nm_wash(world.xz, nm_offshore(depth, fall), time, calm);
            }
        }
    #endif
        // Laid over what shows through the shallows as froth lies on it.
        // Froth is white: lit as the palest thing on the shore would be in
        // this hour's light, facing it full, so that it is never darker
        // than the sand it washes over nor the water it lies on, and the
        // moon's image runs on through it.
        float3 pale = 0.9 * (frame.keyColour.rgb * frame.key.w * frame.land.y + frame.fillColour.rgb + frame.skyLight.rgb);
        float3 foam = max(pale * mix(0.72, 1.0, knowledge.y), colour);
        float cover = 1.0 - (1.0 - clear) * (1.0 - froth);
        colour = (colour * clear * (1.0 - froth) + foam * froth) / max(cover, 0.0001);
        colour = nm_haze(colour, distance(world, frame.eye.xyz) NM_FRAME_PASS);
        return float4(nm_output(colour NM_FRAME_PASS), cover);
    }

    // The river of the sky: a band of faint light along a great circle,
    // torn by dark lanes of dust, thick with fine stars.
    float3 nm_milkyWay(float3 d) {
        float across = dot(d, normalize(float3(0.86, 0.22, 0.46)));
        float along = NM_ATAN2(d.z, d.x);
        float band = exp(-across * across / 0.007);
        // Below the far shore, or well off the band, there is nothing to add.
        if (d.y < -0.02 || band < 0.02) { return float3(0.0); }
        float2 q = float2(along * 3.2, across * 9.0);
        // Clotted, never an even wash: light only where the noise gathers.
        float glow = band * smoothstep(0.35, 0.85, nm_fbm(q * 1.7 + 4.0));
        float lanes = smoothstep(0.42, 0.68, nm_fbm(q * 3.1 + 11.0)) * exp(-across * across / 0.004);
        glow *= 1.0 - 0.75 * lanes;
        float3 colour = float3(0.0022, 0.0024, 0.0031) * glow;
        // Fine stars, many more within the band than without.
        float3 grid = d * 420.0;
        float3 cell = floor(grid);
        float chance = nm_hash13(cell + 57.0);
        float dense = 0.985 - 0.10 * band;
        if (chance > dense) {
            float3 spot = cell + 0.5 + (float3(nm_hash13(cell + 2.3), nm_hash13(cell + 5.9), nm_hash13(cell + 8.1)) - 0.5) * 0.6;
            float far = length(grid - normalize(spot) * 420.0);
            float bright = (chance - dense) / (1.0 - dense);
            colour += mix(float3(0.75, 0.82, 1.0), float3(1.0, 0.9, 0.75), nm_hash13(cell + 9.4))
                * (1.0 - smoothstep(0.0, 0.35, far)) * (0.10 + 0.5 * bright * bright);
        }
        return colour * smoothstep(-0.02, 0.12, d.y);
    }

    // The sky behind everything, at a point of the view (`ndc`, -1 to 1).
    float4 nm_skyShade(float2 ndc NM_FRAME_ARGUMENT) {
        float4 near = frame.inverseViewProjection * float4(ndc, 0.0, 1.0);
        float4 far = frame.inverseViewProjection * float4(ndc, 1.0, 1.0);
        float3 d = normalize(far.xyz / far.w - near.xyz / near.w);
        float time = frame.eye.w;
        // The sky's own stars brighter than their image on the water, and a
        // second, finer field of them behind, so the night over the far
        // shore is full.
        float3 colour = nm_stars(d, time) * 2.4 + nm_stars(float3(d.z, d.x, d.y) * 1.0, time + 31.0) * 0.9
            + nm_milkyWay(d) + nm_moonGlow(d, frame.moonFace.xyz) + nm_moonlight(d, frame.moonFace.xyz) * frame.moonFace.w;
        // The night's haze lies thick along the horizon and thins upward,
        // so the far shore stands dark against a lighter band of air.
        float up = max(d.y, 0.0);
        float3 horizon = frame.mistColour.rgb * 1.6 + kMoonColour * 0.004;
        colour = mix(horizon, colour, smoothstep(0.0, 0.035, up));
        // As much of the night as the hour shows, and the day's sky over it.
        colour = colour * frame.keyColour.a + nm_daySky(d NM_FRAME_PASS);
        return float4(nm_output(colour NM_FRAME_PASS), 1.0);
    }

    // A model at a point of it: `colour` its own colour there, `local` and
    // `localNormal` where on the model and which way its face turns, for
    // its grain; `params` its instance's (risen to, opacity, phase,
    // emphasis). Nothing above what has been raised of it. Its alpha is how
    // much of the pixel it covers as it fades.
    float4 nm_modelShade(float3 world, float3 normal, float3 colour, float localY, float3 local, float3 localNormal,
                         float surface, float material, float4 params, float watched
                         NM_FRAME_ARGUMENT NM_SHADOW_ARGUMENT) {
        if (localY > params.x) {
            NM_DISCARD;
        }
        float time = frame.eye.w + params.z;
        float3 n = normalize(normal);
        float3 toEye = normalize(frame.eye.xyz - world);
        if (dot(n, toEye) < 0.0) {
            n = -n;
        }
        float3 albedo = nm_surface(colour, local, localNormal, surface, length(fwidth(local)));
        // What stands nearer the moon keeps its light off: its glints and
        // its outline with it.
        float moonlit = nm_moonlit(world, n, frame.shadow, frame.still NM_SHADOW_PASS);
        float3 lit = nm_light(albedo, n, frame.key.w * moonlit NM_FRAME_PASS);
        for (int i = 0; i < 4; i++) {
            lit += nm_pointLight(albedo, world, n, frame.lights[i], frame.lights[i + 4]);
        }
        float facing = 1.0 - max(dot(n, toEye), 0.0);
        // The key light behind outlines what stands against it.
        float behind = max(dot(-toEye, frame.key.xyz), 0.0);
        float3 keyColour = frame.keyColour.rgb;
        lit += keyColour * facing * facing * facing * (0.04 + 0.22 * behind * moonlit) * frame.key.w * frame.fillColour.a;
        if (material > 5.5) {
            float3 halfway = normalize(toEye + frame.key.xyz);
            lit += keyColour * pow(max(dot(n, halfway), 0.0), 48.0) * 0.9 * frame.key.w * moonlit;
        } else if (material > 4.5) {
            float glint = pow(max(dot(n, normalize(toEye + frame.key.xyz)), 0.0), 20.0) * moonlit;
            lit += colour * (0.16 + 0.1 * sin(nm_spin(time, 1.7) + world.x * 5.0)) + float3(0.6, 0.7, 0.9) * glint * 0.5;
        } else if (material > 1.5 && material < 2.5) {
            // A lit window, a lantern's pane: bright of itself, brightest at night.
            lit = colour * (frame.glow.x + frame.glow.y * nm_flicker(time + world.x * 3.0 + world.z * 2.0) * frame.world.w);
        }
        // Lit of themselves, as bright against the day as against the night.
        float level = frame.skyLight.a;
        // A work being raised: its newest course pale and fresh.
        if (params.x < 50.0 && localY > params.x - 0.025) {
            lit += float3(0.05, 0.042, 0.03) * level;
        }
        // Chosen, or under the pointer: a light about its edges.
        lit += kGlow * params.w * facing * facing * 0.45 * level;
        if (watched < 0.75) {
            lit = nm_remembered(lit NM_FRAME_PASS);
        }
        lit = nm_haze(lit, distance(world, frame.eye.xyz) NM_FRAME_PASS);
        // Fading, it covers as many of the pixel's samples as it is opaque.
        return float4(nm_output(lit NM_FRAME_PASS), params.y < 0.999 ? clamp(params.y, 0.0, 1.0) : 1.0);
    }

    // A mote at a point of its disc (`corner`, -1 to 1 across it).
    float4 nm_moteShade(float2 corner, float4 colour, float3 world NM_FRAME_ARGUMENT) {
        float r = length(corner);
        if (r > 1.0) {
            NM_DISCARD;
        }
        float soft = 1.0 - smoothstep(0.1, 1.0, r);
        float far = 1.0 - clamp(1.0 - exp(-max(distance(world, frame.eye.xyz) - frame.haze.x, 0.0) * frame.haze.y), 0.0, frame.hazeColour.a);
        // A mote's light is its own, a spark's or a fire's: as bright in a
        // lighter night (Night) as in the night as made, never lifted with
        // the moon's; by day set down by the day's curve with the rest.
        float3 light = colour.rgb * soft * far;
        return float4(nm_encode(mix(light, nm_filmic(light), frame.groundLight.a)), colour.a * soft);
    }
    // END SHADING

    struct ModelVertex {
        packed_float3 position;
        packed_char4 normalMaterial;
        packed_uchar4 colorSway;
        // The part it moves with, a second part it moves with by blend
        // 255ths (skin over a joint), and the grain drawn on it.
        uchar part;
        uchar part2;
        uchar surface;
        uchar blend;
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
        float known = nm_landKnown(knowledge);
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
                                     texture2d<float, access::read> tiles [[texture(0)]],
                                     depth2d<float> shadows [[texture(2)]],
                                     texture2d<float, access::read> housePalette [[texture(3)]]) {
        return nm_landShade(in.world, in.normal, in.colour, in.known, frame, tiles, shadows, housePalette);
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
        return nm_waterShade(in.world, frame, tiles, heights);
    }

    // MARK: The sky

    struct SkyOut {
        float4 position [[position]];
        float2 ndc;
    };

    // One triangle over the whole view, at the far plane: it is drawn only
    // where nothing nearer stands, which is the sky over the far shore.
    vertex SkyOut nm_sky_vertex(uint vid [[vertex_id]]) {
        float2 corner = float2(float((vid << 1u) & 2u), float(vid & 2u)) * 2.0 - 1.0;
        SkyOut out;
        out.position = float4(corner, 1.0, 1.0);
        out.ndc = corner;
        return out;
    }

    fragment float4 nm_sky_fragment(SkyOut in [[stage_in]], constant FrameUniforms &frame [[buffer(0)]]) {
        return nm_skyShade(in.ndc, frame);
    }

    // MARK: Models

    struct ModelOut {
        float4 position [[position]];
        float3 world;
        float3 normal;
        float3 colour;
        float localY;
        // Where on the model, and which way its face turns there: for its grain.
        float3 local;
        float3 localNormal;
        float surface [[flat]];
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
        if (v.blend > 0) {
            float w = float(v.blend) / 255.0;
            part = part * (1.0 - w) + palette[instance.palette + uint(v.part2)] * w;
        }
        float4 posed = part * float4(local, 1.0);
        float4 world = instance.model * posed;
        float3 normal = (instance.model * (part * float4(float3(packedNormal.xyz) / 127.0, 0.0))).xyz;
        float watched = nm_modelWatched(instance.flags, instance.hex, frame.world.x, tiles);
        ModelOut out;
        // What the keeper has never seen is not drawn: put past the far plane.
        out.position = watched > 0.25 ? frame.viewProjection * world : float4(0.0, 0.0, 2.0, 1.0);
        out.world = world.xyz;
        out.normal = normalize(normal);
        out.colour = nm_modelAlbedo(float3(packedColour.xyz) / 255.0, material, float(v.surface), instance.colour, instance.flags);
        out.localY = posed.y;
        out.local = float3(v.position);
        out.localNormal = float3(packedNormal.xyz) / 127.0;
        out.surface = float(v.surface);
        out.material = material;
        out.params = instance.params;
        out.watched = watched;
        return out;
    }

    // A model's vertex as the moon sees it, for its shadow map: placed as the
    // model vertex places it (posed, skinned, swaying), what the keeper has
    // never seen casting nothing, and a work being raised casting only what
    // stands of it, the rest drawn down to its newest course.
    vertex float4 nm_shadow_vertex(uint vid [[vertex_id]],
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
        if (v.blend > 0) {
            float w = float(v.blend) / 255.0;
            part = part * (1.0 - w) + palette[instance.palette + uint(v.part2)] * w;
        }
        float4 posed = part * float4(local, 1.0);
        posed.y = min(posed.y, instance.params.x);
        float4 world = instance.model * posed;
        float watched = nm_modelWatched(instance.flags, instance.hex, frame.world.x, tiles);
        return watched > 0.25 ? frame.shadow * world : float4(0.0, 0.0, 2.0, 1.0);
    }

    fragment float4 nm_model_fragment(ModelOut in [[stage_in]], constant FrameUniforms &frame [[buffer(0)]],
                                      depth2d<float> shadows [[texture(2)]]) {
        return nm_modelShade(in.world, in.normal, in.colour, in.localY, in.local, in.localNormal,
                             in.surface, in.material, in.params, in.watched, frame, shadows);
    }

    // MARK: Motes

    struct Mote {
        float4 place;   // where, and its radius
        float4 colour;  // the light it gives, and how much it hides
    };

    struct MoteOut {
        float4 position [[position]];
        float2 corner;
        float4 colour;
        float3 world;
    };

    vertex MoteOut nm_mote_vertex(uint vid [[vertex_id]],
                                  uint iid [[instance_id]],
                                  const device Mote *motes [[buffer(1)]],
                                  constant FrameUniforms &frame [[buffer(3)]],
                                  texture2d<float, access::read> tiles [[texture(0)]]) {
        Mote mote = motes[iid];
        float2 corner = float2((vid == 1u || vid == 4u || vid == 5u) ? 1.0 : -1.0, (vid == 2u || vid == 3u || vid == 5u) ? 1.0 : -1.0);
        // A disc facing the eye.
        float3 forward = normalize(mote.place.xyz - frame.eye.xyz);
        float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
        float3 up = cross(right, forward);
        float3 world = mote.place.xyz + (right * corner.x + up * corner.y) * mote.place.w;
        int2 h = nm_hexRound(nm_axial(mote.place.xz));
        float2 knowledge = nm_knowledge(h, frame.world.x, tiles);
        MoteOut out;
        // Over what the keeper has never seen, nothing.
        out.position = knowledge.x > 0.5 ? frame.viewProjection * float4(world, 1.0) : float4(0.0, 0.0, 2.0, 1.0);
        out.corner = corner;
        out.colour = mote.colour;
        out.world = world;
        return out;
    }

    fragment float4 nm_mote_fragment(MoteOut in [[stage_in]], constant FrameUniforms &frame [[buffer(0)]]) {
        return nm_moteShade(in.corner, in.colour, in.world, frame);
    }
    """#
}
