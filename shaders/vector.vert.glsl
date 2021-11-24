#version 330 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aUv;

uniform vec2 uViewportSize;
uniform vec2 uTranslate;

out vec2 uv;

void main() {
	gl_Position = vec4(
		(aPos + uTranslate) / uViewportSize * vec2(2, -2) + vec2(-1, 1),
		0.0, 1.0);
	uv = aUv;
}
