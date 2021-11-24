#version 330 core
out vec4 FragColor;

uniform sampler2D uSource;
uniform sampler2D uTarget;
uniform sampler2D uTexture;
uniform mat3 uTextureTransform;
uniform bool uTextureEnabled;
uniform vec4 uColor;
uniform vec2 uViewportSize;
uniform float uContrastFactor;

in vec2 uv;

void main() {
	vec4 sample = texture(uSource, uv);
	vec4 sampleL = texture(uSource, uv - vec2(1.0 / uViewportSize.x, 0));
	vec4 target = texture(uTarget, uv);

	float s0 = sampleL.z;
	float s1 = sampleL.x;
	float s2 = sample.y;
	float s3 = sample.z;
	float s4 = sample.x;

	float nr = mix(s1, (s0 + s1 + s2) / 3.0, uContrastFactor);
	float ng = mix(s2, (s1 + s2 + s3) / 3.0, uContrastFactor);
	float nb = mix(s3, (s2 + s3 + s4) / 3.0, uContrastFactor);
	vec4 color = uTextureEnabled
		? uColor * texture(uTexture, (inverse(uTextureTransform) * vec3(uv.x, -uv.y, 1.0)).xy * vec2(1, -1))
		: uColor;
	FragColor = vec4(
		color.r * nr*color.a + target.r * (1.0 - nr * color.a),
		color.g * ng*color.a + target.g * (1.0 - ng * color.a),
		color.b * nb*color.a + target.b * (1.0 - nb * color.a),
		1.0);
}
