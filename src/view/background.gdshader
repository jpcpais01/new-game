shader_type canvas_item;
// Living backdrop: deep indigo gradient, drifting aurora blobs and twinkling
// star dust. `energy` (0..1) and `hue` are driven by the combo streak so the
// whole world lights up as you chain clears. Visual only.

uniform vec4 top_color : source_color = vec4(0.043, 0.039, 0.114, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.106, 0.067, 0.251, 1.0);
uniform float energy = 0.0;
uniform float hue = 0.0;
uniform float flash = 0.0;
uniform vec2 aspect = vec2(1.0, 1.78);

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * (0.035 + energy * 0.05);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	vec2 p = uv * aspect;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		vec2 c = vec2(0.5 + 0.48 * sin(t * (1.0 + fi * 0.37) + fi * 2.1),
				0.15 + fi * 0.24 + 0.1 * cos(t * (0.8 + fi * 0.21) + fi)) * aspect;
		float d = length(p - c);
		float r = 0.5 + 0.12 * fi;
		float b = exp(-d * d / (r * r * 0.3));
		vec3 bc = hsv2rgb(vec3(fract(hue + 0.66 + fi * 0.08), 0.75, 1.0));
		col += bc * b * (0.085 + 0.16 * energy);
	}
	vec2 sp = p * 34.0;
	vec2 g = floor(sp);
	float h = hash(g);
	float tw = 0.5 + 0.5 * sin(TIME * (0.8 + h * 2.5) + h * 40.0);
	float star = step(0.975, h) * tw * smoothstep(0.32, 0.0, length(fract(sp) - 0.5));
	col += vec3(0.85, 0.85, 1.0) * star * 0.5;
	float v = smoothstep(1.3, 0.3, length((uv - vec2(0.5, 0.42)) * vec2(1.1, 0.9)));
	col *= mix(0.55, 1.0, v);
	col += vec3(flash);
	COLOR = vec4(col, 1.0);
}
