/// Metal source for the world map.
///
/// One fragment shader draws the whole map from a small texture of tile
/// data: terrain, soft edges between terrains, moonlit relief, territory
/// borders, fog, and the Nullmere itself, a black, perfectly still mirror
/// holding the stars and the moon. Units, holds and labels are drawn over it
/// by SwiftUI. Like the launcher's lake, the code between the SCENE markers
/// is written in the subset shared by Metal and GLSL, so a browser can render
/// it for review.
enum WorldShader {
    static let vertexFunction = "nm_world_vertex"
    static let fragmentFunction = "nm_world_fragment"

    /// Packs the tile data the shader reads; see `TileTexture`.
    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct WorldUniforms {
        float4 view;       // viewport width and height in pixels, pixels per world unit, time
        float4 camera;     // world x and y at the viewport centre, world radius, pixels per point
        float4 highlight;  // hovered q and r, selected q and r (999 for none)
    };

    #define NM_TEXTURE_ARGUMENT , texture2d<float, access::read> data
    #define NM_TEXTURE_PASS , data
    #define NM_TILE(cell) data.read(uint2(cell))
    #define NM_ATAN2(y, x) atan2(y, x)

    // BEGIN SCENE
    // Written in the subset shared by Metal Shading Language and GLSL ES 3.00:
    // only float/float2/float3/float4, swizzles and common built-ins; no literal
    // suffixes, implicit int/float conversion, out parameters, arrays or global
    // constants other than #defines. Tile reads and two-argument arctangents go
    // through NM_TILE and NM_ATAN2, defined per language.

    #define NM_ROOT3 1.73205080757

