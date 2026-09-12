#version 120
// DREADFRAME :: gbuffers_skybasic

varying vec4 vColor;

/* DRAWBUFFERS:01 */
void main() {
    gl_FragData[0] = vec4(vColor.rgb, 1.0);
    // b = 0.5 -> "sky": composite must NOT apply block/sky lighting to this
    gl_FragData[1] = vec4(0.0, 1.0, 0.5, 1.0);
}
