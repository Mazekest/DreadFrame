#version 120
// DREADFRAME :: gbuffers_skytextured  (sun, moon, custom sky, end sky)

varying vec4 vColor;
varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    vColor   = gl_Color;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
