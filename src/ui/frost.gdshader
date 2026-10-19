shader_type canvas_item;
// Frosted glass behind menus: blurred, darkened, tinted screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.0;
uniform vec4 tint : source_color = vec4(0.03, 0.02, 0.09, 0.62);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	c = mix(c, tint.rgb, tint.a);
	float vig = length(UV - 0.5);
	c *= 1.0 - 0.45 * smoothstep(0.2, 0.8, vig);
	COLOR = vec4(c, 1.0);
}
