#version 330 core
out vec4 FragColor;

uniform vec4 uColor;

in vec2 uv;

void main() {
	float v = uv.x / 2.0 + uv.y;
	if (v * v > uv.y) {
		discard;
	}
	FragColor = uColor;
}
