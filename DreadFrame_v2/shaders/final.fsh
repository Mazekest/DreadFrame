#version 120
// ============================================================
//  DREADFRAME :: final
//  lens + print layer: chromatic aberration, torn vignette, ink grain
// ============================================================

#define DEBUG_VIEW 0 // [0 1 2 3 4 5 6]

#define PULSE      0.50 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define GRAIN      0.30 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define GRAIN_SIZE 2.0  // [1.0 2.0 3.0 4.0 6.0]
#define CHROMA     0.40 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define VIGNETTE   0.50 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define TORN_EDGE  0.55 // [0.00 0.10 0.20 0.30 0.40 0.50 0.55 0.60 0.70 0.80 1.00]
#define JITTER     0.20 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define SCANLINE   0.20 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float blindness;
uniform int   isEyeInWater;

varying vec2 texcoord;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise2(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i + vec2(0.0, 0.0)), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
    float s = 0.0, a = 0.5, n = 0.0;
    for (int i = 0; i < 3; i++) {
        s += vnoise2(p) * a;
        n += a;
        p = p * 2.31 + vec2(11.7, 3.9);
        a *= 0.55;
    }
    return s / n;
}

float heartbeat(float t) {
    float p = fract(t * 0.72);
    float a = exp(-13.0 * p);
    float b = 0.55 * step(0.20, p) * exp(-15.0 * (p - 0.20));
    return clamp(a + b, 0.0, 1.0);
}

void main() {
    vec2 uv = texcoord;
    vec2 d  = uv - 0.5;
    float r2 = dot(d, d);
    float beat = heartbeat(frameTimeCounter);

#if DEBUG_VIEW == 0
    // ---- breathing lens jitter (low amplitude on purpose) ----
    float wob = sin(frameTimeCounter * 0.83) * 0.5 + sin(frameTimeCounter * 1.97) * 0.5;
    uv += d * wob * JITTER * 0.0018 * (0.5 + beat);

    // ---- chromatic aberration, strongest at the edges ----
    vec2 ca = d * r2 * CHROMA * 0.030 * (1.0 + beat * PULSE * 0.8);
    vec3 col;
    col.r = texture2D(colortex0, uv + ca).r;
    col.g = texture2D(colortex0, uv).g;
    col.b = texture2D(colortex0, uv - ca).b;

    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float aspect = viewWidth / viewHeight;

    // ---- torn vignette: the frame does not fade, it flakes away ----
    float ragged = (fbm2(vec2(uv.x * aspect, uv.y) * 7.5) - 0.5) * TORN_EDGE * 0.34;
    float fray   = (fbm2(vec2(uv.x * aspect, uv.y) * 23.0) - 0.5) * TORN_EDGE * 0.13;
    float rad    = length(d * vec2(aspect / max(aspect, 1.0), 1.0)) * 1.28 + ragged + fray;

    float vAmt = VIGNETTE * (0.75 + beat * PULSE * 0.55) + blindness * 0.4;
    float v = 1.0 - smoothstep(0.26, 0.86, rad);
    v = mix(v, step(0.5, v * 1.15), TORN_EDGE * 0.55);   // crumbly hard edge
    col *= mix(1.0, clamp(v, 0.0, 1.0), clamp(vAmt, 0.0, 1.0));
    col += vec3(0.30, 0.0, 0.0) * (1.0 - v) * beat * PULSE * 0.16;

    // ---- ink grain: chunky flecks, not per-pixel TV static ----
    vec2 gp = floor(uv * vec2(viewWidth, viewHeight) / GRAIN_SIZE);
    float n1 = hash21(gp + fract(frameTimeCounter) * 977.0);
    float n2 = hash21(gp * 0.37 + 41.3);
    float fleck = smoothstep(0.72, 0.99, n1 * 0.55 + n2 * 0.45);
    col += (n1 - 0.5) * GRAIN * 0.13 * (1.25 - lum * 0.85);
    col -= fleck * GRAIN * 0.22 * step(0.10, lum);          // dry pinholes in the ink
    col += vec3(1.0, 0.05, 0.04) * smoothstep(0.965, 1.0, n2) * GRAIN * 0.30 * step(lum, 0.10);

    // ---- scanlines ----
    float sl = 1.0 - SCANLINE * 0.16 * (0.5 + 0.5 * sin(uv.y * viewHeight * 3.14159));
    col *= sl;

    // ---- underwater: drowning red ----
    if (isEyeInWater == 1) col *= vec3(0.55, 0.20, 0.22);

    col = max(col, vec3(0.0));
#else
    vec3 col = texture2D(colortex0, uv).rgb;
#endif

    gl_FragColor = vec4(col, 1.0);
}
