#version 120
// DREADFRAME :: gbuffers_skytextured
// TRAP: vanilla draws sun/moon ADDITIVELY. shaders.properties forces normal
// blending, so we must supply a sane alpha ourselves or they vanish/blow out.

#define SUN_MOON_DIM 0.45 // [0.00 0.15 0.30 0.45 0.60 0.80 1.00]

uniform sampler2D texture;

varying vec4 vColor;
varying vec2 texcoord;

/* DRAWBUFFERS:01 */
void main() {
    vec4 albedo = texture2D(texture, texcoord) * vColor;

    // derive coverage from luminance: black pixels of the sun quad = transparent
    float lum = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
    float cov = clamp(lum * 1.4, 0.0, 1.0) * albedo.a;
    if (cov < 0.02) discard;

    vec3 disc = albedo.rgb * SUN_MOON_DIM;
    disc = mix(disc, vec3(dot(disc, vec3(0.333))) * vec3(1.0, 0.35, 0.28), 0.55);

    gl_FragData[0] = vec4(disc, cov);
    // b = 1.0 -> "emissive / celestial": no lighting, reduced fog
    gl_FragData[1] = vec4(0.0, 1.0, 1.0, cov);
}