    float nm_hash(float2 p) {
        float3 p3 = fract(float3(p.x, p.y, p.x) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    float nm_noise(float2 p) {
        float2 i = floor(p);
        float2 f = p - i;
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = nm_hash(i);
        float b = nm_hash(i + float2(1.0, 0.0));
        float c = nm_hash(i + float2(0.0, 1.0));
        float d = nm_hash(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    float nm_fbm(float2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
            v += a * nm_noise(p);
            p = p * 2.07 + float2(13.1, 7.7);
            a *= 0.5;
        }
        return v;
    }

    // The hex containing a world point, as axial (q, r), for unit-sized hexes.
    float2 nm_hexAt(float2 w) {
        float q = (NM_ROOT3 / 3.0 * w.x - w.y / 3.0);
        float r = (2.0 / 3.0) * w.y;
        float s = -q - r;
        float rq = floor(q + 0.5);
        float rr = floor(r + 0.5);
        float rs = floor(s + 0.5);
        float dq = abs(rq - q);
        float dr = abs(rr - r);
        float ds = abs(rs - s);
        if (dq > dr && dq > ds) {
            rq = -rr - rs;
        } else if (dr > ds) {
            rr = -rq - rs;
        }
        return float2(rq, rr);
    }

    float2 nm_hexCentre(float2 h) {
        return float2(NM_ROOT3 * (h.x + h.y / 2.0), 1.5 * h.y);
    }

    float nm_hexLength(float2 h) {
        return max(max(abs(h.x), abs(h.y)), abs(-h.x - h.y));
    }

    // Distance from a point inside a hex to its edge (0 at the edge, 0.866 at
    // the centre), and which of the six neighbours lies across the nearest edge.
    float2 nm_edge(float2 d) {
        // Pointy-top hexes: two upright edges and four slanted ones.
        float a = d.x;
        float b = dot(d, float2(0.5, 0.8660254));
        float c = dot(d, float2(-0.5, 0.8660254));
        float m = max(max(abs(a), abs(b)), abs(c));
        float side = 0.0;
        if (abs(a) >= abs(b) && abs(a) >= abs(c)) {
            side = a > 0.0 ? 0.0 : 3.0;
        } else if (abs(b) >= abs(c)) {
            side = b > 0.0 ? 5.0 : 2.0;
        } else {
            side = c > 0.0 ? 4.0 : 1.0;
        }
        return float2(0.8660254 - m, side);
    }

    float2 nm_direction(float side) {
        if (side < 0.5) { return float2(1.0, 0.0); }
        if (side < 1.5) { return float2(1.0, -1.0); }
        if (side < 2.5) { return float2(0.0, -1.0); }
        if (side < 3.5) { return float2(-1.0, 0.0); }
        if (side < 4.5) { return float2(-1.0, 1.0); }
        return float2(0.0, 1.0);
    }

    float3 nm_houseColour(float index) {
        if (index < 0.5) { return float3(0.86, 0.74, 0.47); }
        if (index < 1.5) { return float3(0.70, 0.27, 0.25); }
        if (index < 2.5) { return float3(0.30, 0.60, 0.60); }
        if (index < 3.5) { return float3(0.58, 0.44, 0.74); }
        if (index < 4.5) { return float3(0.78, 0.80, 0.84); }
        if (index < 5.5) { return float3(0.86, 0.50, 0.26); }
        if (index < 6.5) { return float3(0.46, 0.68, 0.38); }
        return float3(0.80, 0.56, 0.68);
    }

    // Terrain: 0 still, 1 shallows, 2 strand, 3 salt flat, 4 greyfield,
    // 5 blackwood, 6 barrows, 7 the Spine. Colours are as moonlight shows them:
    // cool, pale where the ground is open, near black under the trees.
    // The noise is shared by every terrain at a point, so it is made once
    // there and passed in: broad patches, grain, fine speckle, and canopy.
    float3 nm_terrainColour(float t, float broad, float grain, float fine, float canopyNoise) {
        if (t < 0.5) { return float3(0.004, 0.006, 0.012); }
        if (t < 1.5) { return mix(float3(0.016, 0.022, 0.030), float3(0.028, 0.036, 0.044), grain); }
        if (t < 2.5) { return mix(float3(0.30, 0.30, 0.29), float3(0.42, 0.41, 0.39), grain) * (0.88 + 0.24 * fine); }
        if (t < 3.5) { return mix(float3(0.62, 0.66, 0.72), float3(0.80, 0.83, 0.88), fine) * (0.90 + 0.15 * grain); }
        if (t < 4.5) {
            float3 dry = float3(0.25, 0.26, 0.24);
            float3 lush = float3(0.17, 0.20, 0.18);
            return mix(lush, dry, broad) * (0.86 + 0.22 * grain) * (0.94 + 0.12 * fine);
        }
        if (t < 5.5) {
            float canopy = smoothstep(0.30, 0.78, canopyNoise);
            return mix(float3(0.018, 0.028, 0.030), float3(0.060, 0.082, 0.076), canopy) * (0.8 + 0.4 * fine);
        }
        if (t < 6.5) { return mix(float3(0.17, 0.155, 0.14), float3(0.27, 0.25, 0.22), grain) * (0.88 + 0.22 * fine); }
        return mix(float3(0.075, 0.078, 0.092), float3(0.20, 0.205, 0.225), smoothstep(0.35, 0.85, grain)) * (0.82 + 0.36 * fine);
    }

    // The unknown: a slow night mist, paler than the black water.
    float3 nm_mist(float2 w, float time) {
        float2 drift = float2(time * 0.012, time * 0.004);
        float mist = nm_fbm(w * 0.45 + drift) * 0.65 + nm_fbm(w * 1.4 - drift * 1.7) * 0.35;
        return float3(0.020, 0.023, 0.032) + float3(0.030, 0.034, 0.046) * mist * mist * 1.6;
    }

    // Height for moonlit relief.
    float nm_height(float t, float2 w) {
        if (t < 1.5) { return 0.0; }
        if (t > 6.5) { return 1.4 * nm_fbm(w * 1.1) + 0.35 * nm_noise(w * 3.6); }
        if (t > 5.5) { return 0.42 * nm_fbm(w * 1.7) + 0.06 * nm_noise(w * 8.0); }
        if (t > 4.5) { return 0.22 * nm_fbm(w * 4.8) + 0.05 * nm_noise(w * 12.0); }
        return 0.07 * nm_fbm(w * 2.0);
    }

    // The still water: black glass holding the stars and the moon.
    float nm_star(float2 px, float ppp, float size, float threshold, float salt) {
        float2 cell = floor(px / (size * ppp));
        float2 jitter = float2(nm_hash(cell + 3.1 + salt), nm_hash(cell + 7.9 + salt));
        float2 star = (cell + 0.2 + 0.6 * jitter) * size * ppp;
        float2 o = (px - star) / ppp;
        float bright = nm_hash(cell + 1.3 + salt);
        if (bright < threshold) { return 0.0; }
        float b = (bright - threshold) / (1.0 - threshold);
        float r2 = dot(o, o);
        return b * b * (exp(-r2 / 0.8) + 0.12 * exp(-r2 / 7.0));
    }

    float3 nm_mirror(float2 w, float2 px, float2 viewport, float ppp, float shallow, float time) {
        // Black glass, faintly holding the sky: a little paler toward the top
        // of the view, where the moon hangs, and along the moon's path.
        float2 uv = px / viewport;
        float gx = (uv.x - 0.5) * viewport.x / max(viewport.y, 1.0);
        float glade = exp(-gx * gx / 0.045) * (0.35 + 0.65 * (1.0 - uv.y));
        float3 c = float3(0.004, 0.007, 0.016) + float3(0.010, 0.014, 0.026) * (1.0 - uv.y);
        c += float3(0.050, 0.060, 0.085) * glade * (0.85 + 0.15 * nm_fbm(w * 0.35 + float2(time * 0.004, 0.0)));
        c = mix(c, float3(0.020, 0.027, 0.036), shallow * 0.8);
        // Reflected stars, fixed to the screen like the sky, sized in points.
        float stars = nm_star(px, ppp, 10.0, 0.52, 0.0) * 0.7 + nm_star(px, ppp, 37.0, 0.5, 17.0) * 1.6;
        float twinkle = 0.85 + 0.15 * sin(time * 0.9 + nm_hash(floor(px / (41.0 * ppp))) * 30.0);
        c += float3(0.66, 0.72, 0.86) * stars * twinkle * (1.0 - 0.75 * shallow);
        // The moon lies in the water at the lake's heart, crisp because
        // nothing moves, and a little dimmer than the moon itself.
        float2 moon = float2(0.0, -2.2);
        float2 mq = (w - moon) / 1.05;
        float dm = length(w - moon);
        float disc = (1.0 - smoothstep(0.96, 1.0, length(mq))) * (1.0 - shallow);
        float breath = 0.5 + 0.5 * sin(6.2831853 * fract(time / 11.0));
        float3 glow = float3(0.50, 0.58, 0.76) * (0.09 * exp(-dm * 0.42) + 0.08 * exp(-dm * 1.8)) * (0.9 + 0.2 * breath);
        c += glow * (1.0 - shallow * 0.6);
        if (disc > 0.0) {
            float maria = smoothstep(0.42, 0.68, nm_fbm(mq * 1.7 + float2(5.2, 1.3)));
            float limb = sqrt(clamp(1.0 - dot(mq, mq), 0.0, 1.0));
            float3 face = float3(0.66, 0.70, 0.76) * (0.78 + 0.22 * limb) * (1.0 - 0.18 * maria);
            c = mix(c, face, disc);
        }
        return c;
    }

    float3 nm_world(float2 px, float2 viewport, float scale, float time, float2 centre, float radius, float ppp, float4 highlight NM_TEXTURE_ARGUMENT) {
        float2 w = (px - viewport * 0.5) / scale + centre;
        float2 h = nm_hexAt(w);
        if (nm_hexLength(h) > radius) {
            // Beyond the Spine: the dark, with a few cold stars.
            return float3(0.003, 0.004, 0.008) + float3(0.5, 0.55, 0.7) * nm_star(px, ppp, 23.0, 0.8, 5.0) * 0.5;
        }

        float4 tile = NM_TILE(h + radius);
        float terrain = floor(tile.r * 255.0 + 0.5);
        float feature = floor(tile.g * 255.0 + 0.5);
        float packed = floor(tile.a * 255.0 + 0.5);
        float visibility = floor(packed / 16.0);
        float owner = packed - visibility * 16.0;

        float2 d = w - nm_hexCentre(h);
        float2 edge = nm_edge(d);
        float2 across = h + nm_direction(edge.y);
        float4 neighbour = NM_TILE(across + radius);
        if (nm_hexLength(across) > radius) {
            neighbour = tile;
        }
        float otherPacked = floor(neighbour.a * 255.0 + 0.5);
        float otherVisibility = floor(otherPacked / 16.0);
        float otherOwner = otherPacked - otherVisibility * 16.0;

        // The ground's look blends this hex with its six neighbours, weighted
        // by distance through a gentle warp, so terrains shade into each other
        // and shores curve like real country. Hex centres always show their own
        // terrain; borders, fog and selection keep to the true grid.
        float2 warp = float2(nm_fbm(w * 0.55 + float2(1.7, 9.2)), nm_fbm(w * 0.55 + float2(8.3, 2.8))) - 0.5;
        float2 ws = w + warp * 0.95 + (float2(nm_noise(w * 2.6), nm_noise(w * 2.6 + 5.0)) - 0.5) * 0.25;
        float total = 0.0;
        float land = 0.0;
        float deep = 0.0;
        float wStrand = 0.0;
        float wSalt = 0.0;
        float wGrey = 0.0;
        float wWood = 0.0;
        float wBarrow = 0.0;
        float wSpine = 0.0;
        float known = 0.0;
        float watched = 0.0;
        for (int i = 0; i < 7; i++) {
            float2 cell = h;
            if (i > 0) {
                cell = h + nm_direction(float(i - 1));
            }
            if (nm_hexLength(cell) > radius) {
                continue;
            }
            float4 cellData = NM_TILE(cell + radius);
            float t = floor(cellData.r * 255.0 + 0.5);
            float seen = floor(floor(cellData.a * 255.0 + 0.5) / 16.0);
            float2 off = ws - nm_hexCentre(cell);
            float weight = exp(-dot(off, off) * 2.6);
            total += weight;
            if (seen > 0.5) { known += weight; }
            if (seen > 1.5) { watched += weight; }
            if (t > 1.5) { land += weight; }
            if (t < 0.5) { deep += weight; }
            if (t > 1.5 && t < 2.5) { wStrand += weight; }
            if (t > 2.5 && t < 3.5) { wSalt += weight; }
            if (t > 3.5 && t < 4.5) { wGrey += weight; }
            if (t > 4.5 && t < 5.5) { wWood += weight; }
            if (t > 5.5 && t < 6.5) { wBarrow += weight; }
            if (t > 6.5) { wSpine += weight; }
        }
        // Fog first: where nothing is known, the mist is all there is, and
        // none of the country beneath it needs drawing.
        float fogNoise = (nm_fbm(w * 1.3 + float2(3.0, 1.0)) - 0.5) * 0.3;
        float isKnown = smoothstep(0.38, 0.62, known / max(total, 0.0001) + fogNoise);
        float isWatched = smoothstep(0.38, 0.62, watched / max(total, 0.0001) + fogNoise);
        float3 unknown = nm_mist(w, time);
        if (isKnown < 0.001) {
            return unknown + (nm_hash(px + fract(time * 3.7) * 61.0) - 0.5) / 255.0;
        }

        float landness = land / max(total, 0.0001) + (nm_fbm(w * 3.1 + float2(2.0, 7.0)) - 0.5) * 0.18;
        float shore = smoothstep(0.42, 0.58, landness);

        float3 c;
        float water = 1.0 - shore;
        // Water: black glass, a little lighter over the dead shallows. Only
        // where there is water to see.
        float3 wet = float3(0.0);
        if (shore < 0.999) {
            float shallow = 1.0 - deep / max(total - land, 0.0001);
            wet = nm_mirror(w, px, viewport, ppp, clamp(shallow, 0.0, 1.0), time);
            // A pale line of salt where the dead water meets the land.
            wet += float3(0.32, 0.33, 0.36) * exp(-abs(landness - 0.43) / 0.025) * 0.5;
            wet += float3(0.40, 0.46, 0.60) * exp(-abs(landness - 0.47) / 0.012) * 0.3;
        }

        // Land, only where there is land to see.
        float3 ground = float3(0.0);
        if (shore > 0.001) {
            float landTotal = max(land, 0.0001);
            float broad = nm_fbm(w * 0.9 + float2(7.0, 3.0));
            float grain = nm_fbm(w * 2.3);
            float fine = nm_noise(w * 11.0);
            float canopyNoise = wWood > 0.01 ? nm_fbm(w * 4.2 + float2(4.0, 1.0)) : 0.0;
            if (wStrand > 0.01) { ground += nm_terrainColour(2.0, broad, grain, fine, canopyNoise) * wStrand; }
            if (wSalt > 0.01) { ground += nm_terrainColour(3.0, broad, grain, fine, canopyNoise) * wSalt; }
            if (wGrey > 0.01) { ground += nm_terrainColour(4.0, broad, grain, fine, canopyNoise) * wGrey; }
            if (wWood > 0.01) { ground += nm_terrainColour(5.0, broad, grain, fine, canopyNoise) * wWood; }
            if (wBarrow > 0.01) { ground += nm_terrainColour(6.0, broad, grain, fine, canopyNoise) * wBarrow; }
            if (wSpine > 0.01) { ground += nm_terrainColour(7.0, broad, grain, fine, canopyNoise) * wSpine; }
            ground /= landTotal;
            // Moonlight from the upper left over the relief.
            float e = 0.06;
            float h0 = nm_height(terrain, w);
            float hx = nm_height(terrain, w + float2(e, 0.0)) - h0;
            float hy = nm_height(terrain, w + float2(0.0, e)) - h0;
            float3 n = normalize(float3(-hx / e, -hy / e, 1.0));
            float3 light = normalize(float3(-0.6, -0.7, 0.62));
            float lit = clamp(dot(n, light), 0.0, 1.0);
            ground *= 0.35 + 1.05 * lit;
            ground *= float3(0.90, 0.96, 1.08);
            ground += float3(0.10, 0.12, 0.16) * pow(lit, 6.0) * (wSalt / landTotal);
        }
        c = mix(wet, ground, shore);

        if (shore > 0.5) {
            // Features, on the true tile.
            if (feature > 0.5) {
                float2 fp = d * 3.2;
                if (feature < 1.5) {
                    // Moonsalt bed: a glittering crust.
                    float glint = nm_star(px, ppp, 6.0, 0.82, 31.0);
                    float phase = nm_hash(floor(px / (6.0 * ppp)) + 2.0) * 40.0;
                    c += float3(0.78, 0.84, 1.0) * glint * 1.4 * (0.4 + 0.6 * sin(time * 1.1 + phase)) * (1.0 - smoothstep(0.55, 0.85, length(d)));
                } else if (feature < 2.5) {
                    // Elder grove: a black heart of ancient trees.
                    c *= 0.45 + 0.55 * smoothstep(0.15, 0.8, length(fp) / 2.2);
                } else if (feature < 3.5) {
                    // Stone seam: pale outcrops.
                    float rock = smoothstep(0.62, 0.72, nm_fbm(w * 5.0 + float2(2.0, 6.0)));
                    c += float3(0.16, 0.155, 0.15) * rock * (1.0 - smoothstep(0.5, 0.8, length(d)));
                } else if (feature < 4.5) {
                    // Dark loam: furrows of black earth.
                    c *= 0.78 + 0.1 * sin((d.x + d.y * 0.4) * 30.0);
                } else {
                    // Drowned ruin: a broken ring of old stone.
                    float ring = abs(length(d) - 0.42);
                    float broken = step(0.35, nm_noise(float2(NM_ATAN2(d.y, d.x) * 2.5, 1.0)));
                    c += float3(0.32, 0.31, 0.28) * (1.0 - smoothstep(0.02, 0.06, ring)) * broken;
                }
            }
        }

        // The moon's light pools around the lake.
        c *= 0.8 + 0.35 * exp(-length(w - float2(0.0, -2.2)) / 18.0);

        // Territory: a tint and a line on the inside of the border.
        if (owner > 0.5 && visibility > 0.5) {
            float3 house = nm_houseColour(owner - 1.0);
            c = mix(c, c * 0.6 + house * 0.18, 0.35);
            if (otherOwner != owner) {
                c = mix(c, house * 0.9, (1.0 - smoothstep(0.015, 0.05, edge.x)) * 0.85);
            }
        }

        // The faintest grid, on land only: the still water is seamless.
        if (water < 0.5) {
            c *= 0.88 + 0.12 * smoothstep(0.0, 0.03, edge.x);
        }

        // Hover and selection.
        float2 hovered = highlight.xy;
        float2 selected = highlight.zw;
        if (abs(h.x - hovered.x) + abs(h.y - hovered.y) < 0.5) {
            c += float3(0.40, 0.44, 0.52) * (1.0 - smoothstep(0.0, 0.05, edge.x)) * 0.8 + float3(0.03, 0.035, 0.045);
        }
        if (abs(h.x - selected.x) + abs(h.y - selected.y) < 0.5) {
            float pulse = 0.75 + 0.25 * sin(time * 2.4);
            c += float3(0.75, 0.80, 0.92) * (1.0 - smoothstep(0.0, 0.06, edge.x)) * pulse + float3(0.04, 0.045, 0.06);
        }

        // Fog, with soft, wandering edges. What was seen but is no longer
        // watched is remembered dim and grey; the unknown is a slow night mist,
        // paler than the black water, so the lake shows as the darkest thing.
        float grey = dot(c, float3(0.30, 0.45, 0.25));
        // Remembered water keeps its stars; remembered land fades to grey.
        float3 remembered = mix(mix(float3(grey), c, 0.4) * 0.5 + float3(0.004, 0.005, 0.008), c * 0.85, water);
        c = mix(remembered, c, isWatched);
        c = mix(unknown, c, isKnown);

        c += (nm_hash(px + fract(time * 3.7) * 61.0) - 0.5) / 255.0;
        return max(c, float3(0.0));
    }
    // END SCENE

    struct WorldVertexOut {
        float4 position [[position]];
    };

    vertex WorldVertexOut nm_world_vertex(uint vid [[vertex_id]]) {
        float2 corner = float2(float((vid << 1) & 2), float(vid & 2));
        WorldVertexOut out;
        out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
        return out;
    }

    fragment float4 nm_world_fragment(WorldVertexOut in [[stage_in]],
                                      constant WorldUniforms& u [[buffer(0)]],
                                      texture2d<float, access::read> data [[texture(0)]]) {
        float3 c = nm_world(in.position.xy, u.view.xy, u.view.z, u.view.w, u.camera.xy, u.camera.z, u.camera.w, u.highlight NM_TEXTURE_PASS);
        return float4(c, 1.0);
    }
    """#
}
