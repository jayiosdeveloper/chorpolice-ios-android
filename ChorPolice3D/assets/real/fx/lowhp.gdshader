shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(c.rgb, vec3(g), amount * 0.85);
	float d = length(SCREEN_UV - vec2(0.5)) * 1.3;
	float vig = smoothstep(0.35, 1.05, d);
	col = mix(col, vec3(0.42, 0.03, 0.03), vig * amount * (0.55 + 0.25 * pulse));
	COLOR = vec4(col, 1.0);
}
