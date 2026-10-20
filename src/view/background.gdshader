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
uniform float gauntlet = 0.0;
// Sectors: the Abyss (black holes) and Corona (a sun at the centre).
uniform float abyss = 0.0;
uniform float corona = 0.0;
uniform vec4 maws[3];          // x, y, grip (0..1.5), unused
uniform float maw_core = 70.0;
uniform float sun_r = 120.0;
uniform float sun_heat = 0.0;  // a flare building, 0..1
// The Shardfield: a glacier-blue sky with a triangular lattice of light.
uniform float shard = 0.0;

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
	// The Abyss: black holes bend the grid towards them like lenses.
	float shadow = 1.0;
	vec3 disk = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		vec4 m = maws[i];
		if (m.z <= 0.0) {
			continue;
		}
		vec2 d = w - m.xy;
		float dist = max(length(d), 1.0);
		float grip = min(m.z, 1.5);
		g += d / dist * grip * 9000.0 / (dist + 90.0) * smoothstep(900.0, 200.0, dist);
		float core = maw_core * (0.6 + 0.4 * min(grip, 1.0));
		shadow *= smoothstep(core * 0.75, core * 1.25, dist);
		// Accretion disk: a spiral of gold into violet, and a thin photon ring.
		float ang = atan(d.y, d.x);
		float spiral = pow(0.5 + 0.5 * sin(ang * 3.0 - log(dist) * 7.0 + t * 2.6), 3.0);
		float diskm = smoothstep(core * 0.9, core * 1.6, dist) * exp(-(dist - core) / (150.0 * grip + 1.0));
		vec3 dc = mix(vec3(1.0, 0.72, 0.36), vec3(0.62, 0.32, 1.0), smoothstep(core, core * 3.5, dist));
		disk += dc * spiral * diskm * 0.9 * min(grip, 1.0);
		disk += vec3(0.9, 0.75, 1.0) * exp(-abs(dist - core * 1.18) / 5.0) * 1.3 * min(grip, 1.0);
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
	if (shard > 0.0) {
		// Three families of lines at 60 degrees: a lattice of triangles, like
		// the facets of the crystals growing out of it.
		vec2 n1 = vec2(0.8660254, 0.5);
		vec2 n2 = vec2(-0.8660254, 0.5);
		float c2 = cell * 1.2;
		float l0 = abs(fract(g.y / c2 + 0.5) - 0.5) * c2;
		float l1 = abs(fract(dot(g, n1) / c2 + 0.5) - 0.5) * c2;
		float l2 = abs(fract(dot(g, n2) / c2 + 0.5) - 0.5) * c2;
		float tri = smoothstep(1.8, 0.0, min(l0, min(l1, l2)) * zoom);
		float c4 = c2 * 4.0;
		float m0 = abs(fract(g.y / c4 + 0.5) - 0.5) * c4;
		float m1 = abs(fract(dot(g, n1) / c4 + 0.5) - 0.5) * c4;
		float m2 = abs(fract(dot(g, n2) / c4 + 0.5) - 0.5) * c4;
		float tmaj = smoothstep(2.6, 0.2, min(m0, min(m1, m2)) * zoom);
		minor = mix(minor, tri, shard);
		major = mix(major, tmaj, shard);
		dots *= 1.0 - shard;
	}

	// Nebula.
	float n1 = fbm(w * 0.0009 + vec2(t * 0.006, -t * 0.004));
	float n2 = fbm(w * 0.0016 - vec2(3.1, t * 0.01));
	vec3 col = vec3(0.012, 0.01, 0.032);
	col += vec3(0.16, 0.03, 0.24) * pow(n1, 3.0) * 1.6;
	col += vec3(0.0, 0.09, 0.16) * pow(n2, 3.2) * 1.4;
	// The Afterdark: the nebula bleeds crimson and a dark corona breathes.
	col = mix(col, vec3(0.03, 0.004, 0.012) + vec3(0.32, 0.02, 0.1) * pow(n1, 2.6) * 1.8
			+ vec3(0.14, 0.0, 0.2) * pow(n2, 3.0) * 1.4, night);

	// The Gauntlet: an amber coliseum, rings of light around the centre like
	// the tiers of an arena, turning slowly.
	col = mix(col, vec3(0.03, 0.016, 0.01) + vec3(0.3, 0.14, 0.03) * pow(n1, 2.8) * 1.7
			+ vec3(0.2, 0.04, 0.12) * pow(n2, 3.0) * 1.3, gauntlet);
	float rr = length(w);
	float tier = abs(fract(rr / 300.0) - 0.5) * 300.0;
	float spokes = 0.6 + 0.4 * sin(atan(w.y, w.x) * 16.0 + t * 0.25);
	col += vec3(1.0, 0.62, 0.22) * smoothstep(3.0, 0.0, tier * zoom) * 0.14 * spokes * gauntlet
			* smoothstep(arena_r, arena_r - 200.0, rr);

	// Stars (two parallax depths).
	vec2 s1 = (cam * 0.35 + sp) / 7.0;
	float st = step(0.996, hash(floor(s1))) * smoothstep(0.5, 0.0, length(fract(s1) - 0.5));
	vec2 s2 = (cam * 0.6 + sp) / 11.0;
	st += step(0.997, hash(floor(s2) + 7.0)) * smoothstep(0.5, 0.0, length(fract(s2) - 0.5)) * 0.7;
	col += vec3(0.7, 0.8, 1.0) * st * (0.5 + 0.5 * sin(t * 2.0 + hash(floor(s1)) * 40.0));

	// The Abyss: a deep indigo sea with teal currents.
	col = mix(col, vec3(0.008, 0.008, 0.03) + vec3(0.08, 0.04, 0.26) * pow(n1, 2.8) * 1.8
			+ vec3(0.0, 0.14, 0.18) * pow(n2, 3.0) * 1.5, abyss * (1.0 - night));
	// The Shardfield: deep glacier blue with ribbons of rose and teal light.
	float rib = pow(0.5 + 0.5 * sin(w.x * 0.0021 + w.y * 0.0013 + n1 * 5.0 + t * 0.15), 6.0);
	col = mix(col, vec3(0.006, 0.016, 0.034) + vec3(0.03, 0.14, 0.24) * pow(n1, 2.6) * 1.8
			+ vec3(0.22, 0.05, 0.2) * pow(n2, 3.0) * 1.4 + vec3(0.05, 0.22, 0.24) * rib * n2 * 0.6,
			shard * (1.0 - night));
	// Corona: an ember sky around a dying sun.
	col = mix(col, vec3(0.03, 0.008, 0.006) + vec3(0.34, 0.07, 0.02) * pow(n1, 2.7) * 1.7
			+ vec3(0.2, 0.02, 0.08) * pow(n2, 3.0) * 1.3, corona * (1.0 - night));

	vec3 gridc = mix(tint, vec3(1.0, 0.18, 0.42), clamp(danger, 0.0, 1.0));
	gridc = mix(gridc, vec3(0.7, 0.55, 1.0), abyss * 0.55);
	gridc = mix(gridc, vec3(1.0, 0.5, 0.2), corona * 0.6);
	gridc = mix(gridc, vec3(0.6, 0.9, 1.0), shard * 0.5);
	gridc = mix(gridc, vec3(1.0, 0.22, 0.55), night * 0.75);
	gridc = mix(gridc, vec3(1.0, 0.66, 0.26), gauntlet * 0.6);
	float near = exp(-pdist / 650.0);
	float lines = minor * 0.09 + major * 0.2 + dots * 0.22;
	col += gridc * lines * (0.3 + 1.1 * near + band_glow * 1.6);
	col += gridc * band_glow * 0.06;

	// Black holes swallow the light (and the grid) at their cores.
	col = col * shadow + disk;

	// The sun: a white-hot core, a turbulent corona that flares when it swells.
	if (corona > 0.0) {
		float sd = length(w);
		float sa = atan(w.y, w.x);
		float flame = fbm(vec2(sa * 3.0 + 7.0, sd * 0.012 - t * 0.9)) + 0.5 * fbm(vec2(sa * 7.0, sd * 0.03 - t * 1.7));
		float rim = sun_r * (1.0 + 0.08 * sun_heat + 0.03 * sin(t * 2.0));
		float body = smoothstep(rim + 3.0, rim - 3.0, sd);
		vec3 sunc = mix(vec3(1.0, 0.55, 0.18), vec3(1.25, 1.1, 0.85), smoothstep(rim, rim * 0.2, sd));
		float halo = exp(-max(sd - rim, 0.0) / (70.0 + 120.0 * sun_heat)) * (0.5 + 0.9 * flame);
		vec3 sun = sunc * body * (1.1 + 0.4 * sun_heat) + vec3(1.0, 0.42, 0.12) * halo * (0.55 + 0.75 * sun_heat);
		sun += vec3(1.0, 0.3, 0.1) * exp(-max(sd - rim, 0.0) / 600.0) * 0.12;
		col = col * (1.0 - body * corona) + sun * corona;
	}

	// Arena wall.
	float r = length(w);
	float edge = abs(r - arena_r);
	float pulse = 0.75 + 0.25 * sin(t * 3.0 + atan(w.y, w.x) * 12.0);
	vec3 wallc = mix(vec3(1.0, 0.28, 0.65), vec3(1.0, 0.7, 0.3), night);
	wallc = mix(wallc, vec3(1.0, 0.78, 0.35), gauntlet);
	wallc = mix(wallc, vec3(0.6, 0.45, 1.0), abyss * (1.0 - night));
	wallc = mix(wallc, vec3(1.0, 0.45, 0.2), corona * (1.0 - night));
	wallc = mix(wallc, vec3(0.5, 0.85, 1.0), shard * (1.0 - night));
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
