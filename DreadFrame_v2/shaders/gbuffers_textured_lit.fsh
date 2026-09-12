#version 120
// DREADFRAME :: gbuffers_textured_lit

uniform sampler2D texture;

varying vec4 vColor;
varying vec2 texcoord;
varying vec2 lmcoord;

/* DRAWBUFFERS:01 */
void main() {
    vec4 albedo = texture2D(texture, texcoord) * vColor;
    if (albedo.a < 0.1) discard;

    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(lmcoord, 0.0, albedo.a);
}
