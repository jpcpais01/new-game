shader_type canvas_item;
// Screen-space impact pass, only drawn while it has something to do: a hit
// splits the image into red and blue fringes that kick outward from the ship,
// and an Overdrive punches a radial zoom blur out of the ship's position.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberr = 0.0;   // 0..1 chromatic split
uniform float zoom = 0.0;    // 0..1 radial blur
uniform vec2 center = vec2(0.5, 0.5);
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float t = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	float r = length(d);
	// A hit also jolts a few thin horizontal slices sideways.
	float band = floor(uv.y * 48.0 + floor(t * 30.0) * 7.0);
	float jolt = fract(sin(band * 12.9898) * 43758.5453);
	uv.x += (jolt > 0.86 ? (jolt - 0.93) * 0.09 : 0.0) * aberr * aberr;
	vec2 off = d * aberr * (0.006 + 0.022 * r);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	if (zoom > 0.001) {
		vec3 acc = col;
		float wsum = 1.0;
		for (int k = 1; k <= 6; k++) {
			float f = float(k) / 6.0;
			vec2 su = uv - d * f * 0.09 * zoom;
			float w = 1.0 - f * 0.6;
			acc += texture(screen_tex, su).rgb * w;
			wsum += w;
		}
		col = mix(col, acc / wsum, clamp(zoom * 1.4, 0.0, 1.0));
		col += tint * zoom * 0.12 * smoothstep(0.7, 0.0, r);
	}
	COLOR = vec4(col, 1.0);
}
