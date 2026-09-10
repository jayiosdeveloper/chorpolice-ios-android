shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col : source_color = vec4(0.3, 0.9, 0.45, 1.0);
uniform vec4 bg : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float alpha_mul = 1.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float ring = smoothstep(0.66, 0.70, r) * (1.0 - smoothstep(0.92, 0.96, r));
	float a = atan(p.x, -p.y);
	if (a < 0.0) { a += 6.2831853; }
	float filled = 1.0 - step(fill * 6.2831853, a);
	vec3 c = mix(bg.rgb, col.rgb, filled);
	float al = ring * mix(bg.a, col.a, filled);
	float disc = 1.0 - smoothstep(0.60, 0.64, r);
	c = mix(c, vec3(0.03, 0.05, 0.08), disc);
	al = max(al, disc * 0.62);
	float rim = smoothstep(0.96, 0.98, r) * (1.0 - smoothstep(0.99, 1.0, r));
	al = max(al, rim * 0.35);
	ALBEDO = c;
	ALPHA = al * alpha_mul;
}
