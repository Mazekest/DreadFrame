#version 120
// ============================================================
//  DREADFRAME :: composite
//  deferred lighting -> depth outlines -> DRY BRUSH ink -> red/black grading
// ============================================================

// ---------------- in-game options ----------------
#define DEBUG_VIEW 0 // [0 1 2 3 4 5 6]

#define DREAD          0.70 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define HARD_CUT       0.00 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define RED_HUE        0.80 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define POSTERIZE      0.00 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// ---- dry brush / screen-print ink ----
#define DRYBRUSH       0.65 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.65 0.70 0.80 0.90 1.00]
#define BRUSH_SCALE    1.0  // [0.25 0.50 0.75 1.0 1.5 2.0 3.0 4.0]
#define BRUSH_STREAK   0.60 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define BRUSH_OCTAVES  3    // [1 2 3 4]
#define INK_BLEED      0.50 // [0.20 0.30 0.40 0.50 0.60 0.70 0.80]
#define SPECKLE        0.45 // [0.00 0.10 0.20 0.30 0.40 0.45 0.50 0.60 0.70 0.80 1.00]
#define BRISTLE_SKIP   0.55 // [0.00 0.10 0.20 0.30 0.40 0.50 0.55 0.60 0.70 0.80 1.00]
#define WORLD_LOCK     0.70 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define EDGE_ROUGH     0.70 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

#define OUTLINE        0.60 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define OUTLINE_WIDTH  1.0  // [1.0 2.0 3.0]

#define VISIBILITY     0.60 // [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define DARK_RANGE     64.0 // [24.0 32.0 40.0 48.0 64.0 96.0 128.0 192.0 256.0]
#define NIGHT_BOOST    0.40 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define TORCH_WARMTH   0.70 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define SKY_DEATH      0.70 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define AMBIENT_FLOOR  0.10 // [0.00 0.05 0.10 0.15 0.20 0.30 0.40 0.60 0.80 1.00]

#define PULSE          0.50 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// buffer layout (default RGBA8 formats - no const directives, nothing to typo)
//   colortex0 : .rgb scene albedo
//   colortex1 : .r blocklight  .g skylight  .b material flag

// ---------------- uniforms ----------------
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float near;
uniform float far;
uniform float rainStrength;
uniform float blindness;
uniform float nightVision;
uniform int   worldTime;
uniform int   isEyeInWater;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;

