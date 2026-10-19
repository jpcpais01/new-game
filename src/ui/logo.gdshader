shader_type canvas_item;
// Logo shimmer: a cyan-to-magenta gradient across the screen with a light
// sweep passing over the letters.

void fragment() {
	vec4 c = COLOR * texture(TEXTURE, UV);
	float x = SCREEN_UV.x;
	vec3 grad = mix(vec3(0.35, 0.95, 1.0), vec3(1.0, 0.35, 0.85), smoothstep(0.15, 0.85, x));
	float sweep = exp(-pow((x - fract(TIME * 0.22) * 1.8 + 0.4) * 9.0, 2.0));
	vec3 rgb = c.rgb * grad * 1.15 + vec3(sweep) * 0.9 * c.a;
	COLOR = vec4(rgb, c.a);
}
