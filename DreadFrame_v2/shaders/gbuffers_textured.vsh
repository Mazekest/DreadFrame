#version 120
// DREADFRAME :: gbuffers_textured

varying vec4 vColor;
varying vec2 texcoord;
varying vec2 lmcoord;

void main() {
    gl_Position = ftransform();
    vColor   = gl_Color;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
}
