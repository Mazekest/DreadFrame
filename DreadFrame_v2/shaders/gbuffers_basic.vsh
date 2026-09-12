#version 120
// DREADFRAME :: gbuffers_basic  (ultimate fallback: lines, leashes, everything unclaimed)

varying vec4 vColor;
varying vec2 lmcoord;

void main() {
    gl_Position = ftransform();
    vColor   = gl_Color;
    lmcoord  = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
}
