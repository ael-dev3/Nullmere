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
    // suffixes, implicit int/float conversion, out parameters, arrays or global
    // constants other than #defines; smoothstep edges always ascending; pow only
    // with non-negative bases.

    #define NM_TAU 6.28318530718
    #define NM_PI 3.14159265359
    #define NM_MOON_X 0.5
    #define NM_MOON_Y 0.795
    #define NM_MOON_R 0.056

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

    // Smooth random flicker, roughly -1...1: a slow swell of brightness with a
    // quicker shimmer on top, different for every star.
    float nm_flicker(float time, float ph) {
        float slow = nm_noise(float2(time * (0.7 + 1.3 * ph), ph * 97.0));
        float quick = nm_noise(float2(time * (3.0 + 3.5 * ph), ph * 61.0 + 40.0));
        return (slow - 0.5) * 1.6 + (quick - 0.5) * 1.0;
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
        if (r > 20.0 * sigma) {
            return float3(0.0);
        }
        float k = nm_hash12(id * 1.31 + seed + 5.0);
        float b = mix(minB, maxB, k * k * k);
        float ph = nm_hash12(id + seed + 23.0);
        float tw = max(1.0 + twinkle * nm_flicker(time, ph), 0.05);
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
        float3 c = mix(low, zenith, pow(max(t, 0.0001), 0.36));
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

    // Now and then a star falls: a bright head drawing a fading trail away from
    // the moon. The first falls a few seconds after the lake appears, later ones
    // at random, about twice a minute. It is a pure function of time, so its
    // reflection follows it across the water.
    float3 nm_fallingStar(float2 p, float aspect, float pt, float time) {
        float period = 17.0;
        float k = floor(time / period);
        float2 hk = nm_hash22(float2(k, 7.0));
        bool first = k < 0.5;
        if (!first && hk.x > 0.6) {
            return float3(0.0);
        }
        float start = first ? 6.5 : 1.0 + hk.y * (period - 3.0);
        float u = (time - k * period - start) / 1.25;
        if (u < 0.0 || u > 1.0) {
            return float3(0.0);
        }
        float2 hs = nm_hash22(float2(k, 19.0));
        float side = hs.x > 0.5 ? 1.0 : -1.0;
        float2 origin = float2(aspect * (0.5 + side * (0.10 + 0.24 * hs.y)), 0.87 + 0.08 * fract(hs.x * 13.0));
        float2 dir = normalize(float2(side * (0.55 + 0.5 * fract(hs.y * 7.0)), -1.0));
        float ease = u * (1.6 - 0.6 * u);
        float2 head = origin + dir * 0.20 * ease;
        float fade = sin(NM_PI * u);
        float tail = 0.13 * (0.25 + 0.75 * sin(NM_PI * min(u * 1.3, 1.0)));
        float2 rel = p - head;
        float dist = length(rel);
        if (dist > tail + 16.0 * pt) {
            return float3(0.0);
        }
        float along = dot(rel, -dir);
        float across = dot(rel, float2(-dir.y, dir.x)) / pt;
        float trail = 0.0;
        if (along > 0.0 && along < tail) {
            float rest = 1.0 - along / tail;
            trail = exp(-across * across / (0.5 + 1.2 * (1.0 - rest))) * rest * rest;
        }
        float r = dist / pt;
        float headGlow = exp(-r * r / 3.0) + 0.20 * exp(-r / 4.0);
        return float3(0.86, 0.91, 1.0) * fade * (0.85 * trail + 1.2 * headGlow);
    }

    // Everything above the waterline: gradient, Milky Way, stars, moon, shore.
    // `activity` is 1 at full motion and smaller when motion is reduced.
    float3 nm_sky(float2 p, float aspect, float pt, float horizon, float time, float activity) {
        float3 c = nm_skyGradient(p.y, horizon);
        float2 m = float2(aspect * NM_MOON_X, NM_MOON_Y);
        float dm = length(p - m);
        // The moon's light swells and settles very slowly.
        float breath = 0.5 + 0.5 * sin(NM_TAU * fract(time / 9.0));

        float altitude = smoothstep(horizon + 0.004, horizon + 0.20, p.y);
        float glare = smoothstep(NM_MOON_R * 1.3, NM_MOON_R * 6.5, dm);
        float visible = altitude * glare;

        // A faint galactic band rising across the left of the sky.
        float2 bandDir = normalize(float2(0.62, 1.0));
        float2 bandOrigin = float2(aspect * 0.12, horizon);
        float across = dot(p - bandOrigin, float2(-bandDir.y, bandDir.x));
        float band = exp(-across * across / 0.018);
        if (band > 0.004) {
            float dust = nm_fbm(p * 3.1 + float2(3.0, 1.0));
            float lanes = smoothstep(0.42, 0.62, nm_fbm(p * 7.3 + float2(9.0, 4.0)));
            c += float3(0.70, 0.76, 0.88) * 0.034 * band * (0.45 + 0.9 * dust) * (1.0 - 0.6 * lanes) * visible;
        }

        // Stars low in the sky flicker more, as through a deeper air.
        float twinkle = 0.72 * activity * (1.4 - 0.6 * altitude);
        float3 s = nm_starLayer(p, 74.0, 0.42 + 0.40 * band, 0.02, 0.20, 0.42, pt, time, twinkle * 0.7, 3.0);
        s += nm_starLayer(p, 31.0, 0.40, 0.10, 0.62, 0.52, pt, time, twinkle, 17.0);
        s += nm_starLayer(p, 11.0, 0.36, 0.50, 1.80, 0.66, pt, time, twinkle, 31.0);
        c += s * visible;
        if (activity > 0.5) {
            c += nm_fallingStar(p, aspect, pt, time) * altitude;
        }

        // Thin haze drifting past the moon catches its light.
        if (dm < 0.45) {
            float veil = smoothstep(0.50, 0.82, nm_fbm(float2(p.x * 2.3 - time * 0.012, p.y * 7.5 + 2.0)));
            c += float3(0.55, 0.64, 0.80) * 0.11 * veil * exp(-dm * 9.0) * (0.85 + 0.3 * breath);
        }

        // Moon: a cold full disc with soft limb darkening, maria and a wide halo.
        float rim = max(dm - NM_MOON_R, 0.0);
        float3 glowTint = float3(0.58, 0.68, 0.86);
        float glow = 0.050 * exp(-rim * 2.2) + 0.080 * exp(-rim * 7.5) + 0.15 * exp(-rim * 24.0) + 0.26 * exp(-rim * 90.0);
        c += glowTint * glow * (0.86 + 0.28 * breath);
        float disc = 1.0 - smoothstep(NM_MOON_R - pt, NM_MOON_R + pt, dm);
        if (disc > 0.0) {
            float2 q = (p - m) / NM_MOON_R;
            float limb = sqrt(clamp(1.0 - dot(q, q), 0.0, 1.0));
            float maria = smoothstep(0.40, 0.70, nm_fbm(q * 1.6 + float2(5.2, 1.3)));
            float grain = nm_fbm(q * 6.0 + float2(1.7, 8.1));
            float2 tq = q - float2(-0.18, -0.62);
            float crater = exp(-dot(tq, tq) * 160.0);
            float3 moon = float3(0.93, 0.95, 0.98) * (0.80 + 0.20 * limb) * (1.0 - 0.15 * maria) * (0.93 + 0.12 * grain);
            moon += float3(0.06) * crater;
            moon *= 0.97 + 0.04 * breath;
            c = mix(c, moon, disc);
        }

        // The far shore: distant mesas veiled by haze, then a darker bank.
        float h = p.y - horizon;
        if (h < 0.06) {
            float mesaTop = nm_mesas(p.x);
            float far = 1.0 - smoothstep(mesaTop - pt, mesaTop + pt, h);
            float3 farColor = mix(float3(0.020, 0.026, 0.038), nm_skyGradient(p.y, horizon) * 0.80, 0.35);
            farColor += float3(0.020, 0.026, 0.036) * exp(-h / 0.010);
            c = mix(c, farColor, far);
            float bankTop = nm_bank(p.x);
            float bank = 1.0 - smoothstep(bankTop - pt, bankTop + pt, h);
            c = mix(c, float3(0.007, 0.009, 0.014) + float3(0.010, 0.013, 0.018) * exp(-h / 0.004), bank);
        }
        return c;
    }

    // One train of waves on the lake, as the slope (dh/dX, dh/dZ) it adds at the
    // plane point w = (X, Z). The camera sits one unit above the water, so a
    // point s below the horizon lies Z = 1/s away. Waves whose image would be
    // smaller than a few points fade out instead of shimmering.
    float2 nm_wave(float2 w, float2 dir, float lambda, float slope, float time, float z, float pt) {
        float onScreen = lambda / (z * sqrt(dir.x * dir.x + dir.y * dir.y * z * z));
        float lod = smoothstep(3.0 * pt, 10.0 * pt, onScreen);
        if (lod <= 0.0) {
            return float2(0.0);
        }
        // Wrap the phase so it stays small however long the launcher runs.
        float speed = 0.24 * sqrt(lambda);
        float phase = fract((dot(dir, w) + speed * time) / lambda);
        return dir * (slope * lod * cos(NM_TAU * phase));
    }

    // Rings spreading where something touched the water. Three independent
    // channels each start a ring now and then, mostly near the moon's path.
    float2 nm_rings(float2 w, float time, float z, float pt) {
        float2 g = float2(0.0);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float period = 6.0 + 2.3 * fi;
            float t = time + 2.7 * fi + 1.5;
            float k = floor(t / period);
            float age = t - k * period;
            float2 h = nm_hash22(float2(k * 1.7 + fi * 31.0, 3.0 + fi));
            if (h.x > 0.85) {
                continue;
            }
            float cz = 2.35 + 2.2 * h.y;
            float2 centre = float2((fract(h.x * 9.7) - 0.5) * 0.55 * cz, cz);
            float2 d = w - centre;
            float dist = length(d);
            float front = dist - 0.11 * age;
            float width = 0.07 + 0.035 * age;
            if (abs(front) > 3.0 * width) {
                continue;
            }
            float lambda = 0.15 + 0.015 * age;
            float lod = smoothstep(3.0 * pt, 9.0 * pt, lambda / (z * z));
            float env = exp(-front * front / (width * width)) * exp(-0.38 * age) * smoothstep(0.0, 0.5, age);
            g += d / max(dist, 0.0001) * (0.13 * lod * env * cos(NM_TAU * front / lambda));
        }
        return g;
    }

    // Glints: points of moonlight flashing on facets that tilt toward the moon,
    // gathered around its image and thinning toward the far shore. They live on
    // a grid of small cells in points, so they stay crisp at any size.
    float3 nm_glints(float2 p, float2 m, float horizon, float depth, float pt, float time) {
        float mirrorY = 2.0 * horizon - m.y;
        float gx = (p.x - m.x) / (NM_MOON_R * (1.1 + 2.4 * depth));
        float gy = (p.y - mirrorY) / (NM_MOON_R * 2.2);
        float path = exp(-gx * gx) * (exp(-gy * gy) + 0.40 * smoothstep(0.05, 0.70, depth) * exp(-abs(gy) * 0.30));
        if (path < 0.02) {
            return float3(0.0);
        }
        float2 cellSize = float2(11.0, 3.0) * pt;
        float2 g = p / cellSize;
        float2 id = floor(g);
        float2 h = nm_hash22(id + 71.0);
        if (h.x > path * 0.45) {
            return float3(0.0);
        }
        float2 pos = 0.3 + 0.4 * nm_hash22(id + 13.0);
        float2 d = (g - id - pos) * cellSize / pt;
        d.x *= 0.26 + 0.2 * h.y;
        float shape = exp(-dot(d, d) / 0.5) * (0.55 + 0.45 * fract(h.y * 5.1));
        float wave = max(sin(NM_TAU * fract(time * (1.6 + 2.8 * h.y) / NM_TAU + h.x * 7.3)), 0.0);
        float flash = wave * wave * wave;
        flash *= flash;
        return float3(0.84, 0.89, 1.0) * shape * flash * (0.35 + 0.65 * fract(h.x * 13.7));
    }

    // The full scene. `uv` is 0...1 with y pointing up, `sizePt` is the view
    // size in points, `px` the fragment position in pixels (for dithering).
    float3 nm_scene(float2 uv, float2 sizePt, float2 px, float time, float activity, float horizon) {
        float aspect = sizePt.x / sizePt.y;
        float pt = 1.0 / sizePt.y;
        float2 p = float2(uv.x * aspect, uv.y);
        float2 m = float2(aspect * NM_MOON_X, NM_MOON_Y);
        float3 c;

        if (p.y >= horizon) {
            c = nm_sky(p, aspect, pt, horizon, time, activity);
        } else {
            // Water: the sky mirrored in a surface that is never quite still. A
            // long swell and wind ripples run toward the shore below, and rings
            // spread where something touched the lake. Their slopes bend the
            // reflection, so the moon's image breaks and gathers again.
            float s = horizon - p.y;
            float z = 1.0 / max(s, 0.0005);
            float2 w = float2((p.x - m.x) * z, z);
            float2 slope = nm_wave(w, normalize(float2(0.20, 1.0)), 1.70, 0.020, time, z, pt);
            slope += nm_wave(w, normalize(float2(-0.45, 1.0)), 0.93, 0.018, time, z, pt);
            slope += nm_wave(w, normalize(float2(0.75, 1.0)), 0.51, 0.016, time, z, pt);
            slope += nm_wave(w, normalize(float2(-0.12, 1.0)), 0.27, 0.014, time, z, pt);
            slope += nm_wave(w, normalize(float2(0.40, 1.0)), 0.15, 0.012, time, z, pt);
            slope += nm_wave(w, normalize(float2(-0.60, 1.0)), 0.085, 0.010, time, z, pt);
            slope += nm_wave(w, normalize(float2(0.90, 1.0)), 0.055, 0.008, time, z, pt);
            float2 ring = float2(0.0);
            if (activity > 0.5) {
                ring = nm_rings(w, time, z, pt);
                slope += ring;
            }

            float2 r = float2(p.x + 0.35 * slope.x, 2.0 * horizon - p.y + 0.55 * slope.y);
            r.y = max(r.y, horizon + 0.0005);
            float depth = s / horizon;
            float reflectance = mix(0.94, 0.50, sqrt(depth));
            c = nm_sky(r, aspect, pt, horizon, time, activity) * reflectance;

            // Faces of the waves turned toward the moon catch a faint sheen.
            float lateral = (p.x - m.x) / (0.30 * aspect);
            float sheen = smoothstep(0.0, 0.06, slope.y) * exp(-lateral * lateral);
            c += float3(0.50, 0.60, 0.78) * 0.05 * sheen * (0.4 + 0.6 * depth);
            float ringLight = max(ring.y, 0.0) * (0.35 + 0.65 * exp(-lateral * lateral));
            c += float3(0.55, 0.64, 0.80) * 0.45 * ringLight;

            float lit = dot(c, float3(0.33, 0.34, 0.33));
            c += nm_glints(p, m, horizon, depth, pt, time) * (0.35 + 0.65 * reflectance) * (1.0 - smoothstep(0.15, 0.40, lit));

            c += float3(0.0015, 0.0022, 0.0035);
        }

        // Mist lying on the water at the horizon.
        float mistBand = exp(-abs(p.y - horizon) / 0.03);
        if (mistBand > 0.01) {
            float mistNoise = nm_fbm(float2(p.x * 1.4 - time * 0.004, p.y * 9.0));
            c += float3(0.55, 0.63, 0.76) * 0.055 * mistBand * (0.30 + 0.70 * mistNoise);
        }

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
        float4 params;        // scene time, activity, horizon, unused
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
