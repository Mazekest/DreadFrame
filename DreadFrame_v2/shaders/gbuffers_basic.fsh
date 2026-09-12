#version 120
// DREADFRAME :: gbuffers_basic

varying vec4 vColor;
varying vec2 lmcoord;

/* DRAWBUFFERS:01 */
void main() {
    // never assume buffer contents: write every channel, every frame.
    gl_FragData[0] = vec4(vColor.rgb, vColor.a);
    gl_FragData[1] = vec4(lmcoord, 0.0, vColor.a);   // b = 0.0 -> "normal geometry"
}
