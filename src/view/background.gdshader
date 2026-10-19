shader_type canvas_item;
// The living arena floor: a nebula, a neon grid that warps under
// shockwaves and bends towards the player, the arena's energy wall,
// a danger tint and the hurt vignette. Screen-space; the camera is passed in.

uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 view_size = vec2(1080.0, 1920.0);
uniform float arena_r = 1500.0;
uniform vec4 waves[8];
uniform vec2 player = vec2(0.0);
uniform float danger = 0.0;
uniform float hurt = 0.0;
uniform float flash = 0.0;
uniform vec3 tint = vec3(0.35, 0.95, 1.0);
uniform float t = 0.0;
uniform float night = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 sp = (UV - 0.5) * view_size;
	vec2 w = cam + sp / zoom;

	// Grid warp: shockwave rings push the grid outwards.
	vec2 g = w;
	float band_glow = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 wv = waves[i];
		if (wv.w <= 0.0) {
			continue;
		}
		vec2 d = w - wv.xy;
		float dist = length(d);
		float x = (dist - wv.z) / 80.0;
		float band = exp(-x * x);
		g -= d / max(dist, 1.0) * band * wv.w * 42.0;
		band_glow += band * wv.w;
	}
	vec2 pd = w - player;
	float pdist = length(pd);
	g += pd / max(pdist, 1.0) * 26.0 * exp(-pdist / 150.0);

	float cell = 90.0;
	vec2 gc = abs(fract(g / cell + 0.5) - 0.5) * cell;
	float minor = smoothstep(1.8, 0.0, min(gc.x, gc.y) * zoom);
	vec2 gm = abs(fract(g / (cell * 4.0) + 0.5) - 0.5) * cell * 4.0;
	float major = smoothstep(2.6, 0.2, min(gm.x, gm.y) * zoom);
	float dots = smoothstep(5.0, 0.0, length(gc) * zoom);

	// Nebula.
	float n1 = fbm(w * 0.0009 + vec2(t * 0.006, -t * 0.004));
	float n2 = fbm(w * 0.0016 - vec2(3.1, t * 0.01));
	vec3 col = vec3(0.012, 0.01, 0.032);
	col += vec3(0.16, 0.03, 0.24) * pow(n1, 3.0) * 1.6;
	col += vec3(0.0, 0.09, 0.16) * pow(n2, 3.2) * 1.4;
	// The Afterdark: the nebula bleeds crimson and a dark corona breathes.
	col = mix(col, vec3(0.03, 0.004, 0.012) + vec3(0.32, 0.02, 0.1) * pow(n1, 2.6) * 1.8
			+ vec3(0.14, 0.0, 0.2) * pow(n2, 3.0) * 1.4, night);

	// Stars (two parallax depths).
	vec2 s1 = (cam * 0.35 + sp) / 7.0;
	float st = step(0.996, hash(floor(s1))) * smoothstep(0.5, 0.0, length(fract(s1) - 0.5));
	vec2 s2 = (cam * 0.6 + sp) / 11.0;
	st += step(0.997, hash(floor(s2) + 7.0)) * smoothstep(0.5, 0.0, length(fract(s2) - 0.5)) * 0.7;
	col += vec3(0.7, 0.8, 1.0) * st * (0.5 + 0.5 * sin(t * 2.0 + hash(floor(s1)) * 40.0));

	vec3 gridc = mix(tint, vec3(1.0, 0.18, 0.42), clamp(danger, 0.0, 1.0));
	gridc = mix(gridc, vec3(1.0, 0.22, 0.55), night * 0.75);
	float near = exp(-pdist / 650.0);
	float lines = minor * 0.09 + major * 0.2 + dots * 0.22;
	col += gridc * lines * (0.3 + 1.1 * near + band_glow * 1.6);
	col += gridc * band_glow * 0.06;

	// Arena wall.
	float r = length(w);
	float edge = abs(r - arena_r);
	float pulse = 0.75 + 0.25 * sin(t * 3.0 + atan(w.y, w.x) * 12.0);
	vec3 wallc = mix(vec3(1.0, 0.28, 0.65), vec3(1.0, 0.7, 0.3), night);
	if (r > arena_r) {
		col *= 0.3;
		float stripe = step(0.5, fract((w.x + w.y) / 70.0 - t * 0.4));
		col += wallc * 0.05 * stripe;
	}
	col += wallc * (exp(-edge / 6.0) * 1.8 * pulse + exp(-edge / 70.0) * 0.28);

	// Vignette, hurt and flash.
	vec2 vu = (UV - 0.5) * vec2(1.0, view_size.y / view_size.x) * 0.9;
	float vig = length(vu);
	col *= 1.0 - (0.5 + 0.25 * night * (0.8 + 0.2 * sin(t * 1.3))) * smoothstep(0.35, 1.1, vig);
	col += vec3(0.75, 0.02, 0.08) * hurt * smoothstep(0.3, 0.95, vig);
	col += vec3(0.6, 0.9, 1.0) * flash * 0.35;
	COLOR = vec4(col, 1.0);
}
