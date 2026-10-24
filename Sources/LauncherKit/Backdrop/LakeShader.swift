/// Metal source for the lake backdrop.
///
/// The shader is compiled at runtime with `MTLDevice.makeLibrary(source:options:)`,
/// which keeps the package buildable with plain `swift build`; SwiftPM does not
/// compile `.metal` files on the command line. The code between the SCENE
/// markers is also rendered by `Tools/scene-preview` in a browser.
enum LakeShader {
    static let vertexFunction = "nm_lake_vertex"
    static let fragmentFunction = "nm_lake_fragment"

    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    // BEGIN SCENE
    // The scene is written in the subset shared by Metal Shading Language and
    // GLSL ES 3.00 so Tools/scene-preview can render it in a browser: only
    // float/float2/float3/float4, swizzles and common built-ins; no literal
    // suffixes, implicit int/float conversion, out parameters or global
    // constants other than #defines; smoothstep edges always ascending.

    #define NM_TAU 6.28318530718
    #define NM_MOON_X 0.705
    #define NM_MOON_Y 0.805
    #define NM_MOON_R 0.027

    float nm_hash12(float2 p) {
        float3 p3 = fract(float3(p.x, p.y, p.x) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    float2 nm_hash22(float2 p) {
        float3 p3 = fract(float3(p.x, p.y, p.x) * float3(0.1031, 0.1030, 0.0973));
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.xx + p3.yz) * p3.zy);
    }

