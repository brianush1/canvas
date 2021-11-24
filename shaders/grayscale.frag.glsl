#version 330 core
out vec4 FragColor;

uniform sampler2D uSource;
uniform sampler2D uTexture;
uniform mat3 uTextureTransform;
uniform bool uTextureEnabled;
uniform vec4 uColor;

in vec2 uv;

void main() {
	vec4 sample = texture(uSource, uv);
	vec4 color = uTextureEnabled
		? uColor * texture(uTexture, (inverse(uTextureTransform) * vec3(uv.x, -uv.y, 1.0)).xy * vec2(1, -1))
		: uColor;
	FragColor = vec4(color.rgb, color.a * sample.x);
}
