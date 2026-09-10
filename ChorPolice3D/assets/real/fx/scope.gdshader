shader_type canvas_item;
// Sniper scope glass: outside the lens the world stays visible but dark + blurred (like
// peripheral vision past a real scope), a metallic bezel, lens tint and an inner shadow.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius = 0.46;      // lens radius as a fraction of the shorter screen side
uniform float aspect = 1.777;
uniform float lens_tint = 0.06;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	float r = length(p) / radius;          // 1.0 at the lens edge
	vec4 c = texture(screen_tex, uv);
	vec3 col = c.rgb;
	if (r > 1.0) {
		// blurred, darkened, slightly desaturated periphery
		vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
		vec3 acc = vec3(0.0);
		float s = 4.0;
		acc += textureLod(screen_tex, uv + vec2( px.x,  0.0) * s, 2.0).rgb;
		acc += textureLod(screen_tex, uv + vec2(-px.x,  0.0) * s, 2.0).rgb;
		acc += textureLod(screen_tex, uv + vec2( 0.0,  px.y) * s, 2.0).rgb;
		acc += textureLod(screen_tex, uv + vec2( 0.0, -px.y) * s, 2.0).rgb;
		acc += textureLod(screen_tex, uv, 2.0).rgb;
		col = acc / 5.0;
		float g = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, vec3(g), 0.45) * 0.30;
		// bezel: dark metal ring just outside the lens with a thin bright rim
		float bez = 1.0 - smoothstep(1.0, 1.075, r);
		vec3 metal = vec3(0.06, 0.065, 0.07) + 0.10 * smoothstep(1.055, 1.07, r) * (1.0 - smoothstep(1.07, 1.085, r));
		col = mix(col, metal, bez);
	} else {
		// lens: subtle blue tint + inner shadow toward the edge + faint glass sheen
		col = mix(col, vec3(0.55, 0.75, 1.0), lens_tint * (0.5 + 0.5 * r));
		col *= 1.0 - 0.55 * smoothstep(0.78, 1.0, r);
		float sheen = smoothstep(0.86, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
		col += vec3(0.35, 0.6, 0.9) * sheen * 0.18;
	}
	COLOR = vec4(col, 1.0);
}
