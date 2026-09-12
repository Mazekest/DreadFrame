#version 120
// DREADFRAME :: gbuffers_skybasic  (sky gradient, horizon, void)

varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    vColor = gl_Color;
}