    float nm_noise(float2 p) {
        float2 i = floor(p);
        float2 f = p - i;
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = nm_hash12(i);
        float b = nm_hash12(i + float2(1.0, 0.0));
        float c = nm_hash12(i + float2(0.0, 1.0));
        float d = nm_hash12(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    float nm_fbm(float2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
            v += a * nm_noise(p);
            p = p * 2.03 + float2(17.1, 9.3);
            a *= 0.5;
        }
        return v;
    }

    // One layer of point stars on a jittered grid. Each cell holds at most one
    // star kept away from the cell border, so a single cell lookup is exact.
    // `pt` is the size of one point in scene units; star sizes are in points so
    // they stay crisp at every window size and backing scale.
    float3 nm_starLayer(float2 p, float scale, float density, float minB, float maxB,
                        float sigma, float pt, float time, float twinkle, float seed) {
        float2 g = p * scale;
        float2 id = floor(g);
        float2 f = g - id;
        if (nm_hash12(id + seed) > density) {
            return float3(0.0);
        }
        float2 pos = 0.2 + 0.6 * nm_hash22(id + seed * 1.7 + 11.0);
        float r = length(f - pos) / (scale * pt);
        float k = nm_hash12(id * 1.31 + seed + 5.0);
        float b = mix(minB, maxB, k * k * k);
        float ph = nm_hash12(id + seed + 23.0);
        float tw = 1.0 + twinkle * sin(time * (0.6 + 1.7 * ph) + NM_TAU * ph);
        float core = exp(-r * r / (2.0 * sigma * sigma));
        float halo = 0.10 * exp(-r / (sigma * 4.0)) * smoothstep(0.55, 1.0, k);
        float temp = nm_hash12(id + seed + 41.0);
        float3 tint = mix(float3(0.76, 0.85, 1.0), float3(1.0, 0.92, 0.82), temp * temp);
        return tint * b * tw * (core + halo);
    }

    float3 nm_skyGradient(float y, float horizon) {
        float t = clamp((y - horizon) / (1.0 - horizon), 0.0, 1.0);
        float3 zenith = float3(0.004, 0.006, 0.012);
        float3 low = float3(0.040, 0.052, 0.074);
        float3 c = mix(low, zenith, pow(t, 0.36));
        c += float3(0.050, 0.062, 0.082) * exp(-t * 18.0);
        return c;
    }

    // Heights of the far shore above the horizon, in scene units: a distant
    // range of flat-topped mesas and a low, nearer bank.
    float nm_mesas(float x) {
        float n = nm_fbm(float2(x * 2.2 + 7.0, 4.3));
        float tops = smoothstep(0.50, 0.56, n) * 0.55 + smoothstep(0.60, 0.65, n) * 0.45;
        float body = 0.012 + 0.030 * tops;
        float wear = 0.0012 * nm_noise(float2(x * 55.0, 1.0));
        float mask = smoothstep(0.15, 0.55, nm_noise(float2(x * 0.9 + 2.0, 8.0)));
        return (body + wear) * mask;
    }

    float nm_bank(float x) {
        float n = nm_fbm(float2(x * 3.1 + 1.0, 2.2));
        return 0.0018 + 0.006 * smoothstep(0.35, 0.75, n) + 0.0007 * nm_noise(float2(x * 70.0, 5.0));
    }

    // A rare, faint meteor. It is a pure function of time, so the mirrored sky
    // in the water shows the same streak.
    float3 nm_meteor(float2 p, float aspect, float pt, float horizon, float time) {
        float period = 37.0;
        float k = floor(time / period);
        float2 hk = nm_hash22(float2(k, 7.0));
        if (hk.x > 0.6) {
            return float3(0.0);
        }
        float u = (time - k * period - (2.0 + hk.y * (period - 4.0))) / 0.9;
        if (u < 0.0 || u > 1.0) {
            return float3(0.0);
        }
        float2 hs = nm_hash22(float2(k, 19.0));
        float2 start = float2(aspect * (0.12 + 0.76 * hs.x), horizon + 0.28 + (0.68 - horizon) * hs.y);
        float2 dir = normalize(float2(hs.x > 0.5 ? -1.0 : 1.0, -0.45));
        float2 head = start + dir * 0.17 * u;
        float tail = 0.075 * (0.35 + 0.65 * sin(3.14159 * u));
        float2 rel = p - head;
        float along = dot(rel, -dir);
        if (along < -0.004 || along > tail) {
            return float3(0.0);
        }
        float across = dot(rel, float2(-dir.y, dir.x)) / pt;
        float streak = exp(-across * across / 0.6) * pow(1.0 - clamp(along / tail, 0.0, 1.0), 2.0);
        float glow = exp(-dot(rel, rel) / (pt * pt * 3.0));
        return float3(0.80, 0.87, 1.0) * sin(3.14159 * u) * (0.6 * streak + 0.7 * glow);
    }

    // Everything above the waterline: gradient, Milky Way, stars, moon, shore.
    float3 nm_sky(float2 p, float aspect, float pt, float horizon, float time, float twinkle) {
        float3 c = nm_skyGradient(p.y, horizon);
        float2 m = float2(aspect * NM_MOON_X, NM_MOON_Y);
        float dm = length(p - m);

        // A faint galactic band, tilted across the sky.
        float2 bandDir = normalize(float2(1.0, 0.42));
        float2 bandOrigin = float2(aspect * 0.30, 0.66);
        float across = dot(p - bandOrigin, float2(-bandDir.y, bandDir.x));
        float band = exp(-across * across / 0.016);
        float dust = nm_fbm(p * 3.1 + float2(3.0, 1.0));
        float lanes = smoothstep(0.42, 0.62, nm_fbm(p * 7.3 + float2(9.0, 4.0)));
        float galaxy = band * (0.45 + 0.9 * dust) * (1.0 - 0.6 * lanes);

        float altitude = smoothstep(horizon + 0.005, horizon + 0.22, p.y);
        float glare = smoothstep(NM_MOON_R * 1.4, NM_MOON_R * 9.0, dm);
        float visible = altitude * glare;
        c += float3(0.70, 0.76, 0.88) * 0.030 * galaxy * visible;

        float3 s = nm_starLayer(p, 74.0, 0.42 + 0.40 * band, 0.02, 0.20, 0.42, pt, time, twinkle * 0.6, 3.0);
        s += nm_starLayer(p, 31.0, 0.40, 0.10, 0.62, 0.52, pt, time, twinkle, 17.0);
        s += nm_starLayer(p, 11.0, 0.36, 0.50, 1.80, 0.66, pt, time, twinkle, 31.0);
        c += s * visible;
        c += nm_meteor(p, aspect, pt, horizon, time) * visible * step(0.15, twinkle);

        // Moon: a cold disc with soft limb darkening, faint maria and a wide halo.
        float rim = max(dm - NM_MOON_R, 0.0);
        float3 glowTint = float3(0.58, 0.68, 0.86);
        c += glowTint * (0.060 * exp(-rim * 3.2) + 0.090 * exp(-rim * 12.0) + 0.16 * exp(-rim * 45.0) + 0.26 * exp(-rim * 180.0));
        float disc = 1.0 - smoothstep(NM_MOON_R - pt, NM_MOON_R + pt, dm);
        if (disc > 0.0) {
            float2 q = (p - m) / NM_MOON_R;
            float limb = sqrt(clamp(1.0 - dot(q, q), 0.0, 1.0));
            float maria = smoothstep(0.40, 0.70, nm_fbm(q * 1.9 + float2(5.2, 1.3)));
            float3 moon = float3(0.93, 0.95, 0.98) * (0.80 + 0.20 * limb) * (1.0 - 0.13 * maria);
            c = mix(c, moon, disc);
        }

        // The far shore: distant mesas veiled by haze, then a darker bank.
        float h = p.y - horizon;
        float mesaTop = nm_mesas(p.x);
        float far = 1.0 - smoothstep(mesaTop - pt, mesaTop + pt, h);
        float3 farColor = mix(float3(0.020, 0.026, 0.038), nm_skyGradient(p.y, horizon) * 0.80, 0.35);
        farColor += float3(0.020, 0.026, 0.036) * exp(-h / 0.010);
        c = mix(c, farColor, far);
        float bankTop = nm_bank(p.x);
        float bank = 1.0 - smoothstep(bankTop - pt, bankTop + pt, h);
        c = mix(c, float3(0.007, 0.009, 0.014) + float3(0.010, 0.013, 0.018) * exp(-h / 0.004), bank);
        return c;
    }

    // The full scene. `uv` is 0...1 with y pointing up, `sizePt` is the view
    // size in points, `px` the fragment position in pixels (for dithering).
    float3 nm_scene(float2 uv, float2 sizePt, float2 px, float time, float twinkle, float horizon) {
        float aspect = sizePt.x / sizePt.y;
        float pt = 1.0 / sizePt.y;
        float2 p = float2(uv.x * aspect, uv.y);
        float3 c;

        if (p.y >= horizon) {
            c = nm_sky(p, aspect, pt, horizon, time, twinkle);
        } else {
            // Water. Mirror the sky about the horizon, disturbed only by a slow,
            // shallow swell whose wavelength shrinks with distance.
            float depth = (horizon - p.y) / horizon;
            float z = 1.0 / (depth + 0.04);
            float wx = (p.x - 0.5 * aspect) * z;
            float swell = 0.6 * sin(z * 4.3 - time * 0.42 + wx * 0.21)
                        + 0.4 * sin(z * 9.1 + time * 0.57 - wx * 0.63);
            float fine = nm_noise(float2(wx * 2.1, z * 6.0 - time * 0.3)) - 0.5;
            float amp = 0.0011 * depth + 0.00025;
            float2 r = float2(p.x + fine * amp * 0.6, 2.0 * horizon - p.y + (swell + fine) * amp);
            float reflectance = mix(0.95, 0.55, pow(depth, 0.5));
            c = nm_sky(r, aspect, pt, horizon, time, twinkle) * reflectance;

            // Moonlight lying on the surface below the moon: a soft glade and a
            // few slow glints where the swell tilts toward the viewer.
            float2 m = float2(aspect * NM_MOON_X, NM_MOON_Y);
            float spread = 0.010 + 0.060 * depth;
            float lx = (p.x - m.x) / spread;
            float lane = exp(-lx * lx);
            float glints = pow(0.5 + 0.5 * sin(z * 41.0 + wx * 5.0 - time * 0.7), 10.0);
            glints *= smoothstep(0.62, 0.90, nm_noise(float2(wx * 9.0, z * 20.0)));
            c += float3(0.52, 0.62, 0.80) * lane * (0.018 + 0.10 * glints) * (1.0 - 0.6 * depth);

            c += float3(0.0015, 0.0022, 0.0035);
        }

        // Mist lying on the water at the horizon.
        float mistBand = exp(-abs(p.y - horizon) / 0.03);
        float mistNoise = nm_fbm(float2(p.x * 1.4 - time * 0.004, p.y * 9.0));
        c += float3(0.55, 0.63, 0.76) * 0.055 * mistBand * (0.30 + 0.70 * mistNoise);

        // The waterline itself catches a hairline of light.
        c += float3(0.40, 0.48, 0.60) * 0.030 * exp(-abs(p.y - horizon) / (pt * 1.2));

        // Vignette and dithering against banding in the dark gradients.
        float2 v = (uv - 0.5) * float2(1.0, 1.15);
        c *= 1.0 - 0.42 * smoothstep(0.25, 0.85, dot(v, v) * 2.0);
        c += (nm_hash12(px + fract(time * 7.13) * 91.0) - 0.5) / 255.0;
        return max(c, float3(0.0));
    }
    // END SCENE

    struct LakeUniforms {
        float4 sizeAndPixels; // view size in points (xy), drawable size in pixels (zw)
        float4 params;        // scene time, twinkle amplitude, horizon, unused
    };

    struct LakeVertexOut {
        float4 position [[position]];
        float2 uv;
    };

    // A single triangle covering the view; uv runs 0...1 with y pointing up.
    vertex LakeVertexOut nm_lake_vertex(uint vid [[vertex_id]]) {
        float2 corner = float2(float((vid << 1) & 2), float(vid & 2));
        LakeVertexOut out;
        out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
        out.uv = corner;
        return out;
    }

    fragment float4 nm_lake_fragment(LakeVertexOut in [[stage_in]],
                                     constant LakeUniforms& u [[buffer(0)]]) {
        float3 color = nm_scene(in.uv, u.sizeAndPixels.xy, in.position.xy,
                                u.params.x, u.params.y, u.params.z);
        return float4(color, 1.0);
    }
    """#
}