// ---------------- helpers ----------------
float linearDepth(float d) {
    return (2.0 * near * far) / (far + near - (d * 2.0 - 1.0) * (far - near));
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float heartbeat(float t) {
    float p = fract(t * 0.72);
    float a = exp(-13.0 * p);
    float b = 0.55 * step(0.20, p) * exp(-15.0 * (p - 0.20));
    return clamp(a + b, 0.0, 1.0);
}

// ---------------- ink noise ----------------
float hash31(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash31(i + vec3(0.0, 0.0, 0.0)), hash31(i + vec3(1.0, 0.0, 0.0)), f.x),
                   mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
               mix(mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x),
                   mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// ridged fbm: sharp crests read as bristle lines, not soft clouds
float bristle(vec3 p) {
    float sum  = 0.0;
    float amp  = 0.5;
    float norm = 0.0;
    for (int o = 0; o < BRUSH_OCTAVES; o++) {
        float n = vnoise(p);
        n = 1.0 - abs(n * 2.0 - 1.0);   // ridge
        sum  += n * amp;
        norm += amp;
        p     = p * 2.17 + vec3(19.3, 7.1, 33.7);
        amp  *= 0.55;
    }
    return sum / max(norm, 1e-4);
}

/* DRAWBUFFERS:0 */
void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);

    vec3  albedo = texture2D(colortex0, texcoord).rgb;
    vec4  data1  = texture2D(colortex1, texcoord);
    vec2  lm     = clamp(data1.rg, 0.0, 1.0);
    float flag   = data1.b;
    float depth  = texture2D(depthtex0, texcoord).r;

    bool  isSky       = (flag > 0.25 && flag < 0.75) || depth >= 1.0;
    bool  isCelestial = flag >= 0.75;

    float dist = linearDepth(depth);

    // ---------- brush coordinates ----------
    // screen-space = silkscreen print (ink on the glass)
    // world-space  = paint stuck to the blocks, slides with them as you walk
    float aspect = viewWidth / viewHeight;
    float ca = 0.9131, sa = 0.4077;                 // ~24 deg stroke angle
    vec2 sc = vec2(texcoord.x * aspect * ca - texcoord.y * sa,
                   texcoord.x * aspect * sa + texcoord.y * ca);
    sc.y *= mix(1.0, 0.15, BRUSH_STREAK);           // stretch along the stroke
    vec3 screenC = vec3(sc * 110.0, 0.0) * BRUSH_SCALE;

    vec3 worldC = screenC;
    if (!isSky && !isCelestial) {
        vec4 ndc  = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        vec4 view = gbufferProjectionInverse * ndc;
        view.xyz /= view.w;
        vec3 rel  = (gbufferModelViewInverse * vec4(view.xyz, 1.0)).xyz;
        // mod() keeps float precision sane far from spawn; pattern wraps at 1024 blocks
        vec3 wp   = rel + mod(cameraPosition, 1024.0);
        wp.y     *= mix(1.0, 0.30, BRUSH_STREAK);
        worldC    = wp * 4.5 * BRUSH_SCALE;
    }

    float dry;
    if (WORLD_LOCK >= 0.999)      dry = bristle(worldC);
    else if (WORLD_LOCK <= 0.001) dry = bristle(screenC);
    else                          dry = mix(bristle(screenC), bristle(worldC), WORLD_LOCK);

    float grit  = vnoise(mix(screenC, worldC, WORLD_LOCK) * 3.1);
    float dryc  = smoothstep(0.28, 0.78, dry);
    float gritc = smoothstep(0.35, 0.75, grit);

    // ---------- night / weather modifiers ----------
    float night = smoothstep(12200.0, 13800.0, float(worldTime))
                * (1.0 - smoothstep(22200.0, 23600.0, float(worldTime)));
    float dreadMod = clamp(DREAD + night * NIGHT_BOOST * 0.35 + rainStrength * 0.10, 0.0, 1.0);
    float beat = heartbeat(frameTimeCounter);

    // ---------- deferred lighting ----------
    vec3 color;
    if (isSky || isCelestial) {
        color = albedo;
        if (isSky) {
            float horizon = 1.0 - clamp(abs(texcoord.y - 0.5) * 2.2, 0.0, 1.0);
            vec3 dead = mix(vec3(0.004, 0.002, 0.003),
                            vec3(0.075, 0.006, 0.010), horizon * horizon);
            color = mix(color, dead, SKY_DEATH);
        }
    } else {
        float bl = pow(lm.x, 2.6);
        float sl = pow(lm.y, 3.4);

        vec3 torch = mix(vec3(1.00, 0.72, 0.45),
                         vec3(1.00, 0.24, 0.07), TORCH_WARMTH) * bl * 1.75;
        vec3 sky   = mix(vec3(0.30, 0.33, 0.40),
                         vec3(0.11, 0.10, 0.13), SKY_DEATH) * sl * (0.85 - night * 0.55);

        vec3 floorLight = vec3(0.016, 0.012, 0.014)
                        * (0.4 + AMBIENT_FLOOR * 4.0)
                        * (0.5 + VISIBILITY);

        vec3 light = torch + sky + floorLight;
        light *= mix(0.55, 1.85, VISIBILITY);
        light += nightVision * 0.35;

        color = albedo * light;
    }

    // ---------- depth outline ----------
    float edge = 0.0;
    if (!isSky && !isCelestial && OUTLINE > 0.001) {
        vec2 o = px * OUTLINE_WIDTH;
        float d0 = dist;
        float dl = linearDepth(texture2D(depthtex0, texcoord + vec2(-o.x, 0.0)).r);
        float dr = linearDepth(texture2D(depthtex0, texcoord + vec2( o.x, 0.0)).r);
        float du = linearDepth(texture2D(depthtex0, texcoord + vec2(0.0, -o.y)).r);
        float dd = linearDepth(texture2D(depthtex0, texcoord + vec2(0.0,  o.y)).r);

        float diff = max(max(abs(dl - d0), abs(dr - d0)),
                         max(abs(du - d0), abs(dd - d0)));
        edge = clamp(diff / (d0 * 0.055 + 0.06) - 0.35, 0.0, 1.0);
        edge *= 1.0 - smoothstep(DARK_RANGE * 0.7, DARK_RANGE * 1.6, d0);

        // a dry pen skips: break the line instead of drawing it clean
        edge *= mix(1.0, smoothstep(0.18, 0.70, dryc) * 1.20, EDGE_ROUGH);
        edge = clamp(edge, 0.0, 1.0);
    }

    // ---------- creeping darkness ----------
    float fogT = isCelestial ? 0.0
                             : 1.0 - exp(-pow(max(dist, 0.0) / DARK_RANGE, 2.2));
    if (isSky) fogT = min(fogT, SKY_DEATH * 0.85);
    fogT = clamp(fogT + blindness * 0.7 + float(isEyeInWater == 1) * 0.15, 0.0, 1.0);
    // the fog front eats in unevenly, like ink soaking outward
    fogT = clamp(fogT + (dryc - 0.5) * DRYBRUSH * 0.16 * (4.0 * fogT * (1.0 - fogT)), 0.0, 1.0);
    color = mix(color, vec3(0.0), fogT);

    color += vec3(1.0, 0.045, 0.035) * edge * OUTLINE * (0.85 + beat * PULSE * 0.5);

    // ---------- tone ramp ----------
    float l = luma(color);
    float t = clamp(pow(l * 1.35, 0.72), 0.0, 1.0);

    float cut = smoothstep(0.055, 0.075, l);
    t = mix(t, cut, HARD_CUT);

    if (POSTERIZE > 0.001) {
        float steps = mix(64.0, 4.0, POSTERIZE);
        t = mix(t, floor(t * steps + 0.5) / steps, POSTERIZE);
    }

    // ==================== DRY BRUSH ====================
    // Every term below is MULTIPLICATIVE on t (except the spatter), which is the
    // whole trick: t == 0 stays 0, so the ink can never fog up the pure black.
    if (DRYBRUSH > 0.001) {
        float db = DRYBRUSH;

        // 1) the stroke thins and thickens. Solid cores are protected by w, so
        //    only the rim of each red mass gets chewed into a ragged edge.
        float w = 1.0 - smoothstep(0.62, 0.98, t);
        t *= 1.0 + (dryc - INK_BLEED) * db * 2.0 * w;

        // 2) bristle skip: sparse black hairlines torn through the ink
        float hole = smoothstep(0.62, 0.97, (1.0 - dryc) * (0.6 + 0.4 * (1.0 - gritc)));
        t *= 1.0 - hole * db * BRISTLE_SKIP * 0.9;

        // 3) fine grit so flat fills never read as vector art
        t *= 1.0 - (1.0 - gritc) * db * 0.10;

        // 4) spatter flicked off the edge of the stroke
        float spray = smoothstep(0.88, 0.995, grit) * smoothstep(0.02, 0.25, t + 0.05);
        t = max(t, spray * db * SPECKLE * 1.2);

        t = clamp(t, 0.0, 1.0);
    }
    // ===================================================

    vec3 dreadCol = vec3(t,
                         pow(t, 3.2) * mix(0.55, 0.06, RED_HUE),
                         pow(t, 4.6) * mix(0.50, 0.04, RED_HUE));
    dreadCol *= 0.65 + 0.85 * t;

    color = mix(color, dreadCol, dreadMod);

    color.r += beat * PULSE * 0.035 * (0.3 + t);

    // ---------- debug views ----------
    #if DEBUG_VIEW == 1
        color = albedo;
    #elif DEBUG_VIEW == 2
        color = vec3(lm.x, lm.y, 0.0);
    #elif DEBUG_VIEW == 3
        color = vec3(clamp(dist / DARK_RANGE, 0.0, 1.0));
    #elif DEBUG_VIEW == 4
        color = vec3(edge);
    #elif DEBUG_VIEW == 5
        color = vec3(flag, float(isSky), float(isCelestial));
    #elif DEBUG_VIEW == 6
        color = vec3(dryc, gritc, 0.0);
    #endif

    gl_FragData[0] = vec4(color, 1.0);
}
